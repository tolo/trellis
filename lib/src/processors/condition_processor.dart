import 'package:html/dom.dart';

import '../processor_api.dart';
import '../truthiness.dart';

/// Processor class for `tl:if` — conditional rendering.
class IfProcessor extends Processor {
  @override
  String get attribute => 'if';

  @override
  ProcessorPriority get priority => ProcessorPriority.highest;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final result = context.evaluate(value, context.variables);
    if (!isTruthy(result)) {
      element.remove();
      return false;
    }
    return true;
  }
}

/// Processor class for `tl:unless` — inverse conditional rendering.
class UnlessProcessor extends Processor {
  @override
  String get attribute => 'unless';

  @override
  ProcessorPriority get priority => ProcessorPriority.highest;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final result = context.evaluate(value, context.variables);
    if (isTruthy(result)) {
      element.remove();
      return false;
    }
    return true;
  }
}
