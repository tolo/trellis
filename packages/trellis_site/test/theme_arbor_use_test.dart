import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

/// Proves arbor, the reference theme, on the `@use` bridge contract: compiled
/// through the same wrapper `trellis build` compiles, with the `@import`
/// deprecation fatal, at every skin, with per-mode colour overrides.

/// Two colours no output style abbreviates, so `contains` assertions are stable.
const _lightOverride = '#123456';
const _darkOverride = '#654321';

/// Colour params' palette keys, mapped to the `:root` custom property each one
/// feeds. The six code tokens have no param; they ride in the same palettes.
const _paletteProps = {
  'text-color': '--trellis-text',
  'muted-color': '--trellis-muted',
  'bg-color': '--trellis-bg',
  'surface-color': '--trellis-surface',
  'border-color': '--trellis-border',
  'primary-color': '--trellis-primary',
  'accent-color': '--trellis-accent',
  'code-keyword': '--trellis-code-keyword',
  'code-string': '--trellis-code-string',
  'code-number': '--trellis-code-number',
  'code-comment': '--trellis-code-comment',
  'code-function': '--trellis-code-function',
  'code-punctuation': '--trellis-code-punctuation',
};

void main() {
  late String arborDir;
  late Directory tempDir;
  late ThemeManifest manifest;
  late Map<String, String> lightPalette;
  late Map<String, String> darkPalette;

  setUpAll(() async {
    arborDir = p.join(await _repoRoot(), 'themes', 'arbor');
    manifest = ThemeManifest.load(arborDir);
    lightPalette = _palette(arborDir, 'light');
    darkPalette = _palette(arborDir, 'dark');
  });

  setUp(() {
    tempDir = Directory(Directory.systemTemp.createTempSync('trellis_arbor_use_').resolveSymbolicLinksSync());
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  /// Compiles arbor exactly as the site builder + CLI do: manifest defaults merged
  /// with [siteParams], the generated params module, and the shared wrapper.
  /// [probe] appends a rule so a test can read a module variable the CSS never
  /// emits (the entry's namespace is `theme`).
  String compileArbor(String skin, {Map<String, dynamic> siteParams = const {}, String? probe}) {
    final merged = const ThemeParamMerger().merge(manifest.defaultParams, {'skin': skin, ...siteParams}).params;
    final config = const ThemeSassGenerator().generate(
      mergedParams: merged,
      paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
      siteDir: tempDir.path,
      themeDir: arborDir,
    );
    final entry = File(p.join(arborDir, 'sass', 'main.scss')).resolveSymbolicLinksSync();
    final wrapper = File(p.join(config.buildDir, 'bridge_main.scss'))
      ..writeAsStringSync('${config.bridgeWrapperSource(entry)}${probe == null ? '' : '.probe { value: $probe; }\n'}');
    return TrellisCss.compileSass(wrapper.path, loadPaths: config.sassLoadPaths, fatalImportDeprecation: true);
  }

  group('S05 skins survive the migration', () {
    test('light and dark differ, and each :root carries its own palette', () {
      final light = compileArbor('light');
      final dark = compileArbor('dark');

      expect(light, isNot(equals(dark)));
      final lightRoot = _props(_rootBlock(light));
      final darkRoot = _props(_rootBlock(dark));
      for (final entry in _paletteProps.entries) {
        expect(lightRoot[entry.value], lightPalette[entry.key], reason: 'light ${entry.key}');
        expect(darkRoot[entry.value], darkPalette[entry.key], reason: 'dark ${entry.key}');
      }
    });

    test('dark :root carries the six code tokens of the dark palette', () {
      final root = _props(_rootBlock(compileArbor('dark')));
      expect(root['--trellis-code-keyword'], '#d2a8ff');
      expect(root['--trellis-code-string'], '#7ee787');
      expect(root['--trellis-code-number'], '#ffa657');
      expect(root['--trellis-code-comment'], '#8b949e');
      expect(root['--trellis-code-function'], '#79c0ff');
      expect(root['--trellis-code-punctuation'], '#8b949e');
    });

    test('values derived from colours read the post-skin variables', () {
      // The focus-ring colour is derived from the primary after the skin is
      // applied; a dark skin that reassigned too late would keep the light one.
      final dark = compileArbor('dark', probe: r'theme.$trellis-focus-ring-color');
      expect(dark, contains('value: ${darkPalette['primary-color']};'));
      final light = compileArbor('light', probe: r'theme.$trellis-focus-ring-color');
      expect(light, contains('value: ${lightPalette['primary-color']};'));
    });

    test('the derived heading font follows its param, and null leaves the theme default in force', () {
      String headingFont(Map<String, dynamic> siteParams) =>
          _props(_rootBlock(compileArbor('dark', siteParams: siteParams)))['--trellis-heading-font']!;

      expect(headingFont({}), 'Charter, Cambria, Georgia, ui-serif, serif');
      expect(headingFont({'heading_font_family': 'Georgia, serif'}), 'Georgia, serif');
      // A configured null is "unset" (Sass `!default` fills null), exactly as the
      // old `@import` bridge behaved.
      expect(headingFont({'heading_font_family': null}), 'Charter, Cambria, Georgia, ui-serif, serif');
    });

    test('auto emits the light palette plus a prefers-color-scheme block carrying the dark palette', () {
      final css = compileArbor('auto');
      final base = _props(_rootBlock(css));
      final media = _props(_darkMediaRoot(css)!);

      for (final entry in _paletteProps.entries) {
        expect(base[entry.value], lightPalette[entry.key], reason: 'base ${entry.key}');
        expect(media[entry.value], darkPalette[entry.key], reason: 'media ${entry.key}');
      }
      // The block also deepens the shadows, which are mode constants, not palette colours.
      expect(media['--trellis-shadow-sm'], isNotNull);
      expect(media['--trellis-shadow-md'], isNotNull);
    });

    test('the prefers-color-scheme block is gated on auto (the guard the old bloom test held)', () {
      expect(compileArbor('auto'), contains('prefers-color-scheme'));
      expect(compileArbor('light'), isNot(contains('prefers-color-scheme')));
      expect(compileArbor('dark'), isNot(contains('prefers-color-scheme')));
    });
  });

  group('S08–S10 per-mode colour params', () {
    test('S08: a _dark override reaches a forced dark skin and nothing else moves', () {
      final plain = _props(_rootBlock(compileArbor('dark')));
      final css = compileArbor('dark', siteParams: {'primary_color_dark': _darkOverride});
      final root = _props(_rootBlock(css));

      expect(root['--trellis-primary'], _darkOverride);
      expect(
        Map.of(root)..remove('--trellis-primary'),
        Map.of(plain)..remove('--trellis-primary'),
        reason: 'every other dark entry is unchanged',
      );
      expect(css, isNot(contains('prefers-color-scheme')));
      // No light-palette entry leaks into the forced dark :root.
      for (final key in ['bg-color', 'text-color', 'primary-color']) {
        expect(root.values, isNot(contains(lightPalette[key])), reason: 'light $key');
      }
    });

    test('S09: a _dark override reaches auto mode through the dark palette, not a literal', () {
      final css = compileArbor('auto', siteParams: {'primary_color_dark': _darkOverride});

      expect(_props(_rootBlock(css))['--trellis-primary'], lightPalette['primary-color']);
      expect(_props(_darkMediaRoot(css)!)['--trellis-primary'], _darkOverride);
    });

    test('S10: a plain colour param sets the light entry only', () {
      // Documented precedence rule, not load-order luck: a forced skin selects a
      // palette and a per-mode param sets one entry in it, so a plain
      // `primary_color` (the light entry) has no effect on a `skin: dark` site.
      final dark = compileArbor('dark', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(dark))['--trellis-primary'], darkPalette['primary-color']);
      expect(dark, isNot(contains(_lightOverride)));

      final auto = compileArbor('auto', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(auto))['--trellis-primary'], _lightOverride);
      expect(_props(_darkMediaRoot(auto)!)['--trellis-primary'], darkPalette['primary-color']);

      final light = compileArbor('light', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(light))['--trellis-primary'], _lightOverride);
    });

    test('S10: a _dark-only override under light changes nothing', () {
      expect(compileArbor('light', siteParams: {'primary_color_dark': _darkOverride}), compileArbor('light'));
    });

    test('a with()-set non-colour param reaches compiled CSS', () {
      final root = _props(_rootBlock(compileArbor('light', siteParams: {'max_width': '900px'})));
      expect(root['--trellis-max-width'], '900px');
    });

    test('a param with no SASS variable is inert, not fatal', () {
      final config = const ThemeSassGenerator().generate(
        mergedParams: manifest.defaultParams,
        paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
        siteDir: tempDir.path,
        themeDir: arborDir,
      );
      expect(config.configurableVars, isNot(contains('trellis-nav-links')));
      expect(
        config.configurableVars,
        containsAll(['trellis-skin', 'trellis-primary-color', 'trellis-primary-color-dark']),
      );
      expect(
        compileArbor(
          'light',
          siteParams: {
            'nav_links': [
              {'label': 'Docs', 'url': '/docs/'},
            ],
          },
        ),
        isNotEmpty,
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
        expect(twin!.defaultValue, darkPalette[key], reason: '${name}_dark default');
        expect(colorParams[name]!.defaultValue, lightPalette[key], reason: '$name default');
        expect(colorParams.containsKey('${name}_dark_dark'), isFalse, reason: 'twins have no twins');
      }
      expect(
        colorParams.keys.where((name) => name.endsWith('_dark')),
        hasLength(bases.length),
        reason: 'no orphan twin',
      );
    });
  });

  group('SC01/SC03/SC04 structure', () {
    String sass(String relative) => File(p.join(arborDir, 'sass', relative)).readAsStringSync();
    final partials = ['_a11y', '_base', '_code', '_components', '_footer', '_layout'];

    test('no @import remains in arbor sass/', () {
      for (final file in Directory(p.join(arborDir, 'sass')).listSync(recursive: true).whereType<File>()) {
        expect(_stripComments(file.readAsStringSync()), isNot(contains('@import')), reason: file.path);
      }
    });

    test("main.scss opens with @forward 'variables' as its first module rule", () {
      final firstRule = RegExp(r'@(use|forward)\b[^;]*;').firstMatch(_stripComments(sass('main.scss')));
      expect(firstRule!.group(0), "@forward 'variables';");
    });

    test(r'skins expose a $palette and declare nothing !default', () {
      for (final skin in ['_light', '_dark']) {
        final source = _stripComments(sass('_skins/$skin.scss'));
        expect(source, contains(r'$palette:'), reason: skin);
        expect(source, isNot(contains('!default')), reason: skin);
      }
    });

    test("every partial reading a \$trellis-* variable declares @use 'variables' as *", () {
      for (final partial in partials) {
        final source = _stripComments(sass('$partial.scss'));
        if (source.contains(r'$trellis-')) {
          expect(source, contains("@use 'variables' as *;"), reason: partial);
        }
      }
      // $bp-* breakpoints live in _layout.scss; _components.scss reads them.
      expect(_stripComments(sass('_components.scss')), contains("@use 'layout' as *;"));
    });

    test('arbor compiles standalone, without the bridge, to its light-palette defaults (auto skin)', () {
      final css = TrellisCss.compileSass(
        File(p.join(arborDir, 'sass', 'main.scss')).resolveSymbolicLinksSync(),
        fatalImportDeprecation: true,
      );
      final root = _props(_rootBlock(css));
      for (final entry in _paletteProps.entries) {
        expect(root[entry.value], lightPalette[entry.key], reason: entry.key);
      }
      // Standalone is `skin: auto`: the light palette plus the dark media block.
      final media = _props(_darkMediaRoot(css)!);
      for (final entry in _paletteProps.entries) {
        expect(media[entry.value], darkPalette[entry.key], reason: 'media ${entry.key}');
      }
    });
  });
}

/// Reads a skin's `$palette` map by compiling it, so the gate sees what Sass sees.
Map<String, String> _palette(String arborDir, String mode) {
  final file = p.join(arborDir, 'sass', '_skins', '_$mode.scss');
  final css = TrellisCss.compileSassString('''
@use "$file" as skin;
:root { @each \$key, \$value in skin.\$palette { --#{\$key}: #{\$value}; } }
''');
  return {for (final e in _props(_rootBlock(css)).entries) e.key.substring(2): e.value};
}

/// Body of the first top-level `:root { ... }` rule.
String _rootBlock(String css) {
  final start = RegExp(r'^:root \{', multiLine: true).firstMatch(css)!;
  return css.substring(start.end, css.indexOf('\n}', start.end));
}

/// Body of the `:root` rule inside `@media (prefers-color-scheme: dark)`, or null.
String? _darkMediaRoot(String css) {
  final media = css.indexOf('@media (prefers-color-scheme: dark)');
  if (media == -1) return null;
  final root = css.indexOf(':root {', media);
  return css.substring(root + ':root {'.length, css.indexOf('}', root));
}

/// Custom properties declared in [block] (`--name: value;` lines).
Map<String, String> _props(String block) => {
  for (final m in RegExp(r'(--[\w-]+):\s*([^;]+);').allMatches(block)) m.group(1)!: m.group(2)!.trim(),
};

String _stripComments(String source) =>
    source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//.*'), '');

/// Resolves the monorepo root by walking up from this package until `themes/arbor`
/// is found, so the test works regardless of the test CWD.
Future<String> _repoRoot() async {
  final uri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/trellis_site.dart'));
  if (uri == null || uri.scheme != 'file') {
    throw StateError('Could not resolve package:trellis_site/trellis_site.dart');
  }
  var dir = Directory(p.dirname(uri.toFilePath()));
  while (!Directory(p.join(dir.path, 'themes', 'arbor')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('Could not find repo root (themes/arbor) from ${uri.toFilePath()}');
    dir = parent;
  }
  return dir.path;
}
