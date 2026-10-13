import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

import 'theme_sass_sources.dart';
import 'theme_use_support.dart';

/// Proves arbor, the reference theme, on the `@use` bridge contract: compiled
/// through the same wrapper `trellis build` compiles, with the `@import`
/// deprecation fatal, at every skin, with per-mode colour overrides.

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
    arborDir = p.join(await findRepoRoot(), 'themes', 'arbor');
    manifest = ThemeManifest.load(arborDir);
    lightPalette = readPalette(arborDir, 'light');
    darkPalette = readPalette(arborDir, 'dark');
  });

  setUp(() {
    tempDir = Directory(Directory.systemTemp.createTempSync('trellis_arbor_use_').resolveSymbolicLinksSync());
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  /// Compiles arbor exactly as the site builder + CLI do: manifest defaults merged
  /// with [siteParams], the generated params module, and the shared wrapper.
  String compileArbor(String skin, {Map<String, dynamic> siteParams = const {}}) {
    final merged = const ThemeParamMerger().merge(manifest.defaultParams, {'skin': skin, ...siteParams}).params;
    final config = const ThemeSassGenerator().generate(
      mergedParams: merged,
      paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
      siteDir: tempDir.path,
      themeDir: arborDir,
    );
    final entry = File(p.join(arborDir, 'sass', 'main.scss')).resolveSymbolicLinksSync();
    final wrapper = File(p.join(config.buildDir, 'bridge_main.scss'))
      ..writeAsStringSync(config.bridgeWrapperSource(entry));
    return TrellisCss.compileSass(wrapper.path, loadPaths: config.sassLoadPaths, fatalImportDeprecation: true);
  }

  group('skins survive the migration', () {
    test('light and dark differ, and each :root carries its own palette', () {
      final light = compileArbor('light');
      final dark = compileArbor('dark');

      expect(light, isNot(equals(dark)));
      final lightRoot = customProps(rootBlock(light));
      final darkRoot = customProps(rootBlock(dark));
      for (final entry in _paletteProps.entries) {
        expect(lightRoot[entry.value], lightPalette[entry.key], reason: 'light ${entry.key}');
        expect(darkRoot[entry.value], darkPalette[entry.key], reason: 'dark ${entry.key}');
      }
    });

    test('dark :root carries the six code tokens of the dark palette', () {
      final root = customProps(rootBlock(compileArbor('dark')));
      expect(root['--trellis-code-keyword'], '#d2a8ff');
      expect(root['--trellis-code-string'], '#7ee787');
      expect(root['--trellis-code-number'], '#ffa657');
      expect(root['--trellis-code-comment'], '#8b949e');
      expect(root['--trellis-code-function'], '#79c0ff');
      expect(root['--trellis-code-punctuation'], '#8b949e');
    });

    test('the derived heading font follows its param, and null leaves the theme default in force', () {
      String headingFont(Map<String, dynamic> siteParams) =>
          customProps(rootBlock(compileArbor('dark', siteParams: siteParams)))['--trellis-heading-font']!;

      expect(headingFont({}), 'Charter, Cambria, Georgia, ui-serif, serif');
      expect(headingFont({'heading_font_family': 'Georgia, serif'}), 'Georgia, serif');
      // A configured null is "unset" (Sass `!default` fills null), exactly as the
      // old `@import` bridge behaved.
      expect(headingFont({'heading_font_family': null}), 'Charter, Cambria, Georgia, ui-serif, serif');
    });

    test('auto emits the light palette plus a prefers-color-scheme block carrying the dark palette', () {
      final css = compileArbor('auto');
      final base = customProps(rootBlock(css));
      final media = customProps(darkMediaRoot(css)!);

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

  group('per-mode colour params', () {
    test('a _dark override reaches a forced dark skin and nothing else moves', () {
      final plain = customProps(rootBlock(compileArbor('dark')));
      final css = compileArbor('dark', siteParams: {'primary_color_dark': darkOverride});
      final root = customProps(rootBlock(css));

      expect(root['--trellis-primary'], darkOverride);
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

    test('a _dark override reaches auto mode through the dark palette, not a literal', () {
      final css = compileArbor('auto', siteParams: {'primary_color_dark': darkOverride});

      expect(customProps(rootBlock(css))['--trellis-primary'], lightPalette['primary-color']);
      expect(customProps(darkMediaRoot(css)!)['--trellis-primary'], darkOverride);
    });

    test('a plain colour param sets the light entry only', () {
      // Documented precedence rule, not load-order luck: a forced skin selects a
      // palette and a per-mode param sets one entry in it, so a plain
      // `primary_color` (the light entry) has no effect on a `skin: dark` site.
      final dark = compileArbor('dark', siteParams: {'primary_color': lightOverride});
      expect(customProps(rootBlock(dark))['--trellis-primary'], darkPalette['primary-color']);
      expect(dark, isNot(contains(lightOverride)));

      final auto = compileArbor('auto', siteParams: {'primary_color': lightOverride});
      expect(customProps(rootBlock(auto))['--trellis-primary'], lightOverride);
      expect(customProps(darkMediaRoot(auto)!)['--trellis-primary'], darkPalette['primary-color']);

      final light = compileArbor('light', siteParams: {'primary_color': lightOverride});
      expect(customProps(rootBlock(light))['--trellis-primary'], lightOverride);
    });

    test('a _dark-only override under light changes nothing', () {
      expect(compileArbor('light', siteParams: {'primary_color_dark': darkOverride}), compileArbor('light'));
    });

    test('a with()-set non-colour param reaches compiled CSS', () {
      final root = customProps(rootBlock(compileArbor('light', siteParams: {'max_width': '900px'})));
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

  group('every colour param has a _dark twin sourced from the palettes', () {
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

  group('structure', () {
    String sass(String relative) => File(p.join(arborDir, 'sass', relative)).readAsStringSync();
    final partials = ['_a11y', '_base', '_code', '_components', '_footer', '_layout'];

    test('no @import remains in arbor sass/', () {
      for (final file in sweepFiles(p.join(arborDir, 'sass'))) {
        expect(stripComments(file.readAsStringSync()), isNot(contains('@import')), reason: file.path);
      }
    });

    test("main.scss opens with @forward 'variables' as its first module rule", () {
      final firstRule = RegExp(r'@(use|forward)\b[^;]*;').firstMatch(stripComments(sass('main.scss')));
      expect(firstRule!.group(0), "@forward 'variables';");
    });

    test(r'skins expose a $palette and declare nothing !default', () {
      for (final skin in ['_light', '_dark']) {
        final source = stripComments(sass('_skins/$skin.scss'));
        expect(source, contains(r'$palette:'), reason: skin);
        expect(source, isNot(contains('!default')), reason: skin);
      }
    });

    test("every partial reading a \$trellis-* variable declares @use 'variables' as *", () {
      for (final partial in partials) {
        final source = stripComments(sass('$partial.scss'));
        if (source.contains(r'$trellis-')) {
          expect(source, contains("@use 'variables' as *;"), reason: partial);
        }
      }
      // $bp-* breakpoints live in _layout.scss; _components.scss reads them.
      expect(stripComments(sass('_components.scss')), contains("@use 'layout' as *;"));
    });

    test('arbor compiles standalone, without the bridge, to its light-palette defaults (auto skin)', () {
      final css = TrellisCss.compileSass(
        File(p.join(arborDir, 'sass', 'main.scss')).resolveSymbolicLinksSync(),
        fatalImportDeprecation: true,
      );
      final root = customProps(rootBlock(css));
      for (final entry in _paletteProps.entries) {
        expect(root[entry.value], lightPalette[entry.key], reason: entry.key);
      }
      // Standalone is `skin: auto`: the light palette plus the dark media block.
      final media = customProps(darkMediaRoot(css)!);
      for (final entry in _paletteProps.entries) {
        expect(media[entry.value], darkPalette[entry.key], reason: 'media ${entry.key}');
      }
    });
  });
}
