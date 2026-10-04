import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

/// Proves bloom and verdant on the `@use` bridge contract arbor established
/// (`theme_arbor_use_test.dart`): compiled through the same wrapper
/// `trellis build` compiles, with the `@import` deprecation fatal, at every skin,
/// with per-mode colour overrides.

/// Two colours no output style abbreviates, so `contains` assertions are stable.
const _lightOverride = '#123456';
const _darkOverride = '#654321';

/// The seven standard colour params' palette keys and the `:root` property each feeds.
const _standardProps = {
  'text-color': '--trellis-text',
  'muted-color': '--trellis-muted',
  'bg-color': '--trellis-bg',
  'surface-color': '--trellis-surface',
  'border-color': '--trellis-border',
  'primary-color': '--trellis-primary',
  'accent-color': '--trellis-accent',
};

/// verdant's six code-token palette entries (no param; they ride in the palettes).
const _codeProps = {
  'code-keyword': '--trellis-code-keyword',
  'code-string': '--trellis-code-string',
  'code-number': '--trellis-code-number',
  'code-comment': '--trellis-code-comment',
  'code-function': '--trellis-code-function',
  'code-punctuation': '--trellis-code-punctuation',
};

/// bloom's two theme-specific colour params.
const _gradientProps = {
  'accent-gradient-start': '--trellis-gradient-start',
  'accent-gradient-end': '--trellis-gradient-end',
};

/// verdant's params with no SASS variable: templates read them, the bridge skips them.
const _verdantTemplateOnly = <String, Object?>{
  'date_format': 'yyyy-MM-dd',
  'excerpt_length': 99,
  'footer_text': 'Custom footer',
  'hero_description': 'Custom description',
  'hero_title': 'Custom title',
  'nav_links': [
    {'label': 'About', 'url': '/about/'},
  ],
  'posts_per_page': 7,
  'show_author': false,
  'show_date': false,
  'show_powered_by': false,
  'show_reading_time': false,
  'show_rss_link': false,
  'show_tags': false,
  'show_toc': true,
  'social_links': [
    {'platform': 'github', 'url': 'https://example.com/me'},
  ],
};

void main() {
  late String repoRoot;

  setUpAll(() async {
    repoRoot = await _repoRoot();
  });

  group('bloom', () => _themeTests('bloom', () => repoRoot, {..._standardProps, ..._gradientProps}));
  group('verdant', () => _themeTests('verdant', () => repoRoot, {..._standardProps, ..._codeProps}));

  group('bloom specifics', () {
    late _Harness h;

    setUpAll(() => h = _Harness.create(repoRoot, 'bloom'));
    setUp(() => h.open());
    tearDown(() => h.close());

    test('S04: a _dark gradient override reaches a forced dark skin', () {
      final css = h.compile('dark', siteParams: {'accent_gradient_start_dark': _darkOverride});
      final root = _props(_rootBlock(css));
      expect(root['--trellis-gradient-start'], _darkOverride);
      expect(root['--trellis-gradient-end'], h.darkPalette['accent-gradient-end']);
    });

    test('S05: a _dark gradient override reaches the auto block, which now carries both gradient tokens', () {
      final css = h.compile('auto', siteParams: {'accent_gradient_start_dark': _darkOverride});
      expect(_props(_rootBlock(css))['--trellis-gradient-start'], h.lightPalette['accent-gradient-start']);
      final media = _props(_darkMediaRoot(css)!);
      expect(media['--trellis-gradient-start'], _darkOverride);
      expect(media['--trellis-gradient-end'], h.darkPalette['accent-gradient-end']);
    });

    test('S06: a plain gradient param does not leak into dark (reverses the old carry-through)', () {
      // Precedence rule, not load-order luck: a plain colour param sets the light
      // palette entry only, so `accent_gradient_start` never reaches a dark view.
      final dark = h.compile('dark', siteParams: {'accent_gradient_start': _lightOverride});
      expect(_props(_rootBlock(dark))['--trellis-gradient-start'], h.darkPalette['accent-gradient-start']);
      expect(dark, isNot(contains(_lightOverride)));

      final auto = h.compile('auto', siteParams: {'accent_gradient_start': _lightOverride});
      expect(_props(_rootBlock(auto))['--trellis-gradient-start'], _lightOverride);
      expect(_props(_darkMediaRoot(auto)!)['--trellis-gradient-start'], h.darkPalette['accent-gradient-start']);

      final light = h.compile('light', siteParams: {'accent_gradient_start': _lightOverride});
      expect(_props(_rootBlock(light))['--trellis-gradient-start'], _lightOverride);
    });

    test('S02: nav_links and social_links stay inert, and still reach templates', () {
      final siteParams = {
        for (final name in ['nav_links', 'social_links']) name: _verdantTemplateOnly[name],
      };
      _expectTemplateOnly(h, siteParams);
    });

    test("SC02: _components.scss reads layout's breakpoints through @use, with no layout import", () {
      final source = _stripComments(h.sass('_components.scss'));
      expect(source, contains("@use 'layout' as *;"));
      expect(source, isNot(contains('@import')));
    });
  });

  group('verdant specifics', () {
    late _Harness h;

    setUpAll(() => h = _Harness.create(repoRoot, 'verdant'));
    setUp(() => h.open());
    tearDown(() => h.close());

    test('auto also deepens the shadows, which are mode constants and stay literals', () {
      final media = _props(_darkMediaRoot(h.compile('auto'))!);
      expect(media['--trellis-shadow-sm'], isNotNull);
      expect(media['--trellis-shadow-md'], isNotNull);
    });

    test('S02: the 15 params with no SASS variable stay inert, and still reach templates', () {
      _expectTemplateOnly(h, _verdantTemplateOnly);
    });
  });
}

/// [siteParams] have no SASS variable: the bridge leaves them out of
/// `configurableVars` and `with()`, the CSS is unchanged, and the merged params
/// the site builder hands to templates still carry each one.
void _expectTemplateOnly(_Harness h, Map<String, Object?> siteParams) {
  final merged = h.merge('light', siteParams);
  final config = h.generate(merged);
  final wrapper = config.bridgeWrapperSource(h.entry);

  for (final name in siteParams.keys) {
    final variable = 'trellis-${name.replaceAll('_', '-')}';
    expect(config.configurableVars, isNot(contains(variable)), reason: name);
    expect(wrapper, isNot(contains('\$$variable:')), reason: '$name must not be in with()');
  }
  expect(wrapper, contains('with ('));
  expect(wrapper, contains(r'$trellis-skin'));

  for (final entry in siteParams.entries) {
    expect(merged[entry.key], entry.value, reason: '${entry.key} reaches templates');
  }
  expect(h.compile('light', siteParams: siteParams), h.compile('light'));
}

/// The cases shared by both themes. [props] maps each palette key the theme's
/// `:root` carries (colour params, plus verdant's code tokens or bloom's gradient
/// pair) to its custom property.
void _themeTests(String theme, String Function() repoRoot, Map<String, String> props) {
  late _Harness h;

  setUpAll(() => h = _Harness.create(repoRoot(), theme));
  setUp(() => h.open());
  tearDown(() => h.close());

  /// A palette key's colour param and the `_dark` twin's: `primary-color` → `primary_color`.
  String param(String key) => key.replaceAll('-', '_');

  group('S01 compiles with @import fatal', () {
    for (final skin in ['light', 'dark', 'auto']) {
      test('bridged at skin: $skin', () => expect(h.compile(skin), isNotEmpty));
    }

    test('standalone, without the bridge, :root carries the light palette', () {
      final css = TrellisCss.compileSass(h.entry, fatalImportDeprecation: true);
      final root = _props(_rootBlock(css));
      for (final entry in props.entries) {
        expect(root[entry.value], h.lightPalette[entry.key], reason: entry.key);
      }
    });
  });

  group('S03 the skins survive the migration', () {
    test('light and dark differ, and each :root carries its own palette', () {
      final light = h.compile('light');
      final dark = h.compile('dark');

      expect(light, isNot(equals(dark)));
      final lightRoot = _props(_rootBlock(light));
      final darkRoot = _props(_rootBlock(dark));
      for (final entry in props.entries) {
        expect(lightRoot[entry.value], h.lightPalette[entry.key], reason: 'light ${entry.key}');
        expect(darkRoot[entry.value], h.darkPalette[entry.key], reason: 'dark ${entry.key}');
      }
    });

    test('the focus ring is derived from the post-skin primary', () {
      // Derived values read the colour after the skin is applied; a dark skin that
      // reassigned too late would keep the light primary.
      final dark = h.compile('dark', probe: r'theme.$trellis-focus-ring-color');
      expect(dark, contains('value: ${h.darkPalette['primary-color']};'));
      final light = h.compile('light', probe: r'theme.$trellis-focus-ring-color');
      expect(light, contains('value: ${h.lightPalette['primary-color']};'));
    });

    test('auto emits the light palette plus a prefers-color-scheme block carrying the dark palette', () {
      final css = h.compile('auto');
      final base = _props(_rootBlock(css));
      final media = _props(_darkMediaRoot(css)!);

      for (final entry in props.entries) {
        expect(base[entry.value], h.lightPalette[entry.key], reason: 'base ${entry.key}');
        expect(media[entry.value], h.darkPalette[entry.key], reason: 'media ${entry.key}');
      }
    });

    test('the prefers-color-scheme block is gated on auto', () {
      expect(h.compile('auto'), contains('prefers-color-scheme'));
      expect(h.compile('light'), isNot(contains('prefers-color-scheme')));
      expect(h.compile('dark'), isNot(contains('prefers-color-scheme')));
    });
  });

  group('S04–S06 per-mode colour params', () {
    test('S04: a _dark override reaches a forced dark skin and nothing else moves', () {
      final plain = _props(_rootBlock(h.compile('dark')));
      final css = h.compile('dark', siteParams: {'primary_color_dark': _darkOverride});
      final root = _props(_rootBlock(css));

      expect(root['--trellis-primary'], _darkOverride);
      expect(
        Map.of(root)..remove('--trellis-primary'),
        Map.of(plain)..remove('--trellis-primary'),
        reason: 'every other dark entry is unchanged',
      );
      expect(css, isNot(contains('prefers-color-scheme')));
      // No light-palette entry leaks into the forced dark :root (where the two
      // palettes differ; bloom's gradient defaults are equal in both).
      for (final key in props.keys.where((k) => k != 'primary-color')) {
        if (h.lightPalette[key] == h.darkPalette[key]) continue;
        expect(root[props[key]], isNot(h.lightPalette[key]), reason: 'light $key');
      }
    });

    test('S05: a _dark override reaches auto mode through the dark palette, not a literal', () {
      final css = h.compile('auto', siteParams: {'primary_color_dark': _darkOverride});

      expect(_props(_rootBlock(css))['--trellis-primary'], h.lightPalette['primary-color']);
      expect(_props(_darkMediaRoot(css)!)['--trellis-primary'], _darkOverride);
    });

    test('S06: a plain colour param sets the light entry only', () {
      // Documented precedence rule, not load-order luck: a forced skin selects a
      // palette and a per-mode param sets one entry in it, so a plain
      // `primary_color` (the light entry) has no effect on a `skin: dark` site.
      final dark = h.compile('dark', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(dark))['--trellis-primary'], h.darkPalette['primary-color']);
      expect(dark, isNot(contains(_lightOverride)));

      final auto = h.compile('auto', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(auto))['--trellis-primary'], _lightOverride);
      expect(_props(_darkMediaRoot(auto)!)['--trellis-primary'], h.darkPalette['primary-color']);

      final light = h.compile('light', siteParams: {'primary_color': _lightOverride});
      expect(_props(_rootBlock(light))['--trellis-primary'], _lightOverride);
    });

    test('S06: a _dark-only override under light changes nothing', () {
      expect(h.compile('light', siteParams: {'primary_color_dark': _darkOverride}), h.compile('light'));
    });

    test('a with()-set non-colour param reaches compiled CSS', () {
      final root = _props(_rootBlock(h.compile('light', siteParams: {'max_width': '900px'})));
      expect(root['--trellis-max-width'], '900px');
    });
  });

  group('S07 every colour param has a _dark twin sourced from the palettes', () {
    test('twins exist, defaults equal the palette entries, twins have no twins', () {
      final colorParams = {
        for (final e in h.manifest.params.entries)
          if (e.value.type == 'color') e.key: e.value,
      };
      final bases = colorParams.keys.where((name) => !name.endsWith('_dark')).toList();
      expect(bases.toSet(), {for (final key in props.keys.where((k) => !k.startsWith('code-'))) param(key)});
      expect(bases, hasLength(theme == 'bloom' ? 9 : 7));

      for (final name in bases) {
        final key = name.replaceAll('_', '-');
        final twin = colorParams['${name}_dark'];
        expect(twin, isNotNull, reason: '$name needs a ${name}_dark twin');
        expect(twin!.defaultValue, h.darkPalette[key], reason: '${name}_dark default');
        expect(colorParams[name]!.defaultValue, h.lightPalette[key], reason: '$name default');
        expect(colorParams.containsKey('${name}_dark_dark'), isFalse, reason: 'twins have no twins');
      }
      expect(
        colorParams.keys.where((name) => name.endsWith('_dark')),
        hasLength(bases.length),
        reason: 'no orphan twin',
      );
    });
  });

  group('SC01/SC02/SC03 structure', () {
    final partials = ['_a11y', '_base', '_code', '_components', '_footer', '_layout'];

    test('no @import remains in sass/', () {
      for (final file in Directory(p.join(h.themeDir, 'sass')).listSync(recursive: true).whereType<File>()) {
        expect(_stripComments(file.readAsStringSync()), isNot(contains('@import')), reason: file.path);
      }
    });

    test("main.scss opens with @forward 'variables' as its first module rule", () {
      final firstRule = RegExp(r'@(use|forward)\b[^;]*;').firstMatch(_stripComments(h.sass('main.scss')));
      expect(firstRule!.group(0), "@forward 'variables';");
    });

    test(r'skins expose a $palette and declare nothing !default', () {
      for (final skin in ['_light', '_dark']) {
        final source = _stripComments(h.sass('_skins/$skin.scss'));
        expect(source, contains(r'$palette:'), reason: skin);
        expect(source, isNot(contains('!default')), reason: skin);
      }
    });

    test("every partial reading a \$trellis-* variable declares @use 'variables' as *", () {
      for (final partial in partials) {
        final source = _stripComments(h.sass('$partial.scss'));
        if (source.contains(r'$trellis-')) {
          expect(source, contains("@use 'variables' as *;"), reason: partial);
        }
      }
    });

    test('main.scss restates no palette value as a literal', () {
      final literal = RegExp(r'^\s*--trellis-[a-z-]+:\s*#[0-9a-fA-F]+;', multiLine: true);
      expect(literal.hasMatch(_stripComments(h.sass('main.scss'))), isFalse);
    });
  });
}

/// Compiles one theme exactly as the site builder + CLI do.
class _Harness {
  final String themeDir;
  final ThemeManifest manifest;
  final Map<String, String> lightPalette;
  final Map<String, String> darkPalette;
  late Directory _tempDir;

  _Harness._(this.themeDir, this.manifest, this.lightPalette, this.darkPalette);

  factory _Harness.create(String repoRoot, String theme) {
    final dir = p.join(repoRoot, 'themes', theme);
    return _Harness._(dir, ThemeManifest.load(dir), _palette(dir, 'light'), _palette(dir, 'dark'));
  }

  void open() {
    _tempDir = Directory(Directory.systemTemp.createTempSync('trellis_use_').resolveSymbolicLinksSync());
  }

  void close() => _tempDir.deleteSync(recursive: true);

  String get entry => File(p.join(themeDir, 'sass', 'main.scss')).resolveSymbolicLinksSync();

  String sass(String relative) => File(p.join(themeDir, 'sass', relative)).readAsStringSync();

  /// Manifest defaults merged with the site's [siteParams], as the site builder does.
  Map<String, dynamic> merge(String skin, Map<String, dynamic> siteParams) =>
      const ThemeParamMerger().merge(manifest.defaultParams, {'skin': skin, ...siteParams}).params;

  ThemeBuildConfig generate(Map<String, dynamic> merged) => const ThemeSassGenerator().generate(
    mergedParams: merged,
    paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
    siteDir: _tempDir.path,
    themeDir: themeDir,
  );

  /// [probe] appends a rule so a test can read a module variable the CSS never
  /// emits (the entry's namespace is `theme`).
  String compile(String skin, {Map<String, dynamic> siteParams = const {}, String? probe}) {
    final config = generate(merge(skin, siteParams));
    final wrapper = File(p.join(config.buildDir, 'bridge_main.scss'))
      ..writeAsStringSync('${config.bridgeWrapperSource(entry)}${probe == null ? '' : '.probe { value: $probe; }\n'}');
    return TrellisCss.compileSass(wrapper.path, loadPaths: config.sassLoadPaths, fatalImportDeprecation: true);
  }
}

/// Reads a skin's `$palette` map by compiling it, so the test sees what Sass sees.
Map<String, String> _palette(String themeDir, String mode) {
  // Loaded by URL through an explicit load path: an absolute path resolves
  // through the cwd importer, which Sass deprecates (fs-importer-cwd).
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

/// Resolves the monorepo root by walking up from this package until `themes/bloom`
/// is found, so the test works regardless of the test CWD.
Future<String> _repoRoot() async {
  final uri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/trellis_site.dart'));
  if (uri == null || uri.scheme != 'file') {
    throw StateError('Could not resolve package:trellis_site/trellis_site.dart');
  }
  var dir = Directory(p.dirname(uri.toFilePath()));
  while (!Directory(p.join(dir.path, 'themes', 'bloom')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('Could not find repo root (themes/bloom) from ${uri.toFilePath()}');
    dir = parent;
  }
  return dir.path;
}
