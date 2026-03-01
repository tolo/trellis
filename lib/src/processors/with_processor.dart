import 'package:html/dom.dart';

import '../evaluator.dart';
import '../utils/binding_parser.dart';

/// Processes `tl:with` local variable binding.
/// Returns the (potentially augmented) context map.
Map<String, dynamic> processWith(
  Element element,
  String attrPrefix,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
) {
  final withExpr = element.attributes['${attrPrefix}with'];
  if (withExpr == null) return context;

  final bindings = parseBindings(withExpr);
  final newContext = {...context};
  for (final (name, expression) in bindings) {
    newContext[name] = evaluator.evaluate(expression, newContext);
  }
  return newContext;
}
