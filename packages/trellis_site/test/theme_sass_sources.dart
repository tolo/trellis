/// "The files a SASS-source sweep reads", shared by this package's theme `@use` suites. The root suite keeps its
/// own copy of the rule as `sourceFiles` in `test/theme_use_support.dart`: change the two together.
///
/// A sweep over a checkout must give the verdict a clean CI checkout gives. The working tree also holds files git
/// does not track: gitignored build output (`example/.trellis/build/bridge_main.scss` from an older build), OS
/// metadata (`.DS_Store`), and the `example/themes/<theme>` link that leads back into the theme. So a sweep reads
/// only files with a SASS extension, skips anything below a dot-entry, and never follows links.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

const sassExtensions = {'.scss', '.sass'};

/// Regular files under [dir] whose extension is in [extensions] (every file when null), excluding any below a
/// dot-entry of [dir] and any reached through a link. [dir] itself may be a dot directory (a site's `.trellis/build`).
List<File> sweepFiles(String dir, {Set<String>? extensions = sassExtensions}) => [
  for (final entity in Directory(dir).listSync(recursive: true, followLinks: false))
    if (entity is File &&
        !p.split(p.relative(entity.path, from: dir)).any((segment) => segment.startsWith('.')) &&
        (extensions == null || extensions.contains(p.extension(entity.path).toLowerCase())))
      entity,
];
