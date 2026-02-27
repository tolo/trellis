import 'package:html/dom.dart';

import 'evaluator.dart';
import 'exceptions.dart';
import 'loaders/template_loader.dart';
import 'processors/attr_processor.dart';
import 'processors/condition_processor.dart';
import 'processors/each_processor.dart';
import 'processors/fragment_processor.dart';
import 'processors/text_processor.dart';
import 'processors/with_processor.dart';

/// Walks the DOM tree and processes `tl:*` attributes in priority order.
class DomProcessor {
  final String prefix;
  final ExpressionEvaluator evaluator;
  final TemplateLoader loader;

  static const int maxFragmentDepth = 32;
  int _fragmentDepth = 0;

  /// Pre-collected fragment definitions for same-file lookup.
  final Map<String, Element> _fragmentRegistry = {};
  final List<Map<String, Element>> _fragmentRegistryStack = [];

  DomProcessor({required this.prefix, required this.loader, Map<String, dynamic Function(dynamic)>? filters})
    : evaluator = ExpressionEvaluator(filters: filters);

  /// Pre-scan a DOM tree to collect fragment definitions before processing.
  void collectFragments(Node root) {
    if (root is Element) {
      final name = root.attributes['$prefix:fragment'];
      if (name != null) {
        _fragmentRegistry[name] = root;
      }
      for (final child in root.children) {
        collectFragments(child);
      }
    } else if (root is Document) {
      for (final child in root.children) {
        collectFragments(child);
      }
    }
  }

  /// Look up a same-file fragment by name from the pre-collected registry.
  Element? lookupFragment(String name) {
    for (final registry in _fragmentRegistryStack.reversed) {
      final found = registry[name];
      if (found != null) return found;
    }
    return _fragmentRegistry[name];
  }

  void pushFragmentRegistry(Map<String, Element> registry) {
    _fragmentRegistryStack.add(registry);
  }

  void popFragmentRegistry() {
    _fragmentRegistryStack.removeLast();
  }

  /// Process an element and its children, applying all `tl:*` directives.
  void process(Element element, Map<String, dynamic> context) {
    // 1. tl:with — bind local variables
    final effectiveContext = processWith(element, prefix, evaluator, context);

    // 2. tl:if / tl:unless — conditional rendering
    if (!processCondition(element, prefix, evaluator, effectiveContext)) return;

    // 3. tl:each — iteration
    if (processEach(element, prefix, evaluator, effectiveContext, process)) return;

    // 4. tl:insert / tl:replace — fragment inclusion
    if (processFragment(element, prefix, evaluator, effectiveContext, loader, _processFragmentContent, this)) return;

    // 5. tl:text / tl:utext — content substitution
    processText(element, prefix, evaluator, effectiveContext);

    // 6. tl:attr, tl:href, tl:src, etc. — attribute mutation
    processAttributes(element, prefix, evaluator, effectiveContext);

    // 7. Remove all tl:* attributes from output
    element.attributes.keys
        .where((key) => key is String && key.startsWith('$prefix:'))
        .toList()
        .forEach(element.attributes.remove);

    // 8. Recurse into children (snapshot to handle DOM mutations)
    for (final child in List<Element>.from(element.children)) {
      process(child, effectiveContext);
    }

    // 9. tl:block — synthetic element: replace with children
    if (element.localName == '$prefix:block') {
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

  /// Process included fragment content with depth guard.
  void _processFragmentContent(Element element, Map<String, dynamic> context) {
    if (_fragmentDepth >= maxFragmentDepth) {
      throw TemplateException('Fragment inclusion depth exceeded (max: $maxFragmentDepth)');
    }
    _fragmentDepth++;
    try {
      process(element, context);
    } finally {
      _fragmentDepth--;
    }
  }
}
