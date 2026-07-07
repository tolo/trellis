import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

/// Full-build integration tests for the theme resolution pipeline.
///
/// Uses the `test_fixtures/theme_resolution_site` fixture which has:
///   - Site layout override: `layouts/_default/single.html` (marker: site-single)
///   - Site home layout:     `layouts/home.html`            (marker: site-home)
///   - Theme layout:         `themes/sample/layouts/_default/single.html` (marker: theme-single)
///   - Theme list layout:    `themes/sample/layouts/_default/list.html`   (marker: theme-list)
///   - Site static:          `static/style.css`, `static/images/logo.png` (content: site-logo)
///   - Theme static:         `themes/sample/static/theme.css`,
///                           `themes/sample/static/images/logo.png`       (content: theme-logo)
///   - Site data:            `data/nav.yaml` (site nav overrides theme nav)
///   - Theme data:           `themes/sample/data/nav.yaml`, `themes/sample/data/footer.yaml`
void main() {
  late Directory outputDir;
  late String fixturePath;

  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    fixturePath = p.join(packageRoot, 'test', 'test_fixtures', 'theme_resolution_site');
  });

  setUp(() {
    outputDir = Directory.systemTemp.createTempSync('theme_resolution_integration_');
  });

  tearDown(() {
    if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
  });

  SiteConfig makeConfig() => SiteConfig(
    siteDir: fixturePath,
    title: 'Theme Resolution Test Site',
    baseUrl: 'https://example.com',
    outputDir: outputDir.path,
    themeConfig: const ThemeConfig(name: 'sample'),
  );

  Future<BuildResult> buildSite() => TrellisSite(makeConfig()).build();

  group('theme layout resolution — full build', () {
    test('about page uses site layout override (site-single), not theme layout', () async {
      final result = await buildSite();
      expect(result.pageCount, greaterThan(0));

      final aboutHtml = File(p.join(outputDir.path, 'about', 'index.html')).readAsStringSync();
      expect(aboutHtml, contains('site-single'));
      expect(aboutHtml, isNot(contains('theme-single')));
    });

    test('home page uses site home.html layout (site-home marker)', () async {
      await buildSite();

      final homeHtml = File(p.join(outputDir.path, 'index.html')).readAsStringSync();
      expect(homeHtml, contains('site-home'));
    });

    test('build succeeds with at least two pages (home + about)', () async {
      final result = await buildSite();
      expect(result.pageCount, greaterThanOrEqualTo(2));
    });

    test('about page contains page title from front matter', () async {
      await buildSite();

      final aboutHtml = File(p.join(outputDir.path, 'about', 'index.html')).readAsStringSync();
      expect(aboutHtml, contains('About'));
    });
  });

  group('theme static asset merging — full build', () {
    test('theme-only static file (theme.css) appears in output', () async {
      await buildSite();

      expect(File(p.join(outputDir.path, 'theme.css')).existsSync(), isTrue);
    });

    test('site static file (style.css) appears in output', () async {
      await buildSite();

      expect(File(p.join(outputDir.path, 'style.css')).existsSync(), isTrue);
    });

    test('site logo overwrites theme logo at same path (site-logo wins)', () async {
      await buildSite();

      final logo = File(p.join(outputDir.path, 'images', 'logo.png'));
      expect(logo.existsSync(), isTrue);
      expect(logo.readAsStringSync().trim(), equals('site-logo'));
    });
  });

  group('build result metadata', () {
    test('staticFileCount includes static files from both theme and site', () async {
      final result = await buildSite();
      // theme.css + images/logo.png + style.css + sitemap.xml = at least 3
      expect(result.staticFileCount, greaterThanOrEqualTo(3));
    });

    test('build completes without warnings for well-formed theme fixture', () async {
      final result = await buildSite();
      expect(result.hasWarnings, isFalse);
    });

    test('elapsed time is non-negative', () async {
      final result = await buildSite();
      expect(result.elapsed.inMilliseconds, greaterThanOrEqualTo(0));
    });
  });

  // A site may reference a theme that lives OUTSIDE its own directory via a
  // relative `theme:` value (e.g. `../../themes/arbor` — the docs site referencing
  // a repo-root theme). `themeDir` is `p.join(siteDir, 'themes', <value>)`, which
  // yields a path with un-collapsed `..` segments through a non-existent
  // `siteDir/themes` directory; the build must normalize it so both the manifest
  // loader and the template FileSystemLoader resolve a real path.
  group('theme resolution — relative theme path escaping the site dir', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('theme_rel_path_');
      // <root>/themes/mytheme/  (the theme, a sibling of the site)
      final themeLayouts = Directory(p.join(root.path, 'themes', 'mytheme', 'layouts', '_default'))
        ..createSync(recursive: true);
      File(p.join(root.path, 'themes', 'mytheme', 'theme.yaml')).writeAsStringSync('name: mytheme\nversion: 1.0.0\n');
      File(
        p.join(themeLayouts.path, 'list.html'),
      ).writeAsStringSync('<html><body><p class="src">from-mytheme</p></body></html>\n');
      // <root>/site/  referencing the theme via a relative escaping path.
      Directory(p.join(root.path, 'site', 'content')).createSync(recursive: true);
      File(p.join(root.path, 'site', 'content', '_index.md')).writeAsStringSync('---\ntitle: Home\n---\nHi\n');
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('a relative theme: path (../../themes/mytheme) resolves and renders', () async {
      final out = Directory.systemTemp.createTempSync('theme_rel_out_');
      addTearDown(() => out.deleteSync(recursive: true));
      final config = SiteConfig(
        siteDir: p.join(root.path, 'site'),
        title: 'Rel Theme Site',
        baseUrl: 'https://example.com',
        outputDir: out.path,
        // Escapes site/ up to <root>/ then into themes/mytheme — the exact shape
        // the docs site uses to reach a repo-root theme.
        themeConfig: const ThemeConfig(name: '../../themes/mytheme'),
      );

      // Must not throw a "base path does not exist" TemplateException.
      final result = await TrellisSite(config).build();
      expect(result.pageCount, greaterThanOrEqualTo(1));

      final html = File(p.join(out.path, 'index.html')).readAsStringSync();
      expect(html, contains('from-mytheme'), reason: 'home page should render through the relative-path theme');
    });
  });
}
