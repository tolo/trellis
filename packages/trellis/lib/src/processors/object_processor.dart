import 'package:html/dom.dart';

import '../evaluator.dart';
import '../processor_api.dart';

/// Processor class for `tl:object` — context-modifying processor.
class ObjectProcessor extends Processor {
  @override
  String get attribute => 'object';

  @override
  ProcessorPriority get priority => .highest;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final result = context.evaluate(value, context.variables);
    context.variables = {...context.variables, ExpressionEvaluator.selectionKey: result};
    return true;
  }
}
