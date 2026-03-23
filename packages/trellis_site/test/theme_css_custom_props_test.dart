import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

void main() {
  group('ThemeSassGenerator — CSS custom property generation', () {
    test('color param generates --trellis- custom property', () {
      final result = _generateCss({'primary_color': '#2563eb'}, {'primary_color': 'color'});
      expect(result, contains('--trellis-primary-color: #2563eb;'));
    });

    test('string param generates custom property without quotes', () {
      final result = _generateCss({'font_family': 'system-ui, sans-serif'}, {'font_family': 'string'});
      expect(result, contains('--trellis-font-family: system-ui, sans-serif;'));
    });

    test('boolean param is excluded from CSS output', () {
      final result = _generateCss({'show_powered_by': true}, {'show_powered_by': 'boolean'});
      expect(result, isNot(contains('--trellis-show-powered-by')));
    });

    test('boolean false param is excluded from CSS output', () {
      final result = _generateCss({'enable_toc': false}, {'enable_toc': 'boolean'});
      expect(result, isNot(contains('--trellis-enable-toc')));
    });

    test('enum param is excluded from CSS output', () {
      final result = _generateCss({'skin': 'dark'}, {'skin': 'enum'});
      expect(result, isNot(contains('--trellis-skin')));
    });

    test('list param is excluded from CSS output', () {
      final result = _generateCss(
        {'nav_links': <dynamic>['a', 'b']},
        {'nav_links': 'list'},
      );
      expect(result, isNot(contains('--trellis-nav-links')));
    });

    test('map param is excluded from CSS output', () {
      final result = _generateCss({'colors': <String, dynamic>{'a': 'b'}}, {'colors': 'map'});
      expect(result, isNot(contains('--trellis-colors')));
    });

    test('null param generates initial keyword', () {
      final result = _generateCss({'hero_title': null}, {'hero_title': 'string'});
      expect(result, contains('--trellis-hero-title: initial;'));
    });

    test('all params wrapped in :root block', () {
      final result = _generateCss({'primary_color': '#fff'}, {'primary_color': 'color'});
      expect(result, contains(':root {'));
      expect(result, contains('}'));
    });

    test('param name underscores converted to hyphens in CSS name', () {
      final result = _generateCss({'border_radius': '6px'}, {'border_radius': 'string'});
      expect(result, contains('--trellis-border-radius: 6px;'));
    });

    test('output includes auto-generated comment', () {
      final result = _generateCss({'x': 'y'}, {});
      expect(result, contains('/* Auto-generated CSS custom properties'));
    });
  });
}

/// Runs [ThemeSassGenerator.generate] in a temp directory and returns the
/// content of the generated `_theme_custom_props.css`.
String _generateCss(Map<String, dynamic> params, Map<String, String> types) {
  final tempDir = Directory.systemTemp.createTempSync('trellis_css_props_test_');
  try {
    const gen = ThemeSassGenerator();
    gen.generate(
      mergedParams: {'skin': 'light', ...params},
      paramTypes: {'skin': 'enum', ...types},
      siteDir: tempDir.path,
    );
    return File(p.join(tempDir.path, '.trellis', 'build', '_theme_custom_props.css')).readAsStringSync();
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
