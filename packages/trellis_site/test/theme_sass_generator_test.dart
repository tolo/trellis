import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

void main() {
  group('ThemeSassGenerator — SASS variable generation', () {
    test('color param generates unquoted hex value', () {
      final result = _generateSass({'primary_color': '#2563eb'}, {'primary_color': 'color'});
      expect(result, contains(r'$trellis-primary-color: #2563eb;'));
    });

    test('4-char hex generates unquoted value', () {
      final result = _generateSass({'accent': '#f00'}, {'accent': 'color'});
      expect(result, contains(r'$trellis-accent: #f00;'));
    });

    test('9-char hex generates unquoted value', () {
      final result = _generateSass({'bg': '#ff000080'}, {'bg': 'color'});
      expect(result, contains(r'$trellis-bg: #ff000080;'));
    });

    test('string param generates interpolated value', () {
      final result = _generateSass({'font_family': 'system-ui, sans-serif'}, {'font_family': 'string'});
      expect(result, contains(r'$trellis-font-family: #{"system-ui, sans-serif"};'));
    });

    test('string param with double quote escapes it', () {
      final result = _generateSass({'label': 'say "hi"'}, {'label': 'string'});
      expect(result, contains(r'$trellis-label: #{"say \"hi\""};'));
    });

    test('string param with backslash escapes it before quotes', () {
      final result = _generateSass({'path': r'C:\themes\verdant'}, {'path': 'string'});
      expect(result, contains(r'$trellis-path: #{"C:\\themes\\verdant"};'));
    });

    test('string param with interpolation marker neutralizes it', () {
      final result = _generateSass({'label': 'total #{1+1} items'}, {'label': 'string'});
      expect(result, contains(r'$trellis-label: #{"total \#{1+1} items"};'));
    });

    test('string param with newline escapes it to a CSS newline', () {
      final result = _generateSass({'notice': 'line1\nline2'}, {'notice': 'string'});
      expect(result, contains(r'$trellis-notice: #{"line1\a line2"};'));
    });

    test('string param with form feed escapes it to a CSS newline (L8)', () {
      // Form feed U+000C is a string-aborting newline in Dart Sass just like \n;
      // it must map to the same `\a ` escape or a `\f`-carrying value aborts.
      final result = _generateSass({'notice': 'line1\fline2'}, {'notice': 'string'});
      expect(result, contains(r'$trellis-notice: #{"line1\a line2"};'));
    });

    // Follow-up review hardening: every branch that can emit a raw (unescaped)
    // value must not let an interpolation-shaped value slip through.

    test('interpolation-shaped value of hex length is escaped, not passed raw (F-A)', () {
      // `#{9}` is length 4 like a 3-digit hex — it must NOT take the hex fast-path.
      final result = _generateSass({'v': '#{9}'}, {'v': 'string'});
      expect(result, contains(r'$trellis-v: #{"\#{9}"};'));
      expect(result, isNot(contains(r'$trellis-v: #{9};')));
    });

    test('genuine hex still passes through unquoted regardless of type (F-A guard)', () {
      final result = _generateSass({'v': '#abc'}, {'v': 'string'});
      expect(result, contains(r'$trellis-v: #abc;'));
    });

    test('color-typed value with interpolation marker is neutralized (F-C)', () {
      final result = _generateSass({'brand': '#{1 + 1}'}, {'brand': 'color'});
      expect(result, contains(r'$trellis-brand: #{"\#{1 + 1}"};'));
      expect(result, isNot(contains(r'$trellis-brand: #{1 + 1};')));
    });

    test('color-typed named/function values still pass through unquoted (F-C guard)', () {
      final result = _generateSass({'brand': 'rgb(0, 0, 0)', 'accent': 'red'}, {'brand': 'color', 'accent': 'color'});
      expect(result, contains(r'$trellis-brand: rgb(0, 0, 0);'));
      expect(result, contains(r'$trellis-accent: red;'));
    });

    test('map key with double quote / interpolation marker is escaped (F-B)', () {
      final result = _generateSass(
        {
          'sizes': <String, dynamic>{'a"#{1+1}': 'x'},
        },
        {'sizes': 'map'},
      );
      expect(result, contains(r'"a\"\#{1+1}": #{"x"}'));
    });

    test('boolean true param generates unquoted true', () {
      final result = _generateSass({'show_powered_by': true}, {'show_powered_by': 'boolean'});
      expect(result, contains(r'$trellis-show-powered-by: true;'));
    });

    test('boolean false param generates unquoted false', () {
      final result = _generateSass({'enable_toc': false}, {'enable_toc': 'boolean'});
      expect(result, contains(r'$trellis-enable-toc: false;'));
    });

    test('integer param generates unquoted number', () {
      final result = _generateSass({'excerpt_length': 160}, {'excerpt_length': 'int'});
      expect(result, contains(r'$trellis-excerpt-length: 160;'));
    });

    test('null param generates null keyword', () {
      final result = _generateSass({'hero_title': null}, {'hero_title': 'string'});
      expect(result, contains(r'$trellis-hero-title: null;'));
    });

    test('list param generates SASS list syntax', () {
      final result = _generateSass(
        {
          'nav_links': [
            {'label': 'Home', 'url': '/'},
          ],
        },
        {'nav_links': 'list'},
      );
      expect(result, contains(r'$trellis-nav-links: (('));
    });

    test('map param generates SASS map syntax', () {
      final result = _generateSass(
        {
          'colors': <String, dynamic>{'primary': '#blue'},
        },
        {'colors': 'map'},
      );
      expect(result, contains(r'$trellis-colors: ("primary": '));
    });

    test('param name underscores converted to hyphens', () {
      final result = _generateSass({'my_custom_param': 'val'}, {'my_custom_param': 'string'});
      expect(result, contains(r'$trellis-my-custom-param'));
    });

    test('empty params generates only header comment', () {
      final result = _generateSassRaw({}, {});
      expect(result, contains('// Auto-generated by Trellis theme system'));
      expect(result, isNot(contains(r'$trellis')));
    });

    test('the generated module declares nothing !default (it is read by namespace, not load order)', () {
      final result = _generateSass(
        {
          'primary_color': '#2563eb',
          'font_family': 'system-ui',
          'show_toc': true,
          'nav_links': [
            {'label': 'Home', 'url': '/'},
          ],
        },
        {'primary_color': 'color', 'font_family': 'string', 'show_toc': 'boolean', 'nav_links': 'list'},
      );
      expect(result, isNot(contains('!default')));
    });

    test('output includes header comment', () {
      final result = _generateSass({'x': 'y'}, {});
      expect(result, contains('// Auto-generated by Trellis theme system'));
      expect(result, contains('// Source: merged theme params'));
    });
  });

  group('ThemeBuildConfig.configurableVars — manifest params the theme declares !default', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('trellis_configurable_test_'));

    tearDown(() => tempDir.deleteSync(recursive: true));

    ThemeBuildConfig generate(
      Map<String, dynamic> params,
      Map<String, String> types, {
      String? variables,
      bool withSassDir = true,
    }) {
      final themeDir = p.join(tempDir.path, 'themes', 'fixture');
      Directory(themeDir).createSync(recursive: true);
      if (withSassDir) {
        Directory(p.join(themeDir, 'sass')).createSync();
        if (variables != null) File(p.join(themeDir, 'sass', '_variables.scss')).writeAsStringSync(variables);
      }
      return const ThemeSassGenerator().generate(
        mergedParams: params,
        paramTypes: types,
        siteDir: tempDir.path,
        themeDir: themeDir,
      );
    }

    test('lists the params whose variable is declared !default', () {
      final config = generate(
        {'skin': 'auto', 'primary_color': '#2563eb', 'max_width': '1200px'},
        {'skin': 'enum', 'primary_color': 'color', 'max_width': 'string'},
        variables: r'''
$trellis-skin: auto !default;
$trellis-primary-color: #0f7a4d !default;
$trellis-max-width: 1000px !default;
''',
      );
      expect(config.configurableVars, ['trellis-skin', 'trellis-primary-color', 'trellis-max-width']);
    });

    test('omits manifest params with no SASS variable (template-only params stay inert)', () {
      final config = generate(
        {'skin': 'auto', 'nav_links': <dynamic>[], 'show_toc': true},
        {'skin': 'enum', 'nav_links': 'list', 'show_toc': 'boolean'},
        variables: r'$trellis-skin: auto !default;',
      );
      expect(config.configurableVars, ['trellis-skin']);
    });

    test('omits a site param name the manifest does not declare', () {
      final config = generate(
        {'skin': 'auto', 'typo_color': '#fff'},
        {'skin': 'enum'},
        variables: '\$trellis-skin: auto !default;\n\$trellis-typo-color: #000 !default;',
      );
      expect(config.configurableVars, ['trellis-skin']);
    });

    test('omits a variable declared without !default', () {
      final config = generate(
        {'skin': 'auto', 'max_width': '1px'},
        {'skin': 'enum', 'max_width': 'string'},
        variables: '\$trellis-skin: auto !default;\n\$trellis-max-width: 1000px;',
      );
      expect(config.configurableVars, ['trellis-skin']);
    });

    test('includes a null-valued param (null configures as "unset")', () {
      final config = generate(
        {'heading_font_family': null},
        {'heading_font_family': 'string'},
        variables: r'$trellis-heading-font-family: Georgia, serif !default;',
      );
      expect(config.configurableVars, ['trellis-heading-font-family']);
    });

    test('includes a declaration that spans several lines (a re-wrapped font stack)', () {
      final config = generate(
        {'font_family': 'x'},
        {'font_family': 'string'},
        variables: r'''
$trellis-font-family:
  system-ui,
  -apple-system,
  sans-serif
  !default;
''',
      );
      expect(config.configurableVars, ['trellis-font-family']);
    });

    test('includes declarations with interpolation, URLs and a trailing comment', () {
      final config = generate(
        {'font_family': 'x', 'logo': 'y', 'max_width': 'z'},
        {'font_family': 'string', 'logo': 'string', 'max_width': 'string'},
        variables: r'''
$trellis-font-family: #{$base}, serif !default;
$trellis-logo: url(https://example.com/logo.png) !default; // hosted
$trellis-max-width: 1200px !default; /* wide */
''',
      );
      expect(config.configurableVars, ['trellis-font-family', 'trellis-logo', 'trellis-max-width']);
    });

    test('ignores commented-out declarations', () {
      final config = generate(
        {'skin': 'auto', 'max_width': 'x', 'border_radius': 'y'},
        {'skin': 'enum', 'max_width': 'string', 'border_radius': 'string'},
        variables: r'''
$trellis-skin: auto !default;
// $trellis-max-width: 1000px !default;
/* $trellis-border-radius: 6px !default; */
''',
      );
      expect(config.configurableVars, ['trellis-skin']);
    });

    test('matches a variable whichever way it spells the underscore', () {
      final config = generate(
        {'max_width': 'x'},
        {'max_width': 'string'},
        variables: r'$trellis-max_width: 1000px !default;',
      );
      expect(config.configurableVars, ['trellis-max-width']);
    });

    test('omits a manifest param that is not in the merged params', () {
      final config = generate(
        {'skin': 'auto'},
        {'skin': 'enum', 'max_width': 'string'},
        variables: '\$trellis-skin: auto !default;\n\$trellis-max-width: 1000px !default;',
      );
      expect(config.configurableVars, ['trellis-skin']);
    });

    test('a theme without sass/ yields no configurable vars and does not throw', () {
      final config = generate({'skin': 'auto'}, {'skin': 'enum'}, withSassDir: false);
      expect(config.configurableVars, isEmpty);
    });

    test('a sass/ directory without _variables.scss yields none', () {
      expect(generate({'skin': 'auto'}, {'skin': 'enum'}).configurableVars, isEmpty);
    });

    test('no theme directory yields none', () {
      final config = const ThemeSassGenerator().generate(
        mergedParams: {'skin': 'auto'},
        paramTypes: {'skin': 'enum'},
        siteDir: tempDir.path,
      );
      expect(config.configurableVars, isEmpty);
    });
  });

  group('ThemeBuildConfig.bridgeWrapperSource', () {
    final entry = p.join(p.rootPrefix(p.current), 'themes', 'my fixture', 'sass', 'main.scss');
    final entryUrl = p.toUri(entry).path;

    ThemeBuildConfig config(List<String> vars) =>
        ThemeBuildConfig(buildDir: '/b', sassLoadPaths: const [], skinMode: SkinMode.auto, configurableVars: vars);

    test('@uses the params module and configures exactly the configurable vars', () {
      final wrapper = config(['trellis-skin', 'trellis-primary-color']).bridgeWrapperSource(entry);
      expect(wrapper, contains('@use "theme_params" as tp;'));
      expect(wrapper, contains('@use "$entryUrl" as theme with ('));
      expect(wrapper, contains(r'$trellis-skin: tp.$trellis-skin,'));
      expect(wrapper, contains(r'$trellis-primary-color: tp.$trellis-primary-color'));
      expect(RegExp(r'tp\.\$').allMatches(wrapper), hasLength(2));
    });

    test('holds no @import and injects no skin file', () {
      final wrapper = config(['trellis-skin']).bridgeWrapperSource(entry);
      expect(wrapper, isNot(contains('@import')));
      expect(wrapper, isNot(contains('_skins')));
    });

    test('omits with() when nothing is configurable', () {
      final wrapper = config([]).bridgeWrapperSource(entry);
      expect(wrapper, contains('@use "$entryUrl" as theme;'));
      expect(wrapper, isNot(contains('with')));
    });

    // Sass reads a raw Windows path `C:\…` as URL scheme `c:` with backslash
    // escapes, so the entry is embedded as a URL path on every platform.
    test('embeds the entry as an encoded URL path, never a native path', () {
      final wrapper = config([]).bridgeWrapperSource(entry);
      expect(wrapper, contains('my%20fixture'));
      expect(wrapper, isNot(contains('"$entry"')));
      expect(wrapper, isNot(contains('file:')), reason: 'Sass resolves a URL with a scheme only via load paths');
    });

    test('a wrapper for an entry whose path needs URL escaping compiles without load paths', () {
      final tempDir = Directory.systemTemp.createTempSync('trellis wrapper %20 ');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final sassDir = Directory(p.join(tempDir.path, 'sass'))..createSync();
      File(p.join(sassDir.path, '_variables.scss')).writeAsStringSync(r'$trellis-bg-color: #ffffff !default;');
      final themeEntry = File(p.join(sassDir.path, 'main.scss'))
        ..writeAsStringSync("@forward 'variables';\n@use 'variables' as *;\n.bg { background: \$trellis-bg-color; }\n");
      File(p.join(tempDir.path, '_theme_params.scss')).writeAsStringSync(r'$trellis-bg-color: #010203;');
      final wrapper = File(p.join(tempDir.path, 'bridge_main.scss'))
        ..writeAsStringSync(config(['trellis-bg-color']).bridgeWrapperSource(themeEntry.path));

      expect(TrellisCss.compileSass(wrapper.path, fatalImportDeprecation: true), contains('#010203'));
    });
  });
}

/// Runs [ThemeSassGenerator.generate] in a temp directory and returns the
/// content of the generated `_theme_params.scss`.
/// Always injects `skin: light` so the generator doesn't fail on missing skin.
String _generateSass(Map<String, dynamic> params, Map<String, String> types) {
  final tempDir = Directory.systemTemp.createTempSync('trellis_sass_test_');
  try {
    const gen = ThemeSassGenerator();
    gen.generate(
      mergedParams: {'skin': 'light', ...params},
      paramTypes: {'skin': 'enum', ...types},
      siteDir: tempDir.path,
    );
    return File(p.join(tempDir.path, '.trellis', 'build', '_theme_params.scss')).readAsStringSync();
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

/// Like [_generateSass] but passes params as-is (no injected skin param).
String _generateSassRaw(Map<String, dynamic> params, Map<String, String> types) {
  final tempDir = Directory.systemTemp.createTempSync('trellis_sass_test_');
  try {
    const gen = ThemeSassGenerator();
    gen.generate(mergedParams: params, paramTypes: types, siteDir: tempDir.path);
    return File(p.join(tempDir.path, '.trellis', 'build', '_theme_params.scss')).readAsStringSync();
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
