import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

void main() {
  late Directory siteDir;

  setUp(() => siteDir = Directory.systemTemp.createTempSync('trellis_sass_compiler_test_'));
  tearDown(() => siteDir.deleteSync(recursive: true));

  String themeDir() => p.join(siteDir.path, 'themes', 'fixture');

  void write(String relative, String text) => File(p.join(themeDir(), relative))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);

  /// A theme whose params are all strings: [params] maps name to default, [sass] maps `sass/` files to text, and
  /// [overrides] are the site's param values.
  ThemeBuildConfig generate(
    Map<String, String> params,
    Map<String, String> sass, {
    Map<String, String> overrides = const {},
  }) {
    final yaml = StringBuffer('name: fixture\nversion: 1.0.0\nparams:\n');
    for (final MapEntry(key: name, value: value) in params.entries) {
      yaml.write('  $name:\n    type: string\n    default: $value\n');
    }
    write('theme.yaml', yaml.toString());
    for (final MapEntry(key: path, value: text) in sass.entries) {
      write(p.join('sass', path), text);
    }
    final manifest = ThemeManifest.load(themeDir());
    return const ThemeSassGenerator().generate(
      mergedParams: {...manifest.defaultParams, ...overrides},
      paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
      siteDir: siteDir.path,
      themeDir: themeDir(),
    );
  }

  String entry() => p.join(themeDir(), 'sass', 'main.scss');

  String wrapper() => File(p.join(siteDir.path, '.trellis', 'build', 'bridge_main.scss')).readAsStringSync();

  group('compileThemeEntry configures what Sass accepts', () {
    test('a candidate Sass rejects is dropped from the wrapper, the others keep their override', () {
      final config = generate(
        {'a': '1px', 'b': '2px', 'c': '3px'},
        {
          '_variables.scss': r'''
$trellis-a: 1px !default;
@mixin m { $trellis-b: 2px !default; }
$trellis-c: 3px !default;
''',
          'main.scss': "@forward 'variables';\n@use 'variables' as v;\n.t { a: v.\$trellis-a; c: v.\$trellis-c; }\n",
        },
        overrides: {'a': '10px', 'b': '20px', 'c': '30px'},
      );

      expect(config.configurableVars, ['trellis-a', 'trellis-b', 'trellis-c']);
      final result = compileThemeEntry(config, entry(), outputStyle: OutputStyle.expanded);
      final css = result.css;

      expect(result.configured, ['trellis-a', 'trellis-c']);
      expect(result.dropped, ['trellis-b']);
      expect(css, allOf(contains('a: 10px'), contains('c: 30px')));
      expect(wrapper(), allOf(contains(r'$trellis-a: tp.$trellis-a'), contains(r'$trellis-c: tp.$trellis-c')));
      expect(wrapper(), isNot(contains('trellis-b')));
    });

    test('a candidate in a partial the entry only @uses is dropped, not an error', () {
      final config = generate(
        {'a': '1px'},
        {'_extra.scss': '\$trellis-a: 1px !default;\n', 'main.scss': "@use 'extra';\n.t { a: extra.\$trellis-a; }\n"},
        overrides: {'a': '10px'},
      );

      final result = compileThemeEntry(config, entry(), outputStyle: OutputStyle.expanded);

      expect(result.dropped, ['trellis-a']);
      expect(result.configured, isEmpty);
      expect(result.css, contains('a: 1px'));
      expect(wrapper(), isNot(contains('trellis-a')));
    });

    test('an error in the theme itself is rethrown with its own location, not read as a rejected variable', () {
      final config = generate(
        {'a': '1px'},
        {
          '_variables.scss': '\$trellis-a: 1px !default;\n',
          '_inner.scss': '\$plain: 1;\n',
          'main.scss': "@forward 'variables';\n@use 'inner' with (\$plain: 2);\n",
        },
      );

      expect(
        () => compileThemeEntry(config, entry()),
        throwsA(
          isA<SassCompilationException>()
              .having((e) => e.message, 'message', contains('!default'))
              .having((e) => e.path, 'path', endsWith('main.scss')),
        ),
      );
    });
  });

  group('paletteDefaultMismatches compares colours, not text', () {
    ThemeManifest theme(String? lightDefault, String lightEntry, {String key = 'primary-color'}) {
      final defaultLine = lightDefault == null ? '' : '    default: "$lightDefault"\n';
      write('theme.yaml', 'name: fixture\nversion: 1.0.0\nparams:\n  primary_color:\n    type: color\n$defaultLine');
      write('sass/_skins/_light.scss', '\$palette: ($key: $lightEntry);\n');
      return ThemeManifest.load(themeDir());
    }

    test('the same colour in another notation or case is no mismatch', () {
      for (final (default_, entry) in [
        ('#fff', '#ffffff'),
        ('#ffffff', 'white'),
        ('#AA0000', '#aa0000'),
        ('rgb(255, 0, 0)', '#ff0000'),
      ]) {
        expect(paletteDefaultMismatches(theme(default_, entry)), isEmpty, reason: '$default_ vs $entry');
      }
    });

    test('a different colour is a mismatch carrying both values as authored', () {
      final mismatches = paletteDefaultMismatches(theme('#fff', '#fffffe'));

      expect(mismatches.map((m) => (m.param, m.mode, m.key, m.defaultValue, m.entry)), [
        ('primary_color', 'light', 'primary-color', '#fff', '#fffffe'),
      ]);
    });

    test('a colour param without a default does not drift: Sass ignores a null configuration', () {
      expect(paletteDefaultMismatches(theme(null, '#ff0000')), isEmpty);
    });

    test('a palette without the key is a mismatch with no entry', () {
      final mismatches = paletteDefaultMismatches(theme('#fff', '#fff', key: 'brand'));

      expect(mismatches.map((m) => (m.param, m.entry)), [('primary_color', null)]);
    });
  });
}
