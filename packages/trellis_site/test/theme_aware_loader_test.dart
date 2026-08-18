import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis/trellis.dart';
import 'package:trellis_site/trellis_site.dart' hide TemplateNotFoundException;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Directory siteDir;
  late Directory themeDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('theme_loader_test_');
    siteDir = Directory(p.join(tempDir.path, 'site'))..createSync();
    themeDir = Directory(p.join(tempDir.path, 'theme'))..createSync();

    // Site template
    final siteLayouts = Directory(p.join(siteDir.path, 'layouts'))..createSync();
    File(p.join(siteLayouts.path, 'site_only.html')).writeAsStringSync('<p>site-only</p>');
    File(p.join(siteLayouts.path, 'shared.html')).writeAsStringSync('<p>site-shared</p>');

    // Theme templates
    final themeLayouts = Directory(p.join(themeDir.path, 'layouts'))..createSync();
    File(p.join(themeLayouts.path, 'theme_only.html')).writeAsStringSync('<p>theme-only</p>');
    File(p.join(themeLayouts.path, 'shared.html')).writeAsStringSync('<p>theme-shared</p>');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  group('ThemeAwareLoader.forTheme()', () {
    test('load() unprefixed name resolves via site-first', () async {
      final loader = ThemeAwareLoader.forTheme(siteDir: siteDir.path, themeDir: themeDir.path);
      final content = await loader.load('layouts/shared.html');
      expect(content, contains('site-shared'));
    });

    test('load() unprefixed name falls back to theme when not in site', () async {
      final loader = ThemeAwareLoader.forTheme(siteDir: siteDir.path, themeDir: themeDir.path);
      final content = await loader.load('layouts/theme_only.html');
      expect(content, contains('theme-only'));
    });

    test('load() site-only template found in site', () async {
      final loader = ThemeAwareLoader.forTheme(siteDir: siteDir.path, themeDir: themeDir.path);
      final content = await loader.load('layouts/site_only.html');
      expect(content, contains('site-only'));
    });

    test('load() theme: prefix loads directly from theme', () async {
      final loader = ThemeAwareLoader.forTheme(siteDir: siteDir.path, themeDir: themeDir.path);
      final content = await loader.load('theme:layouts/shared.html');
      expect(content, contains('theme-shared'));
    });

    test('load() theme: prefix strips prefix correctly', () async {
      final loader = ThemeAwareLoader.forTheme(siteDir: siteDir.path, themeDir: themeDir.path);
      // theme:layouts/theme_only.html → layouts/theme_only.html in themeDir
      final content = await loader.load('theme:layouts/theme_only.html');
      expect(content, contains('theme-only'));
    });

    test('load() template not in site or theme throws TemplateNotFoundException', () async {
      final loader = ThemeAwareLoader.forTheme(siteDir: siteDir.path, themeDir: themeDir.path);
      await expectLater(loader.load('layouts/nonexistent.html'), throwsA(isA<TemplateNotFoundException>()));
    });

    test('loadSync() unprefixed name resolves via site-first', () {
      final loader = ThemeAwareLoader.forTheme(siteDir: siteDir.path, themeDir: themeDir.path);
      final content = loader.loadSync('layouts/shared.html');
      expect(content, contains('site-shared'));
    });

    test('loadSync() theme: prefix loads directly from theme', () {
      final loader = ThemeAwareLoader.forTheme(siteDir: siteDir.path, themeDir: themeDir.path);
      final content = loader.loadSync('theme:layouts/shared.html');
      expect(content, contains('theme-shared'));
    });

    test('loadSync() falls back to theme when not in site', () {
      final loader = ThemeAwareLoader.forTheme(siteDir: siteDir.path, themeDir: themeDir.path);
      final content = loader.loadSync('layouts/theme_only.html');
      expect(content, contains('theme-only'));
    });
  });

  group('ThemeAwareLoader.noTheme()', () {
    test('load() unprefixed name resolves via site only', () async {
      final loader = ThemeAwareLoader.noTheme(siteDir: siteDir.path);
      final content = await loader.load('layouts/site_only.html');
      expect(content, contains('site-only'));
    });

    test('load() theme: prefix with no theme throws TemplateException', () async {
      final loader = ThemeAwareLoader.noTheme(siteDir: siteDir.path);
      await expectLater(
        loader.load('theme:layouts/base.html'),
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('No theme is configured'))),
      );
    });

    test('loadSync() theme: prefix with no theme throws TemplateException', () {
      final loader = ThemeAwareLoader.noTheme(siteDir: siteDir.path);
      expect(
        () => loader.loadSync('theme:layouts/base.html'),
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('No theme is configured'))),
      );
    });

    test('load() template not in site throws TemplateNotFoundException', () async {
      final loader = ThemeAwareLoader.noTheme(siteDir: siteDir.path);
      await expectLater(loader.load('layouts/theme_only.html'), throwsA(isA<TemplateNotFoundException>()));
    });
  });
}
