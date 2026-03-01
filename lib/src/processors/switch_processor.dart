import 'package:html/dom.dart';

import '../evaluator.dart';
import '../exceptions.dart';

/// Processes `tl:switch` / `tl:case` multi-branch conditional.
///
/// On the parent element: evaluates `tl:switch` expression, keeps only the
/// first matching `tl:case` child (or `tl:case="*"` default). Non-case
/// children are preserved. Throws if `tl:case` is found outside `tl:switch`.
void processSwitch(Element element, String attrPrefix, ExpressionEvaluator evaluator, Map<String, dynamic> context) {
  // Orphan tl:case detection — if this element has tl:case but was not
  // processed by a parent's tl:switch, it's an error
  if (element.attributes.containsKey('${attrPrefix}case')) {
    throw TemplateException('tl:case found outside tl:switch context');
  }

  final switchExpr = element.attributes['${attrPrefix}switch'];
  if (switchExpr == null) return;

  final switchValue = evaluator.evaluate(switchExpr, context);
  final switchStr = switchValue.toString();

  Element? defaultChild;
  var matched = false;

  // Snapshot children to handle DOM mutations during iteration
  for (final child in List<Element>.from(element.children)) {
    final caseValue = child.attributes['${attrPrefix}case'];
    if (caseValue == null) continue; // non-case child — leave it

    if (caseValue == '*') {
      if (defaultChild == null) {
        defaultChild = child;
      } else {
        // Duplicate default — remove extras
        child.remove();
      }
      continue;
    }

    if (!matched && caseValue == switchStr) {
      matched = true;
      child.attributes.remove('${attrPrefix}case');
    } else {
      child.remove();
    }
  }

  // Handle default: keep if no match, remove if match found
  if (!matched && defaultChild != null) {
    defaultChild.attributes.remove('${attrPrefix}case');
  } else if (defaultChild != null) {
    defaultChild.remove();
  }
}
