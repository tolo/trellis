import 'package:highlight/highlight.dart' as hljs;
import 'package:highlight/languages/all.dart' show allLanguages;
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;

/// Configuration for build-time syntax highlighting.
///
/// Parsed from the `highlight:` section of `trellis_site.yaml` (mirrors the
/// `search:` → [SearchConfig] pattern). Highlighting is on by default (ADR-010):
///
/// ```yaml
/// highlight:
///   enabled: false   # opt out; omit the block entirely to keep it on
/// ```
class HighlightConfig {
  /// Whether fenced code blocks are highlighted at build time. Default: `true`.
  final bool enabled;

  const HighlightConfig({this.enabled = true});

  /// Parses a [HighlightConfig] from a YAML map.
  ///
  /// Returns the default (enabled) config when [map] is `null` (no `highlight:`
  /// block present). Honors an explicit `enabled: false`; any other value for
  /// `enabled` (including its absence) leaves highlighting on.
  factory HighlightConfig.fromYaml(Map<String, dynamic>? map) {
    if (map == null) return const HighlightConfig();
    return HighlightConfig(enabled: map['enabled'] != false);
  }
}

/// Colors fenced Markdown code blocks server-side, emitting highlight.js
/// `.hljs-*` spans into rendered HTML (ADR-010).
///
/// Given a rendered-Markdown HTML fragment, [highlightHtml] finds each
/// `<pre><code class="language-<lang>">` whose `<lang>` is a language (or alias)
/// `package:highlight` recognizes, tokenizes its source, and replaces **only**
/// that `<code>`'s inner HTML with the `.hljs-*` spans. Blocks without a
/// `language-*` class, and blocks whose language is unrecognized, are left
/// untouched — no crash, no lost markup.
///
/// ## Why the offset-splice, not a DOM re-serialize
///
/// `MarkdownRenderer` output is an HTML **fragment**, not a document. Parsing it
/// and re-serializing the whole tree would normalize non-code markup (e.g.
/// `<br />` → `<br>`, attribute reordering), corrupting the page. So the DOM is
/// used only to *locate and decode* — each `<code>`'s inner byte-range is spliced
/// back into the original string, leaving every byte of surrounding markup
/// verbatim. Requires `generateSpans: true` on the parse.
///
/// ## Why validate the language first
///
/// `highlight.parse` does **not** throw on an unknown language: it silently falls
/// back to plaintext while echoing the bad string via `Result.language`. So the
/// fence language is checked against the known name + alias set before tokenizing;
/// `result.language` is never trusted. Auto-detection is never used (slow, a
/// guess, and it triggers a debug `print()` in the package's hot path).
class CodeHighlighter {
  const CodeHighlighter();

  /// The lowercased set of every language name and alias `package:highlight`
  /// recognizes. Built once; the global `hljs.highlight` instance is
  /// pre-registered with `allLanguages`.
  static final Set<String> _knownLanguages = _buildKnownLanguages();

  static Set<String> _buildKnownLanguages() {
    final names = <String>{};
    for (final entry in allLanguages.entries) {
      names.add(entry.key.toLowerCase());
      for (final alias in entry.value.aliases ?? const <String>[]) {
        names.add(alias.toLowerCase());
      }
    }
    return names;
  }

  /// Returns [html] with every recognized-language fenced code block replaced by
  /// highlight.js `.hljs-*` spans. Non-code markup is byte-for-byte preserved.
  ///
  /// Fenceless and unknown-language blocks pass through untouched. Returns [html]
  /// unchanged when it contains no `language-*` code blocks.
  String highlightHtml(String html) {
    // Cheap pre-check: markdown emits `class="language-<lang>"` only for fenced
    // blocks with an info string, so no substring means nothing to highlight.
    if (html.isEmpty || !html.contains('language-')) return html;

    final fragment = parseFragment(html, generateSpans: true);
    final codeNodes = fragment.querySelectorAll('pre > code');
    if (codeNodes.isEmpty) return html;

    // Each recognized block yields a splice over the original string. Applied
    // last-offset-first so earlier splices never shift later offsets.
    final splices = <_Splice>[];
    for (final code in codeNodes) {
      final language = _languageOf(code);
      if (language == null || !_knownLanguages.contains(language)) continue;

      final openTag = code.sourceSpan;
      final closeTag = code.endSourceSpan;
      if (openTag == null || closeTag == null) continue;

      // node.text decodes entities and drops tags → the raw fenced source.
      // `package:highlight` is stale (ADR-010 Risks): a grammar for a recognized
      // language may throw on pathological input. Contain it per block — a single
      // block that fails to tokenize is left plain, never aborting the whole build.
      final String highlighted;
      try {
        highlighted = hljs.highlight.parse(code.text, language: language).toHtml();
      } on Object {
        continue;
      }
      splices.add(_Splice(openTag.end.offset, closeTag.start.offset, highlighted));
    }
    if (splices.isEmpty) return html;

    splices.sort((a, b) => b.start.compareTo(a.start));
    var result = html;
    for (final splice in splices) {
      result = result.replaceRange(splice.start, splice.end, splice.replacement);
    }
    return result;
  }

  /// The lowercased fence language of [code] (from its `language-<lang>` class),
  /// or `null` when the block carries no `language-*` class.
  String? _languageOf(Element code) {
    for (final className in code.classes) {
      if (className.startsWith('language-')) {
        final language = className.substring('language-'.length).toLowerCase();
        return language.isEmpty ? null : language;
      }
    }
    return null;
  }
}

/// A single inner-HTML replacement over a range of the original HTML string.
class _Splice {
  /// Offset just after the opening `<code …>` tag.
  final int start;

  /// Offset of the `<` in the closing `</code>` tag.
  final int end;

  /// The `.hljs-*` HTML to write between [start] and [end].
  final String replacement;

  const _Splice(this.start, this.end, this.replacement);
}
