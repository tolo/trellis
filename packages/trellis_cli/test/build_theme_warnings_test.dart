import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

import '_workspace_root.dart';

/// `trellis build` and a theme's SASS bridge: the warning for a colour default that differs from its palette entry
/// (TD-055), and the entry being configured with exactly the params Sass accepts, with a warning for a site override
/// of one it cannot reach (TD-056).

class _BufferStdout implements Stdout {
  _BufferStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late Directory siteDir;

  setUp(() => siteDir = Directory.systemTemp.createTempSync('trellis_build_theme_warnings_'));
  tearDown(() => siteDir.deleteSync(recursive: true));

  void write(String path, String content) {
    final file = File(p.join(siteDir.path, path))..parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  /// A site with layouts of its own, so any theme builds under it whatever layouts the theme ships.
  void writeSite({String themeValue = 'warn_theme', String themeParams = ''}) {
    write('trellis_site.yaml', 'title: T\nbaseUrl: https://example.com\ntheme: $themeValue\n$themeParams');
    write('content/_index.md', '---\ntitle: Home\n---\nHi.\n');
    const page = '<!DOCTYPE html><html><head><title>T</title></head><body><h1>T</h1></body></html>\n';
    write('layouts/home.html', page);
    write('layouts/_default/list.html', page);
  }

  /// A theme with one colour param and its dark twin. The palettes carry [lightEntry] and [darkEntry]; the manifest
  /// defaults are [lightDefault] and [darkDefault], and [paletteKey] names the palette key. [variables] is the body of
  /// `sass/_variables.scss`, [rules] goes in `main.scss`'s rule, and [extra] maps more `sass/` files to their text.
  /// [extraParams] is more `theme.yaml` param blocks.
  void writeTheme({
    String lightDefault = '#aa0000',
    String darkDefault = '#00aa00',
    String lightEntry = '#aa0000',
    String darkEntry = '#00aa00',
    String variables = '\$trellis-primary-color: #aa0000 !default;\n\$trellis-primary-color-dark: #00aa00 !default;\n',
    String forwards = "@forward 'variables';\n",
    String rules = '',
    String paletteKey = 'primary-color',
    String extraParams = '',
    Map<String, String> extra = const {},
  }) {
    write('themes/warn_theme/theme.yaml', '''
name: warn_theme
version: 1.0.0
params:
  primary_color:
    type: color
    default: "$lightDefault"
  primary_color_dark:
    type: color
    default: "$darkDefault"
$extraParams''');
    write('themes/warn_theme/sass/_variables.scss', variables);
    write('themes/warn_theme/sass/_skins/_light.scss', '\$palette: ($paletteKey: $lightEntry);\n');
    write('themes/warn_theme/sass/_skins/_dark.scss', '\$palette: ($paletteKey: $darkEntry);\n');
    write(
      'themes/warn_theme/sass/main.scss',
      "$forwards@use 'variables' as *;\n.t { color: \$trellis-primary-color; $rules }\n",
    );
    for (final entry in extra.entries) {
      write('themes/warn_theme/sass/${entry.key}', entry.value);
    }
  }

  Future<({int exitCode, String warnings, String errors, String summary, String output})> build([
    List<String> args = const [],
  ]) async {
    final out = StringBuffer();
    final err = StringBuffer();
    late int exitCode;
    await IOOverrides.runZoned(
      () async => exitCode = await TrellisCli(workingDirectory: siteDir.path).run(['build', ...args]),
      stdout: () => _BufferStdout(out),
      stderr: () => _BufferStdout(err),
    );
    String lines(String text, String needle) => text.split('\n').where((line) => line.contains(needle)).join('\n');
    return (
      exitCode: exitCode,
      warnings: lines('$out\n$err', 'Warning:'),
      errors: err.toString(),
      summary: lines(out.toString(), 'Built '),
      output: out.toString(),
    );
  }

  String css() => File(p.join(siteDir.path, 'output', 'css', 'main.css')).readAsStringSync();

  group('palette default warning (TD-055)', () {
    test('warns, naming the theme, the param and both values, when a default differs from its palette entry', () async {
      writeSite();
      writeTheme(lightEntry: '#bb0000');

      final result = await build();

      expect(result.exitCode, 0, reason: 'a warning does not fail the build');
      expect(
        result.warnings,
        allOf(contains('warn_theme'), contains('primary_color'), contains('#aa0000'), contains('#bb0000')),
      );
      expect(result.warnings, contains('light'));
      expect(result.warnings, contains('unless the site overrides it'));
    });

    test('names the dark palette for a twin', () async {
      writeSite();
      writeTheme(darkEntry: '#00bb00');

      final result = await build();

      expect(
        result.warnings,
        allOf(contains('primary_color_dark'), contains('#00aa00'), contains('#00bb00'), contains('dark')),
      );
      expect(result.warnings, isNot(contains("param 'primary_color'")), reason: 'the light pair agrees');
    });

    test('is silent when defaults equal their palette entries, in any hex case', () async {
      writeSite();
      writeTheme(lightEntry: '#AA0000');

      final result = await build();

      expect(result.exitCode, 0);
      expect(result.warnings, isNot(contains('palette')));
    });

    test('equal colours in different notations are not a difference', () async {
      for (final (default_, entry) in [('#fff', '#ffffff'), ('#ffffff', 'white'), ('rgb(255, 0, 0)', '#ff0000')]) {
        writeSite();
        writeTheme(lightDefault: default_, lightEntry: entry);

        final result = await build();

        expect(result.exitCode, 0, reason: '$default_ vs $entry');
        expect(result.warnings, isEmpty, reason: '$default_ vs $entry');
      }
    });

    test('a palette without the param key is not a drift: no warning', () async {
      // A third-party theme may name its palette keys differently, and would be warned about every colour param.
      writeSite();
      writeTheme(paletteKey: 'brand');

      final result = await build();

      expect(result.exitCode, 0);
      expect(result.warnings, isEmpty);
    });

    test('is a counted build warning, printed without --verbose, and printed once with it', () async {
      writeSite();
      writeTheme(lightEntry: '#bb0000');
      // A second entry would repeat a per-entry warning; this one belongs to the theme.
      write('themes/warn_theme/sass/print.scss', "@forward 'variables';\n");

      final quiet = await build();
      final verbose = await build(['--verbose']);

      // The fixture's layouts do not link the theme, so its inert-theme warning is counted too.
      List<String> driftLines(String warnings) =>
          warnings.split('\n').where((l) => l.contains('primary_color')).toList();
      expect(driftLines(quiet.warnings), hasLength(1));
      expect(quiet.summary, contains('(2 warnings)'));
      expect(driftLines(verbose.warnings), hasLength(1));
      expect(verbose.summary, contains('(2 warnings)'));
    });

    test("compares the manifest default, not the site's override", () async {
      writeSite(themeParams: 'theme_params:\n  primary_color: "#123456"\n');
      writeTheme();

      final result = await build();

      expect(result.exitCode, 0);
      expect(result.warnings, isNot(contains('palette')));
    });

    test('a theme without palette files is not held to the convention', () async {
      writeSite();
      writeTheme();
      Directory(p.join(siteDir.path, 'themes', 'warn_theme', 'sass', '_skins')).deleteSync(recursive: true);

      final result = await build();

      expect(result.exitCode, 0);
      expect(result.warnings, isNot(contains('palette')));
    });

    for (final theme in ['arbor', 'bloom', 'folio', 'lattice', 'meadow', 'verdant']) {
      test('the bundled $theme theme builds with no bridge warning', () async {
        final root = await findWorkspaceRoot();
        writeSite(themeValue: p.relative(p.join(root.path, 'themes', theme), from: p.join(siteDir.path, 'themes')));

        final result = await build();

        expect(result.exitCode, 0, reason: result.errors);
        expect(result.warnings, isNot(contains('palette')));
        expect(result.warnings, isNot(contains(r'$trellis-')));
      });
    }
  });

  group('the entry is configured with the params Sass accepts (TD-056)', () {
    const manifestParam = '''
  other_width:
    type: string
    default: 10px
''';
    const paramsOverride = 'theme_params:\n  other_width: 33px\n';
    const colorVariables =
        '\$trellis-primary-color: #aa0000 !default;\n\$trellis-primary-color-dark: #00aa00 !default;\n';
    const useWidth = r'width: $trellis-other-width;';

    test('a plain theme produces no warning and the override takes effect', () async {
      writeSite(themeParams: paramsOverride);
      writeTheme(
        extraParams: manifestParam,
        rules: useWidth,
        variables: '$colorVariables\$trellis-other-width: 10px !default;\n',
      );

      final result = await build();

      expect(result.exitCode, 0);
      expect(result.warnings, isEmpty);
      expect(css(), contains('width:33px'));
    });

    const sharpEdges = {
      'url(data:...;...)': 'url(data:image/png;base64,AAAA)',
      'url(//...)': 'url(//cdn.example/x.png)',
    };
    for (final entry in sharpEdges.entries) {
      test('${entry.key} in the default does not hide the variable: the override takes effect', () async {
        writeSite(themeParams: paramsOverride);
        writeTheme(
          extraParams: manifestParam,
          rules: useWidth,
          variables: '$colorVariables\$trellis-other-width: ${entry.value} !default;\n',
        );

        final result = await build();

        expect(result.exitCode, 0);
        expect(result.warnings, isEmpty);
        expect(css(), contains('width:33px'));
      });

      test('${entry.key} does not swallow the declaration after it', () async {
        writeSite(themeParams: 'theme_params:\n  other_width: 33px\n  third: 44px\n');
        writeTheme(
          extraParams: '$manifestParam  third:\n    type: string\n    default: 20px\n',
          rules: '$useWidth height: \$trellis-third;',
          variables:
              '$colorVariables\$trellis-other-width: ${entry.value} !default;\n\$trellis-third: 20px !default;\n',
        );

        final result = await build();

        expect(result.exitCode, 0);
        expect(css(), allOf(contains('width:33px'), contains('height:44px')));
      });
    }

    test('a param declared !default outside _variables.scss but forwarded by the entry takes the override', () async {
      writeSite(themeParams: paramsOverride);
      writeTheme(
        extraParams: manifestParam,
        rules: useWidth,
        forwards: "@forward 'variables';\n@forward 'extra';\n@use 'extra' as *;\n",
        extra: {'_extra.scss': '\$trellis-other-width: 10px !default;\n'},
      );

      final result = await build();

      expect(result.exitCode, 0);
      expect(result.warnings, isEmpty);
      expect(css(), contains('width:33px'));
    });

    test(
      'a !default in a file the entry only @uses is not configurable: the override is reported, the default stays',
      () async {
        writeSite(themeParams: paramsOverride);
        writeTheme(
          extraParams: manifestParam,
          forwards: "@forward 'variables';\n@use 'extra' as e;\n",
          rules: 'width: e.\$trellis-other-width;',
          extra: {'_extra.scss': '\$trellis-other-width: 10px !default;\n'},
        );

        final result = await build();

        expect(result.exitCode, 0);
        expect(
          result.warnings,
          allOf(
            contains("theme 'warn_theme'"),
            contains("entry 'main.scss'"),
            contains("param 'other_width'"),
            contains('no effect'),
          ),
        );
        expect(css(), contains('width:10px'));
      },
    );

    const misreadAsDefault = {
      'inside a string': '\$trellis-other-width: "10px !default";\n',
      'inside a mixin': '@mixin m { \$trellis-other-width: 10px !default; }\n',
      'inside an @if': '@if true { \$trellis-other-width: 10px !default; }\n',
    };
    for (final entry in misreadAsDefault.entries) {
      test('a !default ${entry.key} that the site overrides is reported, and the build succeeds', () async {
        writeSite(themeParams: paramsOverride);
        writeTheme(extraParams: manifestParam, variables: '$colorVariables${entry.value}');

        final result = await build();

        expect(result.exitCode, 0, reason: result.errors);
        expect(result.warnings, allOf(contains("param 'other_width'"), contains('no effect')));
        expect(result.warnings.split('\n'), hasLength(1));
        expect(result.summary, contains('(2 warnings)'), reason: 'counted with the fixture\'s inert-theme warning');
      });

      test('a !default ${entry.key} the site leaves alone is listed under --verbose only', () async {
        writeSite();
        writeTheme(extraParams: manifestParam, variables: '$colorVariables${entry.value}');

        final quiet = await build();
        final verbose = await build(['--verbose']);

        expect(quiet.exitCode, 0, reason: quiet.errors);
        expect(quiet.output + quiet.errors, isNot(contains('trellis-other-width')));
        expect(verbose.output, allOf(contains('main.scss'), contains(r'$trellis-other-width')));
        expect(verbose.warnings, isNot(contains('other_width')), reason: 'not a warning: nothing was overridden');
      });
    }

    test('a dropped param is reported once per theme, not once per entry', () async {
      writeSite(themeParams: paramsOverride);
      writeTheme(
        extraParams: manifestParam,
        variables: '$colorVariables@mixin m { \$trellis-other-width: 10px !default; }\n',
      );
      write('themes/warn_theme/sass/print.scss', "@forward 'variables';\n");

      final result = await build(['--verbose']);

      expect(result.warnings.split('\n').where((l) => l.contains("param 'other_width'")), hasLength(1));
      expect(
        result.output.split('\n').where((l) => l.contains(r'$trellis-other-width') && !l.contains('Warning:')),
        hasLength(2),
        reason: 'the verbose list names the param on each entry',
      );
    });

    test('a theme-internal @use ... with() that Sass rejects fails the build with its own error', () async {
      writeSite();
      writeTheme(
        extraParams: manifestParam,
        variables: '$colorVariables\$trellis-other-width: 10px !default;\n',
        extra: {'_inner.scss': '\$not-default: 1;\n', '_uses_inner.scss': "@use 'inner' with (\$not-default: 2);\n"},
        forwards: "@forward 'variables';\n@use 'uses_inner';\n",
      );

      final result = await build();

      expect(result.exitCode, 1);
      expect(result.errors, allOf(contains('_uses_inner.scss'), contains('!default')));
    });
  });
}
