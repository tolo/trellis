import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../evaluator.dart';
import '../exceptions.dart';
import '../loaders/template_loader.dart';
import '../processor.dart';
import '../utils/binding_parser.dart';

/// Regex for cross-file fragment syntax: ~{filename :: fragmentName}
/// Uses greedy match for group 2 to handle nested braces in `${...}` expressions.
final _crossFilePattern = RegExp(r'^~\{(.+?)\s*::\s*(.+)\}$');

/// Parse a parenthesized fragment value like `"card(title, body)"` or `"card(${x}, ${y})"`.
///
/// When [splitNested] is true (invocations), inner content is split respecting
/// nested delimiters via [splitTopLevel]. When false (definitions), simple
/// comma-split is used.
(String name, List<String> parts) _parseFragmentValue(String value, {required bool splitNested}) {
  final parenIdx = value.indexOf('(');
  if (parenIdx < 0) return (value.trim(), const []);
  final name = value.substring(0, parenIdx).trim();
  final closeIdx = value.lastIndexOf(')');
  if (closeIdx < 0) return (name, const []);
  final inner = value.substring(parenIdx + 1, closeIdx).trim();
  if (inner.isEmpty) return (name, const []);
  return (name, splitNested ? splitTopLevel(inner) : inner.split(',').map((p) => p.trim()).toList());
}

/// Parse a fragment definition value like `"card(title, body)"` into name and param names.
(String name, List<String> paramNames) parseFragmentDef(String value) => _parseFragmentValue(value, splitNested: false);

/// Parse a fragment invocation value like `"card(${x}, ${y})"` into name and arg expressions.
(String name, List<String> argExprs) _parseFragmentInvocation(String value) =>
    _parseFragmentValue(value, splitNested: true);

/// Bind fragment arguments to parameter names, creating an augmented context.
Map<String, dynamic> _bindArgs(
  List<String> paramNames,
  List<String> argExprs,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
) {
  if (paramNames.isEmpty) return context;
  final augmented = {...context};
  for (var i = 0; i < paramNames.length; i++) {
    augmented[paramNames[i]] = i < argExprs.length ? evaluator.evaluate(argExprs[i], context) : null;
  }
  return augmented;
}

final class _ResolvedFragment {
  final Element element;
  final Map<String, (Element, List<String>)>? registry;
  final List<String> paramNames;
  final String fragmentId;

  _ResolvedFragment(this.element, {this.registry, this.paramNames = const [], required this.fragmentId});
}

/// Processes `tl:fragment`, `tl:insert`, and `tl:replace` attributes.
/// Returns `true` if `tl:replace` fired and the host element was replaced
/// (caller should stop further processing); `false` otherwise.
bool processFragment(
  Element element,
  Map<String, dynamic> context,
  void Function(Element, Map<String, dynamic>, {String? fragmentId}) processCallback,
  DomProcessor domProcessor,
) {
  final attrPrefix = domProcessor.attrPrefix;
  final evaluator = domProcessor.evaluator;
  final loader = domProcessor.loader;
  // tl:fragment is a definition marker only — no-op here (attribute removed by general cleanup)

  // tl:insert — include fragment content inside host element
  final insertExpr = element.attributes['${attrPrefix}insert'];
  if (insertExpr != null) {
    final (_, argExprs) = _parseFragmentInvocation(insertExpr);
    final resolved = _resolveFragment(insertExpr, attrPrefix, loader, domProcessor);
    final effectiveContext = _bindArgs(resolved.paramNames, argExprs, evaluator, context);
    final clone = resolved.element.clone(true);
    _applyFragment(
      resolved,
      clone,
      effectiveContext,
      processCallback,
      domProcessor,
      attrPrefix,
      fragmentId: resolved.fragmentId,
    );
    element.nodes.clear();
    for (final child in clone.nodes.toList()) {
      element.append(child);
    }
    return false;
  }

  // tl:replace — replace host element with fragment
  final replaceExpr = element.attributes['${attrPrefix}replace'];
  if (replaceExpr != null) {
    final (_, argExprs) = _parseFragmentInvocation(replaceExpr);
    final resolved = _resolveFragment(replaceExpr, attrPrefix, loader, domProcessor);
    final effectiveContext = _bindArgs(resolved.paramNames, argExprs, evaluator, context);
    final clone = resolved.element.clone(true);
    _applyFragment(
      resolved,
      clone,
      effectiveContext,
      processCallback,
      domProcessor,
      attrPrefix,
      fragmentId: resolved.fragmentId,
    );
    element.replaceWith(clone);
    return true;
  }

  return false;
}

void _applyFragment(
  _ResolvedFragment resolved,
  Element clone,
  Map<String, dynamic> context,
  void Function(Element, Map<String, dynamic>, {String? fragmentId}) processCallback,
  DomProcessor domProcessor,
  String attrPrefix, {
  String? fragmentId,
}) {
  clone.attributes.remove('${attrPrefix}fragment');
  if (resolved.registry != null) domProcessor.pushFragmentRegistry(resolved.registry!);
  try {
    processCallback(clone, context, fragmentId: fragmentId);
  } finally {
    if (resolved.registry != null) domProcessor.popFragmentRegistry();
  }
}

/// Resolve a fragment by name — same-file or cross-file.
_ResolvedFragment _resolveFragment(String value, String attrPrefix, TemplateLoader loader, DomProcessor domProcessor) {
  final crossMatch = _crossFilePattern.firstMatch(value);
  if (crossMatch != null) {
    final templateName = crossMatch.group(1)!;
    final fragmentRef = crossMatch.group(2)!;
    final (fragName, _) = _parseFragmentInvocation(fragmentRef);
    return _resolveCrossFile(templateName, fragName, attrPrefix, loader, fragmentId: '$templateName::$fragName');
  }
  final (name, _) = _parseFragmentInvocation(value);
  return _resolveSameFile(name, domProcessor);
}

/// Find fragment in the pre-collected registry, with CSS selector fallback.
_ResolvedFragment _resolveSameFile(String name, DomProcessor domProcessor) {
  // CSS selector (#id, .class) — always use querySelector
  if (_isCssSelector(name)) {
    final found = domProcessor.querySelectorFromDoc(name);
    if (found != null) return _ResolvedFragment(found, fragmentId: name);
    throw FragmentNotFoundException(name);
  }
  // Named fragment lookup
  final found = domProcessor.lookupFragment(name);
  if (found != null) return _ResolvedFragment(found.$1, paramNames: found.$2, fragmentId: name);
  // Tag name fallback
  if (_isTagName(name)) {
    final tagFound = domProcessor.querySelectorFromDoc(name);
    if (tagFound != null) return _ResolvedFragment(tagFound, fragmentId: name);
  }
  throw FragmentNotFoundException(name);
}

/// Load template via loader and find fragment within it, with CSS selector support.
_ResolvedFragment _resolveCrossFile(
  String templateName,
  String fragName,
  String attrPrefix,
  TemplateLoader loader, {
  required String fragmentId,
}) {
  final source = loader.loadSync(templateName);
  if (source == null) {
    throw TemplateNotFoundException(templateName);
  }
  final doc = html_parser.parse(source);

  // CSS selector (#id, .class)
  if (_isCssSelector(fragName)) {
    final found = doc.querySelector(fragName);
    if (found == null) throw FragmentNotFoundException(fragName, templateName: templateName);
    return _ResolvedFragment(found, registry: _collectFragmentRegistry(doc, attrPrefix), fragmentId: fragmentId);
  }

  // Named fragment — search by name prefix (handles both "name" and "name(params)")
  final escapedPrefix = escapeAttrSelector(attrPrefix);
  final registry = _collectFragmentRegistry(doc, attrPrefix);
  final regEntry = registry[fragName];
  if (regEntry != null) {
    return _ResolvedFragment(regEntry.$1, registry: registry, paramNames: regEntry.$2, fragmentId: fragmentId);
  }

  // Legacy: try exact attribute match for fragments without params
  final found = doc.querySelector('[${escapedPrefix}fragment="$fragName"]');
  if (found != null) return _ResolvedFragment(found, registry: registry, fragmentId: fragmentId);

  // Tag name fallback
  if (_isTagName(fragName)) {
    final tagFound = doc.querySelector(fragName);
    if (tagFound != null) return _ResolvedFragment(tagFound, registry: registry, fragmentId: fragmentId);
  }

  throw FragmentNotFoundException(fragName, templateName: templateName);
}

Map<String, (Element, List<String>)> _collectFragmentRegistry(Document doc, String attrPrefix) {
  final escapedPrefix = escapeAttrSelector(attrPrefix);
  final registry = <String, (Element, List<String>)>{};
  for (final node in doc.querySelectorAll('[${escapedPrefix}fragment]')) {
    final fragValue = node.attributes['${attrPrefix}fragment'];
    if (fragValue != null) {
      final (name, paramNames) = parseFragmentDef(fragValue);
      registry[name] = (node, paramNames);
    }
  }
  return registry;
}

/// Escape special CSS selector characters in an attribute prefix.
String escapeAttrSelector(String prefix) {
  return prefix.replaceAllMapped(RegExp(r'[:.]'), (m) => '\\${m[0]}');
}

/// Whether [ref] is a CSS selector (starts with `#` or `.`).
bool _isCssSelector(String ref) => ref.startsWith('#') || ref.startsWith('.');

/// Whether [ref] looks like a bare HTML tag name (lowercase letters/digits only).
final _tagNamePattern = RegExp(r'^[a-z][a-z0-9]*$');
bool _isTagName(String ref) => _tagNamePattern.hasMatch(ref);
