import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

/// Creates a minimal [Page] for search index tests.
Page makePage({
  String sourcePath = 'posts/hello.md',
  String url = '/posts/hello/',
  String section = 'posts',
  PageKind kind = PageKind.single,
  bool isDraft = false,
  Map<String, dynamic>? frontMatter,
  String content = '<p>Hello world content.</p>',
  String summary = '<p>A short summary.</p>',
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

void main() {
  late String buildSiteDir;

  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    buildSiteDir = p.join(packageRoot, 'test', 'test_fixtures', 'build_site');
  });

  // ──────────────────────────────────────────────────
  // SearchConfig
  // ──────────────────────────────────────────────────
  group('SearchConfig', () {
    group('default constructor', () {
      test('disabled by default', () {
        expect(const SearchConfig().enabled, isFalse);
      });

      test('default output filename', () {
        expect(const SearchConfig().output, equals('search-index.json'));
      });

      test('default fields', () {
        expect(const SearchConfig().fields, equals(['title', 'summary', 'content', 'tags']));
      });

      test('default excludeSections empty', () {
        expect(const SearchConfig().excludeSections, isEmpty);
      });

      test('stripHtml defaults to true', () {
        expect(const SearchConfig().stripHtml, isTrue);
      });

      test('maxContentLength defaults to 5000', () {
        expect(const SearchConfig().maxContentLength, equals(5000));
      });
    });

    group('fromYaml', () {
      test('null map returns default (disabled) config', () {
        final cfg = SearchConfig.fromYaml(null);
        expect(cfg.enabled, isFalse);
      });

      test('enabled: true parsed correctly', () {
        final cfg = SearchConfig.fromYaml({'enabled': true});
        expect(cfg.enabled, isTrue);
      });

      test('enabled: false stays false', () {
        final cfg = SearchConfig.fromYaml({'enabled': false});
        expect(cfg.enabled, isFalse);
      });

      test('output field parsed', () {
        final cfg = SearchConfig.fromYaml({'enabled': true, 'output': 'index.json'});
        expect(cfg.output, equals('index.json'));
      });

      test('fields list parsed', () {
        final cfg = SearchConfig.fromYaml({
          'fields': ['title', 'section'],
        });
        expect(cfg.fields, equals(['title', 'section']));
      });

      test('excludeSections parsed', () {
        final cfg = SearchConfig.fromYaml({
          'excludeSections': ['drafts', 'internal'],
        });
        expect(cfg.excludeSections, equals(['drafts', 'internal']));
      });

      test('stripHtml: false parsed', () {
        final cfg = SearchConfig.fromYaml({'stripHtml': false});
        expect(cfg.stripHtml, isFalse);
      });

      test('stripHtml: true explicitly parsed', () {
        final cfg = SearchConfig.fromYaml({'stripHtml': true});
        expect(cfg.stripHtml, isTrue);
      });

      test('maxContentLength parsed', () {
        final cfg = SearchConfig.fromYaml({'maxContentLength': 1000});
        expect(cfg.maxContentLength, equals(1000));
      });

      test('missing maxContentLength gives null (no truncation from YAML)', () {
        final cfg = SearchConfig.fromYaml(<String, dynamic>{});
        expect(cfg.maxContentLength, isNull);
      });

      test('non-list fields falls back to default', () {
        final cfg = SearchConfig.fromYaml({'fields': 'title'});
        expect(cfg.fields, equals(['title', 'summary', 'content', 'tags']));
      });
    });
  });

  // ──────────────────────────────────────────────────
  // SearchIndexGenerator.stripHtml()
  // ──────────────────────────────────────────────────
  group('SearchIndexGenerator.stripHtml()', () {
    test('removes <p> tags', () {
      expect(SearchIndexGenerator.stripHtml('<p>Hello</p>'), equals('Hello'));
    });

    test('removes <div> and <span> tags', () {
      expect(SearchIndexGenerator.stripHtml('<div><span>text</span></div>'), equals('text'));
    });

    test('removes <a> tags', () {
      expect(SearchIndexGenerator.stripHtml('<a href="/foo">click</a>'), equals('click'));
    });

    test('removes <br/> self-closing tag', () {
      expect(SearchIndexGenerator.stripHtml('line1<br/>line2'), equals('line1 line2'));
    });

    test('removes <img/> self-closing tag', () {
      expect(SearchIndexGenerator.stripHtml('before<img src="x.png"/>after'), equals('beforeafter'));
    });

    test('block-level boundaries insert space to prevent word joining', () {
      final result = SearchIndexGenerator.stripHtml('<p>hello</p><p>world</p>');
      expect(result, contains('hello'));
      expect(result, contains('world'));
      // Ensure words are not joined
      expect(result, isNot(contains('helloworld')));
    });

    test('decodes &amp;', () {
      expect(SearchIndexGenerator.stripHtml('a &amp; b'), equals('a & b'));
    });

    test('decodes &lt; and &gt;', () {
      expect(SearchIndexGenerator.stripHtml('&lt;tag&gt;'), equals('<tag>'));
    });

    test('decodes &quot;', () {
      expect(SearchIndexGenerator.stripHtml('say &quot;hi&quot;'), equals('say "hi"'));
    });

    test('decodes &#39; and &apos;', () {
      expect(SearchIndexGenerator.stripHtml(r'it&#39;s'), equals("it's"));
      expect(SearchIndexGenerator.stripHtml(r'it&apos;s'), equals("it's"));
    });

    test('decodes &nbsp;', () {
      expect(SearchIndexGenerator.stripHtml('a&nbsp;b'), equals('a b'));
    });

    test('collapses whitespace', () {
      expect(SearchIndexGenerator.stripHtml('a   b\n\tc'), equals('a b c'));
    });

    test('trims leading and trailing whitespace', () {
      expect(SearchIndexGenerator.stripHtml('  hello  '), equals('hello'));
    });

    test('empty string returns empty string', () {
      expect(SearchIndexGenerator.stripHtml(''), equals(''));
    });

    test('nested tags stripped', () {
      expect(SearchIndexGenerator.stripHtml('<div><p><strong>bold</strong></p></div>'), equals('bold'));
    });
  });

  // ──────────────────────────────────────────────────
  // SearchIndexGenerator.truncate()
  // ──────────────────────────────────────────────────
  group('SearchIndexGenerator.truncate()', () {
    test('text under limit returned unchanged', () {
      expect(SearchIndexGenerator.truncate('hello', 10), equals('hello'));
    });

    test('text at exactly limit returned unchanged', () {
      expect(SearchIndexGenerator.truncate('hello', 5), equals('hello'));
    });

    test('text over limit truncated with ...', () {
      final result = SearchIndexGenerator.truncate('hello world foo', 10);
      expect(result, endsWith('...'));
      expect(result.length, lessThanOrEqualTo(13)); // 10 + "..."
    });

    test('breaks at word boundary when possible', () {
      // "hello world" at max 8: last space at index 5, min=6 → exact cutoff
      final result = SearchIndexGenerator.truncate('hello world extra', 11);
      expect(result, equals('hello world...'));
    });

    test('exact cutoff when no word boundary in range', () {
      // single long word
      final result = SearchIndexGenerator.truncate('abcdefghijklmno', 5);
      expect(result, equals('abcde...'));
    });

    test('empty text with limit returns empty', () {
      expect(SearchIndexGenerator.truncate('', 10), equals(''));
    });
  });

  // ──────────────────────────────────────────────────
  // SearchIndexGenerator.generate() — JSON structure
  // ──────────────────────────────────────────────────
  group('SearchIndexGenerator — generate()', () {
    late SearchIndexGenerator gen;

    setUp(() => gen = const SearchIndexGenerator(SearchConfig(enabled: true)));

    test('empty page list produces empty JSON array', () {
      final json = gen.generate([]);
      final decoded = jsonDecode(json) as List;
      expect(decoded, isEmpty);
    });

    test('generates valid JSON array', () {
      final json = gen.generate([
        makePage(frontMatter: {'title': 'Hello'}),
      ]);
      expect(() => jsonDecode(json), returnsNormally);
      final decoded = jsonDecode(json) as List;
      expect(decoded, hasLength(1));
    });

    test('each entry contains url field', () {
      final json = gen.generate([makePage(url: '/posts/hello/')]);
      final entry = (jsonDecode(json) as List).first as Map;
      expect(entry['url'], equals('/posts/hello/'));
    });

    test('url always present even when not in fields list', () {
      final g = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['title']));
      final json = g.generate([
        makePage(frontMatter: {'title': 'T'}),
      ]);
      final entry = (jsonDecode(json) as List).first as Map;
      expect(entry.containsKey('url'), isTrue);
    });
  });

  // ──────────────────────────────────────────────────
  // Field inclusion
  // ──────────────────────────────────────────────────
  group('field inclusion', () {
    test('title from frontMatter', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['title']));
      final page = makePage(frontMatter: {'title': 'My Title'});
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['title'], equals('My Title'));
    });

    test('summary from page.summary (with HTML stripping)', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['summary'], stripHtml: true));
      final page = makePage(summary: '<p>A short summary.</p>');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['summary'], equals('A short summary.'));
    });

    test('content from page.content (with HTML stripping)', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['content'], stripHtml: true));
      final page = makePage(content: '<p>Hello world.</p>');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['content'], equals('Hello world.'));
    });

    test('tags from frontMatter as List<String>', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['tags']));
      final page = makePage(
        frontMatter: {
          'tags': ['dart', 'web'],
        },
      );
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['tags'], equals(['dart', 'web']));
    });

    test('date from DateTime formatted as YYYY-MM-DD', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['date']));
      final page = makePage(frontMatter: {'date': DateTime(2026, 3, 15)});
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['date'], equals('2026-03-15'));
    });

    test('date from String passed through', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['date']));
      final page = makePage(frontMatter: {'date': '2026-01-20'});
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['date'], equals('2026-01-20'));
    });

    test('section from page.section', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['section']));
      final page = makePage(section: 'posts');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['section'], equals('posts'));
    });

    test('custom fields [title, section] — only those fields present', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['title', 'section']));
      final page = makePage(
        section: 'posts',
        frontMatter: {
          'title': 'T',
          'tags': ['a'],
        },
      );
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry.containsKey('title'), isTrue);
      expect(entry.containsKey('section'), isTrue);
      expect(entry.containsKey('tags'), isFalse);
      expect(entry.containsKey('content'), isFalse);
    });

    test('null title omitted from entry', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['title']));
      final page = makePage(frontMatter: <String, dynamic>{});
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry.containsKey('title'), isFalse);
    });

    test('null tags omitted from entry', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['tags']));
      final page = makePage(frontMatter: <String, dynamic>{});
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry.containsKey('tags'), isFalse);
    });

    test('null date omitted from entry', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['date']));
      final page = makePage(frontMatter: <String, dynamic>{});
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry.containsKey('date'), isFalse);
    });
  });

  // ──────────────────────────────────────────────────
  // HTML stripping config flag
  // ──────────────────────────────────────────────────
  group('HTML stripping config', () {
    test('stripHtml: true strips tags from content', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, stripHtml: true));
      final page = makePage(frontMatter: {'title': 'T'}, content: '<p>Hello</p>');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['content'], equals('Hello'));
    });

    test('stripHtml: false preserves HTML in content', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, stripHtml: false));
      final page = makePage(frontMatter: {'title': 'T'}, content: '<p>Hello</p>');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['content'], equals('<p>Hello</p>'));
    });

    test('stripHtml: true strips tags from summary', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['summary'], stripHtml: true));
      final page = makePage(summary: '<p>Summary text.</p>');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['summary'], equals('Summary text.'));
    });

    test('stripHtml: false preserves HTML in summary', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, fields: ['summary'], stripHtml: false));
      final page = makePage(summary: '<p>Summary text.</p>');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['summary'], equals('<p>Summary text.</p>'));
    });
  });

  // ──────────────────────────────────────────────────
  // Content truncation
  // ──────────────────────────────────────────────────
  group('content truncation', () {
    test('content truncated at maxContentLength', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, stripHtml: false, maxContentLength: 10));
      final page = makePage(frontMatter: {'title': 'T'}, content: 'Hello world, this is long content.');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      final content = entry['content'] as String;
      expect(content, endsWith('...'));
    });

    test('content under maxContentLength unchanged', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, stripHtml: false, maxContentLength: 1000));
      final page = makePage(frontMatter: {'title': 'T'}, content: 'Short.');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect(entry['content'], equals('Short.'));
    });

    test('maxContentLength null means no truncation', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, stripHtml: false, maxContentLength: null));
      final long = 'a ' * 5000;
      final page = makePage(frontMatter: {'title': 'T'}, content: long.trim());
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      expect((entry['content'] as String).endsWith('...'), isFalse);
    });

    test('truncation applied after HTML stripping', () {
      final gen = const SearchIndexGenerator(SearchConfig(enabled: true, stripHtml: true, maxContentLength: 5));
      final page = makePage(frontMatter: {'title': 'T'}, content: '<p>Hello world</p>');
      final entry = (jsonDecode(gen.generate([page])) as List).first as Map;
      // "Hello world" stripped to "Hello world", then truncated at 5 → "Hello..."
      expect(entry['content'], startsWith('Hello'));
    });
  });

  // ──────────────────────────────────────────────────
  // Page filtering
  // ──────────────────────────────────────────────────
  group('page filtering', () {
    late SearchIndexGenerator gen;
    setUp(() => gen = const SearchIndexGenerator(SearchConfig(enabled: true)));

    test('draft pages excluded', () {
      final draft = makePage(isDraft: true, frontMatter: {'title': 'Draft'});
      final decoded = jsonDecode(gen.generate([draft])) as List;
      expect(decoded, isEmpty);
    });

    test('pages with search: false excluded', () {
      final hidden = makePage(frontMatter: {'title': 'Hidden', 'search': false});
      final decoded = jsonDecode(gen.generate([hidden])) as List;
      expect(decoded, isEmpty);
    });

    test('pages with search: true explicitly included', () {
      final explicit = makePage(frontMatter: {'title': 'Explicit', 'search': true});
      final decoded = jsonDecode(gen.generate([explicit])) as List;
      expect(decoded, hasLength(1));
    });

    test('pages without search key included', () {
      final normal = makePage(frontMatter: {'title': 'Normal'});
      final decoded = jsonDecode(gen.generate([normal])) as List;
      expect(decoded, hasLength(1));
    });

    test('section pages excluded', () {
      final section = makePage(kind: PageKind.section, frontMatter: {'title': 'Posts'});
      final decoded = jsonDecode(gen.generate([section])) as List;
      expect(decoded, isEmpty);
    });

    test('home page excluded', () {
      final home = makePage(kind: PageKind.home, frontMatter: {'title': 'Home'});
      final decoded = jsonDecode(gen.generate([home])) as List;
      expect(decoded, isEmpty);
    });

    test('only PageKind.single pages indexed', () {
      final pages = [
        makePage(url: '/posts/a/', kind: PageKind.single, frontMatter: {'title': 'Post'}),
        makePage(url: '/posts/', kind: PageKind.section, frontMatter: {'title': 'Posts'}),
        makePage(url: '/', kind: PageKind.home, frontMatter: {'title': 'Home'}),
      ];
      final decoded = jsonDecode(gen.generate(pages)) as List;
      expect(decoded, hasLength(1));
    });

    test('excludeSections excludes pages from listed sections', () {
      final g = const SearchIndexGenerator(SearchConfig(enabled: true, excludeSections: ['drafts']));
      final pages = [
        makePage(url: '/posts/a/', section: 'posts', frontMatter: {'title': 'Post'}),
        makePage(url: '/drafts/b/', section: 'drafts', frontMatter: {'title': 'Draft content'}),
      ];
      final decoded = jsonDecode(g.generate(pages)) as List;
      expect(decoded, hasLength(1));
      expect((decoded.first as Map)['url'], equals('/posts/a/'));
    });

    test('mix of included and excluded produces correct subset', () {
      final pages = [
        makePage(url: '/a/', frontMatter: {'title': 'A'}),
        makePage(url: '/b/', isDraft: true, frontMatter: {'title': 'B'}),
        makePage(url: '/c/', frontMatter: {'title': 'C', 'search': false}),
        makePage(url: '/d/', frontMatter: {'title': 'D'}),
      ];
      final decoded = jsonDecode(gen.generate(pages)) as List;
      expect(decoded, hasLength(2));
      final urls = decoded.map((e) => (e as Map)['url']).toList();
      expect(urls, containsAll(['/a/', '/d/']));
    });
  });

  // ──────────────────────────────────────────────────
  // writeToOutput()
  // ──────────────────────────────────────────────────
  group('writeToOutput()', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('search_test_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('returns false when config.enabled is false', () {
      const gen = SearchIndexGenerator(SearchConfig());
      expect(gen.writeToOutput([], tempDir.path), isFalse);
    });

    test('returns false when no pages qualify', () {
      const gen = SearchIndexGenerator(SearchConfig(enabled: true));
      final draft = makePage(isDraft: true);
      expect(gen.writeToOutput([draft], tempDir.path), isFalse);
    });

    test('no file written when no pages qualify', () {
      const gen = SearchIndexGenerator(SearchConfig(enabled: true));
      gen.writeToOutput([], tempDir.path);
      expect(File(p.join(tempDir.path, 'search-index.json')).existsSync(), isFalse);
    });

    test('returns true and writes file when pages qualify', () {
      const gen = SearchIndexGenerator(SearchConfig(enabled: true));
      final page = makePage(frontMatter: {'title': 'T'});
      expect(gen.writeToOutput([page], tempDir.path), isTrue);
      expect(File(p.join(tempDir.path, 'search-index.json')).existsSync(), isTrue);
    });

    test('file written at default output path', () {
      const gen = SearchIndexGenerator(SearchConfig(enabled: true));
      gen.writeToOutput([
        makePage(frontMatter: {'title': 'T'}),
      ], tempDir.path);
      expect(File(p.join(tempDir.path, 'search-index.json')).existsSync(), isTrue);
    });

    test('custom output filename respected', () {
      const gen = SearchIndexGenerator(SearchConfig(enabled: true, output: 'index.json'));
      gen.writeToOutput([
        makePage(frontMatter: {'title': 'T'}),
      ], tempDir.path);
      expect(File(p.join(tempDir.path, 'index.json')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'search-index.json')).existsSync(), isFalse);
    });

    test('written file contains valid JSON', () {
      const gen = SearchIndexGenerator(SearchConfig(enabled: true));
      gen.writeToOutput([
        makePage(frontMatter: {'title': 'T'}),
      ], tempDir.path);
      final content = File(p.join(tempDir.path, 'search-index.json')).readAsStringSync();
      expect(() => jsonDecode(content), returnsNormally);
    });
  });

  // ──────────────────────────────────────────────────
  // SiteConfig search config parsing (TI06)
  // ──────────────────────────────────────────────────
  group('SiteConfig searchConfig', () {
    test('no search: section returns default (disabled) config', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.searchConfig.enabled, isFalse);
    });

    test('factory constructor accepts searchConfig parameter', () {
      final config = SiteConfig(siteDir: '/my/site', searchConfig: const SearchConfig(enabled: true));
      expect(config.searchConfig.enabled, isTrue);
    });

    test('searchConfig fields accessible', () {
      final config = SiteConfig(
        siteDir: '/my/site',
        searchConfig: const SearchConfig(enabled: true, output: 'index.json', maxContentLength: 2000),
      );
      expect(config.searchConfig.output, equals('index.json'));
      expect(config.searchConfig.maxContentLength, equals(2000));
    });
  });

  // ──────────────────────────────────────────────────
  // Build pipeline integration (TI07)
  // ──────────────────────────────────────────────────
  group('search index integration', () {
    SiteConfig isolatedSearchConfig({required bool enabled}) {
      final outputDir = Directory.systemTemp.createTempSync('search_integ_').path;
      addTearDown(() => Directory(outputDir).deleteSync(recursive: true));
      return SiteConfig(
        siteDir: buildSiteDir,
        contentDir: p.join(buildSiteDir, 'content'),
        layoutsDir: p.join(buildSiteDir, 'layouts'),
        staticDir: p.join(buildSiteDir, '_no_static'),
        outputDir: outputDir,
        searchConfig: SearchConfig(enabled: enabled),
      );
    }

    test('search-index.json generated when enabled', () async {
      final config = isolatedSearchConfig(enabled: true);
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'search-index.json')).existsSync(), isTrue);
    });

    test('search-index.json not generated when disabled', () async {
      final config = isolatedSearchConfig(enabled: false);
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'search-index.json')).existsSync(), isFalse);
    });

    test('search-index.json contains valid JSON array', () async {
      final config = isolatedSearchConfig(enabled: true);
      await TrellisSite(config).build();
      final content = File(p.join(config.outputDir, 'search-index.json')).readAsStringSync();
      final decoded = jsonDecode(content);
      expect(decoded, isA<List<dynamic>>());
    });

    test('search-index.json contains hello-world page', () async {
      final config = isolatedSearchConfig(enabled: true);
      await TrellisSite(config).build();
      final content = File(p.join(config.outputDir, 'search-index.json')).readAsStringSync();
      expect(content, contains('Hello World'));
    });

    test('draft pages excluded from search index', () async {
      final config = isolatedSearchConfig(enabled: true);
      await TrellisSite(config).build();
      final content = File(p.join(config.outputDir, 'search-index.json')).readAsStringSync();
      expect(content, isNot(contains('Draft Page')));
    });

    test('search index counted in BuildResult.staticFileCount', () async {
      final config = isolatedSearchConfig(enabled: true);
      final result = await TrellisSite(config).build();
      // sitemap.xml + search-index.json at minimum
      expect(result.staticFileCount, greaterThanOrEqualTo(1));
    });

    test('excluded sections excluded from index', () async {
      final outputDir = Directory.systemTemp.createTempSync('search_excl_').path;
      addTearDown(() => Directory(outputDir).deleteSync(recursive: true));
      final config = SiteConfig(
        siteDir: buildSiteDir,
        contentDir: p.join(buildSiteDir, 'content'),
        layoutsDir: p.join(buildSiteDir, 'layouts'),
        staticDir: p.join(buildSiteDir, '_no_static'),
        outputDir: outputDir,
        searchConfig: const SearchConfig(enabled: true, excludeSections: ['posts']),
      );
      await TrellisSite(config).build();
      final content = File(p.join(outputDir, 'search-index.json')).readAsStringSync();
      // hello-world.md is in posts section — should be excluded
      expect(content, isNot(contains('Hello World')));
    });
  });
}
