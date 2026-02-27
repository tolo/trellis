import 'package:html/dom.dart';

import '../evaluator.dart';
import '../utils/binding_parser.dart';

/// Standard HTML boolean attributes — `true` renders valueless, `false` removes.
const _booleanHtmlAttrs = {
  'disabled',
  'checked',
  'readonly',
  'selected',
  'hidden',
  'required',
  'multiple',
  'autofocus',
  'autoplay',
  'controls',
  'loop',
  'muted',
  'defer',
  'async',
  'novalidate',
  'formnovalidate',
  'open',
  'reversed',
};

/// Shorthand attribute names mapped by `tl:$name` → HTML `$name`.
const _shorthands = ['href', 'src', 'value', 'class', 'id'];

/// Processes `tl:attr`, `tl:href`, `tl:src`, `tl:value`, `tl:class`,
/// and `tl:id` attribute mutations.
void processAttributes(Element element, String prefix, ExpressionEvaluator evaluator, Map<String, dynamic> context) {
  // 1. Shorthand attributes
  for (final name in _shorthands) {
    final expr = element.attributes['$prefix:$name'];
    if (expr != null) {
      final value = evaluator.evaluate(expr, context);
      _setAttribute(element, name, value);
    }
  }

  // 2. tl:classappend — conditionally append to existing class attribute
  final classAppendExpr = element.attributes['$prefix:classappend'];
  if (classAppendExpr != null) {
    final value = evaluator.evaluate(classAppendExpr, context);
    if (value != null) {
      final toAppend = value.toString().trim();
      if (toAppend.isNotEmpty) {
        final existing = element.attributes['class'];
        element.attributes['class'] = existing != null ? '$existing $toAppend' : toAppend;
      }
    }
  }

  // 3. tl:attr — multi-attribute
  final attrExpr = element.attributes['$prefix:attr'];
  if (attrExpr != null) {
    final bindings = parseBindings(attrExpr);
    for (final (name, expression) in bindings) {
      final value = evaluator.evaluate(expression, context);
      _setAttribute(element, name, value);
    }
  }
}

void _setAttribute(Element element, String attrName, dynamic value) {
  if (value == null) {
    element.attributes.remove(attrName);
  } else if (_booleanHtmlAttrs.contains(attrName)) {
    if (value == true) {
      element.attributes[attrName] = '';
    } else if (value == false) {
      element.attributes.remove(attrName);
    } else {
      element.attributes[attrName] = value.toString();
    }
  } else {
    element.attributes[attrName] = value.toString();
  }
}
