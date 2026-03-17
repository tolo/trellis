import 'dart:io';

import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:trellis/trellis.dart';

import 'page.dart';
import 'trellis_site_builder.dart' show BuildWarning;

// ---------------------------------------------------------------------------
// Regex patterns
// ---------------------------------------------------------------------------

/// Matches a content shortcode with opening tag, inner content, and closing tag.
///
/// Pattern: `{{% name key="val" %}} inner content {{% /name %}}`
/// Groups: 1=name, 2=params string, 3=inner content
/// Must be matched before [_selfClosingPattern] to avoid partial matches.
final _contentPattern = RegExp(
  r"""\{\{%\s*(\w+)((?:\s+\w+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*%\}\}(.*?)\{\{%\s*/\1\s*%\}\}""",
  dotAll: true,
);

/// Matches a self-closing shortcode.
///
/// Pattern: `{{% name key="val" %}}`
/// Groups: 1=name, 2=params string
final _selfClosingPattern = RegExp(
  r"""\{\{%\s*(\w+)((?:\s+\w+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*%\}\}""",
);

/// Matches an HTML comment shortcode (post-Markdown).
///
/// Pattern: `<!-- tl:name key="val" -->`
/// Groups: 1=name, 2=params string
final _htmlCommentPattern = RegExp(
  r"""<!--\s*tl:(\w+)((?:\s+\w+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*-->""",
);

/// Matches individual key="value" or key='value' param pairs.
///
/// Groups: 1=key, 2=double-quoted value (or null), 3=single-quoted value (or null)
final _paramPattern = RegExp(r"""(\w+)\s*=\s*(?:"([^"]*)"|'([^']*)')""");

// ---------------------------------------------------------------------------
// Param parsing
// ---------------------------------------------------------------------------

/// Parses a shortcode params string into a `Map<String, dynamic>`.
///
/// Example input: ` id="abc123" title="Hello World"` → `{id: "abc123", title: "Hello World"}`.
Map<String, dynamic> _parseParams(String paramsStr) {
  final result = <String, dynamic>{};
  for (final match in _paramPattern.allMatches(paramsStr)) {
    final key = match.group(1)!;
    // Group 2 is double-quoted value, group 3 is single-quoted value
    final value = match.group(2) ?? match.group(3) ?? '';
    result[key] = value;
  }
  return result;
}

// ---------------------------------------------------------------------------
// ShortcodeProcessor
// ---------------------------------------------------------------------------

/// Processes shortcodes in page content, resolving them to rendered
/// Trellis fragment templates.
///
/// Two syntaxes are supported:
/// - **Pre-Markdown** (`{{% name key="value" %}}`): processed in
///   [Page.rawContent] before Markdown rendering via [processPreMarkdown].
/// - **Post-Markdown** (`<!-- tl:name key="value" -->`): processed in
///   [Page.content] after Markdown rendering via [processPostMarkdown].
///
/// Shortcode templates live at `{siteDir}/layouts/shortcodes/{name}.html`.
/// Missing templates emit a [BuildWarning] and preserve the raw shortcode text.
///
/// Example:
/// ```dart
/// final processor = ShortcodeProcessor(siteDir: '/path/to/site');
/// processor.processPreMarkdown(page);
/// mdRenderer.render(page);
/// processor.processPostMarkdown(page);
/// buildResult.warnings.addAll(processor.warnings);
/// ```
class ShortcodeProcessor {
  /// The site root directory (parent of `layouts/`).
  final String siteDir;

  /// Non-fatal warnings accumulated during shortcode processing.
  final List<BuildWarning> warnings = [];

  late final Trellis _engine;
  late final String _shortcodesDir;

  /// Creates a [ShortcodeProcessor] for the site at [siteDir].
  ShortcodeProcessor({required this.siteDir}) {
    _engine = Trellis(loader: FileSystemLoader(siteDir));
    _shortcodesDir = p.join(siteDir, 'layouts', 'shortcodes');
  }

  /// Processes `{{% ... %}}` shortcodes in [page.rawContent].
  ///
  /// Content shortcodes are matched first (before self-closing) to avoid
  /// matching only the opening tag. Updates [page.rawContent] in place.
  ///
  /// Must be called BEFORE [MarkdownRenderer.render].
  void processPreMarkdown(Page page) {
    if (page.rawContent.isEmpty) return;
    if (!Directory(_shortcodesDir).existsSync()) return;

    var content = page.rawContent;

    // Step 1: match content shortcodes first (opening + inner content + closing)
    content = content.replaceAllMapped(_contentPattern, (match) {
      final name = match.group(1)!;
      final paramsStr = match.group(2) ?? '';
      final innerContent = (match.group(3) ?? '').trim();
      final params = _parseParams(paramsStr);
      // Render inner content as Markdown and inject as ${content}
      params['content'] = md.markdownToHtml(innerContent, extensionSet: md.ExtensionSet.gitHubWeb);
      return _renderShortcode(name, params) ?? match.group(0)!;
    });

    // Step 2: match remaining self-closing shortcodes
    content = content.replaceAllMapped(_selfClosingPattern, (match) {
      final name = match.group(1)!;
      final paramsStr = match.group(2) ?? '';
      final params = _parseParams(paramsStr);
      return _renderShortcode(name, params) ?? match.group(0)!;
    });

    page.rawContent = content;
  }

  /// Processes `<!-- tl:name ... -->` shortcodes in [page.content].
  ///
  /// Must be called AFTER [MarkdownRenderer.render].
  void processPostMarkdown(Page page) {
    if (page.content.isEmpty) return;
    if (!Directory(_shortcodesDir).existsSync()) return;

    page.content = page.content.replaceAllMapped(_htmlCommentPattern, (match) {
      final name = match.group(1)!;
      final paramsStr = match.group(2) ?? '';
      final params = _parseParams(paramsStr);
      return _renderShortcode(name, params) ?? match.group(0)!;
    });
  }

  /// Renders the shortcode template for [name] with [params] as context.
  ///
  /// Returns the rendered HTML on success, or `null` on failure (missing
  /// template or render error). Appends a [BuildWarning] on failure.
  String? _renderShortcode(String name, Map<String, dynamic> params) {
    final templateFile = File(p.join(_shortcodesDir, '$name.html'));
    if (!templateFile.existsSync()) {
      warnings.add(BuildWarning(
        'Shortcode template not found: $name',
        context: 'layouts/shortcodes/$name.html',
      ));
      return null;
    }

    try {
      final source = templateFile.readAsStringSync();
      return _engine.render(source, params);
    } on Object catch (e) {
      warnings.add(BuildWarning(
        'Shortcode render error for "$name": $e',
        context: 'layouts/shortcodes/$name.html',
      ));
      return null;
    }
  }
}
