import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis_css/trellis_css.dart';

import 'theme_manifest.dart';
import 'theme_sass_generator.dart' show ThemeBuildConfig;

/// Compiles the theme stylesheet [entry] the way `trellis build` does: through the bridge wrapper
/// ([ThemeBuildConfig.bridgeWrapperSource]) that `@use`s the generated params module and configures the entry with
/// the variables Sass accepts, with the `@import` deprecation fatal (an `@import` theme would build with its skin
/// silently missing, ADR-013).
///
/// [ThemeBuildConfig.configurableVars] are candidates. Sass has the final say on which of them an entry can be
/// configured with (a `!default` the entry forwards at the top level of a file), so a candidate it rejects is dropped
/// and the compile retried. The compile that succeeds is the only one, and costs one extra compile per rejected
/// candidate, which the generator keeps rare by offering only variables some file declares `!default`. The dropped
/// names are in the result, because a dropped candidate has a `!default` by construction: the theme meant the param to
/// be configurable, and its override has no effect on the theme's Sass.
///
/// The wrapper is written to `bridge_<entry name>.scss` in [ThemeBuildConfig.buildDir], where its
/// `@use "theme_params"` finds the generated module, and the entry is `@use`d by canonical path so its own relative
/// `@use`s resolve from where it lives. It lists the variables the entry was configured with. [wrapperSuffix] is
/// appended to the wrapper, so a test can read a module variable the CSS never emits through the `theme` namespace.
///
/// Throws [SassCompilationException] when the theme does not compile.
ThemeEntryCompilation compileThemeEntry(
  ThemeBuildConfig config,
  String entry, {
  OutputStyle outputStyle = OutputStyle.compressed,
  String wrapperSuffix = '',
}) {
  final wrapper = File(p.join(config.buildDir, 'bridge_${p.basenameWithoutExtension(entry)}.scss'));
  final variables = [...config.configurableVars];
  final dropped = <String>[];
  while (true) {
    final source = ThemeBuildConfig(
      buildDir: config.buildDir,
      sassLoadPaths: config.sassLoadPaths,
      configurableVars: variables,
    ).bridgeWrapperSource(p.canonicalize(entry));
    wrapper.writeAsStringSync('$source$wrapperSuffix');
    try {
      final css = TrellisCss.compileSass(
        wrapper.path,
        outputStyle: outputStyle,
        loadPaths: config.sassLoadPaths,
        fatalImportDeprecation: true,
      );
      return ThemeEntryCompilation(css: css, configured: variables, dropped: dropped);
    } on SassCompilationException catch (e) {
      final rejected = _rejectedVariable(e, wrapper.path, source);
      if (rejected == null || !variables.remove(rejected)) rethrow;
      dropped.add(rejected);
    }
  }
}

/// The outcome of [compileThemeEntry].
class ThemeEntryCompilation {
  const ThemeEntryCompilation({required this.css, required this.configured, required this.dropped});

  final String css;

  /// The SASS variable names (without `$`, e.g. `trellis-max-width`) the entry was configured with.
  final List<String> configured;

  /// The candidates ([ThemeBuildConfig.configurableVars]) Sass rejected: each has a `!default` where the entry's
  /// `with()` cannot reach it (a mixin, a string, an `@if`, or a partial the entry only `@use`s).
  final List<String> dropped;
}

/// The variable of the wrapper [source] that [error] says Sass rejected configuring, or null when the error is
/// anything else, including the same complaint raised by a `with()` inside the theme itself.
String? _rejectedVariable(SassCompilationException error, String wrapperPath, String source) {
  final path = error.path;
  final line = error.line;
  if (!error.message.contains('not declared with !default') || path == null || line == null) return null;
  if (p.canonicalize(path) != p.canonicalize(wrapperPath)) return null;
  final lines = source.split('\n');
  if (line < 1 || line > lines.length) return null;
  return RegExp(r'^\s*\$([\w-]+)\s*:').firstMatch(lines[line - 1])?[1];
}

/// A colour param whose `theme.yaml` default does not match its palette entry.
///
/// The bridge configures every manifest param on the theme entry, defaults included, so a colour edited in
/// `sass/_skins/_light.scss` or `_dark.scss` reaches a standalone compile but never a site build until the param's
/// default says the same (ADR-013). A colour param `<x>` reads the light palette's `<x>` entry (kebab case), and its
/// twin `<x>_dark` the dark palette's.
class PaletteDefaultMismatch {
  const PaletteDefaultMismatch({
    required this.theme,
    required this.param,
    required this.mode,
    required this.key,
    required this.defaultValue,
    required this.entry,
  });

  final String theme;
  final String param;

  /// `light` or `dark`: the palette the param is read against.
  final String mode;

  /// The palette key (`primary-color`).
  final String key;
  final String defaultValue;

  /// The compiled palette value, or null when the palette has no [key].
  final String? entry;

  String get message => entry == null
      ? "theme '$theme', param '$param': no '$key' entry in the $mode palette"
      : "theme '$theme', param '$param': default '$defaultValue' differs from the $mode palette entry '$entry' "
            '(sass/_skins/_$mode.scss)';
}

/// The colour params of [manifest]'s theme whose default differs from the palette entry they are read against, or has
/// no entry. Sass compares them (`#fff`, `#ffffff` and `white` are one colour), and reads the palettes by compiling
/// them, so an entry may be built from variables.
///
/// A skin file the theme does not have is skipped: a theme without palettes is not held to the convention. So is a
/// param without a `theme.yaml` default: the bridge configures `null` for it, which Sass ignores, so the palette entry
/// stays in force and cannot drift.
/// Throws [SassCompilationException] when a palette does not compile or has no `$palette` map.
List<PaletteDefaultMismatch> paletteDefaultMismatches(ThemeManifest manifest) {
  final colors = {
    for (final e in manifest.params.entries)
      if (e.value.type == 'color') e.key: e.value,
  };
  // A twin is found among all colour params, but only those with a default are compared.
  bool hasDefault(String name) => colors[name]!.defaultValue != null;
  final sassDir = p.join(manifest.themeDir, 'sass');
  // Which palette and key each colour param is read against.
  final reads = <String, ({String mode, String key})>{};
  for (final name in colors.keys.where(hasDefault)) {
    final isTwin = name.endsWith('_dark') && colors.containsKey(name.substring(0, name.length - '_dark'.length));
    final base = isTwin ? name.substring(0, name.length - '_dark'.length) : name;
    reads[name] = (mode: isTwin ? 'dark' : 'light', key: base.replaceAll('_', '-'));
  }
  final results = {
    for (final mode in const ['light', 'dark'])
      if (File(p.join(sassDir, '_skins', '_$mode.scss')).existsSync())
        mode: _comparePalette(sassDir, mode, {
          for (final MapEntry(key: name, value: read) in reads.entries)
            if (read.mode == mode) name: (key: read.key, defaultValue: colors[name]!.defaultValue.toString()),
        }),
  };

  return [
    for (final MapEntry(key: name, value: read) in reads.entries)
      if (results[read.mode]?[name] case final result? when result.status != 'same')
        PaletteDefaultMismatch(
          theme: p.basename(manifest.themeDir),
          param: name,
          mode: read.mode,
          key: read.key,
          defaultValue: colors[name]!.defaultValue.toString(),
          entry: result.status == 'missing' ? null : result.entry,
        ),
  ];
}

/// Asks Sass, per entry of [checks] (param name to palette key and default), whether the skin [mode]'s `$palette`
/// holds that key with a value equal to the default. The result per param is `same`, `missing`, or `differs` with the
/// palette value as authored (interpolated, so a hex stays hex).
Map<String, ({String status, String entry})> _comparePalette(
  String sassDir,
  String mode,
  Map<String, ({String key, String defaultValue})> checks,
) {
  final params = [
    for (final MapEntry(key: name, value: c) in checks.entries) '"$name": ("${c.key}", ${c.defaultValue})',
  ];
  final css = TrellisCss.compileSassString(
    '''
@use "sass:list";
@use "sass:map";
@use "_skins/$mode" as skin;
\$checks: (${params.join(', ')});
:root {
  @each \$param, \$check in \$checks {
    \$entry: map.get(skin.\$palette, list.nth(\$check, 1));
    @if \$entry == null { --#{\$param}: missing; }
    @else if \$entry == list.nth(\$check, 2) { --#{\$param}: same; }
    @else { --#{\$param}: differs #{\$entry}; }
  }
}
''',
    loadPaths: [sassDir],
  );
  return {
    for (final m in RegExp(r'--([\w-]+):\s*(same|missing|differs)\b\s*([^;]*);').allMatches(css))
      m.group(1)!: (status: m.group(2)!, entry: m.group(3)!.trim()),
  };
}
