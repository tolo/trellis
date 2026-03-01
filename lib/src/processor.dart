import 'package:html/dom.dart';

import 'evaluator.dart';
import 'exceptions.dart';
import 'loaders/template_loader.dart';
import 'processors/attr_processor.dart';
import 'processors/condition_processor.dart';
import 'processors/each_processor.dart';
import 'processors/fragment_processor.dart';
import 'processors/inline_processor.dart';
import 'processors/object_processor.dart';
import 'processors/remove_processor.dart';
import 'processors/switch_processor.dart';
import 'processors/text_processor.dart';
import 'processors/with_processor.dart';

/// Walks the DOM tree and processes `tl:*` attributes in priority order.
final class DomProcessor {
  final String prefix;
  final String separator;
  final ExpressionEvaluator evaluator;
  final TemplateLoader loader;

  /// Combined prefix+separator for attribute lookups (e.g. `'tl:'` or `'data-tl-'`).
  late final String attrPrefix = '$prefix$separator';

  static const int maxFragmentDepth = 32;
  int _fragmentDepth = 0;

  /// Document reference for CSS selector queries on same-file fragments.
  Document? _document;

  /// Inclusion stack for cycle detection — tracks fragment IDs being processed.
  final List<String> _inclusionStack = [];

  /// Pre-collected fragment definitions for same-file lookup.
  /// Each entry maps fragment name → (element, paramNames).
  final Map<String, (Element, List<String>)> _fragmentRegistry = {};
  final List<Map<String, (Element, List<String>)>> _fragmentRegistryStack = [];

  DomProcessor({
    required this.prefix,
    required this.separator,
    required this.loader,
    Map<String, dynamic Function(dynamic)>? filters,
    bool strict = false,
  }) : evaluator = ExpressionEvaluator(filters: filters, strict: strict);

  /// Pre-scan a DOM tree to collect fragment definitions before processing.
  void collectFragments(Node root) {
    if (root is Document) _document = root;
    if (root is Element) {
      final fragValue = root.attributes['${attrPrefix}fragment'];
      if (fragValue != null) {
        final (name, paramNames) = parseFragmentDef(fragValue);
        // Store a clone so the registry retains the unprocessed element
        // (the original will be mutated during processing).
        _fragmentRegistry[name] = (root.clone(true), paramNames);
      }
    }
    for (final child in root.children) {
      collectFragments(child);
    }
  }

  /// Query the stored document by CSS selector (for same-file CSS selector fragment targeting).
  Element? querySelectorFromDoc(String selector) => _document?.querySelector(selector);

  /// Look up a same-file fragment by name from the pre-collected registry.
  (Element, List<String>)? lookupFragment(String name) {
    for (final registry in _fragmentRegistryStack.reversed) {
      final found = registry[name];
      if (found != null) return found;
    }
    return _fragmentRegistry[name];
  }

  void pushFragmentRegistry(Map<String, (Element, List<String>)> registry) {
    _fragmentRegistryStack.add(registry);
  }

  void popFragmentRegistry() {
    _fragmentRegistryStack.removeLast();
  }

  /// Process an element and its children, applying all `tl:*` directives.
  void process(Element element, Map<String, dynamic> context) {
    // 1. tl:with — bind local variables
    var effectiveContext = processWith(element, attrPrefix, evaluator, context);

    // 1.5. tl:object — set selection scope
    effectiveContext = processObject(element, attrPrefix, evaluator, effectiveContext);

    // 2. tl:if / tl:unless — conditional rendering
    if (!processCondition(element, attrPrefix, evaluator, effectiveContext)) return;

    // 2.5. tl:switch / tl:case — multi-branch conditional
    processSwitch(element, attrPrefix, evaluator, effectiveContext);

    // 3. tl:each — iteration
    if (processEach(element, attrPrefix, evaluator, effectiveContext, process)) return;

    // 3.5. tl:fragment with parameters — definition-only, remove from output
    // (empty-param form `name()` is equivalent to `name` and must NOT be removed)
    final fragDef = element.attributes['${attrPrefix}fragment'];
    if (fragDef != null) {
      final (_, paramNames) = parseFragmentDef(fragDef);
      if (paramNames.isNotEmpty) {
        element.remove();
        return;
      }
    }

    // 4. tl:insert / tl:replace — fragment inclusion
    if (processFragment(element, effectiveContext, _processFragmentContent, this)) {
      return;
    }

    // 5. tl:text / tl:utext — content substitution
    processText(element, attrPrefix, evaluator, effectiveContext);

    // 5.5. tl:inline — inline expression processing
    processInline(element, attrPrefix, evaluator, effectiveContext);

    // 6. tl:attr, tl:href, tl:src, etc. — attribute mutation
    processAttributes(element, attrPrefix, evaluator, effectiveContext);

    // 7. tl:remove — element/content removal
    if (processRemove(element, attrPrefix, evaluator, effectiveContext)) return;

    // 8. Remove all tl:* attributes from output
    final keysToRemove = element.attributes.keys.where((key) => key is String && key.startsWith(attrPrefix)).toList();
    for (final key in keysToRemove) {
      element.attributes.remove(key);
    }

    // 9. Recurse into children (snapshot to handle DOM mutations)
    for (final child in List<Element>.from(element.children)) {
      process(child, effectiveContext);
    }

    // 10. tl:block — synthetic element: replace with children
    if (element.localName == '${attrPrefix}block') {
      _unwrapBlock(element);
    }
  }

  void _unwrapBlock(Element element) {
    final parent = element.parentNode;
    if (parent == null) return;
    for (final child in List<Node>.from(element.nodes)) {
      parent.insertBefore(child, element);
    }
    element.remove();
  }

  /// Process included fragment content with depth guard and cycle detection.
  void _processFragmentContent(Element element, Map<String, dynamic> context, {String? fragmentId}) {
    if (_fragmentDepth >= maxFragmentDepth) {
      throw TemplateException('Fragment inclusion depth exceeded (max: $maxFragmentDepth)');
    }
    if (fragmentId != null && _inclusionStack.contains(fragmentId)) {
      final cycleStart = _inclusionStack.indexOf(fragmentId);
      final cyclePath = [..._inclusionStack.sublist(cycleStart), fragmentId];
      throw TemplateException('Fragment cycle detected: ${cyclePath.join(' \u2192 ')}');
    }
    _fragmentDepth++;
    if (fragmentId != null) _inclusionStack.add(fragmentId);
    try {
      process(element, context);
    } finally {
      _fragmentDepth--;
      if (fragmentId != null) _inclusionStack.removeLast();
    }
  }
}
