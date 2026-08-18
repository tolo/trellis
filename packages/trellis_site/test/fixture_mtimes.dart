import 'dart:io';

import 'package:path/path.dart' as p;

/// The source-file mtime the byte-for-byte goldens (`test_fixtures/*_regression_golden.json`) expect:
/// `<lastmod>2026-03-18</lastmod>` / `<updated>2026-03-18T12:00:00Z</updated>`. Noon UTC, because the
/// sitemap `<lastmod>` is the *local* calendar date of the mtime — midday keeps that date stable in every
/// zone from UTC-11 to UTC+11 (a 07:25Z pin flipped to 03-17 in Anchorage/Hawaii).
final DateTime buildSiteFixtureMtime = DateTime.utc(2026, 3, 18, 12);

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
