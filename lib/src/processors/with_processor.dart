import 'package:html/dom.dart';

import '../processor_api.dart';
import '../utils/binding_parser.dart';

/// Processor class for `tl:with` — context-modifying processor.
class WithProcessor extends Processor {
  @override
  String get attribute => 'with';

  @override
  ProcessorPriority get priority => .highest;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final bindings = parseBindings(value);
    final newContext = {...context.variables};
    for (final (name, expression) in bindings) {
      newContext[name] = context.evaluate(expression, newContext);
    }
    context.variables = newContext;
    return true;
  }
}
