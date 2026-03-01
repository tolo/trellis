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

/// Parse a fragment definition value like `"card(title, body)"` into name and param names.
(String name, List<String> paramNames) parseFragmentDef(String value) {
  final parenIdx = value.indexOf('(');
  if (parenIdx < 0) return (value.trim(), const []);
  final name = value.substring(0, parenIdx).trim();
  final closeIdx = value.lastIndexOf(')');
  if (closeIdx < 0) return (name, const []);
  final paramsStr = value.substring(parenIdx + 1, closeIdx).trim();
  if (paramsStr.isEmpty) return (name, const []);
  return (name, paramsStr.split(',').map((p) => p.trim()).toList());
}

/// Parse a fragment invocation value like `"card(${x}, ${y})"` into name and arg expressions.
(String name, List<String> argExprs) _parseFragmentInvocation(String value) {
  final parenIdx = value.indexOf('(');
  if (parenIdx < 0) return (value.trim(), const []);
  final name = value.substring(0, parenIdx).trim();
  final closeIdx = value.lastIndexOf(')');
  if (closeIdx < 0) return (name, const []);
  final argsStr = value.substring(parenIdx + 1, closeIdx).trim();
  if (argsStr.isEmpty) return (name, const []);
  return (name, splitTopLevel(argsStr));
}

/// Bind fragment arguments to parameter names, creating an augmented context.
Map<String, dynamic> _bindArgs(
  List<String> paramNames,
  List<String> argExprs,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
) {
  if (paramNames.isEmpty) return context;
  final augmented = Map<String, dynamic>.from(context);
  for (var i = 0; i < paramNames.length; i++) {
    augmented[paramNames[i]] = i < argExprs.length ? evaluator.evaluate(argExprs[i], context) : null;
  }
  return augmented;
}

final class _ResolvedFragment {
  final Element element;
  final Map<String, (Element, List<String>)>? registry;
  final List<String> paramNames;

  _ResolvedFragment(this.element, {this.registry, this.paramNames = const []});
}

/// Processes `tl:fragment`, `tl:insert`, and `tl:replace` attributes.
/// Returns `true` if `tl:replace` fired and the host element was replaced
/// (caller should stop further processing); `false` otherwise.
bool processFragment(
  Element element,
  String attrPrefix,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
  TemplateLoader loader,
  void Function(Element, Map<String, dynamic>, {String? fragmentId}) processCallback,
  DomProcessor domProcessor,
) {
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
      fragmentId: _makeFragmentId(insertExpr),
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
      fragmentId: _makeFragmentId(replaceExpr),
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
    return _resolveCrossFile(crossMatch.group(1)!, crossMatch.group(2)!, attrPrefix, loader);
  }
  final (name, _) = _parseFragmentInvocation(value);
  return _resolveSameFile(name, domProcessor);
}

/// Find fragment in the pre-collected registry, with CSS selector fallback.
_ResolvedFragment _resolveSameFile(String name, DomProcessor domProcessor) {
  // CSS selector (#id, .class) — always use querySelector
  if (_isCssSelector(name)) {
    final found = domProcessor.querySelectorFromDoc(name);
    if (found != null) return _ResolvedFragment(found);
    throw FragmentNotFoundException(name);
  }
  // Named fragment lookup
  final found = domProcessor.lookupFragment(name);
  if (found != null) return _ResolvedFragment(found.$1, paramNames: found.$2);
  // Tag name fallback
  if (_isTagName(name)) {
    final tagFound = domProcessor.querySelectorFromDoc(name);
    if (tagFound != null) return _ResolvedFragment(tagFound);
  }
  throw FragmentNotFoundException(name);
}

/// Load template via loader and find fragment within it, with CSS selector support.
_ResolvedFragment _resolveCrossFile(String templateName, String fragmentRef, String attrPrefix, TemplateLoader loader) {
  String? source;
  try {
    source = loader.loadSync(templateName);
  } on TemplateNotFoundException {
    rethrow;
  }
  if (source == null) {
    throw TemplateNotFoundException(templateName);
  }
  final doc = html_parser.parse(source);
  final (fragName, _) = _parseFragmentInvocation(fragmentRef);

  // CSS selector (#id, .class)
  if (_isCssSelector(fragName)) {
    final found = doc.querySelector(fragName);
    if (found == null) throw FragmentNotFoundException(fragName, templateName: templateName);
    return _ResolvedFragment(found, registry: _collectFragmentRegistry(doc, attrPrefix));
  }

  // Named fragment — search by name prefix (handles both "name" and "name(params)")
  final escapedPrefix = escapeAttrSelector(attrPrefix);
  final registry = _collectFragmentRegistry(doc, attrPrefix);
  final regEntry = registry[fragName];
  if (regEntry != null) {
    return _ResolvedFragment(regEntry.$1, registry: registry, paramNames: regEntry.$2);
  }

  // Legacy: try exact attribute match for fragments without params
  final found = doc.querySelector('[${escapedPrefix}fragment="$fragName"]');
  if (found != null) return _ResolvedFragment(found, registry: registry);

  // Tag name fallback
  if (_isTagName(fragName)) {
    final tagFound = doc.querySelector(fragName);
    if (tagFound != null) return _ResolvedFragment(tagFound, registry: registry);
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

/// Build a fragment ID string for cycle detection.
String _makeFragmentId(String expr) {
  final crossMatch = _crossFilePattern.firstMatch(expr);
  if (crossMatch != null) {
    final (fragName, _) = _parseFragmentInvocation(crossMatch.group(2)!);
    return '${crossMatch.group(1)}::$fragName';
  }
  final (name, _) = _parseFragmentInvocation(expr);
  return name;
}
