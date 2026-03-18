import 'package:html/parser.dart' as html_parser;

/// Normalizes rendered HTML for stable snapshot comparison.
///
/// Parses the HTML string through `package:html` and re-serializes it.
/// This produces consistent whitespace and attribute ordering, preventing
/// spurious snapshot failures from insignificant formatting differences.
///
/// Trailing newline is appended if not present, ensuring consistent file endings.
String normalizeHtml(String html) {
  final doc = html_parser.parseFragment(html);
  var normalized = doc.outerHtml;
  if (!normalized.endsWith('\n')) {
    normalized = '$normalized\n';
  }
  return normalized;
}
