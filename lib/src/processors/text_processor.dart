import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../evaluator.dart';

/// Processes `tl:text` (escaped) and `tl:utext` (unescaped) attributes.
void processText(Element element, String prefix, ExpressionEvaluator evaluator, Map<String, dynamic> context) {
  final textExpr = element.attributes['$prefix:text'];
  if (textExpr != null) {
    final value = evaluator.evaluate(textExpr, context);
    final text = value?.toString() ?? '';
    // Text node auto-escapes <>&" on serialization via package:html
    element.nodes
      ..clear()
      ..add(Text(text));
    return; // tl:text wins over tl:utext if both present
  }

  final utextExpr = element.attributes['$prefix:utext'];
  if (utextExpr != null) {
    final value = evaluator.evaluate(utextExpr, context);
    final text = value?.toString() ?? '';
    element.nodes.clear();
    if (text.isNotEmpty) {
      final fragment = html_parser.parseFragment(text);
      element.nodes.addAll(fragment.nodes.toList());
    }
  }
}
