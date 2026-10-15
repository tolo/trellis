import 'dart:io';

import 'package:path/path.dart' as p;

/// Links the theme root into its own example site as `example/themes/<name>`.
///
/// The build resolves a theme as `<siteDir>/themes/<name>`, and the example site
/// lives inside the theme, so the entry is a relative link back up to the theme
/// root. A link rather than a copy keeps the preview live: edits to the theme's
/// layouts and SASS show up in the next `trellis build` without re-installing.
///
/// Returns null on success. Where the link cannot be created (Windows without
/// the symlink privilege, a filesystem without symlinks) it returns the message
/// that tells the user how to create it by hand, so scaffolding still succeeds.
String? linkThemeIntoExample(String projectDir, String themeName) {
  final linkPath = p.join(projectDir, 'example', 'themes', themeName);
  try {
    Directory(p.dirname(linkPath)).createSync(recursive: true);
    Link(linkPath).createSync(p.join('..', '..'));
    return null;
  } on FileSystemException catch (e) {
    final relative = p.join('example', 'themes', themeName);
    final manual = Platform.isWindows ? 'mklink /J $relative .' : 'ln -s ../.. $relative';
    return 'Could not link the theme into its example site (${e.message}).\n'
        '  The example sets `theme: $themeName`, so `trellis build` in example/ needs $relative to point at the\n'
        '  theme root. Create it by hand, from the theme root: $manual';
  }
}
