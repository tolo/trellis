import 'dart:io';

import 'package:path/path.dart' as p;

/// The source-file mtime the byte-for-byte goldens (`test_fixtures/*_regression_golden.json`) were
/// captured with: `<lastmod>2026-03-18</lastmod>` / `<updated>2026-03-18T07:25:45Z</updated>`.
final DateTime buildSiteFixtureMtime = DateTime.utc(2026, 3, 18, 7, 25, 45);

/// Pins the mtime of every content file in the `build_site` fixture to [buildSiteFixtureMtime].
///
/// Pages without a `date:` front-matter key fall back to their source file's mtime for the sitemap
/// `<lastmod>` and feed `<updated>`, and git does not preserve mtimes — so on a fresh clone (CI, a
/// second machine) the goldens would otherwise carry checkout time and fail. Call from `setUpAll`
/// of any test that compares a `build_site` build byte-for-byte.
void pinBuildSiteFixtureMtimes(String fixturesRoot) {
  final content = Directory(p.join(fixturesRoot, 'build_site', 'content'));
  for (final entity in content.listSync(recursive: true)) {
    if (entity is File) entity.setLastModifiedSync(buildSiteFixtureMtime);
  }
}
