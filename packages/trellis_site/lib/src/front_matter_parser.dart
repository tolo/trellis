import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'page.dart';
import 'yaml_utils.dart';

/// Thrown when front matter cannot be parsed from a content file.
class FrontMatterException implements Exception {
  /// A human-readable error message.
  final String message;

  /// Absolute path to the source file that caused the error, if available.
  final String? path;

  /// Line number in the source file where the error occurred (1-based), if available.
  final int? line;

  const FrontMatterException(this.message, {this.path, this.line});

  @override
  String toString() {
    final parts = <String>[?path, if (line != null) 'line $line'];
    final loc = parts.join(':');
    return loc.isEmpty ? 'FrontMatterException: $message' : 'FrontMatterException at $loc: $message';
  }
}

/// Reads a page's source file, extracts YAML front matter, and populates
/// [Page.frontMatter], [Page.rawContent], and [Page.isDraft].
///
/// Front matter is a YAML block delimited by `---` on its own line at the start
/// of the file. If no front matter is present, [Page.frontMatter] is an empty
/// map and [Page.rawContent] is the full file contents.
///
/// Example:
/// ```markdown
/// ---
/// title: Hello World
/// draft: false
/// ---
///
/// # Hello World
///
/// Content here.
/// ```
class FrontMatterParser {
  /// Creates a [FrontMatterParser].
  const FrontMatterParser();

  /// Parses the source file for [page], populating:
  /// - [Page.frontMatter] — YAML key/value map (empty if no front matter)
  /// - [Page.rawContent] — Markdown body after the closing `---` delimiter
  /// - [Page.isDraft] — `true` if front matter contains `draft: true`
  ///
  /// The source file is read from `path.join(contentDir, page.sourcePath)`.
  ///
  /// Throws [FrontMatterException] if the YAML is malformed or the file cannot
  /// be read.
  void parse(Page page, String contentDir) {
    final fullPath = p.join(contentDir, page.sourcePath);
    final String source;
    try {
      source = File(fullPath).readAsStringSync();
    } on IOException catch (e) {
      throw FrontMatterException('Could not read file: $e', path: fullPath);
    }

    final (frontMatter, rawContent) = _extractFrontMatter(source, fullPath);
    page.frontMatter = frontMatter;
    page.rawContent = rawContent;
    page.isDraft = frontMatter['draft'] == true;
  }
}

/// Extracts front matter and raw content from [source].
///
/// Returns a record of `(frontMatter, rawContent)`. If [source] does not begin
/// with a `---` delimiter, `frontMatter` is an empty map and `rawContent` is
/// the full source string.
(Map<String, dynamic>, String) _extractFrontMatter(String source, String path) {
  // Normalize Windows line endings to simplify delimiter detection.
  final normalized = source.replaceAll('\r\n', '\n');

  // Opening delimiter must be on the very first line.
  if (!normalized.startsWith('---\n')) {
    return ({}, source);
  }

  // Search for closing delimiter starting after the opening '---\n' (position 4).
  // Match '\n---\n' or '\n---' at end of string.
  final closingPattern = '\n---';
  final closingIndex = normalized.indexOf(closingPattern, 4);

  if (closingIndex == -1) {
    // No closing delimiter — treat entire file as raw content (graceful fallback).
    return ({}, source);
  }

  // Extract the YAML block (between opening '---\n' and closing '\n---').
  final yamlBlock = normalized.substring(4, closingIndex);

  // Raw content starts after the closing delimiter line.
  // Consume the '\n---' plus any trailing '\n'. Operate on normalized source
  // (Windows \r\n already collapsed) for correct index arithmetic.
  final afterClosing = closingIndex + closingPattern.length;
  final rawContent = afterClosing < normalized.length && normalized[afterClosing] == '\n'
      ? normalized.substring(afterClosing + 1)
      : normalized.substring(afterClosing);

  // Parse the YAML block.
  final dynamic yaml;
  try {
    yaml = loadYaml(yamlBlock);
  } on YamlException catch (e) {
    final line = e.span?.start.line != null ? e.span!.start.line + 1 : null;
    throw FrontMatterException(e.message, path: path, line: line);
  }

  if (yaml == null) {
    // Empty front matter block — valid, produce empty map.
    return ({}, rawContent);
  }

  if (yaml is! YamlMap) {
    throw FrontMatterException('Front matter must be a YAML mapping (got ${yaml.runtimeType})', path: path);
  }

  final frontMatter = convertYamlMap(yaml);
  return (frontMatter, rawContent);
}
