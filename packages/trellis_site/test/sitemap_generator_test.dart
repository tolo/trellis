import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

late String _testFixturesDir;

String fixture(String name) => p.join(_testFixturesDir, name);

/// Creates a minimal [Page] for testing.
Page makePage({
  String sourcePath = 'about.md',
  String url = '/about/',
  PageKind kind = PageKind.single,
  bool isDraft = false,
  Map<String, dynamic>? frontMatter,
}) => Page(
  sourcePath: sourcePath,
  url: url,
  section: '',
  kind: kind,
  isDraft: isDraft,
  isBundle: false,
  bundleAssets: const [],
  frontMatter: frontMatter,
);

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _testFixturesDir = p.join(packageRoot, 'test', 'test_fixtures');
  });

  group('SitemapGenerator XML structure', () {
    late SitemapGenerator gen;
    setUp(() => gen = SitemapGenerator(baseUrl: 'https://example.com', contentDir: '/fake'));

    test('starts with XML declaration', () {
      final xml = gen.generate([makePage()]);
      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    });

    test('contains urlset with sitemap namespace', () {
      final xml = gen.generate([makePage()]);
      expect(xml, contains('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'));
    });

    test('ends with </urlset>', () {
      final xml = gen.generate([makePage()]);
      expect(xml.trimRight(), endsWith('</urlset>'));
    });

    test('each page produces a <url> with <loc> and <lastmod>', () {
      final xml = gen.generate([
        makePage(frontMatter: {'date': DateTime(2026, 3, 15)}),
      ]);
      expect(xml, contains('<url>'));
      expect(xml, contains('<loc>'));
      expect(xml, contains('<lastmod>2026-03-15</lastmod>'));
      expect(xml, contains('</url>'));
    });

    test('empty page list produces valid sitemap with no <url> entries', () {
      final xml = gen.generate([]);
      expect(xml, contains('<urlset'));
      expect(xml, isNot(contains('<url>')));
      expect(xml, contains('</urlset>'));
    });
  });

  group('SitemapGenerator URL construction', () {
    test('baseUrl without trailing slash', () {
      final gen = SitemapGenerator(baseUrl: 'https://example.com', contentDir: '/fake');
      final xml = gen.generate([makePage(url: '/posts/hello/')]);
      expect(xml, contains('<loc>https://example.com/posts/hello/</loc>'));
    });

    test('baseUrl with trailing slash — no double slash in path', () {
      final gen = SitemapGenerator(baseUrl: 'https://example.com/', contentDir: '/fake');
      final xml = gen.generate([makePage(url: '/posts/hello/')]);
      expect(xml, contains('<loc>https://example.com/posts/hello/</loc>'));
      // Verify the path portion has no double slash (allow :// from protocol)
      expect(xml, isNot(contains('com//'))); // no double slash after domain
    });

    test('baseUrl with path', () {
      final gen = SitemapGenerator(baseUrl: 'https://example.com/blog', contentDir: '/fake');
      final xml = gen.generate([makePage(url: '/posts/hello/')]);
      expect(xml, contains('<loc>https://example.com/blog/posts/hello/</loc>'));
    });

    test('empty baseUrl uses page URL as-is', () {
      final gen = SitemapGenerator(baseUrl: '', contentDir: '/fake');
      final xml = gen.generate([makePage(url: '/posts/hello/')]);
      expect(xml, contains('<loc>/posts/hello/</loc>'));
    });

    test('home page URL / produces correct loc', () {
      final gen = SitemapGenerator(baseUrl: 'https://example.com', contentDir: '/fake');
      final xml = gen.generate([makePage(url: '/', kind: PageKind.home)]);
      expect(xml, contains('<loc>https://example.com/</loc>'));
    });
  });

  group('SitemapGenerator filtering', () {
    late SitemapGenerator gen;
    setUp(() => gen = SitemapGenerator(baseUrl: 'https://example.com', contentDir: '/fake'));

    test('draft pages are excluded', () {
      final xml = gen.generate([makePage(isDraft: true)]);
      expect(xml, isNot(contains('<url>')));
    });

    test('pages with sitemap: false are excluded', () {
      final xml = gen.generate([
        makePage(frontMatter: {'sitemap': false}),
      ]);
      expect(xml, isNot(contains('<url>')));
    });

    test('pages with sitemap: true (explicit) are included', () {
      final xml = gen.generate([
        makePage(frontMatter: {'sitemap': true}),
      ]);
      expect(xml, contains('<url>'));
    });

    test('pages without sitemap key in front matter are included', () {
      final xml = gen.generate([makePage(frontMatter: {})]);
      expect(xml, contains('<url>'));
    });

    test('mix: only non-draft, non-excluded pages included', () {
      final pages = [
        makePage(url: '/a/', isDraft: false),
        makePage(url: '/b/', isDraft: true),
        makePage(url: '/c/', frontMatter: {'sitemap': false}),
        makePage(url: '/d/', isDraft: false),
      ];
      final xml = gen.generate(pages);
      expect(xml, contains('/a/'));
      expect(xml, isNot(contains('/b/')));
      expect(xml, isNot(contains('/c/')));
      expect(xml, contains('/d/'));
    });

    test('PageKind.single included', () {
      final xml = gen.generate([makePage(kind: PageKind.single)]);
      expect(xml, contains('<url>'));
    });

    test('PageKind.section included', () {
      final xml = gen.generate([makePage(url: '/posts/', kind: PageKind.section)]);
      expect(xml, contains('/posts/'));
    });

    test('PageKind.home included', () {
      final xml = gen.generate([makePage(url: '/', kind: PageKind.home)]);
      expect(xml, contains('<url>'));
    });
  });

  group('SitemapGenerator lastmod resolution', () {
    late SitemapGenerator gen;
    setUp(() => gen = SitemapGenerator(baseUrl: 'https://example.com', contentDir: '/fake'));

    test('DateTime in front matter formats as YYYY-MM-DD', () {
      final xml = gen.generate([
        makePage(frontMatter: {'date': DateTime(2026, 3, 15)}),
      ]);
      expect(xml, contains('<lastmod>2026-03-15</lastmod>'));
    });

    test('DateTime with single-digit month and day pads correctly', () {
      final xml = gen.generate([
        makePage(frontMatter: {'date': DateTime(2026, 1, 5)}),
      ]);
      expect(xml, contains('<lastmod>2026-01-05</lastmod>'));
    });

    test('date string in front matter parses and formats as YYYY-MM-DD', () {
      final xml = gen.generate([
        makePage(frontMatter: {'date': '2026-03-10'}),
      ]);
      expect(xml, contains('<lastmod>2026-03-10</lastmod>'));
    });

    test('invalid date string falls back to file mtime', () {
      // Create a temp file so mtime fallback doesn't fall to current date
      final tmpDir = Directory.systemTemp.createTempSync('sitemap_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final tmpFile = File(p.join(tmpDir.path, 'about.md'))..writeAsStringSync('# About');

      final g = SitemapGenerator(baseUrl: '', contentDir: tmpDir.path);
      final xml = g.generate([
        makePage(sourcePath: 'about.md', frontMatter: {'date': 'not-a-date'}),
      ]);
      // Should produce a valid date (from mtime), not crash
      expect(xml, matches(RegExp(r'<lastmod>\d{4}-\d{2}-\d{2}</lastmod>')));
      expect(tmpFile.existsSync(), isTrue);
    });

    test('no date in front matter falls back to file mtime', () {
      final tmpDir = Directory.systemTemp.createTempSync('sitemap_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      File(p.join(tmpDir.path, 'post.md')).writeAsStringSync('# Post');

      final g = SitemapGenerator(baseUrl: '', contentDir: tmpDir.path);
      final xml = g.generate([makePage(sourcePath: 'post.md', frontMatter: {})]);
      expect(xml, matches(RegExp(r'<lastmod>\d{4}-\d{2}-\d{2}</lastmod>')));
    });

    test('no date and missing file falls back to current date', () {
      final g = SitemapGenerator(baseUrl: '', contentDir: '/nonexistent');
      final xml = g.generate([makePage(sourcePath: 'ghost.md', frontMatter: {})]);
      expect(xml, matches(RegExp(r'<lastmod>\d{4}-\d{2}-\d{2}</lastmod>')));
    });
  });

  group('SitemapGenerator XML escaping', () {
    test('& in URL is escaped to &amp;', () {
      final gen = SitemapGenerator(baseUrl: '', contentDir: '/fake');
      final xml = gen.generate([makePage(url: '/search?a=1&b=2')]);
      expect(xml, contains('&amp;'));
      expect(xml, isNot(contains('&b=2')));
    });
  });

  group('SitemapGenerator.writeToOutput', () {
    test('returns false and does not write file when no pages qualify', () {
      final tmpDir = Directory.systemTemp.createTempSync('sitemap_out_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final gen = SitemapGenerator(baseUrl: 'https://example.com', contentDir: '/fake');
      final result = gen.writeToOutput([makePage(isDraft: true)], tmpDir.path);

      expect(result, isFalse);
      expect(File(p.join(tmpDir.path, 'sitemap.xml')).existsSync(), isFalse);
    });

    test('returns true and writes sitemap.xml when pages qualify', () {
      final tmpDir = Directory.systemTemp.createTempSync('sitemap_out_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final gen = SitemapGenerator(baseUrl: 'https://example.com', contentDir: '/fake');
      final page = makePage(frontMatter: {'date': DateTime(2026, 3, 1)});
      final result = gen.writeToOutput([page], tmpDir.path);

      expect(result, isTrue);
      final sitemapFile = File(p.join(tmpDir.path, 'sitemap.xml'));
      expect(sitemapFile.existsSync(), isTrue);
      expect(sitemapFile.readAsStringSync(), contains('<loc>https://example.com/about/</loc>'));
    });

    test('returns false for empty page list', () {
      final tmpDir = Directory.systemTemp.createTempSync('sitemap_out_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final gen = SitemapGenerator(baseUrl: '', contentDir: '/fake');
      expect(gen.writeToOutput([], tmpDir.path), isFalse);
    });
  });
}
