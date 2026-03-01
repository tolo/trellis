import 'package:html/dom.dart';

import '../evaluator.dart';
import '../exceptions.dart';

/// Known mode keywords — checked before expression evaluation.
const _modeKeywords = {'all', 'body', 'tag', 'all-but-first', 'none'};

/// Processes `tl:remove` attribute.
/// Returns `true` if the element was removed from DOM (caller should stop
/// further processing); `false` otherwise.
bool processRemove(Element element, String attrPrefix, ExpressionEvaluator evaluator, Map<String, dynamic> context) {
  final removeExpr = element.attributes['${attrPrefix}remove'];
  if (removeExpr == null) return false;

  // Keyword-first: treat known mode names directly without expression eval
  final String mode;
  if (_modeKeywords.contains(removeExpr)) {
    mode = removeExpr;
  } else {
    final value = evaluator.evaluate(removeExpr, context);
    mode = value?.toString() ?? '';
  }

  switch (mode) {
    case 'all':
      element.remove();
      return true;

    case 'body':
      element.nodes.clear();
      return false;

    case 'tag':
      final parent = element.parentNode;
      if (parent != null) {
        for (final child in List<Node>.from(element.nodes)) {
          parent.insertBefore(child, element);
        }
        element.remove();
      }
      return true;

    case 'all-but-first':
      final children = element.children;
      if (children.isNotEmpty) {
        final firstChild = children.first;
        var foundFirst = false;
        for (final node in List<Node>.from(element.nodes)) {
          if (node == firstChild) {
            foundFirst = true;
            continue;
          }
          if (foundFirst) {
            node.remove();
          }
        }
      }
      return false;

    case 'none':
      return false;

    default:
      throw TemplateException('Invalid tl:remove value: "$mode"');
  }
}
