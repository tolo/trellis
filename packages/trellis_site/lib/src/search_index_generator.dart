import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'page.dart';

/// Configuration for JSON search index generation.
///
/// Parsed from the `search:` section in `trellis_site.yaml`.
///
/// Example YAML:
/// ```yaml
/// search:
///   enabled: true
///   output: search-index.json
///   fields: [title, summary, content, tags]
///   excludeSections: [drafts, internal]
///   stripHtml: true
///   maxContentLength: 5000
/// ```
class SearchConfig {
  /// Whether search index generation is enabled. Default: `false`.
  final bool enabled;

  /// Output filename (relative to the output directory).
  /// Default: `'search-index.json'`.
  final String output;

  /// Fields to include in each index entry. `url` is always included
  /// regardless of this list.
  ///
  /// Supported fields: `title`, `summary`, `content`, `tags`, `date`,
  /// `section`.
  ///
  /// Default: `['title', 'summary', 'content', 'tags']`.
  final List<String> fields;

  /// Sections to exclude from the index. Default: empty (all included).
  final List<String> excludeSections;

  /// Whether to strip HTML tags from `content` and `summary` fields.
  /// Default: `true`.
  final bool stripHtml;

  /// Maximum character length for the `content` field after HTML stripping.
  /// `null` means no truncation. Default: `5000`.
  ///
  /// When the YAML key is absent, defaults to `5000` via the const constructor.
  /// To disable truncation in a loaded config, omit the key — the factory
  /// reads `null` from the map and stores `null` (no truncation).
  final int? maxContentLength;

  const SearchConfig({
    this.enabled = false,
    this.output = 'search-index.json',
    this.fields = const ['title', 'summary', 'content', 'tags'],
    this.excludeSections = const [],
    this.stripHtml = true,
    this.maxContentLength = 5000,
  });

  /// Parses a [SearchConfig] from a YAML map.
  ///
  /// Returns the default (disabled) config if [map] is `null`.
  factory SearchConfig.fromYaml(Map<String, dynamic>? map) {
    if (map == null) return const SearchConfig();
    return SearchConfig(
      enabled: map['enabled'] == true,
      output: (map['output'] as String?) ?? 'search-index.json',
      fields: _parseStringList(map['fields'], const ['title', 'summary', 'content', 'tags']),
      excludeSections: _parseStringList(map['excludeSections'], const []),
      stripHtml: map['stripHtml'] != false,
      maxContentLength: map['maxContentLength'] as int?,
    );
  }

  static List<String> _parseStringList(dynamic value, List<String> defaultValue) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return defaultValue;
  }
}

/// Generates a JSON search index for client-side search integration.
///
/// Produces a JSON array of page objects with configurable fields,
/// compatible with Lunr.js, Fuse.js, Pagefind, and similar libraries.
///
/// Example:
/// ```dart
/// final config = SearchConfig(enabled: true, fields: ['title', 'content']);
/// final generator = SearchIndexGenerator(config);
/// final json = generator.generate(pages);
/// generator.writeToOutput(pages, '/path/to/output');
/// ```
class SearchIndexGenerator {
  /// The search index configuration.
  final SearchConfig config;

  const SearchIndexGenerator(this.config);

  /// Generates JSON search index content for the given [pages].
  ///
  /// Filters out draft pages, excluded sections, and pages with
  /// `search: false` in front matter. Returns a pretty-printed JSON
  /// string containing an array of page objects.
  String generate(List<Page> pages) {
    final entries = pages.where(_shouldInclude).map(_buildEntry).toList();
    return const JsonEncoder.withIndent('  ').convert(entries);
  }

  /// Writes the JSON search index to `[outputDir]/[config.output]`.
  ///
  /// Returns `true` if the file was written, `false` if search is disabled
  /// or no pages qualify.
  bool writeToOutput(List<Page> pages, String outputDir) {
    if (!config.enabled) return false;
    final entries = pages.where(_shouldInclude).map(_buildEntry).toList();
    if (entries.isEmpty) return false;
    final json = const JsonEncoder.withIndent('  ').convert(entries);
    final filePath = p.join(outputDir, config.output);
    Directory(p.dirname(filePath)).createSync(recursive: true);
    File(filePath).writeAsStringSync(json);
    return true;
  }

  bool _shouldInclude(Page page) {
    if (page.isDraft) return false;
    if (page.frontMatter['search'] == false) return false;
    if (config.excludeSections.contains(page.section)) return false;
    if (page.kind != PageKind.single) return false;
    return true;
  }

  Map<String, dynamic> _buildEntry(Page page) {
    final entry = <String, dynamic>{'url': page.url};

    for (final field in config.fields) {
      switch (field) {
        case 'title':
          final v = page.frontMatter['title'];
          if (v != null) entry['title'] = v.toString();
        case 'summary':
          final raw = page.summary;
          final v = config.stripHtml ? SearchIndexGenerator.stripHtml(raw) : raw;
          if (v.isNotEmpty) entry['summary'] = v;
        case 'content':
          var v = config.stripHtml ? SearchIndexGenerator.stripHtml(page.content) : page.content;
          if (config.maxContentLength != null) {
            v = SearchIndexGenerator.truncate(v, config.maxContentLength!);
          }
          if (v.isNotEmpty) entry['content'] = v;
        case 'tags':
          final raw = page.frontMatter['tags'];
          if (raw != null) {
            final tags = (raw as List).map((e) => e.toString()).toList();
            entry['tags'] = tags;
          }
        case 'date':
          final raw = page.frontMatter['date'];
          if (raw is DateTime) {
            entry['date'] = _formatDate(raw);
          } else if (raw is String) {
            entry['date'] = raw;
          }
        case 'section':
          entry['section'] = page.section;
      }
    }

    return entry;
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$mo-$d';
  }

  /// Strips HTML tags from [html], returning plain text.
  ///
  /// Handles standard tags, self-closing tags, and attributes. Block-level
  /// tag boundaries are replaced with a space to prevent word joining.
  /// Common HTML entities are decoded. Whitespace is collapsed and trimmed.
  static String stripHtml(String html) {
    // Replace block-level tag boundaries with space to prevent word joining
    var text = html.replaceAll(
      RegExp(r'</?(p|div|br|h[1-6]|li|tr|td|th|blockquote|pre|hr)[^>]*>', caseSensitive: false),
      ' ',
    );

    // Remove remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode common HTML entities
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');

    // Collapse whitespace and trim
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Truncates [text] to [maxLength] characters.
  ///
  /// Returns [text] unchanged if it fits within [maxLength]. Otherwise
  /// truncates and attempts to break at a word boundary (last space within
  /// the final 20% of [maxLength]). Appends `'...'` when truncating.
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    final cutoff = text.lastIndexOf(' ', maxLength);
    final minCutoff = (maxLength * 0.8).floor();
    if (cutoff > minCutoff) {
      return '${text.substring(0, cutoff)}...';
    }
    return '${text.substring(0, maxLength)}...';
  }
}
