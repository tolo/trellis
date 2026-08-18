import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

late String _fixtureDir;

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _fixtureDir = p.join(packageRoot, 'test', 'test_fixtures');
  });

  group('TrellisSite.build() — theme integration', () {
    late Directory tempOutput;

    setUp(() {
      tempOutput = Directory.systemTemp.createTempSync('theme_integration_');
    });

    tearDown(() {
      if (tempOutput.existsSync()) tempOutput.deleteSync(recursive: true);
    });

    SiteConfig themeSiteConfig({String? outputDir}) {
      final configPath = p.join(_fixtureDir, 'theme_site', 'trellis_site.yaml');
      final config = SiteConfig.load(configPath);
      return SiteConfig(
        siteDir: config.siteDir,
        title: config.title,
        baseUrl: config.baseUrl,
        outputDir: outputDir ?? tempOutput.path,
        themeConfig: config.themeConfig,
      );
    }

    test('\${theme.primary_color} renders the site-overridden value in output HTML', () async {
      final config = themeSiteConfig();
      final site = TrellisSite(config);
      await site.build();

      final outputFile = File(p.join(tempOutput.path, 'index.html'));
      expect(outputFile.existsSync(), isTrue);
      final html = outputFile.readAsStringSync();
      // Site overrides primary_color to #e11d48
      expect(html, contains('#e11d48'));
    });

    test('\${theme.skin} reflects site override (dark), not theme default (auto)', () async {
      final config = themeSiteConfig();
      final site = TrellisSite(config);
      await site.build();

      final html = File(p.join(tempOutput.path, 'index.html')).readAsStringSync();
      expect(html, contains('dark'));
      expect(html, isNot(contains('>auto<')));
    });

    test('\${theme.font_family} reflects the theme default (not overridden)', () async {
      final config = themeSiteConfig();
      final site = TrellisSite(config);
      await site.build();

      final html = File(p.join(tempOutput.path, 'index.html')).readAsStringSync();
      expect(html, contains('system-ui'));
    });

    test('build without theme config completes without \${theme.*} errors', () async {
      final tempDir = Directory.systemTemp.createTempSync('no_theme_site_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // Minimal site with no theme:
      Directory(p.join(tempDir.path, 'content')).createSync();
      Directory(p.join(tempDir.path, 'layouts')).createSync();
      File(p.join(tempDir.path, 'content', '_index.md')).writeAsStringSync('---\ntitle: Home\n---\nHello\n');
      File(
        p.join(tempDir.path, 'layouts', 'home.html'),
      ).writeAsStringSync('<html><body><h1 tl:text="\${page.title}">T</h1></body></html>');

      final config = SiteConfig(siteDir: tempDir.path, outputDir: tempOutput.path);
      final site = TrellisSite(config);
      final result = await site.build();

      expect(result.pageCount, equals(1));
    });

    test('unknown theme_params: key produces build warning', () async {
      final tempDir = Directory.systemTemp.createTempSync('unknown_param_site_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // Set up minimal site with a theme
      final themeDir = Directory(p.join(tempDir.path, 'themes', 'mytheme'))..createSync(recursive: true);
      File(
        p.join(themeDir.path, 'theme.yaml'),
      ).writeAsStringSync('name: mytheme\nversion: 1.0.0\nparams:\n  skin:\n    default: light\n');
      Directory(p.join(tempDir.path, 'content')).createSync();
      Directory(p.join(tempDir.path, 'layouts')).createSync();
      File(p.join(tempDir.path, 'content', '_index.md')).writeAsStringSync('---\ntitle: Home\n---\n');
      File(
        p.join(tempDir.path, 'layouts', 'home.html'),
      ).writeAsStringSync('<html><body><h1 tl:text="\${page.title}">T</h1></body></html>');

      final config = SiteConfig(
        siteDir: tempDir.path,
        outputDir: tempOutput.path,
        themeConfig: const ThemeConfig(name: 'mytheme', params: {'skin': 'dark', 'no_such_param': 'value'}),
      );
      final site = TrellisSite(config);
      final result = await site.build();

      expect(result.warnings, isNotEmpty);
      expect(result.warnings.any((w) => w.message.contains('no_such_param')), isTrue);
    });

    test('missing theme directory throws SiteConfigException', () async {
      final tempDir = Directory.systemTemp.createTempSync('missing_theme_site_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      Directory(p.join(tempDir.path, 'content')).createSync();
      Directory(p.join(tempDir.path, 'layouts')).createSync();

      final config = SiteConfig(
        siteDir: tempDir.path,
        outputDir: tempOutput.path,
        themeConfig: const ThemeConfig(name: 'nonexistent'),
      );
      final site = TrellisSite(config);

      await expectLater(site.build(), throwsA(isA<SiteConfigException>()));
    });
  });
}
