import 'package:html/dom.dart';

import '../evaluator.dart';

/// Processes `tl:object` selection scope.
/// Returns the context augmented with the selection object.
Map<String, dynamic> processObject(
  Element element,
  String attrPrefix,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
) {
  final objectExpr = element.attributes['${attrPrefix}object'];
  if (objectExpr == null) return context;

  final value = evaluator.evaluate(objectExpr, context);
  return {...context, ExpressionEvaluator.selectionKey: value};
}
