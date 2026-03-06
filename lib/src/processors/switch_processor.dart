import 'package:html/dom.dart';

import '../processor_api.dart';

/// Processor class for `tl:switch` — multi-branch conditional.
class SwitchProcessor extends Processor {
  @override
  String get attribute => 'switch';

  @override
  ProcessorPriority get priority => ProcessorPriority.highest;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final switchValue = context.evaluate(value, context.variables);
    final switchStr = switchValue.toString();

    Element? defaultChild;
    var matched = false;

    for (final child in List<Element>.from(element.children)) {
      final caseValue = child.attributes['${context.attrPrefix}case'];
      if (caseValue == null) continue;

      if (caseValue == '*') {
        if (defaultChild == null) {
          defaultChild = child;
        } else {
          child.remove();
        }
        continue;
      }

      if (!matched && caseValue == switchStr) {
        matched = true;
        child.attributes.remove('${context.attrPrefix}case');
      } else {
        child.remove();
      }
    }

    if (!matched && defaultChild != null) {
      defaultChild.attributes.remove('${context.attrPrefix}case');
    } else if (defaultChild != null) {
      defaultChild.remove();
    }

    return true;
  }
}
