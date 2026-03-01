import 'package:html/dom.dart';

import '../evaluator.dart';
import '../exceptions.dart';
import '../utils/binding_parser.dart' show findTopLevelDelimiter;

/// Processes `tl:each` iteration attribute.
/// Returns `true` if `tl:each` was present and handled (element was replicated).
bool processEach(
  Element element,
  String attrPrefix,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
  void Function(Element, Map<String, dynamic>) processCallback,
) {
  final attrValue = element.attributes['${attrPrefix}each'];
  if (attrValue == null) return false;

  // Parse: "item : ${collection}" or "item, stat : ${collection}"
  final colonIndex = findTopLevelDelimiter(attrValue, ':');
  if (colonIndex == -1) {
    throw TemplateException('Invalid tl:each syntax: "$attrValue". Expected "item : \${collection}".');
  }

  final leftSide = attrValue.substring(0, colonIndex).trim();
  final collectionExpr = attrValue.substring(colonIndex + 1).trim();
  if (leftSide.isEmpty || collectionExpr.isEmpty) {
    throw TemplateException('Invalid tl:each syntax: "$attrValue". Expected "item : \${collection}".');
  }

  // Parse left side for item var and optional status var
  late final String itemVar;
  late final String statVar;
  if (leftSide.contains(',')) {
    final parts = leftSide.split(',').map((part) => part.trim()).toList();
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw TemplateException('Invalid tl:each syntax: "$attrValue". Expected "item, stat : \${collection}".');
    }
    itemVar = parts[0];
    statVar = parts[1];
  } else {
    itemVar = leftSide;
    statVar = '${itemVar}Stat';
  }

  // Evaluate collection expression
  final result = evaluator.evaluate(collectionExpr, context);

  // Convert to list of items
  final List<dynamic> items;
  if (result is Map) {
    items = result.entries.map<Map<String, dynamic>>((e) => {'key': e.key, 'value': e.value}).toList();
  } else if (result is Iterable) {
    items = result.toList();
  } else {
    throw TemplateException('tl:each requires an Iterable or Map, got ${result.runtimeType}.');
  }

  // Empty collection: remove element entirely
  if (items.isEmpty) {
    element.remove();
    return true;
  }

  final total = items.length;
  final parent = element.parent!;

  for (var i = 0; i < total; i++) {
    final item = items[i];
    final statusMap = <String, dynamic>{
      'index': i,
      'count': i + 1,
      'size': total,
      'current': item,
      'first': i == 0,
      'last': i == total - 1,
      'odd': i.isOdd,
      'even': i.isEven,
    };

    final scopedContext = {...context, itemVar: item, statVar: statusMap};

    final clone = element.clone(true);
    clone.attributes.remove('${attrPrefix}each');
    parent.insertBefore(clone, element);
    processCallback(clone, scopedContext);
  }

  // Remove the original template element
  element.remove();
  return true;
}
