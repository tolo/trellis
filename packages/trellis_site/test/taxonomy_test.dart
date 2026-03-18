import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

/// Creates a minimal non-draft [Page] with the given front matter.
Page _page(String url, Map<String, dynamic> fm) => Page(
  sourcePath: 'content/${url.replaceAll(RegExp(r'^/|/$'), '')}.md',
  url: url,
  section: url.split('/').where((s) => s.isNotEmpty).firstOrNull ?? '',
  kind: PageKind.single,
  isDraft: false,
  isBundle: false,
  bundleAssets: const [],
  frontMatter: fm,
);

void main() {
  // ---------------------------------------------------------------------------
  // normalizeTerm
  // ---------------------------------------------------------------------------
  group('TaxonomyCollector.normalizeTerm', () {
    test('lowercases input', () {
      expect(TaxonomyCollector.normalizeTerm('DART'), equals('dart'));
    });

    test('trims whitespace', () {
      expect(TaxonomyCollector.normalizeTerm('  dart  '), equals('dart'));
    });

    test('lowercases and trims combined', () {
      expect(TaxonomyCollector.normalizeTerm('  HTMX  '), equals('htmx'));
    });

    test('returns empty string for blank input', () {
      expect(TaxonomyCollector.normalizeTerm('   '), equals(''));
    });
  });

  // ---------------------------------------------------------------------------
  // slugify
  // ---------------------------------------------------------------------------
  group('TaxonomyCollector.slugify', () {
    test('simple word unchanged', () {
      expect(TaxonomyCollector.slugify('dart'), equals('dart'));
    });

    test('spaces become hyphens', () {
      expect(TaxonomyCollector.slugify('hello world'), equals('hello-world'));
    });

    test('special chars replaced by single hyphen', () {
      expect(TaxonomyCollector.slugify('C++ programming'), equals('c-programming'));
    });

    test('leading and trailing hyphens stripped', () {
      expect(TaxonomyCollector.slugify('  My Term  '), equals('my-term'));
    });

    test('multiple consecutive non-alnum collapse to one hyphen', () {
      expect(TaxonomyCollector.slugify('a   b'), equals('a-b'));
    });

    test('underscores replaced by hyphen', () {
      expect(TaxonomyCollector.slugify('hello_world'), equals('hello-world'));
    });
  });

  // ---------------------------------------------------------------------------
  // collect
  // ---------------------------------------------------------------------------
  group('TaxonomyCollector.collect', () {
    const collector = TaxonomyCollector();

    test('extracts terms from List front matter value', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart', 'web'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      expect(index['tags']!.terms.map((t) => t.name), containsAll(['dart', 'web']));
    });

    test('extracts term from String front matter value', () {
      final pages = [
        _page('/posts/a/', {'tags': 'dart'}),
      ];
      final index = collector.collect(['tags'], pages);
      expect(index['tags']!.terms.length, equals(1));
      expect(index['tags']!.terms.first.name, equals('dart'));
    });

    test('handles page with no taxonomy key', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
        }),
        _page('/posts/b/', {}), // no tags
      ];
      final index = collector.collect(['tags'], pages);
      expect(index['tags']!.terms.length, equals(1));
    });

    test('normalises terms — uppercased terms are merged', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['Dart'],
        }),
        _page('/posts/b/', {
          'tags': ['dart'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      expect(index['tags']!.terms.length, equals(1));
      expect(index['tags']!.terms.first.count, equals(2));
    });

    test('terms sorted alphabetically', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['web', 'dart', 'tutorial'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final names = index['tags']!.terms.map((t) => t.name).toList();
      expect(names, equals(['dart', 'tutorial', 'web']));
    });

    test('term count reflects number of tagged pages', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
        }),
        _page('/posts/b/', {
          'tags': ['dart', 'web'],
        }),
        _page('/posts/c/', {
          'tags': ['web'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final dartTerm = index['tags']!.terms.firstWhere((t) => t.name == 'dart');
      final webTerm = index['tags']!.terms.firstWhere((t) => t.name == 'web');
      expect(dartTerm.count, equals(2));
      expect(webTerm.count, equals(2));
    });

    test('handles multiple taxonomies simultaneously', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
          'categories': ['programming'],
        }),
      ];
      final index = collector.collect(['tags', 'categories'], pages);
      expect(index.containsKey('tags'), isTrue);
      expect(index.containsKey('categories'), isTrue);
      expect(index['tags']!.terms.first.name, equals('dart'));
      expect(index['categories']!.terms.first.name, equals('programming'));
    });

    test('deduplicates terms on same page (Dart and dart)', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['Dart', 'dart'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      expect(index['tags']!.terms.length, equals(1));
    });

    test('TaxonomyTerm.url is /{taxonomy}/{slug}/', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['hello world'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      expect(index['tags']!.terms.first.url, equals('/tags/hello-world/'));
    });

    test('TaxonomyIndex.toTermMapList returns list of maps', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final mapList = index['tags']!.toTermMapList();
      expect(mapList.first['name'], equals('dart'));
      expect(mapList.first['count'], equals(1));
      expect(mapList.first['pages'], isA<List<Map<String, dynamic>>>());
    });
  });

  // ---------------------------------------------------------------------------
  // buildVirtualPages
  // ---------------------------------------------------------------------------
  group('TaxonomyCollector.buildVirtualPages', () {
    const collector = TaxonomyCollector();

    test('creates a taxonomy listing page', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final virtual = collector.buildVirtualPages(index, pages);
      final listing = virtual.firstWhere((pg) => pg.url == '/tags/');
      expect(listing.kind, equals(PageKind.section));
      expect(listing.section, equals('tags'));
      expect(listing.isDraft, isFalse);
    });

    test('listing page has terms in frontMatter', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart', 'web'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final virtual = collector.buildVirtualPages(index, pages);
      final listing = virtual.firstWhere((pg) => pg.url == '/tags/');
      expect(listing.frontMatter['terms'], isA<List<Map<String, dynamic>>>());
      expect((listing.frontMatter['terms'] as List<Map<String, dynamic>>).length, equals(2));
    });

    test('creates a term page per term', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
        }),
        _page('/posts/b/', {
          'tags': ['web'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final virtual = collector.buildVirtualPages(index, pages);
      expect(virtual.any((pg) => pg.url == '/tags/dart/'), isTrue);
      expect(virtual.any((pg) => pg.url == '/tags/web/'), isTrue);
    });

    test('term page has kind=single', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final virtual = collector.buildVirtualPages(index, pages);
      final termPage = virtual.firstWhere((pg) => pg.url == '/tags/dart/');
      expect(termPage.kind, equals(PageKind.single));
    });

    test('term page frontMatter contains pages list', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
        }),
        _page('/posts/b/', {
          'tags': ['dart'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final virtual = collector.buildVirtualPages(index, pages);
      final termPage = virtual.firstWhere((pg) => pg.url == '/tags/dart/');
      expect(termPage.frontMatter['pages'], isA<List<Map<String, dynamic>>>());
      expect((termPage.frontMatter['pages'] as List<Map<String, dynamic>>).length, equals(2));
    });

    test('term page frontMatter contains term map', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final virtual = collector.buildVirtualPages(index, pages);
      final termPage = virtual.firstWhere((pg) => pg.url == '/tags/dart/');
      expect(termPage.frontMatter['term'], isA<Map<String, dynamic>>());
      expect((termPage.frontMatter['term'] as Map<String, dynamic>)['name'], equals('dart'));
    });

    test('listing page title is capitalised taxonomy name', () {
      final pages = [
        _page('/posts/a/', {
          'tags': ['dart'],
        }),
      ];
      final index = collector.collect(['tags'], pages);
      final virtual = collector.buildVirtualPages(index, pages);
      final listing = virtual.firstWhere((pg) => pg.url == '/tags/');
      expect(listing.frontMatter['title'], equals('Tags'));
    });
  });

  // ---------------------------------------------------------------------------
  // Integration: TrellisSite.build() with taxonomy
  // ---------------------------------------------------------------------------
  group('TrellisSite.build() taxonomy integration', () {
    late String taxonomySiteDir;

    setUpAll(() async {
      final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
      final packageRoot = p.dirname(packageUri!.toFilePath());
      taxonomySiteDir = p.join(packageRoot, 'test', 'test_fixtures', 'taxonomy_site');
    });

    SiteConfig isolatedTaxonomyConfig() {
      final outputDir = Directory.systemTemp.createTempSync('trellis_tax_').path;
      addTearDown(() => Directory(outputDir).deleteSync(recursive: true));
      return SiteConfig(siteDir: taxonomySiteDir, outputDir: outputDir, taxonomies: ['tags']);
    }

    test('taxonomy listing page is generated at /tags/', () async {
      final config = isolatedTaxonomyConfig();
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'tags', 'index.html')).existsSync(), isTrue);
    });

    test('taxonomy term page generated for dart', () async {
      final config = isolatedTaxonomyConfig();
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'tags', 'dart', 'index.html')).existsSync(), isTrue);
    });

    test('taxonomy term page generated for tutorial', () async {
      final config = isolatedTaxonomyConfig();
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'tags', 'tutorial', 'index.html')).existsSync(), isTrue);
    });

    test('dart term page lists tagged pages', () async {
      final config = isolatedTaxonomyConfig();
      await TrellisSite(config).build();
      final html = File(p.join(config.outputDir, 'tags', 'dart', 'index.html')).readAsStringSync();
      expect(html, contains('Dart Intro'));
      expect(html, contains('Dart Advanced'));
    });

    test('tutorial term page contains only tutorial-tagged pages', () async {
      final config = isolatedTaxonomyConfig();
      await TrellisSite(config).build();
      final html = File(p.join(config.outputDir, 'tags', 'tutorial', 'index.html')).readAsStringSync();
      expect(html, contains('Dart Intro'));
      expect(html, contains('Web Basics'));
      expect(html, isNot(contains('Dart Advanced')));
    });

    test('taxonomy listing page contains all terms', () async {
      final config = isolatedTaxonomyConfig();
      await TrellisSite(config).build();
      final html = File(p.join(config.outputDir, 'tags', 'index.html')).readAsStringSync();
      expect(html, contains('dart'));
      expect(html, contains('web'));
      expect(html, contains('tutorial'));
    });

    test('build result pageCount includes taxonomy pages', () async {
      final config = isolatedTaxonomyConfig();
      final result = await TrellisSite(config).build();
      // content: home + 3 posts; taxonomy: /tags/ + /tags/dart/ + /tags/web/ + /tags/tutorial/
      expect(result.pageCount, greaterThanOrEqualTo(7));
    });
  });
}
