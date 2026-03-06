import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../processor_api.dart';

/// Processor class for `tl:text` — escaped content substitution.
class TextProcessor extends Processor {
  @override
  String get attribute => 'text';

  @override
  ProcessorPriority get priority => ProcessorPriority.afterInclusion;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    if (value == '_') return true; // no-op sentinel
    final result = context.evaluate(value, context.variables);
    final text = result?.toString() ?? '';
    element.nodes
      ..clear()
      ..add(Text(text));
    return true;
  }
}

/// Processor class for `tl:utext` — unescaped (raw HTML) content substitution.
class UtextProcessor extends Processor {
  @override
  String get attribute => 'utext';

  @override
  ProcessorPriority get priority => ProcessorPriority.afterInclusion;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    // tl:text wins over tl:utext — if tl:text is also present, skip
    if (element.attributes.containsKey('${context.attrPrefix}text')) return true;

    if (value == '_') return true; // no-op sentinel
    final result = context.evaluate(value, context.variables);
    final text = result?.toString() ?? '';
    element.nodes.clear();
    if (text.isNotEmpty) {
      final fragment = html_parser.parseFragment(text);
      element.nodes.addAll(fragment.nodes.toList());
    }
    return true;
  }
}
