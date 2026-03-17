import 'dart:io';

import 'package:path/path.dart' as p;

import 'page.dart';

/// Generates a `sitemap.xml` conforming to the sitemap protocol.
///
/// Includes all non-draft pages that do not have `sitemap: false` in their
/// front matter. Each `<url>` entry contains a `<loc>` (full URL with
/// [baseUrl] prepended) and `<lastmod>` (ISO 8601 date).
///
/// Example:
/// ```dart
/// final generator = SitemapGenerator(
///   baseUrl: 'https://example.com',
///   contentDir: '/path/to/content',
/// );
/// final xml = generator.generate(pages);
/// generator.writeToOutput(pages, '/path/to/output');
/// ```
class SitemapGenerator {
  /// The site's canonical base URL (e.g. `https://example.com`).
  ///
  /// May be empty — sitemap will use relative URLs in that case.
  final String baseUrl;

  /// The content directory path, used to resolve source file paths for
  /// mtime fallback when no `date` front matter is present.
  final String contentDir;

  const SitemapGenerator({required this.baseUrl, required this.contentDir});

  /// Generates sitemap XML for the given [pages].
  ///
  /// Filters out draft pages and pages with `sitemap: false` in front
  /// matter. Returns a valid XML string with XML declaration and
  /// `urlset` namespace, or a minimal empty sitemap if no pages qualify.
  String generate(List<Page> pages) => _generateFromIncluded(pages.where(_shouldInclude).toList());

  String _generateFromIncluded(List<Page> includedPages) {
    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');

    for (final page in includedPages) {
      final loc = _escapeXml(_buildUrl(page.url));
      final lastmod = _resolveLastmod(page);
      buf
        ..writeln('  <url>')
        ..writeln('    <loc>$loc</loc>')
        ..writeln('    <lastmod>$lastmod</lastmod>')
        ..writeln('  </url>');
    }

    buf.write('</urlset>');
    return buf.toString();
  }

  /// Writes the sitemap XML to `[outputDir]/sitemap.xml`.
  ///
  /// Returns `true` if the sitemap was written, `false` if skipped.
  /// Skips generation (returns `false`) when [baseUrl] is empty, since the
  /// sitemap protocol requires absolute `<loc>` URLs.
  bool writeToOutput(List<Page> pages, String outputDir) {
    if (baseUrl.isEmpty) return false;

    final includedPages = pages.where(_shouldInclude).toList();
    if (includedPages.isEmpty) return false;

    final xml = _generateFromIncluded(includedPages);
    File(p.join(outputDir, 'sitemap.xml')).writeAsStringSync(xml);
    return true;
  }

  /// Returns `true` if [page] should be included in the sitemap.
  bool _shouldInclude(Page page) {
    if (page.isDraft) return false;
    if (page.frontMatter['sitemap'] == false) return false;
    return true;
  }

  /// Joins [baseUrl] and [pageUrl], normalizing slashes to avoid doubles.
  String _buildUrl(String pageUrl) {
    if (baseUrl.isEmpty) return pageUrl;
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$base$pageUrl';
  }

  /// Returns the ISO 8601 date string (`YYYY-MM-DD`) for [page].
  ///
  /// Resolution order:
  /// 1. `page.frontMatter['date']` as [DateTime]
  /// 2. `page.frontMatter['date']` as parseable [String]
  /// 3. Source file modification time
  /// 4. Current date (fallback if file does not exist)
  String _resolveLastmod(Page page) {
    final date = page.frontMatter['date'];
    if (date is DateTime) return _formatDate(date);
    if (date is String) {
      try {
        return _formatDate(DateTime.parse(date));
      } on FormatException {
        // fall through to mtime
      }
    }

    final sourceFile = File(p.join(contentDir, page.sourcePath));
    if (sourceFile.existsSync()) {
      return _formatDate(sourceFile.lastModifiedSync());
    }

    return _formatDate(DateTime.now());
  }

  /// Formats a [DateTime] as `YYYY-MM-DD`.
  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Escapes XML special characters in [value].
  String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll("'", '&apos;')
      .replaceAll('"', '&quot;');
}
