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
      // Symlinks resolved so a path Sass reports compares equal to ours (macOS /var).
      tempDir = Directory(Directory.systemTemp.createTempSync('trellis_sass_integ_').resolveSymbolicLinksSync());
      siteDir = tempDir.path;
      themeDir = p.join(siteDir, 'themes', 'verdant');
      Directory(themeDir).createSync(recursive: true);
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('generate() creates _theme_params.scss as a plain module with the merged values', () {
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
      expect(content, contains(r'$trellis-primary-color: #2563eb;'));
      expect(content, contains(r'$trellis-font-family: #{"system-ui, sans-serif"};'));
      // Guard the deprecation-free emission: the legacy global unquote() builtin
      // (removed in Dart Sass 3.0.0, warns today) must not reappear.
      expect(content, isNot(contains('unquote(')));
      expect(content, contains(r'$trellis-show-powered-by: true;'));
      // A plain module read by namespace: nothing in it may rely on load order.
      expect(content, isNot(contains('!default')));
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
      expect(config.configurableVars, isEmpty);
    });

    group('compiled CSS through the bridge wrapper', () {
      test('string param produces unquoted font-family, not a quoted literal', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {'skin': 'light', 'font_family': 'system-ui, -apple-system, sans-serif', 'max_width': '1200px'},
          types: {'skin': 'enum', 'font_family': 'string', 'max_width': 'string'},
          variables: r'''
$trellis-skin: auto !default;
$trellis-font-family: serif !default;
$trellis-max-width: 1000px !default;
''',
          main: r'body { font-family: $trellis-font-family; max-width: $trellis-max-width; }',
        );

        expect(css, contains('font-family: system-ui, -apple-system, sans-serif;'));
        expect(css, contains('max-width: 1200px;'));
        expect(css, isNot(contains('font-family: "')));
        expect(css, isNot(contains('max-width: "')));
      });

      test('string value containing a double quote is escaped and compiles cleanly', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {'hero_title': 'Say "hello" to Trellis'},
          types: {'hero_title': 'string'},
          variables: r'$trellis-hero-title: null !default;',
          main: r'body::before { content: $trellis-hero-title; }',
        );

        expect(css, contains('content: Say "hello" to Trellis;'));
      });

      test('value containing a SASS interpolation marker is emitted literally, not evaluated', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {'hero_title': r'total #{1 + 1} items'},
          types: {'hero_title': 'string'},
          variables: r'$trellis-hero-title: null !default;',
          main: r'body::before { content: $trellis-hero-title; }',
        );

        // The `#{1 + 1}` stays literal text — it must NOT evaluate to `total 2 items`.
        expect(css, contains(r'content: total #{1 + 1} items;'));
        expect(css, isNot(contains('total 2 items')));
      });

      test('interpolation-shaped hex-length value is literal, not evaluated (F-A)', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {'hero_title': r'#{9}'},
          types: {'hero_title': 'string'},
          variables: r'$trellis-hero-title: null !default;',
          main: r'body::before { content: $trellis-hero-title; }',
        );

        // `#{9}` is hex-length; the old length-only fast-path evaluated it to `9`.
        expect(css, contains(r'content: #{9};'));
        expect(css, isNot(contains('content: 9;')));
      });

      test('color-typed interpolation value is literal, not evaluated (F-C)', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {'brand_color': r'#{1 + 1}'},
          types: {'brand_color': 'color'},
          variables: r'$trellis-brand-color: red !default;',
          main: r'a { color: $trellis-brand-color; }',
        );

        // The `color` passthrough must neutralize interpolation, not evaluate it.
        expect(css, contains(r'color: #{1 + 1};'));
        expect(css, isNot(contains('color: 2;')));
      });

      test('map with a hostile key compiles without breaking the literal (F-B)', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {
            'sizes': <String, dynamic>{'a"#{1+1}': 'x', 'norm': 'y'},
          },
          types: {'sizes': 'map'},
          variables: r'$trellis-sizes: () !default;',
          main: r'''
@use 'sass:map';
a { color: red; width: map.get($trellis-sizes, "norm"); }
''',
        );

        // An unescaped `"` in the key aborts the module while parsing the map
        // literal; reading the sibling key back proves the literal parsed intact.
        expect(css, contains('color: red;'));
        expect(css, contains('width: y;'));
      });

      test('multiline value compiles without aborting (F-D)', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {'notice': 'line1\nline2'},
          types: {'notice': 'string'},
          variables: r'$trellis-notice: null !default;',
          main: r'body::before { content: $trellis-notice; }',
        );

        // A raw newline aborts the SASS compile; the CSS `\a ` escape keeps it compiling.
        expect(css, contains('line1'));
        expect(css, contains('line2'));
      });

      test('form-feed value compiles without aborting (L8)', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {'notice': 'line1\fline2'},
          types: {'notice': 'string'},
          variables: r'$trellis-notice: null !default;',
          main: r'body::before { content: $trellis-notice; }',
        );

        // Form feed U+000C is a string-aborting newline in Dart Sass; the `\a `
        // escape keeps it compiling as literal text, same as the newline case.
        expect(css, contains('line1'));
        expect(css, contains('line2'));
      });

      test('site overrides win for a color, int, boolean, enum, list and map param', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {
            'primary_color': '#ff0000',
            'excerpt_length': 42,
            'show_toc': false,
            'layout': 'wide',
            'tags': ['a', 'b'],
            'sizes': <String, dynamic>{'sm': '10px'},
          },
          types: {
            'primary_color': 'color',
            'excerpt_length': 'int',
            'show_toc': 'boolean',
            'layout': 'enum',
            'tags': 'list',
            'sizes': 'map',
          },
          variables: r'''
$trellis-primary-color: #0f7a4d !default;
$trellis-excerpt-length: 160 !default;
$trellis-show-toc: true !default;
$trellis-layout: narrow !default;
$trellis-tags: (x, y, z) !default;
$trellis-sizes: ("sm": 1px) !default;
''',
          main: r'''
@use 'sass:list';
@use 'sass:map';
a { color: $trellis-primary-color; line-height: $trellis-excerpt-length; }
.toc { @if $trellis-show-toc { display: block; } @else { display: none; } }
.layout-#{$trellis-layout} { count: list.length($trellis-tags); width: map.get($trellis-sizes, "sm"); }
''',
        );

        expect(css, contains('color: #ff0000;'));
        expect(css, contains('line-height: 42;'));
        expect(css, contains('display: none;'));
        expect(css, contains('.layout-wide'));
        expect(css, contains('count: 2;'));
        expect(css, contains('width: 10px;'));
      });

      test('an unset param leaves the theme default in force', () {
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          params: {'skin': 'auto'},
          types: {'skin': 'enum', 'primary_color': 'color'},
          variables: r'''
$trellis-skin: auto !default;
$trellis-primary-color: #0f7a4d !default;
''',
          main: r'a { color: $trellis-primary-color; }',
        );

        expect(css, contains('color: #0f7a4d;'));
      });
    });

    group('inert, unknown and absent inputs', () {
      test('params without a SASS variable, undeclared site names and a null param do not fail the build', () {
        late ThemeBuildConfig config;
        final css = _compileThroughBridge(
          siteDir,
          themeDir,
          // `not_in_manifest` is a site-supplied name the manifest does not declare.
          params: {
            'skin': 'auto',
            'nav_links': [
              {'label': 'Home', 'url': '/'},
            ],
            'social_links': <dynamic>[],
            'not_in_manifest': 'x',
            'heading_font_family': null,
            'font_family': 'Inter, system-ui, sans-serif',
          },
          types: {
            'skin': 'enum',
            'nav_links': 'list',
            'social_links': 'list',
            'heading_font_family': 'string',
            'font_family': 'string',
          },
          // A declaration a formatter wrapped over several lines still configures.
          variables: r'''
$trellis-skin: auto !default;
$trellis-heading-font-family: Georgia, serif !default;
$trellis-font-family:
  system-ui,
  sans-serif
  !default;
''',
          main: r'''
body { font-family: $trellis-font-family; }
h1 { font-family: $trellis-heading-font-family; }
''',
          onConfig: (c) => config = c,
        );

        expect(config.configurableVars, ['trellis-skin', 'trellis-heading-font-family', 'trellis-font-family']);
        // The multi-line declaration's site override reaches compiled CSS.
        expect(css, contains('font-family: Inter, system-ui, sans-serif;'));
        // `null` is "unset": the theme's own default stays in force.
        expect(css, contains('font-family: Georgia, serif;'));
      });

      test('a broken load order fails loudly, naming the theme entry', () {
        final sassDir = Directory(p.join(themeDir, 'sass'))..createSync(recursive: true);
        File(p.join(sassDir.path, '_variables.scss')).writeAsStringSync(r'$trellis-skin: auto !default;');
        // The partial reaches `variables` before main.scss forwards it.
        File(
          p.join(sassDir.path, '_early.scss'),
        ).writeAsStringSync("@use 'variables' as *;\na { b: \$trellis-skin; }\n");
        final entry = File(p.join(sassDir.path, 'main.scss'))
          ..writeAsStringSync("@use 'early';\n@forward 'variables';\n");
        final config = _generate(
          siteDir: siteDir,
          themeDir: themeDir,
          params: {'skin': 'auto'},
          types: {'skin': 'enum'},
        );

        expect(
          () => _compileWrapper(config, entry.path),
          throwsA(
            isA<SassCompilationException>()
                .having((e) => e.message, 'message', contains('This module was already loaded'))
                .having((e) => e.path, 'path', entry.path),
          ),
        );
      });

      test('an entry whose file name is not a Sass identifier still compiles', () {
        // `@import` accepted any entry name; a bare `@use "2col.scss"` would fail
        // because its default namespace `2col` is not an identifier.
        final sassDir = Directory(p.join(themeDir, 'sass'))..createSync(recursive: true);
        File(p.join(sassDir.path, '_variables.scss')).writeAsStringSync(r'$trellis-max-width: 1px !default;');
        final entry = File(p.join(sassDir.path, '2col.scss'))
          ..writeAsStringSync("@forward 'variables';\n@use 'variables' as *;\na { max-width: \$trellis-max-width; }\n");
        final config = _generate(
          siteDir: siteDir,
          themeDir: themeDir,
          params: {'max_width': '900px'},
          types: {'max_width': 'string'},
        );

        expect(_compileWrapper(config, entry.path), contains('max-width: 900px;'));
      });
    });
  });
}

/// Writes an `@use`-native fixture theme under [themeDir]: `_variables.scss`
/// with [variables], and a `main.scss` that forwards it first and then runs
/// [main] with its variables in scope, as a migrated theme does. Returns the
/// path of `main.scss`.
String _writeTheme(String themeDir, {required String variables, required String main}) {
  final sassDir = Directory(p.join(themeDir, 'sass'))..createSync(recursive: true);
  File(p.join(sassDir.path, '_variables.scss')).writeAsStringSync(variables);
  final entry = File(p.join(sassDir.path, 'main.scss'))
    ..writeAsStringSync("@forward 'variables';\n@use 'variables' as *;\n$main\n");
  return entry.path;
}

/// Generates the bridge for a fixture theme and compiles its wrapper with the
/// import deprecation fatal, exactly as `trellis build` does.
String _compileThroughBridge(
  String siteDir,
  String themeDir, {
  required Map<String, dynamic> params,
  required Map<String, String> types,
  required String variables,
  required String main,
  void Function(ThemeBuildConfig config)? onConfig,
}) {
  final entry = _writeTheme(themeDir, variables: variables, main: main);
  final config = _generate(siteDir: siteDir, themeDir: themeDir, params: params, types: types);
  onConfig?.call(config);
  return _compileWrapper(config, entry);
}

String _compileWrapper(ThemeBuildConfig config, String entry) {
  final wrapper = File(p.join(config.buildDir, 'bridge_main.scss'))
    ..writeAsStringSync(config.bridgeWrapperSource(entry));
  return TrellisCss.compileSass(wrapper.path, loadPaths: config.sassLoadPaths, fatalImportDeprecation: true);
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
