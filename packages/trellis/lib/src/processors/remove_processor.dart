import 'package:html/dom.dart';

import '../exceptions.dart';
import '../processor_api.dart';

/// Known mode keywords — checked before expression evaluation.
const _modeKeywords = {'all', 'body', 'tag', 'all-but-first', 'none'};

/// Shared implementation for remove mode resolution and execution.
bool _executeRemoveMode(Element element, String value, ProcessorContext context) {
  final String mode;
  if (_modeKeywords.contains(value)) {
    mode = value;
  } else {
    final result = context.evaluate(value, context.variables);
    mode = result?.toString() ?? '';
  }

  switch (mode) {
    case 'all':
      element.remove();
      return false; // element removed

    case 'body':
      element.nodes.clear();
      return true; // element remains

    case 'tag':
      final parent = element.parentNode;
      if (parent != null) {
        for (final child in List<Node>.from(element.nodes)) {
          parent.insertBefore(child, element);
        }
        element.remove();
      }
      return false; // element removed

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
      return true; // element remains

    case 'none':
      return true; // element remains

    default:
      throw TemplateException('Invalid tl:remove value: "$mode"');
  }
}

/// Processor class for `tl:remove` — element/content removal.
class RemoveProcessor extends Processor {
  @override
  String get attribute => 'remove';

  @override
  ProcessorPriority get priority => .afterAttributes;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    return _executeRemoveMode(element, value, context);
  }
}
