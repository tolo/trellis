import 'package:html/dom.dart';

import '../evaluator.dart';
import '../truthiness.dart';

/// Processes `tl:if` and `tl:unless` conditional attributes.
/// Returns `true` if the element should be kept, `false` if removed.
bool processCondition(Element element, String attrPrefix, ExpressionEvaluator evaluator, Map<String, dynamic> context) {
  final ifExpr = element.attributes['${attrPrefix}if'];
  if (ifExpr != null) {
    final value = evaluator.evaluate(ifExpr, context);
    if (!isTruthy(value)) {
      element.remove();
      return false;
    }
  }

  final unlessExpr = element.attributes['${attrPrefix}unless'];
  if (unlessExpr != null) {
    final value = evaluator.evaluate(unlessExpr, context);
    if (isTruthy(value)) {
      element.remove();
      return false;
    }
  }

  return true;
}
