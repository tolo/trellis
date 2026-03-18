import 'dart:io';

import 'package:path/path.dart' as p;

import 'page.dart';

/// Configuration for feed generation, parsed from the `feeds:` section
/// of `trellis_site.yaml`.
class FeedConfig {
  /// Whether to generate Atom (RFC 4287) feeds. Defaults to `true`.
  final bool atom;

  /// Whether to generate RSS 2.0 feeds. Defaults to `false`.
  final bool rss;

  /// Sections to generate per-section feeds for. Empty list means site-wide only.
  final List<String> sections;

  /// Maximum number of items per feed. Defaults to `20`.
  final int limit;

  /// Whether to include full page content or summary only. Defaults to `false`.
  final bool fullContent;

  const FeedConfig({
    this.atom = true,
    this.rss = false,
    this.sections = const [],
    this.limit = 20,
    this.fullContent = false,
  });

  /// Parses a [FeedConfig] from a YAML map.
  ///
  /// Returns `null` if [yaml] is `null` (feeds section absent from config).
  /// Returns default config if [yaml] is non-null but not a Map.
  static FeedConfig? fromYaml(dynamic yaml) {
    if (yaml == null) return null;
    if (yaml is! Map) return const FeedConfig();
    return FeedConfig(
      atom: (yaml['atom'] as bool?) ?? true,
      rss: (yaml['rss'] as bool?) ?? false,
      sections: _parseStringList(yaml['sections']),
      limit: (yaml['limit'] as int?) ?? 20,
      fullContent: (yaml['fullContent'] as bool?) ?? false,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}

/// The result of feed generation.
class FeedResult {
  /// The number of feed files written.
  final int fileCount;

  /// Feed URLs keyed by format, for injection into the template context.
  ///
  /// Example: `{'atom': '/feed.xml', 'rss': '/rss.xml'}`.
  final Map<String, dynamic> feedUrls;

  /// Non-fatal warnings (e.g. unknown section names).
  final List<String> warnings;

  const FeedResult({
    required this.fileCount,
    required this.feedUrls,
    this.warnings = const [],
  });
}

/// Generates Atom (RFC 4287) and optionally RSS 2.0 feeds for a static site.
///
/// Receives the list of pages and site configuration, produces XML as strings,
/// and writes feed files to the output directory. Integrates into the
/// [TrellisSite.build()] pipeline after sitemap generation.
///
/// Example:
/// ```dart
/// final generator = FeedGenerator(
///   config: feedConfig,
///   baseUrl: 'https://example.com',
///   siteTitle: 'My Blog',
///   siteDescription: 'A blog about Dart',
///   contentDir: '/path/to/content',
/// );
/// final result = generator.writeToOutput(pages, '/path/to/output');
/// ```
class FeedGenerator {
  /// The feed configuration.
  final FeedConfig config;

  /// The site's canonical base URL (e.g. `https://example.com`).
  final String baseUrl;

  /// The site title, used as the feed title.
  final String siteTitle;

  /// The site description, used as the feed subtitle/description.
  final String siteDescription;

  /// The content directory path, used for file mtime fallback.
  final String contentDir;

  /// The site-level author name, used as fallback when a page has no author.
  final String? siteAuthor;

  static const _rfc822Days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _rfc822Months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  const FeedGenerator({
    required this.config,
    required this.baseUrl,
    required this.siteTitle,
    required this.siteDescription,
    required this.contentDir,
    this.siteAuthor,
  });

  /// Generates Atom XML for the given [pages], optionally filtered to [section].
  ///
  /// Returns a valid Atom feed string (RFC 4287). Returns a feed with metadata
  /// but no entries if no pages match.
  String generateAtom(List<Page> pages, {String? section}) {
    final entries = _collectFeedPages(pages, section: section);
    final feedTitle = _feedTitle(section: section);
    final selfUrl = section != null ? _buildUrl('/$section/feed.xml') : _buildUrl('/feed.xml');
    final siteUrl = _buildUrl('/');
    final updated = entries.isNotEmpty ? _formatRfc3339(_resolveDateTime(entries.first)) : _formatRfc3339(DateTime.now().toUtc());

    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<feed xmlns="http://www.w3.org/2005/Atom">')
      ..writeln('  <title>${_escapeXml(feedTitle)}</title>');

    if (siteDescription.isNotEmpty) {
      buf.writeln('  <subtitle>${_escapeXml(siteDescription)}</subtitle>');
    }

    buf
      ..writeln('  <link href="${_escapeXml(siteUrl)}" rel="alternate"/>')
      ..writeln('  <link href="${_escapeXml(selfUrl)}" rel="self"/>')
      ..writeln('  <id>${_escapeXml(siteUrl)}</id>')
      ..writeln('  <updated>$updated</updated>')
      ..writeln('  <generator>Trellis Site</generator>');

    for (final page in entries) {
      final pageUrl = _buildUrl(page.url);
      final pageDate = _formatRfc3339(_resolveDateTime(page));
      final title = _escapeXml((page.frontMatter['title'] as String?) ?? '');
      final author = _escapeXml(_entryAuthor(page));

      buf
        ..writeln('  <entry>')
        ..writeln('    <title>$title</title>')
        ..writeln('    <link href="${_escapeXml(pageUrl)}" rel="alternate"/>')
        ..writeln('    <id>${_escapeXml(pageUrl)}</id>')
        ..writeln('    <updated>$pageDate</updated>')
        ..writeln('    <author>')
        ..writeln('      <name>$author</name>')
        ..writeln('    </author>');

      if (config.fullContent) {
        buf.writeln('    <content type="html">${_wrapCdata(page.content)}</content>');
      } else {
        buf.writeln('    <summary type="html">${_escapeXml(page.summary)}</summary>');
      }

      buf.writeln('  </entry>');
    }

    buf.write('</feed>');
    return buf.toString();
  }

  /// Generates RSS 2.0 XML for the given [pages], optionally filtered to [section].
  ///
  /// Returns a valid RSS 2.0 feed string. Returns a feed with channel metadata
  /// but no items if no pages match.
  String generateRss(List<Page> pages, {String? section}) {
    final entries = _collectFeedPages(pages, section: section);
    final feedTitle = _feedTitle(section: section);
    final selfUrl = section != null ? _buildUrl('/$section/rss.xml') : _buildUrl('/rss.xml');
    final siteUrl = _buildUrl('/');
    final lastBuildDate = entries.isNotEmpty
        ? _formatRfc822(_resolveDateTime(entries.first))
        : _formatRfc822(DateTime.now().toUtc());

    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">')
      ..writeln('  <channel>')
      ..writeln('    <title>${_escapeXml(feedTitle)}</title>')
      ..writeln('    <description>${_escapeXml(siteDescription)}</description>')
      ..writeln('    <link>${_escapeXml(siteUrl)}</link>')
      ..writeln(
        '    <atom:link href="${_escapeXml(selfUrl)}" rel="self" type="application/rss+xml"/>',
      )
      ..writeln('    <lastBuildDate>$lastBuildDate</lastBuildDate>')
      ..writeln('    <generator>Trellis Site</generator>');

    for (final page in entries) {
      final pageUrl = _buildUrl(page.url);
      final pubDate = _formatRfc822(_resolveDateTime(page));
      final title = _escapeXml((page.frontMatter['title'] as String?) ?? '');
      final description = _escapeXml(config.fullContent ? page.content : page.summary);

      buf
        ..writeln('    <item>')
        ..writeln('      <title>$title</title>')
        ..writeln('      <link>${_escapeXml(pageUrl)}</link>')
        ..writeln('      <guid isPermaLink="true">${_escapeXml(pageUrl)}</guid>')
        ..writeln('      <pubDate>$pubDate</pubDate>')
        ..writeln('      <description>$description</description>')
        ..writeln('    </item>');
    }

    buf
      ..writeln('  </channel>')
      ..write('</rss>');
    return buf.toString();
  }

  /// Writes all configured feeds to the [outputDir].
  ///
  /// Returns a [FeedResult] containing the number of files written,
  /// feed URLs for template context injection, and any warnings.
  FeedResult writeToOutput(List<Page> pages, String outputDir) {
    var fileCount = 0;
    final feedUrls = <String, dynamic>{};
    final warnings = <String>[];

    if (config.atom) {
      final xml = generateAtom(pages);
      final path = p.join(outputDir, 'feed.xml');
      Directory(p.dirname(path)).createSync(recursive: true);
      File(path).writeAsStringSync(xml);
      fileCount++;
      feedUrls['atom'] = '/feed.xml';
    }

    if (config.rss) {
      final xml = generateRss(pages);
      final path = p.join(outputDir, 'rss.xml');
      Directory(p.dirname(path)).createSync(recursive: true);
      File(path).writeAsStringSync(xml);
      fileCount++;
      feedUrls['rss'] = '/rss.xml';
    }

    for (final section in config.sections) {
      if (config.atom) {
        final xml = generateAtom(pages, section: section);
        final path = p.join(outputDir, section, 'feed.xml');
        Directory(p.dirname(path)).createSync(recursive: true);
        File(path).writeAsStringSync(xml);
        fileCount++;
      }
      if (config.rss) {
        final xml = generateRss(pages, section: section);
        final path = p.join(outputDir, section, 'rss.xml');
        Directory(p.dirname(path)).createSync(recursive: true);
        File(path).writeAsStringSync(xml);
        fileCount++;
      }
    }

    return FeedResult(fileCount: fileCount, feedUrls: feedUrls, warnings: warnings);
  }

  // --- Private helpers ---

  /// Returns feed-eligible pages, filtered by [section], sorted newest-first,
  /// and truncated to [config.limit].
  List<Page> _collectFeedPages(List<Page> pages, {String? section}) {
    Iterable<Page> eligible = pages.where(
      (pg) => !pg.isDraft && pg.kind == PageKind.single && pg.frontMatter['feed'] != false,
    );

    if (section != null) {
      eligible = eligible.where((pg) => pg.section == section);
    } else if (config.sections.isNotEmpty) {
      eligible = eligible.where((pg) => config.sections.contains(pg.section));
    }

    final sorted = eligible.toList()..sort(_compareByDateDesc);
    if (sorted.length > config.limit) return sorted.sublist(0, config.limit);
    return sorted;
  }

  int _compareByDateDesc(Page a, Page b) {
    final da = _resolveDateTime(a);
    final db = _resolveDateTime(b);
    return db.compareTo(da); // newest first
  }

  /// Resolves a [DateTime] for [page] using front matter date, file mtime, or now.
  DateTime _resolveDateTime(Page page) {
    final date = page.frontMatter['date'];
    if (date is DateTime) return date.toUtc();
    if (date is String) {
      try {
        return DateTime.parse(date).toUtc();
      } on FormatException {
        // fall through
      }
    }
    final sourceFile = File(p.join(contentDir, page.sourcePath));
    if (sourceFile.existsSync()) return sourceFile.lastModifiedSync().toUtc();
    return DateTime.now().toUtc();
  }

  /// Formats a [DateTime] as RFC 3339 (`YYYY-MM-DDTHH:MM:SSZ`).
  String _formatRfc3339(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final mo = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '$y-$mo-${d}T$h:$mi:${s}Z';
  }

  /// Formats a [DateTime] as RFC 822 (`ddd, DD MMM YYYY HH:MM:SS GMT`).
  String _formatRfc822(DateTime dt) {
    final utc = dt.toUtc();
    final dow = _rfc822Days[utc.weekday - 1];
    final d = utc.day.toString().padLeft(2, '0');
    final mon = _rfc822Months[utc.month - 1];
    final y = utc.year.toString();
    final h = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '$dow, $d $mon $y $h:$mi:$s GMT';
  }

  /// Joins [baseUrl] and [pageUrl], normalizing to avoid double slashes.
  String _buildUrl(String pageUrl) {
    if (baseUrl.isEmpty) return pageUrl;
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$base$pageUrl';
  }

  /// Escapes XML special characters in [value].
  String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll("'", '&apos;')
      .replaceAll('"', '&quot;');

  /// Returns the author for [page], falling back to [siteAuthor] then `'Unknown'`.
  String _entryAuthor(Page page) {
    final pageAuthor = page.frontMatter['author'];
    if (pageAuthor is String && pageAuthor.isNotEmpty) return pageAuthor;
    if (siteAuthor != null && siteAuthor!.isNotEmpty) return siteAuthor!;
    return 'Unknown';
  }

  /// Returns the feed title, adding a capitalized section suffix for per-section feeds.
  String _feedTitle({String? section}) {
    if (section == null) return siteTitle;
    final capitalized = section.isEmpty ? section : section[0].toUpperCase() + section.substring(1);
    return '$siteTitle - $capitalized';
  }

  /// Wraps [content] in a CDATA section, splitting on `]]>` if present.
  ///
  /// Per the XML spec, `]]>` cannot appear inside a CDATA section. When it
  /// occurs in content, it is split by replacing each `]]>` with
  /// `]]]]><![CDATA[>`, which ends the current CDATA, inserts the literal
  /// `]]>`, and opens a new CDATA section.
  String _wrapCdata(String content) {
    final escaped = content.replaceAll(']]>', ']]]]><![CDATA[>');
    return '<![CDATA[$escaped]]>';
  }
}
