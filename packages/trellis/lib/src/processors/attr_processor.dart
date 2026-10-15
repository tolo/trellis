import 'package:html/dom.dart';

import '../evaluator.dart';
import '../exceptions.dart';
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

/// Shape of a runtime attribute name accepted from a `tl:attrs` map.
final _spreadNamePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_:.-]*$');

/// Applies a `tl:attrs` map to [element]. Runs before every other directive in the group, so explicit directives
/// override spread entries. Keys are validated up front so a rejected map leaves the element untouched.
void _spreadAttributes(Element element, Object? map, String attrPrefix) {
  if (map == null) return;
  if (map is! Map) {
    throw TemplateException('${attrPrefix}attrs expects a Map but got ${map.runtimeType}: $map');
  }
  final lowerPrefix = attrPrefix.toLowerCase();
  for (final key in map.keys) {
    if (key is! String || !_spreadNamePattern.hasMatch(key)) {
      throw TemplateException('${attrPrefix}attrs: illegal attribute name "$key"');
    }
    // A prefixed key would be re-read as a directive by later processor passes (see ADR-014 AC-02).
    if (key.toLowerCase().startsWith(lowerPrefix)) {
      throw TemplateException(
        '${attrPrefix}attrs: attribute name "$key" starts with the directive prefix "$attrPrefix"',
      );
    }
  }
  for (final MapEntry(:key, :value) in map.entries) {
    switch (key) {
      case 'class':
        _appendClass(element, value);
      case 'style':
        _appendStyle(element, value);
      default:
        _setAttribute(element, key as String, value);
    }
  }
}

/// Appends to the class attribute; `null` or blank is a no-op (never a removal).
void _appendClass(Element element, Object? value) {
  if (value == null) return;
  final toAppend = value.toString().trim();
  if (toAppend.isEmpty) return;
  final existing = element.attributes['class'];
  element.attributes['class'] = existing != null ? '$existing $toAppend' : toAppend;
}

/// Appends to the style attribute, `;`-separated; `null` or blank is a no-op (never a removal).
void _appendStyle(Element element, Object? value) {
  if (value == null) return;
  final toAppend = value.toString().trim();
  if (toAppend.isEmpty) return;
  final existing = element.attributes['style'];
  if (existing != null) {
    final base = existing.trimRight().endsWith(';') ? existing.trimRight() : '${existing.trimRight()};';
    element.attributes['style'] = '$base $toAppend';
  } else {
    element.attributes['style'] = toAppend;
  }
}

void _processAttributesImpl(
  Element element,
  String attrPrefix,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
) {
  // 0. tl:attrs — spread a map of attributes; first, so the directives below override it
  final attrsExpr = element.attributes['${attrPrefix}attrs'];
  if (attrsExpr != null && attrsExpr != '_') {
    _spreadAttributes(element, evaluator.evaluate(attrsExpr, context), attrPrefix);
  }

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
    _appendClass(element, evaluator.evaluate(classAppendExpr, context));
  }

  // 3. tl:styleappend — conditionally append to existing style attribute
  final styleAppendExpr = element.attributes['${attrPrefix}styleappend'];
  if (styleAppendExpr != null && styleAppendExpr != '_') {
    _appendStyle(element, evaluator.evaluate(styleAppendExpr, context));
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
  if (element.attributes.containsKey('${attrPrefix}attrs')) return true;
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
