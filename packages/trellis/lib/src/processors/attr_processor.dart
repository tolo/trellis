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

/// Every `tl:*` directive the attribute group evaluates, so detection and capture-time stripping share one list.
const _groupDirectives = {'attrs', 'attr', 'classappend', 'styleappend', ..._shorthands};

/// Attributes known to contain URLs — values from `@{}` expressions are
/// percent-encoded via `Uri.encodeComponent()` (RFC 3986) at the evaluator
/// layer. Plain `${var}` values are assumed pre-built and are not re-encoded.
// ignore: unused_element
const _urlAttributes = {'href', 'src', 'action', 'formaction', 'poster', 'data'};

/// Whether [name] is an HTML attribute name (WHATWG "attribute name" state): non-empty, and no ASCII whitespace,
/// control character, `"`, `'`, `>`, `/`, `=` or noncharacter. Shorthands such as `@click`, `:class` and `_` qualify,
/// which is why the Alpine/hyperscript names a parser produces pass when a `...rest` map is forwarded through
/// `tl:attrs`. A name the parser accepts but this rule does not (`x"y`) still throws.
bool _isAttributeName(String name) {
  if (name.isEmpty) return false;
  for (final c in name.runes) {
    final illegal =
        c <= 0x20 ||
        (c >= 0x7F && c <= 0x9F) ||
        c == 0x22 || // "
        c == 0x27 || // '
        c == 0x3E || // >
        c == 0x2F || // /
        c == 0x3D || // =
        (c >= 0xFDD0 && c <= 0xFDEF) ||
        (c & 0xFFFE) == 0xFFFE;
    if (illegal) return false;
  }
  return true;
}

int _foldAscii(int c) => c >= 0x41 && c <= 0x5A ? c + 0x20 : c;

bool _sameNameIgnoringAsciiCase(String a, String b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (_foldAscii(a.codeUnitAt(i)) != _foldAscii(b.codeUnitAt(i))) return false;
  }
  return true;
}

/// Removes every attribute whose name equals [name] ignoring ASCII case but is not [name] itself, and returns the first
/// removed value. HTML attribute names are case-insensitive and the tokenizer keeps the first of two duplicates, so a
/// stale `HREF` written earlier would otherwise shadow the `href` written later; the later write must win. A foreign
/// attribute (an `AttributeName` key such as `xlink:href` on SVG) matches by its qualified `prefix:local` name.
String? _dropCaseVariants(Element element, String name) {
  String? dropped;
  for (final key in element.attributes.keys.toList()) {
    final qualified = switch (key) {
      String() => key,
      AttributeName(:final prefix, :final name) => prefix == null ? name : '$prefix:$name',
      _ => null,
    };
    if (qualified != null && key != name && _sameNameIgnoringAsciiCase(qualified, name)) {
      final value = element.attributes.remove(key);
      dropped ??= value;
    }
  }
  return dropped;
}

/// Applies a `tl:attrs` map to [element]. Runs before every other directive in the group, so explicit directives
/// override spread entries. Keys are validated up front so a rejected map leaves the element untouched.
void _spreadAttributes(Element element, Object? map, String attrPrefix) {
  if (map == null) return;
  if (map is! Map) {
    throw TemplateException('${attrPrefix}attrs expects a Map but got ${map.runtimeType}');
  }
  final lowerPrefix = attrPrefix.toLowerCase();
  for (final key in map.keys) {
    if (key is! String || !_isAttributeName(key)) {
      throw TemplateException('${attrPrefix}attrs: illegal attribute name "$key"');
    }
    // A prefixed key would be re-read as a directive by later processor passes (ADR-014 §2).
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

/// Current value of [name], or `null` when absent or blank (a blank literal behaves like an absent one). A case-variant
/// spelling written earlier in the pass counts as the same attribute.
String? _nonBlankValue(Element element, String name) {
  final variant = _dropCaseVariants(element, name);
  final value = element.attributes[name] ?? variant;
  return value == null || value.trim().isEmpty ? null : value;
}

/// Appends to the class attribute; `null` or blank is a no-op (never a removal).
void _appendClass(Element element, Object? value) {
  if (value == null) return;
  final toAppend = value.toString().trim();
  if (toAppend.isEmpty) return;
  final existing = _nonBlankValue(element, 'class');
  element.attributes['class'] = existing != null ? '$existing $toAppend' : toAppend;
}

/// Appends to the style attribute, `;`-separated; `null` or blank is a no-op (never a removal).
void _appendStyle(Element element, Object? value) {
  if (value == null) return;
  final toAppend = value.toString().trim();
  if (toAppend.isEmpty) return;
  final existing = _nonBlankValue(element, 'style');
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
  _dropCaseVariants(element, attrName);
  if (value == null) {
    element.attributes.remove(attrName);
  } else if (_booleanHtmlAttrs.contains(attrName.toLowerCase())) {
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
  return _groupDirectives.any((name) => element.attributes.containsKey('$attrPrefix$name'));
}

bool _hasPrefix(Object key, String lowerPrefix) => key is String && key.toLowerCase().startsWith(lowerPrefix);

/// Runs the attribute group once on the invoking [host] and returns its resulting non-directive attributes, for a
/// fragment's `...rest` parameter.
///
/// Reuses [_processAttributesImpl] so the merge order has one implementation (including `tl:attrs` as step 0).
/// The consumed group directives are stripped from [host] afterwards so the host's own `AttrProcessor` pass cannot
/// evaluate them a second time; a surviving `tl:insert` host keeps their results. Every `tl:*` control attribute
/// (`tl:if`, `tl:replace`, ...) is left on the host and excluded from the map. A `tl:*` name that `tl:attr` wrote
/// during the run is undone, because it would otherwise execute later on a surviving host, which a non-rest callee's
/// host never does (the attribute group runs after every directive it could name).
Map<String, dynamic> captureHostAttributes(
  Element host,
  String attrPrefix,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
) {
  final lowerPrefix = attrPrefix.toLowerCase();
  if (hasAttrAttributes(host, attrPrefix)) {
    final directives = {
      for (final MapEntry(:key, :value) in host.attributes.entries)
        if (_hasPrefix(key, lowerPrefix)) key: value,
    };
    _processAttributesImpl(host, attrPrefix, evaluator, context);
    for (final key in host.attributes.keys.toList()) {
      if (_hasPrefix(key, lowerPrefix) && !directives.containsKey(key)) host.attributes.remove(key);
    }
    for (final MapEntry(:key, :value) in directives.entries) {
      host.attributes[key] = value;
    }
    for (final name in _groupDirectives) {
      host.attributes.remove('$attrPrefix$name');
    }
  }
  return {
    for (final MapEntry(:key, :value) in host.attributes.entries)
      if (key is String && !_hasPrefix(key, lowerPrefix)) key: value,
  };
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
