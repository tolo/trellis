import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

/// Proves lattice on the `@use` bridge contract: compiled through the same
/// wrapper `trellis build` compiles, with the `@import` deprecation fatal, at
/// every skin, with per-mode colour overrides reaching every dark view.

/// Two colours no output style abbreviates, so `contains` assertions are stable.
const _lightOverride = '#123456';
const _darkOverride = '#654321';

/// Colour params' palette keys, mapped to the lattice token each one feeds in
/// both the light `:root` and the dark views.
const _paletteTokens = {
  'bg-color': '--paper',
  'text-color': '--ink',
  'muted-color': '--ink-soft',
  'primary-color': '--leaf',
  'accent-color': '--tendril',
  'surface-color': '--card',
  'border-color': '--lattice',
};

/// Tokens that stay theme-authored in dark: no colour param backs them.
const _themeAuthoredDark = ['--footer-link', '--leaf-hover', '--on-leaf', '--lattice-strong', '--bg-lattice'];

void main() {
  late String themeDir;
  late Directory tempDir;
  late ThemeManifest manifest;
  late Map<String, String> lightPalette;
  late Map<String, String> darkPalette;

  setUpAll(() async {
    themeDir = p.join(await _repoRoot(), 'themes', 'lattice');
    manifest = ThemeManifest.load(themeDir);
    lightPalette = _palette(themeDir, 'light');
    darkPalette = _palette(themeDir, 'dark');
  });

  setUp(() {
    tempDir = Directory(Directory.systemTemp.createTempSync('trellis_lattice_use_').resolveSymbolicLinksSync());
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  ThemeBuildConfig generate(String skin, Map<String, dynamic> siteParams) {
    final merged = const ThemeParamMerger().merge(manifest.defaultParams, {'skin': skin, ...siteParams}).params;
    return const ThemeSassGenerator().generate(
      mergedParams: merged,
      paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
      siteDir: tempDir.path,
      themeDir: themeDir,
    );
  }

  /// Compiles lattice exactly as the site builder + CLI do: manifest defaults merged
  /// with [siteParams], the generated params module, and the shared wrapper.
  String compileLattice(String skin, {Map<String, dynamic> siteParams = const {}}) {
    final config = generate(skin, siteParams);
    final entry = File(p.join(themeDir, 'sass', 'main.scss')).resolveSymbolicLinksSync();
    final wrapper = File(p.join(config.buildDir, 'bridge_main.scss'))
      ..writeAsStringSync(config.bridgeWrapperSource(entry));
    return TrellisCss.compileSass(wrapper.path, loadPaths: config.sassLoadPaths, fatalImportDeprecation: true);
  }

  group('S01 compiles with fatal import deprecation, bridged and standalone', () {
    test('every skin compiles through the bridge', () {
      for (final skin in ['light', 'dark', 'auto']) {
        expect(compileLattice(skin), contains('--leaf:'), reason: skin);
      }
    });

    test('standalone compile carries the light palette defaults and no @import remains', () {
      final css = TrellisCss.compileSass(
        File(p.join(themeDir, 'sass', 'main.scss')).resolveSymbolicLinksSync(),
        fatalImportDeprecation: true,
      );
      expect(_props(_rootBlock(css))['--leaf']!.toLowerCase(), '#2e7d4f');
      for (final file in Directory(p.join(themeDir, 'sass')).listSync(recursive: true).whereType<File>()) {
        expect(_stripComments(file.readAsStringSync()), isNot(contains('@import')), reason: file.path);
      }
    });
  });

  group('S02/S03 configurable variables and non-colour overrides', () {
    test('S02: configurableVars covers every lattice variable, multi-line font stacks included', () {
      const params = [
        'skin',
        'primary_color',
        'accent_color',
        'text_color',
        'muted_color',
        'bg_color',
        'surface_color',
        'border_color',
        'primary_color_dark',
        'accent_color_dark',
        'text_color_dark',
        'muted_color_dark',
        'bg_color_dark',
        'surface_color_dark',
        'border_color_dark',
        'font_family',
        'heading_font_family',
        'code_font_family',
        'max_width',
        'border_radius',
        'footer_text',
        'show_powered_by',
        'show_rss_link',
        'show_sidebar',
        'show_toc',
        'show_prev_next',
        'show_search',
      ];
      expect(params, hasLength(27));
      expect(generate('auto', const {}).configurableVars.toSet(), {
        for (final name in params) 'trellis-${name.replaceAll('_', '-')}',
      });
    });

    test('S03: site overrides for non-colour variables win on compiled CSS', () {
      final root = _props(
        _rootBlock(
          compileLattice(
            'auto',
            siteParams: {
              'font_family': 'Inter, sans-serif',
              'heading_font_family': 'Georgia, serif',
              'code_font_family': 'Menlo, monospace',
              'max_width': '900px',
              'border_radius': '2px',
            },
          ),
        ),
      );
      expect(root['--body'], 'Inter, sans-serif');
      expect(root['--display'], 'Georgia, serif');
      expect(root['--mono'], 'Menlo, monospace');
      expect(root['--content-width'], '900px');
      expect(root['--radius'], '2px');
    });
  });

  group('S04 skins survive the migration', () {
    test('light, dark and auto carry their palettes and dark views', () {
      final light = compileLattice('light');
      final dark = compileLattice('dark');
      final auto = compileLattice('auto');

      _expectPalette(_props(_rootBlock(light)), lightPalette, reason: 'light :root');
      _expectPalette(_props(_rootBlock(auto)), lightPalette, reason: 'auto :root');
      _expectPalette(_props(_rootBlock(dark)), darkPalette, reason: 'dark :root');

      for (final css in [light, dark, auto]) {
        _expectPalette(_props(_toggleDarkBlock(css)!), darkPalette, reason: 'toggle dark rule');
      }
      expect(light, isNot(contains('prefers-color-scheme')));
      expect(dark, isNot(contains('prefers-color-scheme')));
      _expectPalette(_props(_mediaDarkBlock(auto)!), darkPalette, reason: 'auto @media rule');
    });
  });

  group('S08-S10 per-mode colour params', () {
    test('S08: a _dark override reaches a forced dark skin and nothing else moves', () {
      final plain = compileLattice('dark');
      final css = compileLattice('dark', siteParams: {'primary_color_dark': _darkOverride});
      final plainRoot = _props(_rootBlock(plain));
      final root = _props(_rootBlock(css));
      final rule = _props(_toggleDarkBlock(css)!);

      expect(rule['--leaf'], _darkOverride);
      expect(root['--leaf'], _darkOverride);
      expect(root['--footer-link'], plainRoot['--footer-link']);
      expect(
        Map.of(rule)..remove('--leaf'),
        Map.of(_props(_toggleDarkBlock(plain)!))..remove('--leaf'),
        reason: 'every other dark-rule token is unchanged',
      );
      expect(
        Map.of(root)
          ..remove('--leaf')
          ..remove('--leaf-hover'),
        Map.of(plainRoot)
          ..remove('--leaf')
          ..remove('--leaf-hover'),
        reason: 'only the primary and its derived hover move in :root',
      );
      expect(css, isNot(contains('prefers-color-scheme')));
      expect(compileLattice('auto'), contains('prefers-color-scheme'), reason: 'the negative query is not vacuous');
    });

    test('S08: every _dark twin reaches its token in the forced dark views', () {
      for (final key in _paletteTokens.keys) {
        final css = compileLattice('dark', siteParams: {'${key.replaceAll('-', '_')}_dark': _darkOverride});
        final token = _paletteTokens[key]!;
        expect(_props(_rootBlock(css))[token], _darkOverride, reason: ':root $token');
        expect(_props(_toggleDarkBlock(css)!)[token], _darkOverride, reason: 'dark rule $token');
      }
    });

    test('S09: a _dark override reaches both dark views under auto, through the palette', () {
      final plain = compileLattice('auto');
      final css = compileLattice('auto', siteParams: {'primary_color_dark': _darkOverride});
      final media = _props(_mediaDarkBlock(css)!);

      expect(_props(_rootBlock(css))['--leaf']!.toLowerCase(), lightPalette['primary-color']);
      expect(_props(_toggleDarkBlock(css)!)['--leaf'], _darkOverride);
      expect(media['--leaf'], _darkOverride);
      expect(media['--footer-link'], _props(_mediaDarkBlock(plain)!)['--footer-link'], reason: 'theme-authored');
    });

    test('S09: every _dark twin reaches its token in the toggle rule and the @media rule', () {
      for (final key in _paletteTokens.keys) {
        final css = compileLattice('auto', siteParams: {'${key.replaceAll('-', '_')}_dark': _darkOverride});
        final token = _paletteTokens[key]!;
        expect(_props(_toggleDarkBlock(css)!)[token], _darkOverride, reason: 'toggle $token');
        expect(_props(_mediaDarkBlock(css)!)[token], _darkOverride, reason: '@media $token');
        expect(_props(_rootBlock(css))[token]!.toLowerCase(), isNot(_darkOverride), reason: 'light :root $token');
      }
    });

    test('S10: a plain colour param sets the light entry only', () {
      // Documented precedence rule, not load-order luck: a forced skin selects a
      // palette and a per-mode param sets one entry in it, so a plain
      // `primary_color` (the light entry) has no effect on a `skin: dark` site.
      final dark = compileLattice('dark', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(dark))['--leaf'], darkPalette['primary-color']);
      expect(_props(_toggleDarkBlock(dark)!)['--leaf'], darkPalette['primary-color']);

      final auto = compileLattice('auto', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(auto))['--leaf'], _lightOverride);
      expect(_props(_toggleDarkBlock(auto)!)['--leaf'], darkPalette['primary-color']);
      expect(_props(_mediaDarkBlock(auto)!)['--leaf'], darkPalette['primary-color']);

      final light = compileLattice('light', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(light))['--leaf'], _lightOverride);
    });

    test('S10: a _dark-only override under light leaves :root unchanged', () {
      expect(
        _rootBlock(compileLattice('light', siteParams: {'primary_color_dark': _darkOverride})),
        _rootBlock(compileLattice('light')),
      );
    });
  });

  group('S11 every colour param has a _dark twin sourced from the palettes', () {
    test('twins exist, defaults equal the palette entries, twins have no twins', () {
      final colorParams = {
        for (final e in manifest.params.entries)
          if (e.value.type == 'color') e.key: e.value,
      };
      final bases = colorParams.keys.where((name) => !name.endsWith('_dark')).toList();
      expect(bases, hasLength(7));

      for (final name in bases) {
        final key = name.replaceAll('_', '-');
        final twin = colorParams['${name}_dark'];
        expect(twin, isNotNull, reason: '$name needs a ${name}_dark twin');
        expect((twin!.defaultValue as String).toLowerCase(), darkPalette[key]!.toLowerCase(), reason: '${name}_dark');
        expect(
          (colorParams[name]!.defaultValue as String).toLowerCase(),
          lightPalette[key]!.toLowerCase(),
          reason: name,
        );
        expect(colorParams.containsKey('${name}_dark_dark'), isFalse, reason: 'twins have no twins');
      }
      expect(
        colorParams.keys.where((name) => name.endsWith('_dark')),
        hasLength(bases.length),
        reason: 'no orphan twin',
      );
    });
  });

  group('SC02-SC04 structure', () {
    String sass(String relative) => _stripComments(File(p.join(themeDir, 'sass', relative)).readAsStringSync());

    test("main.scss opens with @forward 'variables' as its first module rule", () {
      final firstRule = RegExp(r'@(use|forward)\b[^;]*;').firstMatch(sass('main.scss'));
      expect(firstRule!.group(0), "@forward 'variables';");
      expect(sass('main.scss'), contains("@use 'variables' as *;"));
    });

    test(r'skins expose a $palette and declare nothing !default', () {
      for (final skin in ['_light', '_dark']) {
        final source = sass('_skins/$skin.scss');
        expect(source, contains(r'$palette:'), reason: skin);
        expect(source, isNot(contains('!default')), reason: skin);
      }
    });

    test('the font stacks keep their multi-line declarations, which the bridge still configures', () {
      final variables = sass('_variables.scss');
      expect(variables, matches(RegExp(r'\$trellis-font-family:\s*\n\s+Instrument Sans,[^;]*!default;')));
      expect(variables, matches(RegExp(r'\$trellis-code-font-family:\s*\n\s+Spline Sans Mono,[^;]*!default;')));
    });

    test('the dark mixin reads each palette-backed token from the dark palette and keeps the rest literal', () {
      final source = sass('main.scss');
      final mixin = source.substring(source.indexOf('@mixin lattice-dark'), source.indexOf('[data-skin="dark"]'));
      for (final entry in _paletteTokens.entries) {
        expect(
          mixin,
          contains('${entry.value}: #{map.get(\$trellis-palette-dark, ${entry.key})};'),
          reason: '${entry.value} reads ${entry.key}',
        );
      }
      for (final token in _themeAuthoredDark) {
        final declaration = RegExp('^\\s*${RegExp.escape(token)}:\\s*([^;]+);', multiLine: true).firstMatch(mixin);
        expect(declaration, isNotNull, reason: token);
        expect(declaration!.group(1), isNot(contains(r'$')), reason: '$token stays a literal');
      }
    });
  });
}

/// Reads a skin's `$palette` map by compiling it, so the test sees what Sass sees.
Map<String, String> _palette(String themeDir, String mode) {
  final css = TrellisCss.compileSassString(
    '''
@use "_$mode" as skin;
:root { @each \$key, \$value in skin.\$palette { --#{\$key}: #{\$value}; } }
''',
    loadPaths: [p.join(themeDir, 'sass', '_skins')],
  );
  return {for (final e in _props(_rootBlock(css)).entries) e.key.substring(2): e.value};
}

/// Asserts [props] carries every palette entry on the token it feeds, case-insensitively.
void _expectPalette(Map<String, String> props, Map<String, String> palette, {required String reason}) {
  for (final entry in _paletteTokens.entries) {
    expect(props[entry.value]?.toLowerCase(), palette[entry.key]!.toLowerCase(), reason: '$reason ${entry.value}');
  }
}

/// Body of the first top-level `:root { ... }` rule.
String _rootBlock(String css) {
  final start = RegExp(r'^:root \{', multiLine: true).firstMatch(css)!;
  return css.substring(start.end, css.indexOf('\n}', start.end));
}

/// Body of the grouped dark rule `[data-skin=dark], [data-skin=auto][data-theme=dark]`
/// (Sass serializes the attribute values unquoted), or null.
String? _toggleDarkBlock(String css) {
  final start = RegExp(
    r'^\[data-skin="?dark"?\],\s*\[data-skin="?auto"?\]\[data-theme="?dark"?\]\s*\{',
    multiLine: true,
  ).firstMatch(css);
  return start == null ? null : css.substring(start.end, css.indexOf('\n}', start.end));
}

/// Body of `[data-skin=auto]:not([data-theme=light])` inside `@media (prefers-color-scheme: dark)`, or null.
String? _mediaDarkBlock(String css) {
  final media = css.indexOf('@media (prefers-color-scheme: dark)');
  if (media == -1) return null;
  final start = RegExp(r'\[data-skin="?auto"?\]:not\(\[data-theme="?light"?\]\)\s*\{').firstMatch(css.substring(media));
  if (start == null) return null;
  final from = media + start.end;
  return css.substring(from, css.indexOf('}', from));
}

/// Custom properties declared in [block] (`--name: value;` lines).
Map<String, String> _props(String block) => {
  for (final m in RegExp(r'(--[\w-]+):\s*([^;]+);').allMatches(block)) m.group(1)!: m.group(2)!.trim(),
};

String _stripComments(String source) =>
    source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//.*'), '');

/// Resolves the monorepo root by walking up from this package until `themes/lattice`
/// is found, so the test works regardless of the test CWD.
Future<String> _repoRoot() async {
  final uri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/trellis_site.dart'));
  if (uri == null || uri.scheme != 'file') {
    throw StateError('Could not resolve package:trellis_site/trellis_site.dart');
  }
  var dir = Directory(p.dirname(uri.toFilePath()));
  while (!Directory(p.join(dir.path, 'themes', 'lattice')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('Could not find repo root (themes/lattice) from ${uri.toFilePath()}');
    dir = parent;
  }
  return dir.path;
}
