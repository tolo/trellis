import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

/// Creates a minimal [Page] for testing feed generation.
Page makePage({
  String sourcePath = 'posts/hello.md',
  String url = '/posts/hello/',
  String section = 'posts',
  PageKind kind = PageKind.single,
  bool isDraft = false,
  Map<String, dynamic>? frontMatter,
  String content = '<p>Hello world content.</p>',
  String summary = 'Hello world summary.',
}) => Page(
  sourcePath: sourcePath,
  url: url,
  section: section,
  kind: kind,
  isDraft: isDraft,
  isBundle: false,
  bundleAssets: const [],
  frontMatter: frontMatter,
  content: content,
  summary: summary,
);

/// Creates a default [FeedGenerator] for testing.
FeedGenerator makeGenerator({
  FeedConfig? config,
  String baseUrl = 'https://example.com',
  String siteTitle = 'My Blog',
  String siteDescription = 'A blog about Dart',
  String contentDir = '/fake/content',
  String? siteAuthor,
}) => FeedGenerator(
  config: config ?? const FeedConfig(),
  baseUrl: baseUrl,
  siteTitle: siteTitle,
  siteDescription: siteDescription,
  contentDir: contentDir,
  siteAuthor: siteAuthor,
);

void main() {
  // ──────────────────────────────────────────────────
  // FeedConfig
  // ──────────────────────────────────────────────────
  group('FeedConfig', () {
    group('fromYaml', () {
      test('null returns null', () {
        expect(FeedConfig.fromYaml(null), isNull);
      });

      test('empty map returns default config', () {
        final cfg = FeedConfig.fromYaml(<String, dynamic>{});
        expect(cfg, isNotNull);
        expect(cfg!.atom, isTrue);
        expect(cfg.rss, isFalse);
        expect(cfg.limit, equals(20));
        expect(cfg.fullContent, isFalse);
        expect(cfg.sections, isEmpty);
      });

      test('non-Map (string) returns default config', () {
        final cfg = FeedConfig.fromYaml('invalid');
        expect(cfg, isNotNull);
        expect(cfg!.atom, isTrue);
      });

      test('parses all fields', () {
        final cfg = FeedConfig.fromYaml(<String, dynamic>{
          'atom': false,
          'rss': true,
          'limit': 10,
          'fullContent': true,
          'sections': ['posts', 'notes'],
        });
        expect(cfg!.atom, isFalse);
        expect(cfg.rss, isTrue);
        expect(cfg.limit, equals(10));
        expect(cfg.fullContent, isTrue);
        expect(cfg.sections, equals(['posts', 'notes']));
      });

      test('sections: non-list returns empty', () {
        final cfg = FeedConfig.fromYaml(<String, dynamic>{'sections': 'posts'});
        expect(cfg!.sections, isEmpty);
      });

      test('defaults when keys absent', () {
        final cfg = FeedConfig.fromYaml(<String, dynamic>{})!;
        expect(cfg.atom, isTrue);
        expect(cfg.rss, isFalse);
        expect(cfg.limit, equals(20));
        expect(cfg.fullContent, isFalse);
      });
    });
  });

  // ──────────────────────────────────────────────────
  // FeedGenerator — Atom generation
  // ──────────────────────────────────────────────────
  group('FeedGenerator — generateAtom()', () {
    late FeedGenerator gen;

    setUp(() => gen = makeGenerator());

    group('XML structure', () {
      test('starts with XML declaration', () {
        expect(gen.generateAtom([]), startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      });

      test('contains Atom namespace', () {
        expect(gen.generateAtom([]), contains('<feed xmlns="http://www.w3.org/2005/Atom">'));
      });

      test('ends with </feed>', () {
        expect(gen.generateAtom([]).trimRight(), endsWith('</feed>'));
      });

      test('contains <title>', () {
        expect(gen.generateAtom([]), contains('<title>My Blog</title>'));
      });

      test('contains <subtitle> when description non-empty', () {
        expect(gen.generateAtom([]), contains('<subtitle>A blog about Dart</subtitle>'));
      });

      test('omits <subtitle> when description empty', () {
        final g = makeGenerator(siteDescription: '');
        expect(g.generateAtom([]), isNot(contains('<subtitle>')));
      });

      test('contains <generator>', () {
        expect(gen.generateAtom([]), contains('<generator>Trellis Site</generator>'));
      });

      test('contains alternate link to site root', () {
        expect(gen.generateAtom([]), contains('rel="alternate"'));
      });

      test('contains self link to feed.xml', () {
        expect(gen.generateAtom([]), contains('href="https://example.com/feed.xml"'));
        expect(gen.generateAtom([]), contains('rel="self"'));
      });

      test('contains <id> with site URL', () {
        expect(gen.generateAtom([]), contains('<id>https://example.com/</id>'));
      });

      test('contains <updated>', () {
        expect(gen.generateAtom([]), contains('<updated>'));
      });
    });

    group('entries', () {
      late Page page;
      setUp(() {
        page = makePage(
          url: '/posts/hello/',
          frontMatter: {
            'title': 'Hello World',
            'date': DateTime.utc(2026, 3, 15),
            'author': 'Jane Doe',
          },
          summary: 'A first post.',
          content: '<p>Full content here.</p>',
        );
      });

      test('produces <entry> for matching page', () {
        expect(gen.generateAtom([page]), contains('<entry>'));
        expect(gen.generateAtom([page]), contains('</entry>'));
      });

      test('entry contains <title>', () {
        expect(gen.generateAtom([page]), contains('<title>Hello World</title>'));
      });

      test('entry contains <link> with full URL', () {
        expect(gen.generateAtom([page]), contains('href="https://example.com/posts/hello/"'));
      });

      test('entry contains <id> with full URL', () {
        expect(gen.generateAtom([page]), contains('<id>https://example.com/posts/hello/</id>'));
      });

      test('entry contains <updated> in RFC 3339 format', () {
        expect(gen.generateAtom([page]), contains('<updated>2026-03-15T00:00:00Z</updated>'));
      });

      test('entry contains <author><name>', () {
        expect(gen.generateAtom([page]), contains('<author>'));
        expect(gen.generateAtom([page]), contains('<name>Jane Doe</name>'));
      });

      test('default mode: entry contains <summary type="html">', () {
        expect(gen.generateAtom([page]), contains('<summary type="html">'));
        expect(gen.generateAtom([page]), contains('A first post.'));
      });

      test('fullContent mode: entry contains <content type="html"> with CDATA', () {
        final g = makeGenerator(config: const FeedConfig(fullContent: true));
        final xml = g.generateAtom([page]);
        expect(xml, contains('<content type="html">'));
        expect(xml, contains('<![CDATA['));
        expect(xml, contains('<p>Full content here.</p>'));
      });

      test('fullContent mode: no <summary> element', () {
        final g = makeGenerator(config: const FeedConfig(fullContent: true));
        expect(g.generateAtom([page]), isNot(contains('<summary')));
      });

      test('feed <updated> equals newest entry date', () {
        expect(
          gen.generateAtom([page]),
          contains('<updated>2026-03-15T00:00:00Z</updated>'),
        );
      });
    });

    group('URL construction', () {
      test('trailing slash in baseUrl avoided', () {
        final g = makeGenerator(baseUrl: 'https://example.com/');
        expect(g.generateAtom([]), isNot(contains('example.com//')));
      });

      test('empty baseUrl uses relative URLs', () {
        final g = makeGenerator(baseUrl: '');
        expect(g.generateAtom([]), contains('href="/feed.xml"'));
      });

      test('per-section self link uses /{section}/feed.xml', () {
        final xml = gen.generateAtom([], section: 'posts');
        expect(xml, contains('href="https://example.com/posts/feed.xml"'));
      });
    });

    group('filtering', () {
      test('draft pages excluded', () {
        final draft = makePage(isDraft: true, frontMatter: {'title': 'Draft'});
        expect(gen.generateAtom([draft]), isNot(contains('<entry>')));
      });

      test('pages with feed: false excluded', () {
        final hidden = makePage(frontMatter: {'title': 'Hidden', 'feed': false});
        expect(gen.generateAtom([hidden]), isNot(contains('<entry>')));
      });

      test('pages with feed: true explicitly included', () {
        final explicit = makePage(frontMatter: {'title': 'Explicit', 'feed': true});
        expect(gen.generateAtom([explicit]), contains('<entry>'));
      });

      test('pages without feed key included', () {
        final normal = makePage(frontMatter: {'title': 'Normal'});
        expect(gen.generateAtom([normal]), contains('<entry>'));
      });

      test('section listing pages excluded', () {
        final sectionPage = makePage(kind: PageKind.section, frontMatter: {'title': 'Posts'});
        expect(gen.generateAtom([sectionPage]), isNot(contains('<entry>')));
      });

      test('home page excluded', () {
        final home = makePage(kind: PageKind.home, frontMatter: {'title': 'Home'});
        expect(gen.generateAtom([home]), isNot(contains('<entry>')));
      });
    });

    group('section filtering', () {
      late List<Page> pages;
      setUp(() {
        pages = [
          makePage(url: '/posts/a/', section: 'posts', frontMatter: {'title': 'Post A'}),
          makePage(url: '/notes/b/', section: 'notes', frontMatter: {'title': 'Note B'}),
        ];
      });

      test('section filter includes only matching pages', () {
        final xml = gen.generateAtom(pages, section: 'posts');
        expect(xml, contains('Post A'));
        expect(xml, isNot(contains('Note B')));
      });

      test('config.sections non-empty filters site-wide feed', () {
        final g = makeGenerator(config: const FeedConfig(sections: ['posts']));
        final xml = g.generateAtom(pages);
        expect(xml, contains('Post A'));
        expect(xml, isNot(contains('Note B')));
      });

      test('empty config.sections includes all sections', () {
        final xml = gen.generateAtom(pages);
        expect(xml, contains('Post A'));
        expect(xml, contains('Note B'));
      });
    });

    group('sorting and limiting', () {
      test('pages sorted newest first', () {
        final older = makePage(url: '/posts/old/', frontMatter: {'title': 'Old', 'date': DateTime.utc(2026, 1, 1)});
        final newer = makePage(url: '/posts/new/', frontMatter: {'title': 'New', 'date': DateTime.utc(2026, 6, 1)});
        final xml = gen.generateAtom([older, newer]);
        expect(xml.indexOf('New'), lessThan(xml.indexOf('Old')));
      });

      test('pages limited to config.limit', () {
        final g = makeGenerator(config: const FeedConfig(limit: 2));
        final pages = List.generate(
          5,
          (i) => makePage(
            url: '/posts/p$i/',
            frontMatter: {'title': 'Page $i', 'date': DateTime.utc(2026, 1, i + 1)},
          ),
        );
        final xml = g.generateAtom(pages);
        expect('<entry>'.allMatches(xml).length, equals(2));
      });

      test('fewer pages than limit: all included', () {
        final g = makeGenerator(config: const FeedConfig(limit: 10));
        final pages = [
          makePage(frontMatter: {'title': 'One'}),
          makePage(url: '/posts/two/', frontMatter: {'title': 'Two'}),
        ];
        final xml = g.generateAtom(pages);
        expect('<entry>'.allMatches(xml).length, equals(2));
      });
    });

    group('date formatting', () {
      test('DateTime in front matter formats as RFC 3339', () {
        final page = makePage(frontMatter: {'date': DateTime.utc(2026, 3, 15, 10, 30, 0)});
        expect(gen.generateAtom([page]), contains('2026-03-15T10:30:00Z'));
      });

      test('date string in front matter parsed correctly', () {
        // Use an ISO 8601 string with Z suffix to avoid local-timezone shift
        final page = makePage(frontMatter: {'date': '2026-01-20T12:00:00Z'});
        expect(gen.generateAtom([page]), contains('2026-01-20T12:00:00Z'));
      });
    });

    group('section feed title', () {
      test('site-wide feed uses siteTitle', () {
        expect(gen.generateAtom([]), contains('<title>My Blog</title>'));
      });

      test('per-section feed title includes capitalized section', () {
        expect(gen.generateAtom([], section: 'posts'), contains('<title>My Blog - Posts</title>'));
      });
    });

    group('empty feed', () {
      test('no entries produces valid feed with metadata', () {
        final xml = gen.generateAtom([]);
        expect(xml, contains('<feed'));
        expect(xml, contains('<title>'));
        expect(xml, isNot(contains('<entry>')));
        expect(xml.trimRight(), endsWith('</feed>'));
      });
    });

    group('XML escaping', () {
      test('special characters in title escaped', () {
        final page = makePage(frontMatter: {'title': 'Hello & <World>'});
        final xml = gen.generateAtom([page]);
        expect(xml, contains('Hello &amp; &lt;World&gt;'));
      });

      test('special chars in summary escaped', () {
        final page = makePage(frontMatter: {'title': 'T'}, summary: 'A & B < C');
        final xml = gen.generateAtom([page]);
        expect(xml, contains('A &amp; B &lt; C'));
      });

      test('CDATA wrapping for full content', () {
        final g = makeGenerator(config: const FeedConfig(fullContent: true));
        final page = makePage(frontMatter: {'title': 'T'}, content: '<p>Hi</p>');
        expect(g.generateAtom([page]), contains('<![CDATA[<p>Hi</p>]]>'));
      });

      test('CDATA split when content contains ]]>', () {
        final g = makeGenerator(config: const FeedConfig(fullContent: true));
        final page = makePage(frontMatter: {'title': 'T'}, content: 'before]]>after');
        final xml = g.generateAtom([page]);
        // ]]> split correctly: <![CDATA[before]]]]><![CDATA[>after]]>
        expect(xml, contains('<![CDATA[before]]]]><![CDATA[>after]]>'));
      });
    });

    group('author fallback', () {
      test('page-level author used when present', () {
        final page = makePage(frontMatter: {'author': 'Alice', 'title': 'T'});
        expect(gen.generateAtom([page]), contains('<name>Alice</name>'));
      });

      test('site author fallback when no page author', () {
        final g = makeGenerator(siteAuthor: 'Site Author');
        final page = makePage(frontMatter: {'title': 'T'});
        expect(g.generateAtom([page]), contains('<name>Site Author</name>'));
      });

      test('Unknown fallback when no author anywhere', () {
        final page = makePage(frontMatter: {'title': 'T'});
        expect(gen.generateAtom([page]), contains('<name>Unknown</name>'));
      });

      test('empty page author falls back to site author', () {
        final g = makeGenerator(siteAuthor: 'Site Author');
        final page = makePage(frontMatter: {'author': '', 'title': 'T'});
        expect(g.generateAtom([page]), contains('<name>Site Author</name>'));
      });
    });
  });

  // ──────────────────────────────────────────────────
  // FeedGenerator — RSS generation
  // ──────────────────────────────────────────────────
  group('FeedGenerator — generateRss()', () {
    late FeedGenerator gen;
    setUp(() => gen = makeGenerator());

    group('XML structure', () {
      test('starts with XML declaration', () {
        expect(gen.generateRss([]), startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      });

      test('contains rss 2.0 element with atom namespace', () {
        expect(
          gen.generateRss([]),
          contains('<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">'),
        );
      });

      test('ends with </rss>', () {
        expect(gen.generateRss([]).trimRight(), endsWith('</rss>'));
      });

      test('contains <channel>', () {
        expect(gen.generateRss([]), contains('<channel>'));
        expect(gen.generateRss([]), contains('</channel>'));
      });

      test('contains <title>', () {
        expect(gen.generateRss([]), contains('<title>My Blog</title>'));
      });

      test('contains <description>', () {
        expect(gen.generateRss([]), contains('<description>A blog about Dart</description>'));
      });

      test('contains <link> to site root', () {
        expect(gen.generateRss([]), contains('<link>https://example.com/</link>'));
      });

      test('contains atom:link self-reference', () {
        expect(gen.generateRss([]), contains('<atom:link'));
        expect(gen.generateRss([]), contains('rel="self"'));
        expect(gen.generateRss([]), contains('type="application/rss+xml"'));
      });

      test('self link points to rss.xml', () {
        expect(gen.generateRss([]), contains('href="https://example.com/rss.xml"'));
      });

      test('contains <lastBuildDate>', () {
        expect(gen.generateRss([]), contains('<lastBuildDate>'));
      });

      test('contains <generator>', () {
        expect(gen.generateRss([]), contains('<generator>Trellis Site</generator>'));
      });
    });

    group('items', () {
      late Page page;
      setUp(() {
        page = makePage(
          url: '/posts/hello/',
          frontMatter: {
            'title': 'Hello World',
            'date': DateTime.utc(2026, 3, 15),
          },
          summary: 'A first post.',
          content: '<p>Full content.</p>',
        );
      });

      test('produces <item> for matching page', () {
        expect(gen.generateRss([page]), contains('<item>'));
        expect(gen.generateRss([page]), contains('</item>'));
      });

      test('item contains <title>', () {
        expect(gen.generateRss([page]), contains('<title>Hello World</title>'));
      });

      test('item contains <link> with full URL', () {
        expect(gen.generateRss([page]), contains('<link>https://example.com/posts/hello/</link>'));
      });

      test('item contains <guid isPermaLink="true">', () {
        expect(
          gen.generateRss([page]),
          contains('<guid isPermaLink="true">https://example.com/posts/hello/</guid>'),
        );
      });

      test('item contains <pubDate> in RFC 822 format', () {
        final xml = gen.generateRss([page]);
        expect(xml, contains('<pubDate>'));
        expect(xml, matches(RegExp(r'<pubDate>\w{3}, \d{2} \w{3} 2026 \d{2}:\d{2}:\d{2} GMT</pubDate>')));
      });

      test('default mode: <description> contains XML-escaped summary', () {
        final page2 = makePage(frontMatter: {'title': 'T'}, summary: 'A & B');
        final xml = gen.generateRss([page2]);
        expect(xml, contains('<description>A &amp; B</description>'));
      });

      test('fullContent mode: <description> contains escaped full content', () {
        final g = makeGenerator(config: const FeedConfig(fullContent: true));
        final xml = g.generateRss([page]);
        expect(xml, contains('&lt;p&gt;Full content.&lt;/p&gt;'));
      });
    });

    group('date formatting — RFC 822', () {
      test('lastBuildDate uses RFC 822 format', () {
        final page = makePage(frontMatter: {'date': DateTime.utc(2026, 3, 15)});
        final xml = gen.generateRss([page]);
        expect(
          xml,
          matches(RegExp(r'<lastBuildDate>\w{3}, \d{2} \w{3} 2026 \d{2}:\d{2}:\d{2} GMT</lastBuildDate>')),
        );
      });

      test('month names are English', () {
        final page = makePage(frontMatter: {'date': DateTime.utc(2026, 3, 1)});
        final xml = gen.generateRss([page]);
        expect(xml, contains('Mar'));
      });

      test('day names are English', () {
        final page = makePage(frontMatter: {'date': DateTime.utc(2026, 3, 16)}); // Monday
        final xml = gen.generateRss([page]);
        expect(xml, contains('Mon'));
      });
    });

    group('filtering', () {
      test('draft pages excluded', () {
        final draft = makePage(isDraft: true);
        expect(gen.generateRss([draft]), isNot(contains('<item>')));
      });

      test('feed: false excluded', () {
        final hidden = makePage(frontMatter: {'feed': false});
        expect(gen.generateRss([hidden]), isNot(contains('<item>')));
      });

      test('section listing pages excluded', () {
        final sectionPage = makePage(kind: PageKind.section);
        expect(gen.generateRss([sectionPage]), isNot(contains('<item>')));
      });
    });

    group('per-section self link', () {
      test('per-section self link uses /{section}/rss.xml', () {
        final xml = gen.generateRss([], section: 'posts');
        expect(xml, contains('href="https://example.com/posts/rss.xml"'));
      });
    });

    group('empty feed', () {
      test('no items produces valid RSS with channel metadata', () {
        final xml = gen.generateRss([]);
        expect(xml, contains('<channel>'));
        expect(xml, isNot(contains('<item>')));
        expect(xml.trimRight(), endsWith('</rss>'));
      });
    });
  });

  // ──────────────────────────────────────────────────
  // FeedGenerator — writeToOutput()
  // ──────────────────────────────────────────────────
  group('FeedGenerator — writeToOutput()', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('feed_test_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('atom-only config writes feed.xml but not rss.xml', () {
      final gen = makeGenerator(config: const FeedConfig(atom: true, rss: false));
      gen.writeToOutput([], tempDir.path);
      expect(File(p.join(tempDir.path, 'feed.xml')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'rss.xml')).existsSync(), isFalse);
    });

    test('rss-enabled config writes both feed.xml and rss.xml', () {
      final gen = makeGenerator(config: const FeedConfig(atom: true, rss: true));
      gen.writeToOutput([], tempDir.path);
      expect(File(p.join(tempDir.path, 'feed.xml')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'rss.xml')).existsSync(), isTrue);
    });

    test('per-section atom feed writes {section}/feed.xml', () {
      final gen = makeGenerator(config: const FeedConfig(sections: ['posts']));
      gen.writeToOutput([], tempDir.path);
      expect(File(p.join(tempDir.path, 'posts', 'feed.xml')).existsSync(), isTrue);
    });

    test('per-section rss feed writes {section}/rss.xml', () {
      final gen = makeGenerator(config: const FeedConfig(rss: true, sections: ['posts']));
      gen.writeToOutput([], tempDir.path);
      expect(File(p.join(tempDir.path, 'posts', 'rss.xml')).existsSync(), isTrue);
    });

    test('FeedResult.fileCount matches files written (atom only)', () {
      final gen = makeGenerator(config: const FeedConfig(atom: true, rss: false));
      final result = gen.writeToOutput([], tempDir.path);
      expect(result.fileCount, equals(1));
    });

    test('FeedResult.fileCount matches files written (atom + rss)', () {
      final gen = makeGenerator(config: const FeedConfig(atom: true, rss: true));
      final result = gen.writeToOutput([], tempDir.path);
      expect(result.fileCount, equals(2));
    });

    test('FeedResult.fileCount includes per-section feeds', () {
      final gen = makeGenerator(config: const FeedConfig(atom: true, rss: true, sections: ['posts']));
      final result = gen.writeToOutput([], tempDir.path);
      // site-wide atom + rss + posts/atom + posts/rss = 4
      expect(result.fileCount, equals(4));
    });

    test('FeedResult.feedUrls contains atom URL', () {
      final gen = makeGenerator(config: const FeedConfig(atom: true, rss: false));
      final result = gen.writeToOutput([], tempDir.path);
      expect(result.feedUrls['atom'], equals('/feed.xml'));
    });

    test('FeedResult.feedUrls contains rss URL when rss enabled', () {
      final gen = makeGenerator(config: const FeedConfig(atom: true, rss: true));
      final result = gen.writeToOutput([], tempDir.path);
      expect(result.feedUrls['rss'], equals('/rss.xml'));
    });

    test('FeedResult.feedUrls has no rss key when rss disabled', () {
      final gen = makeGenerator(config: const FeedConfig(atom: true, rss: false));
      final result = gen.writeToOutput([], tempDir.path);
      expect(result.feedUrls.containsKey('rss'), isFalse);
    });

    test('parent directories created for per-section feeds', () {
      final gen = makeGenerator(config: const FeedConfig(sections: ['posts', 'notes']));
      gen.writeToOutput([], tempDir.path);
      expect(Directory(p.join(tempDir.path, 'posts')).existsSync(), isTrue);
      expect(Directory(p.join(tempDir.path, 'notes')).existsSync(), isTrue);
    });
  });

  // ──────────────────────────────────────────────────
  // SiteConfig feeds integration (TI14)
  // ──────────────────────────────────────────────────
  group('SiteConfig feeds', () {
    test('factory constructor accepts feeds parameter', () {
      final config = SiteConfig(
        siteDir: '/my/site',
        feeds: const FeedConfig(atom: true, rss: true),
      );
      expect(config.feeds, isNotNull);
      expect(config.feeds!.rss, isTrue);
    });

    test('feeds defaults to null', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.feeds, isNull);
    });

    test('feeds.atom accessible', () {
      final config = SiteConfig(siteDir: '/my/site', feeds: const FeedConfig(atom: true, rss: false));
      expect(config.feeds!.atom, isTrue);
      expect(config.feeds!.rss, isFalse);
    });

    test('feeds with sections accessible', () {
      final config = SiteConfig(
        siteDir: '/my/site',
        feeds: const FeedConfig(sections: ['posts', 'notes']),
      );
      expect(config.feeds!.sections, equals(['posts', 'notes']));
    });
  });

  // ──────────────────────────────────────────────────
  // Template context injection (TI15)
  // ──────────────────────────────────────────────────
  group('template context feeds injection', () {
    test('SiteConfig with atom-only feeds has feeds.atom set', () {
      final config = SiteConfig(
        siteDir: '/my/site',
        feeds: const FeedConfig(atom: true, rss: false),
      );
      expect(config.feeds!.atom, isTrue);
      expect(config.feeds!.rss, isFalse);
    });

    test('SiteConfig with rss enabled has feeds.rss set', () {
      final config = SiteConfig(
        siteDir: '/my/site',
        feeds: const FeedConfig(atom: true, rss: true),
      );
      expect(config.feeds!.rss, isTrue);
    });

    test('feeds null when no feeds config', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.feeds, isNull);
    });
  });
}
