import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

import 'theme_sass_sources.dart';
import 'theme_use_support.dart';

/// Proves lattice on the `@use` bridge contract: compiled through the same
/// wrapper `trellis build` compiles, with the `@import` deprecation fatal, at
/// every skin, with per-mode colour overrides reaching every dark view.

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
    themeDir = p.join(await findRepoRoot(), 'themes', 'lattice');
    manifest = ThemeManifest.load(themeDir);
    lightPalette = readPalette(themeDir, 'light');
    darkPalette = readPalette(themeDir, 'dark');
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
      expect(customProps(rootBlock(css))['--leaf']!.toLowerCase(), '#2e7d4f');
      for (final file in sweepFiles(p.join(themeDir, 'sass'))) {
        expect(stripComments(file.readAsStringSync()), isNot(contains('@import')), reason: file.path);
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
      final root = customProps(
        rootBlock(
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

      _expectPalette(customProps(rootBlock(light)), lightPalette, reason: 'light :root');
      _expectPalette(customProps(rootBlock(auto)), lightPalette, reason: 'auto :root');
      _expectPalette(customProps(rootBlock(dark)), darkPalette, reason: 'dark :root');

      for (final css in [light, dark, auto]) {
        _expectPalette(customProps(_toggleDarkBlock(css)!), darkPalette, reason: 'toggle dark rule');
      }
      expect(light, isNot(contains('prefers-color-scheme')));
      expect(dark, isNot(contains('prefers-color-scheme')));
      _expectPalette(customProps(_mediaDarkBlock(auto)!), darkPalette, reason: 'auto @media rule');
    });
  });

  group('S08-S10 per-mode colour params', () {
    test('S08: a _dark override reaches a forced dark skin and nothing else moves', () {
      final plain = compileLattice('dark');
      final css = compileLattice('dark', siteParams: {'primary_color_dark': darkOverride});
      final plainRoot = customProps(rootBlock(plain));
      final root = customProps(rootBlock(css));
      final rule = customProps(_toggleDarkBlock(css)!);

      expect(rule['--leaf'], darkOverride);
      expect(root['--leaf'], darkOverride);
      expect(root['--footer-link'], plainRoot['--footer-link']);
      expect(
        Map.of(rule)..remove('--leaf'),
        Map.of(customProps(_toggleDarkBlock(plain)!))..remove('--leaf'),
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
        final css = compileLattice('dark', siteParams: {'${key.replaceAll('-', '_')}_dark': darkOverride});
        final token = _paletteTokens[key]!;
        expect(customProps(rootBlock(css))[token], darkOverride, reason: ':root $token');
        expect(customProps(_toggleDarkBlock(css)!)[token], darkOverride, reason: 'dark rule $token');
      }
    });

    test('S09: a _dark override reaches both dark views under auto, through the palette', () {
      final plain = compileLattice('auto');
      final css = compileLattice('auto', siteParams: {'primary_color_dark': darkOverride});
      final media = customProps(_mediaDarkBlock(css)!);

      expect(customProps(rootBlock(css))['--leaf']!.toLowerCase(), lightPalette['primary-color']);
      expect(customProps(_toggleDarkBlock(css)!)['--leaf'], darkOverride);
      expect(media['--leaf'], darkOverride);
      expect(media['--footer-link'], customProps(_mediaDarkBlock(plain)!)['--footer-link'], reason: 'theme-authored');
    });

    test('S09: every _dark twin reaches its token in the toggle rule and the @media rule', () {
      for (final key in _paletteTokens.keys) {
        final css = compileLattice('auto', siteParams: {'${key.replaceAll('-', '_')}_dark': darkOverride});
        final token = _paletteTokens[key]!;
        expect(customProps(_toggleDarkBlock(css)!)[token], darkOverride, reason: 'toggle $token');
        expect(customProps(_mediaDarkBlock(css)!)[token], darkOverride, reason: '@media $token');
        expect(customProps(rootBlock(css))[token]!.toLowerCase(), isNot(darkOverride), reason: 'light :root $token');
      }
    });

    test('S10: a plain colour param sets the light entry only', () {
      // Documented precedence rule, not load-order luck: a forced skin selects a
      // palette and a per-mode param sets one entry in it, so a plain
      // `primary_color` (the light entry) has no effect on a `skin: dark` site.
      final dark = compileLattice('dark', siteParams: {'primary_color': lightOverride});
      expect(customProps(rootBlock(dark))['--leaf'], darkPalette['primary-color']);
      expect(customProps(_toggleDarkBlock(dark)!)['--leaf'], darkPalette['primary-color']);

      final auto = compileLattice('auto', siteParams: {'primary_color': lightOverride});
      expect(customProps(rootBlock(auto))['--leaf'], lightOverride);
      expect(customProps(_toggleDarkBlock(auto)!)['--leaf'], darkPalette['primary-color']);
      expect(customProps(_mediaDarkBlock(auto)!)['--leaf'], darkPalette['primary-color']);

      final light = compileLattice('light', siteParams: {'primary_color': lightOverride});
      expect(customProps(rootBlock(light))['--leaf'], lightOverride);
    });

    test('S10: a _dark-only override under light leaves :root unchanged', () {
      expect(
        rootBlock(compileLattice('light', siteParams: {'primary_color_dark': darkOverride})),
        rootBlock(compileLattice('light')),
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
    String sass(String relative) => stripComments(File(p.join(themeDir, 'sass', relative)).readAsStringSync());

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

/// Asserts [props] carries every palette entry on the token it feeds, case-insensitively.
void _expectPalette(Map<String, String> props, Map<String, String> palette, {required String reason}) {
  for (final entry in _paletteTokens.entries) {
    expect(props[entry.value]?.toLowerCase(), palette[entry.key]!.toLowerCase(), reason: '$reason ${entry.value}');
  }
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
