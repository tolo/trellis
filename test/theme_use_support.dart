/// Shared by the folio and meadow contract suites: compiles a theme through the
/// bridge wrapper `trellis build` compiles, with the `@import` deprecation fatal,
/// and reads the compiled CSS back as custom-property blocks.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

/// Two colours no output style abbreviates, so `contains` assertions are stable.
const lightOverride = '#123456';
const darkOverride = '#654321';

/// Compiles [themeDir] exactly as the site builder + CLI do: manifest defaults
/// merged with [siteParams] over `skin: [skin]`, the generated params module, and
/// the shared wrapper. [probe] appends a rule so a test can read a module variable
/// the CSS never emits (the entry's namespace is `theme`).
String compileBridged(String themeDir, String skin, {Map<String, dynamic> siteParams = const {}, String? probe}) {
  final manifest = ThemeManifest.load(themeDir);
  final siteDir = Directory.systemTemp.createTempSync('trellis_theme_use_').resolveSymbolicLinksSync();
  try {
    final merged = const ThemeParamMerger().merge(manifest.defaultParams, {'skin': skin, ...siteParams}).params;
    final config = const ThemeSassGenerator().generate(
      mergedParams: merged,
      paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
      siteDir: siteDir,
      themeDir: themeDir,
    );
    final entry = File(p.join(themeDir, 'sass', 'main.scss')).resolveSymbolicLinksSync();
    final wrapper = File(p.join(config.buildDir, 'bridge_main.scss'))
      ..writeAsStringSync('${config.bridgeWrapperSource(entry)}${probe == null ? '' : '.probe { value: $probe; }\n'}');
    return TrellisCss.compileSass(wrapper.path, loadPaths: config.sassLoadPaths, fatalImportDeprecation: true);
  } finally {
    Directory(siteDir).deleteSync(recursive: true);
  }
}

/// Compiles [themeDir]'s entry without the bridge: bare, or as `@use "<entry>" with ([configuration])`
/// for a comma-list value written parenthesised, as Sass requires.
String compileStandalone(String themeDir, {String? configuration}) {
  final entry = File(p.join(themeDir, 'sass', 'main.scss')).resolveSymbolicLinksSync();
  if (configuration == null) return TrellisCss.compileSass(entry, fatalImportDeprecation: true);
  final tempDir = Directory.systemTemp.createTempSync('trellis_theme_standalone_');
  try {
    final wrapper = File(p.join(tempDir.path, 'standalone.scss'))
      ..writeAsStringSync('@use "$entry" as theme with ($configuration);\n');
    return TrellisCss.compileSass(wrapper.path, fatalImportDeprecation: true);
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

/// The `.scss`/`.sass` files under [dir] that git would track: a sweep over them gives a clean CI checkout's verdict
/// on any checkout. Files below a dot-entry (gitignored `.trellis/` build output, `.DS_Store`) and links (the
/// `example/themes/<theme>` loop back into the theme) are skipped, and non-SASS files are never read as text.
List<File> sassSources(String dir) => [
  for (final entity in Directory(dir).listSync(recursive: true, followLinks: false))
    if (entity is File &&
        const {'.scss', '.sass'}.contains(p.extension(entity.path).toLowerCase()) &&
        !p.split(p.relative(entity.path, from: dir)).any((segment) => segment.startsWith('.')))
      entity,
];

/// Reads a skin's `$palette` map by compiling it, so a test sees what Sass sees.
/// Keys are the palette keys (`primary-color`), values the compiled colours.
Map<String, String> readPalette(String themeDir, String mode) {
  final css = TrellisCss.compileSassString(
    '''
@use "_skins/$mode" as skin;
:root { @each \$key, \$value in skin.\$palette { --#{\$key}: #{\$value}; } }
''',
    loadPaths: [p.join(themeDir, 'sass')],
  );
  return {for (final e in customProps(rootBlock(css)).entries) e.key.substring(2): e.value};
}

/// Body of the first top-level `:root { ... }` rule.
String rootBlock(String css) => rootBlocks(css).first;

/// Bodies of every top-level `:root { ... }` rule, in source order.
List<String> rootBlocks(String css) => [
  for (final start in RegExp(r'^:root \{', multiLine: true).allMatches(css))
    css.substring(start.end, css.indexOf('\n}', start.end)),
];

/// Body of the `:root` rule inside `@media (prefers-color-scheme: dark)`, or null.
String? darkMediaRoot(String css) {
  final media = css.indexOf('@media (prefers-color-scheme: dark)');
  if (media == -1) return null;
  final root = css.indexOf(':root {', media);
  return css.substring(root + ':root {'.length, css.indexOf('}', root));
}

/// Body of the first rule whose selector is exactly [selector] (e.g. `:root[data-skin=dark]`), or null.
String? ruleBody(String css, String selector) {
  final start = css.indexOf('$selector {');
  if (start == -1) return null;
  final open = start + selector.length + 2;
  return css.substring(open, css.indexOf('}', open));
}

/// Custom properties declared in [block] (`--name: value;` lines).
Map<String, String> customProps(String block) => {
  for (final m in RegExp(r'(--[\w-]+):\s*([^;]+);').allMatches(block)) m.group(1)!: m.group(2)!.trim(),
};

String stripComments(String source) =>
    source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//.*'), '');
