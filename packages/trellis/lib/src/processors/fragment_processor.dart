import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../evaluator.dart';
import '../exceptions.dart';
import '../loaders/template_loader.dart';
import '../processor_api.dart';
import '../truthiness.dart';
import '../utils/binding_parser.dart';
import 'attr_processor.dart' show captureHostAttributes;

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

/// Marks a fragment's trailing rest parameter, e.g. `field(label, ...attrs)`.
const _restMarker = '...';

/// The author-chosen name of the rest parameter declared last in [paramNames], or null when there is none.
///
/// The rest parameter travels as the literal last `paramNames` entry (`'...attrs'`) so the registry record type
/// and `FragmentHost` stay unchanged.
String? restParameterName(List<String> paramNames) => paramNames.isNotEmpty && paramNames.last.startsWith(_restMarker)
    ? paramNames.last.substring(_restMarker.length)
    : null;

/// Reject a fragment definition whose `...rest` parameter is repeated, not last, or unnamed.
///
/// Called by both definition-collection sites, because a rest parameter that is not final would silently bind an
/// argument over the forwarded attribute map.
void validateFragmentParams(String name, List<String> paramNames) {
  for (var i = 0; i < paramNames.length; i++) {
    final param = paramNames[i];
    if (!param.startsWith(_restMarker)) continue;
    if (i != paramNames.length - 1) {
      throw TemplateException(
        'Fragment "$name": rest parameter "$param" must be the last parameter and may appear only once',
      );
    }
    if (param.length == _restMarker.length) {
      throw TemplateException('Fragment "$name": rest parameter "..." needs a name, e.g. "...attrs"');
    }
  }
}

/// Bind fragment arguments to parameter names, creating an augmented context.
///
/// A trailing rest parameter binds [rest] (the invoking host's attributes) under its author-chosen name and
/// accepts no positional argument: an extra one throws instead of overwriting the map. Fragments without a rest
/// parameter keep ignoring extra arguments.
Map<String, dynamic> _bindArgs(
  String fragmentName,
  List<String> paramNames,
  List<String> argExprs,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context, {
  Map<String, dynamic>? rest,
}) {
  if (paramNames.isEmpty) return context;
  final restName = restParameterName(paramNames);
  final positional = restName == null ? paramNames : paramNames.sublist(0, paramNames.length - 1);
  if (restName != null && argExprs.length > positional.length) {
    throw TemplateException(
      'Fragment "$fragmentName" takes ${positional.length} positional argument(s) before its rest parameter '
      '"...$restName" but got ${argExprs.length}',
    );
  }
  final augmented = {...context};
  for (var i = 0; i < positional.length; i++) {
    augmented[positional[i]] = i < argExprs.length ? evaluator.evaluate(argExprs[i], context) : null;
  }
  if (restName != null) augmented[restName] = rest ?? <String, dynamic>{};
  return augmented;
}

final class _ResolvedFragment {
  final Element element;
  final Map<String, (Element, List<String>)>? registry;
  final List<String> paramNames;
  final String fragmentId;

  /// Whether the fragment was found by `tl:fragment` name. Only these declare content slots; CSS-selector and
  /// tag-name targets keep their pre-slot semantics.
  final bool byName;

  _ResolvedFragment(
    this.element, {
    this.registry,
    this.paramNames = const [],
    required this.fragmentId,
    this.byName = false,
  });
}

void _applyFragment(
  _ResolvedFragment resolved,
  Element clone,
  Map<String, dynamic> context,
  void Function(Element, Map<String, dynamic>, {String? fragmentId}) processCallback,
  FragmentHost domProcessor,
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
_ResolvedFragment _resolveFragment(String value, String attrPrefix, TemplateLoader loader, FragmentHost domProcessor) {
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
_ResolvedFragment _resolveSameFile(String name, FragmentHost domProcessor) {
  // CSS selector (#id, .class) — always use querySelector
  if (_isCssSelector(name)) {
    final found = domProcessor.querySelectorFromDoc(name);
    if (found != null) return _ResolvedFragment(found, fragmentId: name);
    throw FragmentNotFoundException(name);
  }
  // Named fragment lookup
  final found = domProcessor.lookupFragment(name);
  if (found != null) return _ResolvedFragment(found.$1, paramNames: found.$2, fragmentId: name, byName: true);
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
    return _ResolvedFragment(
      regEntry.$1,
      registry: registry,
      paramNames: regEntry.$2,
      fragmentId: fragmentId,
      byName: true,
    );
  }

  // Legacy: try exact attribute match for fragments without params
  final found = doc.querySelector('[${escapedPrefix}fragment="$fragName"]');
  if (found != null) return _ResolvedFragment(found, registry: registry, fragmentId: fragmentId, byName: true);

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
      validateFragmentParams(name, paramNames);
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

/// Declared content slots of a fragment clone, keyed by slot name (`''` is the anonymous slot).
///
/// Mirrors `InheritanceResolver._collectBlocks`: depth-first, and a matched region is not descended into, so a
/// `tl:slot` inside another region's fallback content is that fallback, not a second declaration. Derived on each
/// invocation rather than stored in the fragment registry, so definition errors surface at invocation.
Map<String, Element> _collectSlotRegions(Element fragmentRoot, String attrPrefix) {
  final slotAttr = '${attrPrefix}slot';
  if (fragmentRoot.attributes.containsKey(slotAttr)) {
    throw TemplateException(
      'tl:slot cannot be on the tl:fragment root element <${fragmentRoot.localName}>; '
      'declare the region on an inner element instead',
    );
  }
  final regions = <String, Element>{};
  void walk(Element element) {
    final name = element.attributes[slotAttr];
    if (name != null) {
      final key = name.trim();
      if (regions.containsKey(key)) {
        throw TemplateException(
          key.isEmpty
              ? 'Duplicate anonymous tl:slot in fragment "${_fragmentLabel(fragmentRoot, attrPrefix)}"'
              : 'Duplicate tl:slot "$key" in fragment "${_fragmentLabel(fragmentRoot, attrPrefix)}"',
        );
      }
      regions[key] = element;
      return;
    }
    element.children.forEach(walk);
  }

  fragmentRoot.children.forEach(walk);
  return regions;
}

String _fragmentLabel(Element fragmentRoot, String attrPrefix) =>
    parseFragmentDef(fragmentRoot.attributes['${attrPrefix}fragment'] ?? '').$1;

/// Collect the invoking [host]'s slot contributions from its literal direct children and graft them into the
/// matching regions of [clone] with the `tl:define` merge rule: region element kept, children replaced.
///
/// Must run before the host's children are cleared or the host is replaced. Grafted nodes stay unprocessed, so
/// processing [clone] afterwards resolves them in the fragment's effective [scope].
void _graftSlots(
  Element clone,
  Element host, {
  required bool byName,
  required ProcessorContext context,
  required Map<String, dynamic> scope,
}) {
  final attrPrefix = context.attrPrefix;
  final regions = byName ? _collectSlotRegions(clone, attrPrefix) : const <String, Element>{};
  final slotAttr = '${attrPrefix}slot';
  final controlAttrs = {slotAttr, '${attrPrefix}if', '${attrPrefix}unless'};
  final contributions = <String, List<Node>>{};

  for (final node in host.nodes) {
    if (node is Element && node.attributes.containsKey(slotAttr)) {
      for (final key in node.attributes.keys) {
        if (key is String && key.startsWith(attrPrefix) && !controlAttrs.contains(key)) {
          throw TemplateException(
            'Unsupported attribute "$key" on slot marker <${node.localName} $slotAttr>; '
            'only ${attrPrefix}if and ${attrPrefix}unless may accompany $slotAttr',
          );
        }
      }
      final name = node.attributes[slotAttr]!.trim();
      if (!regions.containsKey(name)) {
        throw TemplateException(
          name.isEmpty
              ? 'Slot marker <${node.localName} $slotAttr> targets the anonymous slot, which the fragment does not declare'
              : 'Slot marker $slotAttr="$name" targets a slot the fragment does not declare',
        );
      }
      final ifExpr = node.attributes['${attrPrefix}if'];
      final unlessExpr = node.attributes['${attrPrefix}unless'];
      if (ifExpr != null && !isTruthy(context.evaluate(ifExpr, scope))) continue;
      if (unlessExpr != null && isTruthy(context.evaluate(unlessExpr, scope))) continue;
      contributions.putIfAbsent(name, () => []).addAll(node.nodes);
    } else if (_isUnmarkedContent(node) && regions.containsKey('')) {
      contributions.putIfAbsent('', () => []).add(node);
    }
  }

  for (final MapEntry(:key, :value) in contributions.entries) {
    final region = regions[key]!;
    region.nodes.clear();
    for (final node in value) {
      region.append(node.clone(true));
    }
  }
}

/// Whether a host child is content for the anonymous slot: whitespace-only text (pretty-printing) and comments
/// are not, so they neither fill the slot nor displace its fallback. Whitespace means HTML ASCII whitespace, not
/// `String.trim`'s Unicode set, so an `&nbsp;` is content.
bool _isUnmarkedContent(Node node) => switch (node) {
  Text(:final data) => _nonHtmlWhitespace.hasMatch(data),
  Comment() => false,
  _ => true,
};

final _nonHtmlWhitespace = RegExp(r'[^\t\n\f\r ]');

/// Resolve, bind, clone, graft slot content from [host], and process a fragment invocation.
Element _resolveAndProcess(String value, ProcessorContext context, Element host) {
  final dp = context.domProcessor;
  final attrPrefix = context.attrPrefix;
  final (_, argExprs) = _parseFragmentInvocation(value);
  final resolved = _resolveFragment(value, attrPrefix, context.loader, dp);
  // Capture only for a rest-parameter callee: it consumes the host's attribute directives, which a non-rest
  // invocation must leave exactly as before (inert on a tl:replace host).
  final rest = restParameterName(resolved.paramNames) == null
      ? null
      : captureHostAttributes(host, attrPrefix, dp.evaluator, context.variables);
  final effectiveContext = _bindArgs(
    resolved.fragmentId,
    resolved.paramNames,
    argExprs,
    dp.evaluator,
    context.variables,
    rest: rest,
  );
  final clone = resolved.element.clone(true);
  _graftSlots(clone, host, byName: resolved.byName, context: context, scope: effectiveContext);
  _applyFragment(
    resolved,
    clone,
    effectiveContext,
    dp.processFragmentContent,
    dp,
    attrPrefix,
    fragmentId: resolved.fragmentId,
  );
  return clone;
}

/// Processor class for `tl:insert` — fragment inclusion inside host element.
class InsertProcessor extends Processor {
  @override
  String get attribute => 'insert';

  @override
  ProcessorPriority get priority => .afterIteration;

  @override
  bool get autoProcessChildren => false;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final clone = _resolveAndProcess(value, context, element);
    element.nodes.clear();
    for (final child in clone.nodes.toList()) {
      element.append(child);
    }
    return true;
  }
}

/// Processor class for `tl:replace` — replace host element with fragment.
class ReplaceProcessor extends Processor {
  @override
  String get attribute => 'replace';

  @override
  ProcessorPriority get priority => .afterIteration;

  @override
  bool get autoProcessChildren => false;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final clone = _resolveAndProcess(value, context, element);
    element.replaceWith(clone);
    return false;
  }
}
