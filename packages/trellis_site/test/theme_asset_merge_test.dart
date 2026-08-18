import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Directory siteDir;
  late Directory themeDir;
  late Directory outputDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('theme_asset_merge_test_');
    siteDir = Directory(p.join(tempDir.path, 'site'))..createSync();
    themeDir = Directory(p.join(tempDir.path, 'theme'))..createSync();
    outputDir = Directory(p.join(tempDir.path, 'output'))..createSync();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  // Helpers that mirror TrellisSite._copyThemeStaticAssets and _copyStaticAssets
  // so we can test the merge logic without running a full build.
  void copyThemeStatic(String themeStaticSrc) {
    final themeStaticDir = Directory(themeStaticSrc);
    if (!themeStaticDir.existsSync()) return;

    for (final entity in themeStaticDir.listSync(recursive: true).whereType<File>()) {
      final ext = p.extension(entity.path).toLowerCase();
      if (ext == '.scss' || ext == '.sass') continue;

      final relative = p.relative(entity.path, from: themeStaticDir.path);
      final dest = p.join(outputDir.path, relative);
      Directory(p.dirname(dest)).createSync(recursive: true);
      entity.copySync(dest);
    }
  }

  void copySiteStatic(String siteStaticSrc) {
    final staticDir = Directory(siteStaticSrc);
    if (!staticDir.existsSync()) return;

    for (final entity in staticDir.listSync(recursive: true).whereType<File>()) {
      final ext = p.extension(entity.path).toLowerCase();
      if (ext == '.scss' || ext == '.sass') continue;

      final relative = p.relative(entity.path, from: staticDir.path);
      final dest = p.join(outputDir.path, relative);
      Directory(p.dirname(dest)).createSync(recursive: true);
      entity.copySync(dest);
    }
  }

  group('theme static asset merging', () {
    test('theme static/ files appear in output after copy', () {
      File(p.join(themeDir.path, 'static', 'theme.css'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('body { color: red; }');

      copyThemeStatic(p.join(themeDir.path, 'static'));

      expect(File(p.join(outputDir.path, 'theme.css')).existsSync(), isTrue);
      expect(File(p.join(outputDir.path, 'theme.css')).readAsStringSync(), contains('color: red'));
    });

    test('site static/ file at same path overwrites theme file', () {
      File(p.join(themeDir.path, 'static', 'images', 'logo.png'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('theme-logo');
      File(p.join(siteDir.path, 'static', 'images', 'logo.png'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('site-logo');

      // Mimic pipeline order: theme first, site second
      copyThemeStatic(p.join(themeDir.path, 'static'));
      copySiteStatic(p.join(siteDir.path, 'static'));

      final result = File(p.join(outputDir.path, 'images', 'logo.png')).readAsStringSync();
      expect(result, equals('site-logo'));
    });

    test('theme static/ file with no site conflict appears in output', () {
      File(p.join(themeDir.path, 'static', 'fonts', 'font.woff2'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('font-data');

      copyThemeStatic(p.join(themeDir.path, 'static'));
      copySiteStatic(p.join(siteDir.path, 'static')); // siteDir has no static/

      expect(File(p.join(outputDir.path, 'fonts', 'font.woff2')).existsSync(), isTrue);
      expect(File(p.join(outputDir.path, 'fonts', 'font.woff2')).readAsStringSync(), equals('font-data'));
    });

    test('.scss files in theme static/ are skipped', () {
      File(p.join(themeDir.path, 'static', 'style.scss'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('body { color: blue; }');
      File(p.join(themeDir.path, 'static', 'theme.css'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('/* compiled */');

      copyThemeStatic(p.join(themeDir.path, 'static'));

      expect(File(p.join(outputDir.path, 'style.scss')).existsSync(), isFalse);
      expect(File(p.join(outputDir.path, 'theme.css')).existsSync(), isTrue);
    });

    test('.sass files in theme static/ are also skipped', () {
      File(p.join(themeDir.path, 'static', 'style.sass'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('body\n  color: blue');

      copyThemeStatic(p.join(themeDir.path, 'static'));

      expect(File(p.join(outputDir.path, 'style.sass')).existsSync(), isFalse);
    });

    test('theme without static/ directory causes no error, zero files copied', () {
      // themeDir has no static/ subdirectory
      expect(() => copyThemeStatic(p.join(themeDir.path, 'static')), returnsNormally);
      expect(outputDir.listSync(), isEmpty);
    });
  });

  group('theme data file merging', () {
    test('theme data/ file loaded as fallback when no site data', () {
      final themeDataDir = Directory(p.join(themeDir.path, 'data'))..createSync(recursive: true);
      File(p.join(themeDataDir.path, 'nav.yaml')).writeAsStringSync('- label: Home (theme)\n  url: /\n');
      final siteDataDir = p.join(siteDir.path, 'data'); // does not exist

      final generator = PageGenerator(
        siteDir: siteDir.path,
        outputDir: outputDir.path,
        dataDir: siteDataDir,
        themeDataDir: themeDataDir.path,
      );

      final globalData = generator.loadGlobalData();
      expect(globalData.containsKey('nav'), isTrue);
      final nav = globalData['nav'] as List<dynamic>;
      expect(nav.first, isA<Map<String, dynamic>>());
      expect((nav.first as Map<String, dynamic>)['label'], equals('Home (theme)'));
    });

    test('site data/ file at same key overwrites theme data entirely', () {
      final themeDataDir = Directory(p.join(themeDir.path, 'data'))..createSync(recursive: true);
      File(p.join(themeDataDir.path, 'nav.yaml')).writeAsStringSync('- label: Home (theme)\n  url: /\n');

      final siteDataDir = Directory(p.join(siteDir.path, 'data'))..createSync(recursive: true);
      File(p.join(siteDataDir.path, 'nav.yaml')).writeAsStringSync('- label: Home (site)\n  url: /\n');

      final generator = PageGenerator(
        siteDir: siteDir.path,
        outputDir: outputDir.path,
        dataDir: siteDataDir.path,
        themeDataDir: themeDataDir.path,
      );

      final globalData = generator.loadGlobalData();
      final nav = globalData['nav'] as List<dynamic>;
      expect((nav.first as Map<String, dynamic>)['label'], equals('Home (site)'));
    });

    test('theme data/ file with no site conflict is available via globalData', () {
      final themeDataDir = Directory(p.join(themeDir.path, 'data'))..createSync(recursive: true);
      File(p.join(themeDataDir.path, 'footer.yaml')).writeAsStringSync('text: Powered by Trellis\n');

      final siteDataDir = p.join(siteDir.path, 'data'); // does not exist

      final generator = PageGenerator(
        siteDir: siteDir.path,
        outputDir: outputDir.path,
        dataDir: siteDataDir,
        themeDataDir: themeDataDir.path,
      );

      final globalData = generator.loadGlobalData();
      expect(globalData.containsKey('footer'), isTrue);
      final footer = globalData['footer'] as Map<String, dynamic>;
      expect(footer['text'], equals('Powered by Trellis'));
    });

    test('site has data/ and theme has data/ — both keys available when non-overlapping', () {
      final themeDataDir = Directory(p.join(themeDir.path, 'data'))..createSync(recursive: true);
      File(p.join(themeDataDir.path, 'footer.yaml')).writeAsStringSync('text: Theme footer\n');

      final siteDataDir = Directory(p.join(siteDir.path, 'data'))..createSync(recursive: true);
      File(p.join(siteDataDir.path, 'nav.yaml')).writeAsStringSync('- label: Home\n  url: /\n');

      final generator = PageGenerator(
        siteDir: siteDir.path,
        outputDir: outputDir.path,
        dataDir: siteDataDir.path,
        themeDataDir: themeDataDir.path,
      );

      final globalData = generator.loadGlobalData();
      expect(globalData.containsKey('footer'), isTrue);
      expect(globalData.containsKey('nav'), isTrue);
    });

    test('theme without data/ directory causes no error, empty fallback', () {
      // themeDir has no data/ subdirectory — themeDataDir path does not exist
      final generator = PageGenerator(
        siteDir: siteDir.path,
        outputDir: outputDir.path,
        themeDataDir: p.join(themeDir.path, 'data'),
      );

      expect(generator.loadGlobalData, returnsNormally);
      expect(generator.loadGlobalData(), isEmpty);
    });
  });
}
