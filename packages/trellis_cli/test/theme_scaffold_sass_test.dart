import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

/// Proves the `trellis create --template theme` scaffold on the `@use` bridge
/// contract: compiled through the same wrapper `trellis build` compiles, with the
/// `@import` deprecation fatal, at every skin, with per-mode colour overrides.
/// The bundled themes are proved in `trellis_site`; the scaffold lives here
/// because it needs the generator.

/// Two colours no output style abbreviates, so `contains` assertions are stable.
const _lightOverride = '#123456';
const _darkOverride = '#654321';

/// The scaffold's seven colour params' palette keys, mapped to the `:root`
/// custom property each one feeds.
const _paletteProps = {
  'text-color': '--trellis-text',
  'muted-color': '--trellis-muted',
  'bg-color': '--trellis-bg',
  'surface-color': '--trellis-surface',
  'border-color': '--trellis-border',
  'primary-color': '--trellis-primary',
  'accent-color': '--trellis-accent',
};

void main() {
  late Directory siteDir;
  late String themeDir;
  late ThemeManifest manifest;
  late Map<String, String> lightPalette;
  late Map<String, String> darkPalette;

  setUp(() async {
    siteDir = Directory(Directory.systemTemp.createTempSync('trellis_scaffold_sass_').resolveSymbolicLinksSync());
    themeDir = p.join(siteDir.path, 'themes', 'my_theme');
    await ThemeProjectGenerator(projectName: 'my_theme', writer: DiskFileWriter(themeDir)).generate();
    manifest = ThemeManifest.load(themeDir);
    lightPalette = _palette(themeDir, 'light');
    darkPalette = _palette(themeDir, 'dark');
  });

  tearDown(() => siteDir.deleteSync(recursive: true));

  /// Compiles the scaffold exactly as the site builder + CLI do: manifest
  /// defaults merged with [siteParams], the generated params module, and the
  /// shared wrapper. The scaffold sits under a site with no `theme_params:`
  /// beyond [siteParams].
  String compileScaffold(String skin, {Map<String, dynamic> siteParams = const {}}) {
    final merged = const ThemeParamMerger().merge(manifest.defaultParams, {'skin': skin, ...siteParams}).params;
    final config = const ThemeSassGenerator().generate(
      mergedParams: merged,
      paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
      siteDir: siteDir.path,
      themeDir: themeDir,
    );
    final entry = File(p.join(themeDir, 'sass', 'main.scss')).resolveSymbolicLinksSync();
    final wrapper = File(p.join(config.buildDir, 'bridge_main.scss'))
      ..writeAsStringSync(config.bridgeWrapperSource(entry));
    return TrellisCss.compileSass(wrapper.path, loadPaths: config.sassLoadPaths, fatalImportDeprecation: true);
  }

  group('S01 the scaffold compiles with the import deprecation fatal', () {
    for (final skin in ['light', 'dark', 'auto']) {
      test('through the bridge at skin: $skin', () {
        expect(compileScaffold(skin), contains(':root'));
      });
    }

    test('standalone, without the bridge', () {
      final css = TrellisCss.compileSass(
        File(p.join(themeDir, 'sass', 'main.scss')).resolveSymbolicLinksSync(),
        fatalImportDeprecation: true,
      );
      // Standalone is `skin: auto`: the light palette plus the dark media block.
      final root = _props(_rootBlock(css));
      final media = _props(_darkMediaRoot(css)!);
      for (final entry in _paletteProps.entries) {
        expect(root[entry.value], lightPalette[entry.key], reason: 'base ${entry.key}');
        expect(media[entry.value], darkPalette[entry.key], reason: 'media ${entry.key}');
      }
    });

    test('no generated scaffold file contains @import', () {
      final files = Directory(themeDir).listSync(recursive: true).whereType<File>().toList();
      expect(files, isNotEmpty);
      for (final file in files) {
        expect(file.readAsStringSync(), isNot(contains('@import')), reason: p.relative(file.path, from: themeDir));
      }
    });

    test("main.scss opens with @forward 'variables' as its first module rule", () {
      final main = File(p.join(themeDir, 'sass', 'main.scss')).readAsStringSync();
      expect(RegExp(r'@(use|forward)\b[^;]*;').firstMatch(_stripComments(main))!.group(0), "@forward 'variables';");
    });

    test(r'the skins expose a $palette and declare nothing !default', () {
      for (final skin in ['light', 'dark']) {
        final source = _stripComments(File(p.join(themeDir, 'sass', '_skins', '_$skin.scss')).readAsStringSync());
        expect(source, contains(r'$palette:'), reason: skin);
        expect(source, isNot(contains('!default')), reason: skin);
        expect(source, isNot(contains(r'$trellis-')), reason: skin);
      }
    });
  });

  group('S02 the scaffold skins work', () {
    test('light and dark differ, and each :root carries its own palette', () {
      final light = compileScaffold('light');
      final dark = compileScaffold('dark');

      expect(light, isNot(equals(dark)));
      final lightRoot = _props(_rootBlock(light));
      final darkRoot = _props(_rootBlock(dark));
      expect(darkPalette, hasLength(7), reason: 'the dark palette carries the seven colours');
      for (final entry in _paletteProps.entries) {
        expect(lightRoot[entry.value], lightPalette[entry.key], reason: 'light ${entry.key}');
        expect(darkRoot[entry.value], darkPalette[entry.key], reason: 'dark ${entry.key}');
      }
    });

    test('auto emits the light palette plus a prefers-color-scheme block carrying the dark palette', () {
      final css = compileScaffold('auto');
      final base = _props(_rootBlock(css));
      final media = _props(_darkMediaRoot(css)!);

      for (final entry in _paletteProps.entries) {
        expect(base[entry.value], lightPalette[entry.key], reason: 'base ${entry.key}');
        expect(media[entry.value], darkPalette[entry.key], reason: 'media ${entry.key}');
      }
    });

    test('the prefers-color-scheme block is gated on auto', () {
      expect(compileScaffold('auto'), contains('prefers-color-scheme'));
      expect(compileScaffold('light'), isNot(contains('prefers-color-scheme')));
      expect(compileScaffold('dark'), isNot(contains('prefers-color-scheme')));
    });
  });

  group('S03 per-mode colours reach the dark views, and a plain colour does not', () {
    test('a _dark override reaches forced dark and nothing else moves', () {
      final plain = _props(_rootBlock(compileScaffold('dark')));
      final css = compileScaffold('dark', siteParams: {'primary_color_dark': _darkOverride});
      final root = _props(_rootBlock(css));

      expect(root['--trellis-primary'], _darkOverride);
      expect(
        Map.of(root)..remove('--trellis-primary'),
        Map.of(plain)..remove('--trellis-primary'),
        reason: 'every other dark entry is unchanged',
      );
    });

    test('a _dark override reaches the auto media block through the dark palette', () {
      final css = compileScaffold('auto', siteParams: {'primary_color_dark': _darkOverride});
      final media = _props(_darkMediaRoot(css)!);
      final plainMedia = _props(_darkMediaRoot(compileScaffold('auto'))!);

      expect(_props(_rootBlock(css))['--trellis-primary'], lightPalette['primary-color']);
      expect(media['--trellis-primary'], _darkOverride);
      expect(
        Map.of(media)..remove('--trellis-primary'),
        Map.of(plainMedia)..remove('--trellis-primary'),
        reason: 'every other dark entry is unchanged',
      );
    });

    test('a plain colour param sets the light entry only', () {
      // Documented precedence rule, not load-order luck: a forced skin selects a
      // palette and a per-mode param sets one entry in it, so a plain
      // `primary_color` (the light entry) has no effect on a `skin: dark` site.
      final dark = compileScaffold('dark', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(dark))['--trellis-primary'], darkPalette['primary-color']);
      expect(dark, isNot(contains(_lightOverride)));

      final auto = compileScaffold('auto', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(auto))['--trellis-primary'], _lightOverride);
      expect(_props(_darkMediaRoot(auto)!)['--trellis-primary'], darkPalette['primary-color']);

      final light = compileScaffold('light', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(light))['--trellis-primary'], _lightOverride);
    });

    test('a _dark-only override under light changes nothing', () {
      expect(compileScaffold('light', siteParams: {'primary_color_dark': _darkOverride}), compileScaffold('light'));
    });
  });

  group('S04 the scaffold manifest is the 25-param contract', () {
    test('every colour has a _dark twin whose default is its dark palette entry', () {
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

    test('declares 25 params: the 18 prior standard ones plus the seven twins', () {
      expect(manifest.params, hasLength(25));
    });
  });

  group('S05 params with no SASS variable, and unknown names, do not break the build', () {
    test('nav_links, social_links and footer_text have no variable and stay inert', () {
      final config = const ThemeSassGenerator().generate(
        mergedParams: manifest.defaultParams,
        paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
        siteDir: siteDir.path,
        themeDir: themeDir,
      );
      expect(manifest.params.keys, containsAll(['nav_links', 'social_links', 'footer_text']));
      expect(
        config.configurableVars,
        isNot(anyOf(contains('trellis-nav-links'), contains('trellis-social-links'), contains('trellis-footer-text'))),
      );
      expect(
        config.configurableVars,
        containsAll(['trellis-skin', 'trellis-primary-color', 'trellis-primary-color-dark', 'trellis-max-width']),
      );
    });

    test('a theme_params name the manifest does not declare is dropped, and max_width reaches the CSS', () {
      final css = compileScaffold(
        'light',
        siteParams: {
          'max_width': '900px',
          'no_such_param': 'x',
          'nav_links': [
            {'label': 'Docs', 'url': '/docs/'},
          ],
        },
      );
      expect(_props(_rootBlock(css))['--trellis-max-width'], '900px');
      expect(css, isNot(contains('no_such_param')));
      expect(css, isNot(contains('no-such-param')));
    });
  });
}

/// Reads a skin's `$palette` map by compiling it, so the test sees what Sass sees.
Map<String, String> _palette(String themeDir, String mode) {
  final css = TrellisCss.compileSassString(
    '''
@use "_skins/$mode" as skin;
:root { @each \$key, \$value in skin.\$palette { --#{\$key}: #{\$value}; } }
''',
    loadPaths: [p.join(themeDir, 'sass')],
  );
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
