import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../processor_api.dart';

/// Processor class for `tl:text` — escaped content substitution.
class TextProcessor extends Processor {
  @override
  String get attribute => 'text';

  @override
  ProcessorPriority get priority => .afterInclusion;

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
  ProcessorPriority get priority => .afterInclusion;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    // tl:text wins over tl:utext, and `_` is a no-op: either way the element keeps template content, which the
    // engine processes as usual.
    if (element.attributes.containsKey('${context.attrPrefix}text') || value == '_') return true;

    final result = context.evaluate(value, context.variables);
    final text = result?.toString() ?? '';
    element.nodes.clear();
    if (text.isNotEmpty) {
      final fragment = html_parser.parseFragment(text);
      element.nodes.addAll(fragment.nodes.toList());
    }
    // The inserted value is output, not template code: processing its `tl:*` attributes would let any HTML that
    // reaches `tl:utext` read the render context and include other templates. Opting out only here, not for the
    // whole processor, leaves the element's other subtree owners (e.g. `tl:insert`) to decide for the kept content.
    context.skipChildRecursion();
    return true;
  }
}
