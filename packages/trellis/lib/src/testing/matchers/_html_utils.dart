import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Parses an HTML string into a [DocumentFragment] for CSS selector queries.
///
/// Uses `parseFragment` which handles both full documents and partial HTML.
DocumentFragment parseHtml(String html) {
  return html_parser.parseFragment(html);
}
