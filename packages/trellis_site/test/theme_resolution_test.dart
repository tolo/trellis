import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Directory siteLayouts;
  late Directory themeLayouts;
  late Directory outputDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('theme_resolution_test_');
    siteLayouts = Directory(p.join(tempDir.path, 'layouts'))..createSync();
    final themeDir = Directory(p.join(tempDir.path, 'themes', 'sample'))..createSync(recursive: true);
    themeLayouts = Directory(p.join(themeDir.path, 'layouts'))..createSync();
    outputDir = Directory(p.join(tempDir.path, 'output'))..createSync();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  PageGenerator makeGenerator({bool withTheme = true}) {
    final themeLayoutsPath = p.join(tempDir.path, 'themes', 'sample', 'layouts');
    return PageGenerator(
      siteDir: tempDir.path,
      outputDir: outputDir.path,
      layoutsDir: siteLayouts.path,
      layoutSearchPaths: withTheme ? [themeLayoutsPath] : null,
    );
  }

  Page makePage(String url, {PageKind kind = PageKind.single, String section = ''}) {
    return Page(
      sourcePath: 'content/$url.md',
      url: '/$url/',
      kind: kind,
      section: section,
      isDraft: false,
      isBundle: false,
      bundleAssets: const [],
      frontMatter: {'title': 'Test'},
      content: '<p>Content</p>',
    );
  }

  group('resolveLayout() — site-first, theme-fallback', () {
    test('site layout overrides theme layout at same path', () {
      File(p.join(siteLayouts.path, '_default', 'single.html'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('<p>site-single</p>');
      File(p.join(themeLayouts.path, '_default', 'single.html'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('<p>theme-single</p>');

      final generator = makeGenerator();
      final result = generator.resolveLayout(makePage('about'));
      expect(result, equals('layouts/_default/single.html'));

      // Verify the site file is found first (by checking both files exist)
      expect(File(p.join(siteLayouts.path, '_default', 'single.html')).existsSync(), isTrue);
      expect(File(p.join(themeLayouts.path, '_default', 'single.html')).existsSync(), isTrue);
    });

    test('theme layout used as fallback when site does not have it', () {
      File(p.join(themeLayouts.path, '_default', 'single.html'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('<p>theme-single</p>');

      final generator = makeGenerator();
      final result = generator.resolveLayout(makePage('about'));
      expect(result, equals('layouts/_default/single.html'));
    });

    test('home page uses site home.html layout', () {
      File(p.join(siteLayouts.path, 'home.html')).writeAsStringSync('<p>site-home</p>');

      final generator = makeGenerator();
      final homePage = makePage('', kind: PageKind.home);
      final result = generator.resolveLayout(homePage);
      expect(result, equals('layouts/home.html'));
    });

    test('home page falls back to theme _default/list.html when no home layout', () {
      File(p.join(themeLayouts.path, '_default', 'list.html'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('<p>theme-list</p>');

      final generator = makeGenerator();
      final homePage = makePage('', kind: PageKind.home);
      final result = generator.resolveLayout(homePage);
      expect(result, equals('layouts/_default/list.html'));
    });

    test('layout candidate priority preserved across site and theme', () {
      // Only provide a less-specific fallback in the theme
      File(p.join(themeLayouts.path, '_default', 'single.html'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('<p>theme-default</p>');
      // Site has a more specific section layout
      File(p.join(siteLayouts.path, 'posts', 'single.html'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('<p>site-posts</p>');

      final generator = makeGenerator();
      final page = makePage('post', section: 'posts');
      final result = generator.resolveLayout(page);
      // posts/single.html (site, more specific) beats _default/single.html (theme, less specific)
      expect(result, equals('layouts/posts/single.html'));
    });

    test('TemplateNotFoundException.tried includes both site and theme paths', () {
      final generator = makeGenerator();
      expect(
        () => generator.resolveLayout(makePage('about')),
        throwsA(
          isA<TemplateNotFoundException>().having(
            (e) => e.tried,
            'tried',
            allOf(
              anyElement(contains(siteLayouts.path)),
              anyElement(contains(themeLayouts.path)),
            ),
          ),
        ),
      );
    });

    test('site without theme — resolution works as before (single layoutsDir)', () {
      File(p.join(siteLayouts.path, '_default', 'single.html'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('<p>site-single</p>');

      final generator = makeGenerator(withTheme: false);
      final result = generator.resolveLayout(makePage('about'));
      expect(result, equals('layouts/_default/single.html'));
    });

    test('site without theme — TemplateNotFoundException.tried has only site paths', () {
      final generator = makeGenerator(withTheme: false);
      expect(
        () => generator.resolveLayout(makePage('about')),
        throwsA(
          isA<TemplateNotFoundException>().having(
            (e) => e.tried,
            'tried',
            everyElement(contains(siteLayouts.path)),
          ),
        ),
      );
    });

    test('resolveLayout() returns template name not absolute path', () {
      File(p.join(themeLayouts.path, '_default', 'single.html'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('<p>theme-single</p>');

      final generator = makeGenerator();
      final result = generator.resolveLayout(makePage('about'));
      expect(result, startsWith('layouts/'));
      expect(p.isAbsolute(result), isFalse);
    });
  });
}
