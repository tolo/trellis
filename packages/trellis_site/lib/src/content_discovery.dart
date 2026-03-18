import 'dart:io';

import 'package:path/path.dart' as p;

import 'page.dart';

/// Derives the URL path for a content file from its source path (relative to content dir).
///
/// Rules:
/// - `about.md` → `/about/`
/// - `posts/hello-world.md` → `/posts/hello-world/`
/// - `posts/_index.md` → `/posts/`
/// - `_index.md` → `/`
/// - `posts/my-trip/index.md` → `/posts/my-trip/` (page bundle)
String deriveUrl(String sourcePath) {
  // Normalize to forward slashes regardless of platform.
  final normalized = sourcePath.replaceAll(r'\', '/');
  final parts = p.posix.split(normalized);
  final filename = parts.last;
  final base = p.posix.basenameWithoutExtension(filename);

  if (base == '_index') {
    // _index.md — URL is the containing directory
    if (parts.length == 1) return '/';
    final dir = parts.sublist(0, parts.length - 1).join('/');
    return '/$dir/';
  }

  if (base == 'index') {
    // index.md page bundle — URL is the containing directory
    if (parts.length == 1) return '/';
    final dir = parts.sublist(0, parts.length - 1).join('/');
    return '/$dir/';
  }

  // Regular file — strip extension and use full path as URL slug
  final withoutExt = parts.sublist(0, parts.length - 1)..add(base);
  return '/${withoutExt.join('/')}/';
}

/// Detects the [PageKind] for a content file.
///
/// - `_index.md` at content root → [PageKind.home]
/// - `_index.md` in any subdirectory → [PageKind.section]
/// - All other `.md` files (including `index.md` bundles) → [PageKind.single]
PageKind detectKind(String sourcePath) {
  final normalized = sourcePath.replaceAll(r'\', '/');
  final filename = p.posix.basename(normalized);
  final base = p.posix.basenameWithoutExtension(filename);

  if (base != '_index') return PageKind.single;

  final parts = p.posix.split(normalized);
  if (parts.length == 1) return PageKind.home;
  return PageKind.section;
}

/// Derives the top-level section name for a content file.
///
/// - Root-level files → `''` (empty string)
/// - `posts/hello.md` → `posts`
/// - `docs/advanced/config.md` → `docs` (top-level only)
String deriveSection(String sourcePath) {
  final normalized = sourcePath.replaceAll(r'\', '/');
  final parts = p.posix.split(normalized);
  if (parts.length <= 1) return '';
  return parts.first;
}

/// Scans a content directory and discovers all Markdown pages.
class ContentDiscovery {
  /// The root content directory path.
  final String contentDir;

  /// Creates a [ContentDiscovery] for the given [contentDir].
  ContentDiscovery(this.contentDir);

  /// Discovers all pages in the content directory.
  ///
  /// Returns a list of [Page] objects with [Page.sourcePath], [Page.url],
  /// [Page.section], [Page.kind], [Page.isBundle], and [Page.bundleAssets]
  /// populated. Front matter and content fields are left at their default
  /// empty values (populated by later pipeline stages).
  ///
  /// Pages are sorted by [Page.sourcePath] for deterministic output.
  ///
  /// Throws [ArgumentError] if [contentDir] does not exist.
  Future<List<Page>> discover() async {
    final dir = Directory(contentDir);
    if (!dir.existsSync()) {
      throw ArgumentError('Content directory does not exist: $contentDir');
    }

    // Collect all files recursively.
    final allFiles = dir
        .listSync(recursive: true, followLinks: true)
        .whereType<File>()
        .map((f) => p.normalize(f.path))
        .toList();

    // Group all files by their parent directory (absolute path) for bundle detection.
    final filesByDir = <String, List<String>>{};
    for (final absPath in allFiles) {
      final parent = p.dirname(absPath);
      (filesByDir[parent] ??= []).add(absPath);
    }

    // Filter to .md files only and build pages.
    final contentDirNorm = p.normalize(contentDir);
    final mdFiles = allFiles.where((f) => f.endsWith('.md')).toList()..sort();

    final pages = <Page>[];
    for (final absPath in mdFiles) {
      // Compute path relative to content dir, using forward slashes.
      var relativePath = p.relative(absPath, from: contentDirNorm);
      relativePath = relativePath.replaceAll(r'\', '/');

      final filename = p.basename(relativePath);
      final base = p.basenameWithoutExtension(filename);

      final url = deriveUrl(relativePath);
      final kind = detectKind(relativePath);
      final section = deriveSection(relativePath);

      // Bundle detection: index.md (not _index.md) in a directory.
      final isBundle = base == 'index';
      final bundleAssets = <String>[];

      if (isBundle) {
        final parentDir = p.dirname(absPath);
        final siblings = filesByDir[parentDir] ?? [];
        for (final sibling in siblings) {
          if (!sibling.endsWith('.md') && sibling != absPath) {
            var assetPath = p.relative(sibling, from: contentDirNorm);
            assetPath = assetPath.replaceAll(r'\', '/');
            bundleAssets.add(assetPath);
          }
        }
        bundleAssets.sort();
      }

      pages.add(
        Page(
          sourcePath: relativePath,
          url: url,
          section: section,
          kind: kind,
          isDraft: false,
          isBundle: isBundle,
          bundleAssets: bundleAssets,
        ),
      );
    }

    return pages;
  }
}
