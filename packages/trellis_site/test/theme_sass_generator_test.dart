import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

void main() {
  group('ThemeSassGenerator — SASS variable generation', () {
    test('color param generates unquoted hex value', () {
      final result = _generateSass({'primary_color': '#2563eb'}, {'primary_color': 'color'});
      expect(result, contains(r'$trellis-primary-color: #2563eb !default;'));
    });

    test('4-char hex generates unquoted value', () {
      final result = _generateSass({'accent': '#f00'}, {'accent': 'color'});
      expect(result, contains(r'$trellis-accent: #f00 !default;'));
    });

    test('9-char hex generates unquoted value', () {
      final result = _generateSass({'bg': '#ff000080'}, {'bg': 'color'});
      expect(result, contains(r'$trellis-bg: #ff000080 !default;'));
    });

    test('string param generates interpolated value', () {
      final result = _generateSass({'font_family': 'system-ui, sans-serif'}, {'font_family': 'string'});
      expect(result, contains(r'$trellis-font-family: #{"system-ui, sans-serif"} !default;'));
    });

    test('string param with double quote escapes it', () {
      final result = _generateSass({'label': 'say "hi"'}, {'label': 'string'});
      expect(result, contains(r'$trellis-label: #{"say \"hi\""} !default;'));
    });

    test('string param with backslash escapes it before quotes', () {
      final result = _generateSass({'path': r'C:\themes\verdant'}, {'path': 'string'});
      expect(result, contains(r'$trellis-path: #{"C:\\themes\\verdant"} !default;'));
    });

    test('string param with interpolation marker neutralizes it', () {
      final result = _generateSass({'label': 'total #{1+1} items'}, {'label': 'string'});
      expect(result, contains(r'$trellis-label: #{"total \#{1+1} items"} !default;'));
    });

    test('string param with newline escapes it to a CSS newline', () {
      final result = _generateSass({'notice': 'line1\nline2'}, {'notice': 'string'});
      expect(result, contains(r'$trellis-notice: #{"line1\a line2"} !default;'));
    });

    test('string param with form feed escapes it to a CSS newline (L8)', () {
      // Form feed U+000C is a string-aborting newline in Dart Sass just like \n;
      // it must map to the same `\a ` escape or a `\f`-carrying value aborts.
      final result = _generateSass({'notice': 'line1\fline2'}, {'notice': 'string'});
      expect(result, contains(r'$trellis-notice: #{"line1\a line2"} !default;'));
    });

    // Follow-up review hardening: every branch that can emit a raw (unescaped)
    // value must not let an interpolation-shaped value slip through.

    test('interpolation-shaped value of hex length is escaped, not passed raw (F-A)', () {
      // `#{9}` is length 4 like a 3-digit hex — it must NOT take the hex fast-path.
      final result = _generateSass({'v': '#{9}'}, {'v': 'string'});
      expect(result, contains(r'$trellis-v: #{"\#{9}"} !default;'));
      expect(result, isNot(contains(r'$trellis-v: #{9} !default;')));
    });

    test('genuine hex still passes through unquoted regardless of type (F-A guard)', () {
      final result = _generateSass({'v': '#abc'}, {'v': 'string'});
      expect(result, contains(r'$trellis-v: #abc !default;'));
    });

    test('color-typed value with interpolation marker is neutralized (F-C)', () {
      final result = _generateSass({'brand': '#{1 + 1}'}, {'brand': 'color'});
      expect(result, contains(r'$trellis-brand: #{"\#{1 + 1}"} !default;'));
      expect(result, isNot(contains(r'$trellis-brand: #{1 + 1} !default;')));
    });

    test('color-typed named/function values still pass through unquoted (F-C guard)', () {
      final result = _generateSass({'brand': 'rgb(0, 0, 0)', 'accent': 'red'}, {'brand': 'color', 'accent': 'color'});
      expect(result, contains(r'$trellis-brand: rgb(0, 0, 0) !default;'));
      expect(result, contains(r'$trellis-accent: red !default;'));
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
      expect(result, contains(r'$trellis-show-powered-by: true !default;'));
    });

    test('boolean false param generates unquoted false', () {
      final result = _generateSass({'enable_toc': false}, {'enable_toc': 'boolean'});
      expect(result, contains(r'$trellis-enable-toc: false !default;'));
    });

    test('integer param generates unquoted number', () {
      final result = _generateSass({'excerpt_length': 160}, {'excerpt_length': 'int'});
      expect(result, contains(r'$trellis-excerpt-length: 160 !default;'));
    });

    test('null param generates null keyword', () {
      final result = _generateSass({'hero_title': null}, {'hero_title': 'string'});
      expect(result, contains(r'$trellis-hero-title: null !default;'));
    });

    test('list param generates SASS list syntax with !default', () {
      final result = _generateSass(
        {
          'nav_links': [
            {'label': 'Home', 'url': '/'},
          ],
        },
        {'nav_links': 'list'},
      );
      expect(result, contains(r'$trellis-nav-links'));
      expect(result, contains('!default;'));
    });

    test('map param generates SASS map syntax with !default', () {
      final result = _generateSass(
        {
          'colors': <String, dynamic>{'primary': '#blue'},
        },
        {'colors': 'map'},
      );
      expect(result, contains(r'$trellis-colors'));
      expect(result, contains('!default;'));
    });

    test('param name underscores converted to hyphens', () {
      final result = _generateSass({'my_custom_param': 'val'}, {'my_custom_param': 'string'});
      expect(result, contains(r'$trellis-my-custom-param'));
    });

    test('empty params generates only header comment', () {
      final result = _generateSassRaw({}, {});
      expect(result, contains('// Auto-generated by Trellis theme system'));
      expect(result, isNot(contains('!default;')));
    });

    test('output includes header comment', () {
      final result = _generateSass({'x': 'y'}, {});
      expect(result, contains('// Auto-generated by Trellis theme system'));
      expect(result, contains('// Source: merged theme params'));
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
