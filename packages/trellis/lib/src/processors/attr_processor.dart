import 'package:html/dom.dart';

import '../evaluator.dart';
import '../processor_api.dart';
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
const _shorthands = {'href', 'src', 'value', 'class', 'id'};

/// Attributes known to contain URLs — values from `@{}` expressions are
/// percent-encoded via `Uri.encodeComponent()` (RFC 3986) at the evaluator
/// layer. Plain `${var}` values are assumed pre-built and are not re-encoded.
// ignore: unused_element
const _urlAttributes = {'href', 'src', 'action', 'formaction', 'poster', 'data'};

void _processAttributesImpl(
  Element element,
  String attrPrefix,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
) {
  // 1. Shorthand attributes
  for (final name in _shorthands) {
    final expr = element.attributes['$attrPrefix$name'];
    if (expr != null) {
      if (expr == '_') continue; // no-op sentinel
      final value = evaluator.evaluate(expr, context);
      _setAttribute(element, name, value);
    }
  }

  // 2. tl:classappend — conditionally append to existing class attribute
  final classAppendExpr = element.attributes['${attrPrefix}classappend'];
  if (classAppendExpr != null && classAppendExpr != '_') {
    final value = evaluator.evaluate(classAppendExpr, context);
    if (value != null) {
      final toAppend = value.toString().trim();
      if (toAppend.isNotEmpty) {
        final existing = element.attributes['class'];
        element.attributes['class'] = existing != null ? '$existing $toAppend' : toAppend;
      }
    }
  }

  // 3. tl:styleappend — conditionally append to existing style attribute
  final styleAppendExpr = element.attributes['${attrPrefix}styleappend'];
  if (styleAppendExpr != null && styleAppendExpr != '_') {
    final value = evaluator.evaluate(styleAppendExpr, context);
    if (value != null) {
      final toAppend = value.toString().trim();
      if (toAppend.isNotEmpty) {
        final existing = element.attributes['style'];
        if (existing != null) {
          final base = existing.trimRight().endsWith(';') ? existing.trimRight() : '${existing.trimRight()};';
          element.attributes['style'] = '$base $toAppend';
        } else {
          element.attributes['style'] = toAppend;
        }
      }
    }
  }

  // 4. tl:attr — multi-attribute
  final attrExpr = element.attributes['${attrPrefix}attr'];
  if (attrExpr != null && attrExpr != '_') {
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

/// Returns true if the element has any attribute-related tl:* attributes.
bool hasAttrAttributes(Element element, String attrPrefix) {
  if (element.attributes.containsKey('${attrPrefix}attr')) return true;
  if (element.attributes.containsKey('${attrPrefix}classappend')) return true;
  if (element.attributes.containsKey('${attrPrefix}styleappend')) return true;
  for (final name in _shorthands) {
    if (element.attributes.containsKey('$attrPrefix$name')) return true;
  }
  return false;
}

/// Processor class for `tl:attr` and related attributes — attribute mutation.
class AttrProcessor extends Processor {
  @override
  String get attribute => 'attr';

  @override
  ProcessorPriority get priority => .afterContent;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    _processAttributesImpl(element, context.attrPrefix, context.evaluator, context.variables);
    return true;
  }
}
