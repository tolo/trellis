import 'dart:io';

import 'package:path/path.dart' as p;

/// Returns the theme layouts the site shadows, as paths relative to [siteDir]
/// (e.g. `layouts/base.html`), sorted.
///
/// Layout resolution is site-first (see `ThemeAwareLoader.forTheme`), so a file
/// in [siteLayoutsDir] always wins over the theme's file at the same relative
/// path — the theme's copy is never rendered. `trellis theme add` reports this
/// list on install, and `trellis build` uses it to name the culprits when the
/// theme turns out to be inert.
///
/// Returns an empty list when either directory is missing.
List<String> shadowedThemeLayouts({required String siteDir, required String siteLayoutsDir, required String themeDir}) {
  final themeLayoutsDir = Directory(p.join(themeDir, 'layouts'));
  if (!themeLayoutsDir.existsSync() || !Directory(siteLayoutsDir).existsSync()) return const [];

  final shadowed = <String>[];
  // followLinks: false mirrors the loader, which refuses to serve a template
  // symlinked out of its base directory.
  for (final file in themeLayoutsDir.listSync(recursive: true, followLinks: false).whereType<File>()) {
    if (p.extension(file.path).toLowerCase() != '.html') continue;
    final relative = p.relative(file.path, from: themeLayoutsDir.path);
    final siteFile = p.join(siteLayoutsDir, relative);
    if (File(siteFile).existsSync()) shadowed.add(p.relative(siteFile, from: siteDir));
  }
  return shadowed..sort();
}
