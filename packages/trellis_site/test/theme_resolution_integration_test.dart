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
}
