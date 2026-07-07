import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

void main() {
  group('ThemeSassGenerator — integration', () {
    late Directory tempDir;
    late String siteDir;
    late String themeDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_sass_integ_');
      siteDir = tempDir.path;
      themeDir = p.join(siteDir, 'themes', 'verdant');
      Directory(themeDir).createSync(recursive: true);
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('generate() creates _theme_params.scss with correct content', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {
          'skin': 'light',
          'primary_color': '#2563eb',
          'font_family': 'system-ui, sans-serif',
          'show_powered_by': true,
        },
        types: {'skin': 'enum', 'primary_color': 'color', 'font_family': 'string', 'show_powered_by': 'boolean'},
      );

      final sassFile = File(p.join(config.buildDir, '_theme_params.scss'));
      expect(sassFile.existsSync(), isTrue);
      final content = sassFile.readAsStringSync();
      expect(content, contains(r'$trellis-primary-color: #2563eb !default;'));
      expect(content, contains(r'$trellis-font-family: #{"system-ui, sans-serif"} !default;'));
      // Guard the deprecation-free emission: the legacy global unquote() builtin
      // (removed in Dart Sass 3.0.0, warns today) must not reappear.
      expect(content, isNot(contains('unquote(')));
      expect(content, contains(r'$trellis-show-powered-by: true !default;'));
    });

    test('generate() creates _theme_custom_props.css with :root block', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light', 'primary_color': '#2563eb', 'show_powered_by': true},
        types: {'skin': 'enum', 'primary_color': 'color', 'show_powered_by': 'boolean'},
      );

      final cssFile = File(p.join(config.buildDir, '_theme_custom_props.css'));
      expect(cssFile.existsSync(), isTrue);
      final content = cssFile.readAsStringSync();
      expect(content, contains(':root {'));
      expect(content, contains('--trellis-primary-color: #2563eb;'));
      // boolean excluded
      expect(content, isNot(contains('--trellis-show-powered-by')));
    });

    test('generate() creates .trellis/.gitignore', () {
      _generate(siteDir: siteDir, themeDir: themeDir, params: {'skin': 'auto'}, types: {'skin': 'enum'});
      final gitignore = File(p.join(siteDir, '.trellis', '.gitignore'));
      expect(gitignore.existsSync(), isTrue);
      expect(gitignore.readAsStringSync(), contains('*'));
    });

    test('generate() returns correct SASS load paths', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light'},
        types: {'skin': 'enum'},
      );
      expect(config.sassLoadPaths, contains(p.join(siteDir, 'sass')));
      expect(config.sassLoadPaths, contains(p.join(themeDir, 'sass')));
      expect(config.sassLoadPaths, contains(config.buildDir));
      // Order: build dir first (bridge files), then site sass, then theme sass
      final siteIdx = config.sassLoadPaths.indexOf(p.join(siteDir, 'sass'));
      final themeIdx = config.sassLoadPaths.indexOf(p.join(themeDir, 'sass'));
      final buildIdx = config.sassLoadPaths.indexOf(config.buildDir);
      expect(buildIdx, lessThan(siteIdx));
      expect(siteIdx, lessThan(themeIdx));
    });

    test('generate() resolves skinMode correctly', () {
      final config = _generate(siteDir: siteDir, themeDir: themeDir, params: {'skin': 'dark'}, types: {'skin': 'enum'});
      expect(config.skinMode, SkinMode.dark);
    });

    test('generate() with null themeDir omits theme paths', () {
      final config = _generate(siteDir: siteDir, themeDir: null, params: {'skin': 'auto'}, types: {'skin': 'enum'});
      expect(config.sassLoadPaths, isNot(contains(p.join(themeDir, 'sass'))));
    });

    test('generate() with theme without sass/ directory still generates CSS custom properties', () {
      // themeDir exists but has no sass/ subdirectory
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light', 'primary_color': '#abc'},
        types: {'skin': 'enum', 'primary_color': 'color'},
      );
      final cssFile = File(p.join(config.buildDir, '_theme_custom_props.css'));
      expect(cssFile.existsSync(), isTrue);
      expect(cssFile.readAsStringSync(), contains('--trellis-primary-color: #abc;'));
    });

    test('compiled CSS: string param produces unquoted font-family, not a quoted literal', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light', 'font_family': 'system-ui, -apple-system, sans-serif', 'max_width': '1200px'},
        types: {'skin': 'enum', 'font_family': 'string', 'max_width': 'string'},
      );

      // A minimal theme main.scss that consumes the bridged variables like a
      // real theme's _variables.scss would — proving the compiled CSS (not
      // just the generated .scss text) is unquoted.
      final mainScss = File(p.join(themeDir, 'sass', 'main.scss'))..parent.createSync(recursive: true);
      mainScss.writeAsStringSync('''
@import "theme_params";
body { font-family: \$trellis-font-family; max-width: \$trellis-max-width; }
''');

      final css = TrellisCss.compileSass(mainScss.path, loadPaths: config.sassLoadPaths);

      expect(css, contains('font-family: system-ui, -apple-system, sans-serif;'));
      expect(css, contains('max-width: 1200px;'));
      expect(css, isNot(contains('font-family: "')));
      expect(css, isNot(contains('max-width: "')));
    });

    test('compiled CSS: string value containing a double quote is escaped and compiles cleanly', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light', 'hero_title': 'Say "hello" to Trellis'},
        types: {'skin': 'enum', 'hero_title': 'string'},
      );

      final mainScss = File(p.join(themeDir, 'sass', 'main.scss'))..parent.createSync(recursive: true);
      mainScss.writeAsStringSync('''
@import "theme_params";
body::before { content: \$trellis-hero-title; }
''');

      final css = TrellisCss.compileSass(mainScss.path, loadPaths: config.sassLoadPaths);

      expect(css, contains('content: Say "hello" to Trellis;'));
    });

    test('compiled CSS: value containing a SASS interpolation marker is emitted literally, not evaluated', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light', 'hero_title': r'total #{1 + 1} items'},
        types: {'skin': 'enum', 'hero_title': 'string'},
      );

      final mainScss = File(p.join(themeDir, 'sass', 'main.scss'))..parent.createSync(recursive: true);
      mainScss.writeAsStringSync('''
@import "theme_params";
body::before { content: \$trellis-hero-title; }
''');

      final css = TrellisCss.compileSass(mainScss.path, loadPaths: config.sassLoadPaths);

      // The `#{1 + 1}` stays literal text — it must NOT evaluate to `total 2 items`.
      expect(css, contains(r'content: total #{1 + 1} items;'));
      expect(css, isNot(contains('total 2 items')));
    });
  });
}

ThemeBuildConfig _generate({
  required String siteDir,
  required String? themeDir,
  required Map<String, dynamic> params,
  required Map<String, String> types,
}) {
  const gen = ThemeSassGenerator();
  return gen.generate(mergedParams: params, paramTypes: types, siteDir: siteDir, themeDir: themeDir);
}
