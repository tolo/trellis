import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../evaluator.dart';
import '../exceptions.dart';
import '../loaders/template_loader.dart';
import '../processor.dart';

/// Regex for cross-file fragment syntax: ~{filename :: fragmentName}
final _crossFilePattern = RegExp(r'^~\{(.+?)\s*::\s*(.+?)\}$');

final class _ResolvedFragment {
  final Element element;
  final Map<String, Element>? registry;

  _ResolvedFragment(this.element, {this.registry});
}

/// Processes `tl:fragment`, `tl:insert`, and `tl:replace` attributes.
/// Returns `true` if `tl:replace` fired and the host element was replaced
/// (caller should stop further processing); `false` otherwise.
bool processFragment(
  Element element,
  String prefix,
  ExpressionEvaluator evaluator,
  Map<String, dynamic> context,
  TemplateLoader loader,
  void Function(Element, Map<String, dynamic>) processCallback,
  DomProcessor domProcessor,
) {
  // tl:fragment is a definition marker only — no-op here (attribute removed by general cleanup)

  // tl:insert — include fragment content inside host element
  final insertExpr = element.attributes['$prefix:insert'];
  if (insertExpr != null) {
    final resolved = _resolveFragment(insertExpr, prefix, loader, domProcessor);
    final clone = resolved.element.clone(true);
    _applyFragment(resolved, clone, context, processCallback, domProcessor, prefix);
    element.nodes.clear();
    for (final child in clone.nodes.toList()) {
      element.append(child);
    }
    return false;
  }

  // tl:replace — replace host element with fragment
  final replaceExpr = element.attributes['$prefix:replace'];
  if (replaceExpr != null) {
    final resolved = _resolveFragment(replaceExpr, prefix, loader, domProcessor);
    final clone = resolved.element.clone(true);
    _applyFragment(resolved, clone, context, processCallback, domProcessor, prefix);
    element.replaceWith(clone);
    return true;
  }

  return false;
}

void _applyFragment(
  _ResolvedFragment resolved,
  Element clone,
  Map<String, dynamic> context,
  void Function(Element, Map<String, dynamic>) processCallback,
  DomProcessor domProcessor,
  String prefix,
) {
  clone.attributes.remove('$prefix:fragment');
  if (resolved.registry != null) domProcessor.pushFragmentRegistry(resolved.registry!);
  try {
    processCallback(clone, context);
  } finally {
    if (resolved.registry != null) domProcessor.popFragmentRegistry();
  }
}

/// Resolve a fragment by name — same-file or cross-file.
_ResolvedFragment _resolveFragment(String value, String prefix, TemplateLoader loader, DomProcessor domProcessor) {
  final crossMatch = _crossFilePattern.firstMatch(value);
  if (crossMatch != null) {
    return _resolveCrossFile(crossMatch.group(1)!, crossMatch.group(2)!, prefix, loader);
  }
  return _resolveSameFile(value, domProcessor);
}

/// Find fragment in the pre-collected registry.
_ResolvedFragment _resolveSameFile(String name, DomProcessor domProcessor) {
  final found = domProcessor.lookupFragment(name);
  if (found != null) return _ResolvedFragment(found);
  throw FragmentNotFoundException(name);
}

/// Load template via loader and find fragment within it.
_ResolvedFragment _resolveCrossFile(String templateName, String fragmentName, String prefix, TemplateLoader loader) {
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
  final found = doc.querySelector('[$prefix\\:fragment="$fragmentName"]');
  if (found == null) {
    throw FragmentNotFoundException(fragmentName, templateName: templateName);
  }
  return _ResolvedFragment(found, registry: _collectFragmentRegistry(doc, prefix));
}

Map<String, Element> _collectFragmentRegistry(Document doc, String prefix) {
  final registry = <String, Element>{};
  for (final node in doc.querySelectorAll('[$prefix\\:fragment]')) {
    final name = node.attributes['$prefix:fragment'];
    if (name != null) {
      registry[name] = node;
    }
  }
  return registry;
}
