import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

late String _testFixturesDir;

/// Returns the absolute path to a test fixture, resolved via package resolution
/// so it works regardless of where `dart test` is invoked from.
String fixture(String name) => p.join(_testFixturesDir, name);

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _testFixturesDir = p.join(packageRoot, 'test', 'test_fixtures');
  });

  group('deriveUrl', () {
    test('regular file at root', () => expect(deriveUrl('about.md'), '/about/'));
    test('regular file in subdirectory', () => expect(deriveUrl('posts/hello-world.md'), '/posts/hello-world/'));
    test('_index.md at root', () => expect(deriveUrl('_index.md'), '/'));
    test('_index.md in subdirectory', () => expect(deriveUrl('posts/_index.md'), '/posts/'));
    test('index.md bundle', () => expect(deriveUrl('posts/my-trip/index.md'), '/posts/my-trip/'));
    test(
      'deeply nested file',
      () => expect(deriveUrl('docs/advanced/configuration.md'), '/docs/advanced/configuration/'),
    );
    test('deeply nested _index.md', () => expect(deriveUrl('docs/advanced/_index.md'), '/docs/advanced/'));
  });

  group('detectKind', () {
    test('_index.md at root → home', () => expect(detectKind('_index.md'), PageKind.home));
    test('_index.md in subdir → section', () => expect(detectKind('posts/_index.md'), PageKind.section));
    test('_index.md deeply nested → section', () => expect(detectKind('docs/advanced/_index.md'), PageKind.section));
    test('regular file → single', () => expect(detectKind('about.md'), PageKind.single));
    test('index.md bundle → single', () => expect(detectKind('posts/my-trip/index.md'), PageKind.single));
    test('posts file → single', () => expect(detectKind('posts/hello-world.md'), PageKind.single));
  });

  group('deriveSection', () {
    test('root file → empty string', () => expect(deriveSection('about.md'), ''));
    test('root _index.md → empty string', () => expect(deriveSection('_index.md'), ''));
    test('one level deep → top-level section', () => expect(deriveSection('posts/hello.md'), 'posts'));
    test('deeply nested → top-level section', () => expect(deriveSection('docs/advanced/config.md'), 'docs'));
    test('section index → section name', () => expect(deriveSection('posts/_index.md'), 'posts'));
  });

  group('ContentDiscovery', () {
    late String simpleSiteDir;
    late String emptySiteDir;
    late String nestedSiteDir;

    setUp(() {
      simpleSiteDir = fixture('simple_site/content');
      emptySiteDir = fixture('empty_site/content');
      nestedSiteDir = fixture('nested_site/content');
    });

    test('throws ArgumentError for non-existent directory', () async {
      final discovery = ContentDiscovery('/non/existent/path/that/does/not/exist');
      expect(discovery.discover(), throwsArgumentError);
    });

    test('returns empty list for empty content directory', () async {
      final discovery = ContentDiscovery(emptySiteDir);
      final pages = await discovery.discover();
      expect(pages, isEmpty);
    });

    test('discovers all pages in simple site', () async {
      final discovery = ContentDiscovery(simpleSiteDir);
      final pages = await discovery.discover();
      expect(pages.length, 5);
    });

    test('pages are sorted by sourcePath', () async {
      final discovery = ContentDiscovery(simpleSiteDir);
      final pages = await discovery.discover();
      final paths = pages.map((p) => p.sourcePath).toList();
      final sorted = [...paths]..sort();
      expect(paths, sorted);
    });

    test('home page detection: _index.md at root', () async {
      final discovery = ContentDiscovery(simpleSiteDir);
      final pages = await discovery.discover();
      final home = pages.firstWhere((p) => p.sourcePath == '_index.md');
      expect(home.kind, PageKind.home);
      expect(home.url, '/');
      expect(home.section, '');
    });

    test('section detection: _index.md in subdirectory', () async {
      final discovery = ContentDiscovery(simpleSiteDir);
      final pages = await discovery.discover();
      final section = pages.firstWhere((p) => p.sourcePath == 'posts/_index.md');
      expect(section.kind, PageKind.section);
      expect(section.url, '/posts/');
      expect(section.section, 'posts');
    });

    test('single page: regular .md file', () async {
      final discovery = ContentDiscovery(simpleSiteDir);
      final pages = await discovery.discover();
      final about = pages.firstWhere((p) => p.sourcePath == 'about.md');
      expect(about.kind, PageKind.single);
      expect(about.url, '/about/');
      expect(about.section, '');
      expect(about.isDraft, false);
    });

    test('posts page URL derivation', () async {
      final discovery = ContentDiscovery(simpleSiteDir);
      final pages = await discovery.discover();
      final post = pages.firstWhere((p) => p.sourcePath == 'posts/hello-world.md');
      expect(post.url, '/posts/hello-world/');
      expect(post.section, 'posts');
      expect(post.kind, PageKind.single);
    });

    test('page bundle detection: index.md with sibling assets', () async {
      final discovery = ContentDiscovery(simpleSiteDir);
      final pages = await discovery.discover();
      final bundle = pages.firstWhere((p) => p.sourcePath == 'posts/my-trip/index.md');
      expect(bundle.isBundle, true);
      expect(bundle.url, '/posts/my-trip/');
      expect(bundle.kind, PageKind.single);
      expect(bundle.bundleAssets, contains('posts/my-trip/photo.jpg'));
    });

    test('non-bundle pages have empty bundleAssets', () async {
      final discovery = ContentDiscovery(simpleSiteDir);
      final pages = await discovery.discover();
      final about = pages.firstWhere((p) => p.sourcePath == 'about.md');
      expect(about.isBundle, false);
      expect(about.bundleAssets, isEmpty);
    });

    test('nested site: section derivation for deeply nested files', () async {
      final discovery = ContentDiscovery(nestedSiteDir);
      final pages = await discovery.discover();

      final config = pages.firstWhere((p) => p.sourcePath == 'docs/advanced/configuration.md');
      expect(config.section, 'docs');
      expect(config.url, '/docs/advanced/configuration/');
      expect(config.kind, PageKind.single);

      final advancedSection = pages.firstWhere((p) => p.sourcePath == 'docs/advanced/_index.md');
      expect(advancedSection.kind, PageKind.section);
      expect(advancedSection.url, '/docs/advanced/');
      expect(advancedSection.section, 'docs');
    });

    test('default mutable fields are empty after discovery', () async {
      final discovery = ContentDiscovery(simpleSiteDir);
      final pages = await discovery.discover();
      for (final page in pages) {
        expect(page.frontMatter, isEmpty);
        expect(page.rawContent, '');
        expect(page.content, '');
        expect(page.summary, '');
        expect(page.toc, isEmpty);
      }
    });
  });
}
