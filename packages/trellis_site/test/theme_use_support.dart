/// Helpers shared by the per-theme `@use` suites (arbor, bloom/verdant, lattice): reading compiled CSS back as
/// custom-property blocks, a skin's `$palette`, and the monorepo root.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_css/trellis_css.dart';

/// Two colours no output style abbreviates, so `contains` assertions are stable.
const lightOverride = '#123456';
const darkOverride = '#654321';

/// Reads a skin's `$palette` map by compiling it, so a test sees what Sass sees.
/// Keys are the palette keys (`primary-color`), values the compiled colours.
///
/// Loaded by URL through an explicit load path: an absolute path resolves through the cwd importer, which Sass
/// deprecates (fs-importer-cwd).
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
String rootBlock(String css) {
  final start = RegExp(r'^:root \{', multiLine: true).firstMatch(css)!;
  return css.substring(start.end, css.indexOf('\n}', start.end));
}

/// Body of the `:root` rule inside `@media (prefers-color-scheme: dark)`, or null.
String? darkMediaRoot(String css) {
  final media = css.indexOf('@media (prefers-color-scheme: dark)');
  if (media == -1) return null;
  final root = css.indexOf(':root {', media);
  return css.substring(root + ':root {'.length, css.indexOf('}', root));
}

/// Custom properties declared in [block] (`--name: value;` lines).
Map<String, String> customProps(String block) => {
  for (final m in RegExp(r'(--[\w-]+):\s*([^;]+);').allMatches(block)) m.group(1)!: m.group(2)!.trim(),
};

String stripComments(String source) =>
    source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//.*'), '');

/// Resolves the monorepo root by walking up from this package until `themes/` and
/// `packages/trellis_site` are found, so a test works from any CWD.
Future<String> findRepoRoot() async {
  final uri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/trellis_site.dart'));
  if (uri == null || uri.scheme != 'file') {
    throw StateError('Could not resolve package:trellis_site/trellis_site.dart');
  }
  var dir = Directory(p.dirname(uri.toFilePath()));
  while (!(Directory(p.join(dir.path, 'themes')).existsSync() &&
      Directory(p.join(dir.path, 'packages', 'trellis_site')).existsSync())) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('Could not find repo root (themes/) from ${uri.toFilePath()}');
    dir = parent;
  }
  return dir.path;
}
