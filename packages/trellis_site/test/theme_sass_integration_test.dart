import 'dart:io';
import 'dart:isolate';

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

    test('compiled CSS: interpolation-shaped hex-length value is literal, not evaluated (F-A)', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light', 'hero_title': r'#{9}'},
        types: {'skin': 'enum', 'hero_title': 'string'},
      );

      final mainScss = File(p.join(themeDir, 'sass', 'main.scss'))..parent.createSync(recursive: true);
      mainScss.writeAsStringSync('''
@import "theme_params";
body::before { content: \$trellis-hero-title; }
''');

      final css = TrellisCss.compileSass(mainScss.path, loadPaths: config.sassLoadPaths);

      // `#{9}` is hex-length; the old length-only fast-path evaluated it to `9`.
      expect(css, contains(r'content: #{9};'));
      expect(css, isNot(contains('content: 9;')));
    });

    test('compiled CSS: color-typed interpolation value is literal, not evaluated (F-C)', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light', 'brand_color': r'#{1 + 1}'},
        types: {'skin': 'enum', 'brand_color': 'color'},
      );

      final mainScss = File(p.join(themeDir, 'sass', 'main.scss'))..parent.createSync(recursive: true);
      mainScss.writeAsStringSync('''
@import "theme_params";
a { color: \$trellis-brand-color; }
''');

      final css = TrellisCss.compileSass(mainScss.path, loadPaths: config.sassLoadPaths);

      // The `color` passthrough must neutralize interpolation, not evaluate it.
      expect(css, contains(r'color: #{1 + 1};'));
      expect(css, isNot(contains('color: 2;')));
    });

    test('compiled CSS: map with a hostile key compiles without breaking the literal (F-B)', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {
          'skin': 'light',
          'sizes': <String, dynamic>{'a"#{1+1}': 'x', 'norm': 'y'},
        },
        types: {'skin': 'enum', 'sizes': 'map'},
      );

      final mainScss = File(p.join(themeDir, 'sass', 'main.scss'))..parent.createSync(recursive: true);
      mainScss.writeAsStringSync('''
@import "theme_params";
a { color: red; }
''');

      // An unescaped `"` in the key aborts the `@import` while parsing the map
      // literal; a clean compile proves the hostile key was escaped and the map
      // literal parsed intact.
      final css = TrellisCss.compileSass(mainScss.path, loadPaths: config.sassLoadPaths);
      expect(css, contains('color: red;'));
    });

    test('compiled CSS: multiline param value compiles without aborting (F-D)', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light', 'notice': 'line1\nline2'},
        types: {'skin': 'enum', 'notice': 'string'},
      );

      final mainScss = File(p.join(themeDir, 'sass', 'main.scss'))..parent.createSync(recursive: true);
      mainScss.writeAsStringSync('''
@import "theme_params";
body::before { content: \$trellis-notice; }
''');

      // A raw newline aborts the SASS compile; the CSS `\a ` escape keeps it compiling.
      final css = TrellisCss.compileSass(mainScss.path, loadPaths: config.sassLoadPaths);
      expect(css, contains('line1'));
      expect(css, contains('line2'));
    });

    test('compiled CSS: skin param gates the theme auto dark-mode @media block (M3 regression)', () async {
      // M3: the bridge emits `$trellis-skin`, which a theme's main.scss uses to
      // gate its `@media (prefers-color-scheme: dark)` block (`@if $trellis-skin
      // == auto`). Compiling the shipped bloom theme through the bridge proves
      // the gate end-to-end: skin=light must drop the dark media block; skin=auto
      // must keep it. Before M3 the skin value was dead config and the block
      // always emitted, so a forced-light site still flipped dark under a dark OS.
      final bloomDir = p.join(await _repoRoot(), 'themes', 'bloom');

      String compileBloom(String skin) {
        final config = _generate(siteDir: siteDir, themeDir: bloomDir, params: {'skin': skin}, types: {'skin': 'enum'});
        // Mirror the CLI wrapper: bridge params first, then the theme's entry point.
        final entry = File(p.join(config.buildDir, '_skin_gate_probe.scss'))
          ..writeAsStringSync('@import "theme_params";\n@import "main";\n');
        return TrellisCss.compileSass(entry.path, loadPaths: config.sassLoadPaths);
      }

      expect(compileBloom('light'), isNot(contains('prefers-color-scheme')));
      expect(compileBloom('auto'), contains('prefers-color-scheme'));
    });

    test('compiled CSS: form-feed param value compiles without aborting (L8)', () {
      final config = _generate(
        siteDir: siteDir,
        themeDir: themeDir,
        params: {'skin': 'light', 'notice': 'line1\fline2'},
        types: {'skin': 'enum', 'notice': 'string'},
      );

      final mainScss = File(p.join(themeDir, 'sass', 'main.scss'))..parent.createSync(recursive: true);
      mainScss.writeAsStringSync('''
@import "theme_params";
body::before { content: \$trellis-notice; }
''');

      // Form feed U+000C is a string-aborting newline in Dart Sass; before the L8
      // fix a `\f`-carrying value aborted the compile. The `\a ` escape now keeps
      // it compiling as literal text, same as the newline case above.
      final css = TrellisCss.compileSass(mainScss.path, loadPaths: config.sassLoadPaths);
      expect(css, contains('line1'));
      expect(css, contains('line2'));
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

/// Resolves the monorepo root by walking up from this package until `themes/bloom`
/// is found, so tests can compile a shipped theme regardless of the test CWD.
Future<String> _repoRoot() async {
  final uri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/trellis_site.dart'));
  if (uri == null || uri.scheme != 'file') {
    throw StateError('Could not resolve package:trellis_site/trellis_site.dart');
  }
  var dir = Directory(p.dirname(uri.toFilePath()));
  while (!Directory(p.join(dir.path, 'themes', 'bloom')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('Could not find repo root (themes/bloom) from ${uri.toFilePath()}');
    dir = parent;
  }
  return dir.path;
}
