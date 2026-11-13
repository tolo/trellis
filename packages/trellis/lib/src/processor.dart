import 'dart:io' show stderr;

import 'package:html/dom.dart';

import 'dialect.dart';
import 'evaluator.dart';
import 'exceptions.dart';
import 'expression/ast.dart';
import 'message_source.dart';
import 'loaders/template_loader.dart';
import 'processor_api.dart';
import 'processors/attr_processor.dart';
import 'processors/fragment_processor.dart';

/// Walks the DOM tree and processes `tl:*` attributes in priority order.
///
/// Uses a sorted list of [Processor] instances [D01]. Built-in processors are
/// registered in the exact v0.2 pipeline order to maintain behavioral parity.
final class DomProcessor implements FragmentHost {
  final String prefix;
  final String separator;
  @override
  final ExpressionEvaluator evaluator;
  final TemplateLoader loader;

  /// Combined prefix+separator for attribute lookups (e.g. `'tl:'` or `'data-tl-'`).
  late final String attrPrefix = '$prefix$separator';

  static const int maxFragmentDepth = 32;
  int _fragmentDepth = 0;

  /// Unprocessed copy of the document, for same-file CSS selector and tag-name fragment targets.
  ///
  /// A copy rather than the live document, because an element that precedes its host is already processed by the
  /// time the host queries it: copying that output would process it again, `tl:utext` HTML included. Name lookups
  /// clone their definitions at collection for the same reason. Built by [_buildDocument] on the first query, since
  /// few templates use these targets and a copy per render costs every render.
  Document? _document;
  Document Function()? _buildDocument;

  /// Inclusion stack for cycle detection — tracks fragment IDs being processed.
  final List<String> _inclusionStack = [];

  /// Pre-collected fragment definitions for same-file lookup.
  /// Each entry maps fragment name → (element, paramNames).
  final Map<String, (Element, List<String>)> _fragmentRegistry = {};
  final List<({Map<String, (Element, List<String>)> registry, Document? document})> _fragmentRegistryStack = [];

  /// Sorted list of all processors (built-in + custom), in priority order.
  late final List<Processor> _processors;

  /// Set of built-in processor instances for error wrapping identification.
  late final Set<Processor> _builtIns;

  DomProcessor({
    required this.prefix,
    required this.separator,
    required this.loader,
    Map<String, Function>? filters,
    bool strict = false,
    List<Processor>? processors,
    List<Dialect>? dialects,
    bool includeStandard = true,
    MessageSource? messageSource,
    String? locale,
    Map<String, Expr>? expressionCache,
  }) : evaluator = ExpressionEvaluator(
         filters: _mergeFilters(
           dialects: dialects ?? const [],
           engineFilters: filters,
           includeStandard: includeStandard,
         ),
         strict: strict,
         messageSource: messageSource,
         locale: locale,
         expressionCache: expressionCache,
       ) {
    _processors = _buildProcessorList(
      dialects: dialects ?? const [],
      customProcessors: processors ?? const [],
      includeStandard: includeStandard,
    );
  }

  /// Merge filters from dialects and engine-level filters.
  /// Order: StandardDialect (if included) -> user dialects -> engine-level.
  /// Later sources override earlier (engine-level wins on conflict).
  static Map<String, Function>? _mergeFilters({
    required List<Dialect> dialects,
    required Map<String, Function>? engineFilters,
    required bool includeStandard,
  }) {
    // If no dialects and no engine filters and includeStandard: return null
    // to let ExpressionEvaluator use its built-in defaults.
    if (includeStandard && dialects.isEmpty && engineFilters == null) {
      return null;
    }

    final merged = <String, Function>{};

    // 1. StandardDialect filters (if included)
    if (includeStandard) {
      merged.addAll(StandardDialect().filters);
    }

    // 2. User dialect filters (in list order, later overrides earlier)
    for (final dialect in dialects) {
      merged.addAll(dialect.filters);
    }

    // 3. Engine-level filters (overrides dialect filters)
    if (engineFilters != null) {
      merged.addAll(engineFilters);
    }

    return merged;
  }

  /// Build the merged, priority-sorted processor list from dialects + custom.
  List<Processor> _buildProcessorList({
    required List<Dialect> dialects,
    required List<Processor> customProcessors,
    required bool includeStandard,
  }) {
    // 1. Assemble processors: StandardDialect (if included), then user dialects, then custom.
    // This registration order is preserved inside each priority bucket.
    final builtIns = <Processor>[];
    if (includeStandard) {
      builtIns.addAll(StandardDialect().processors);
    }
    _builtIns = builtIns.toSet();

    // Collect all non-built-in processors (dialect + custom)
    final nonBuiltIn = <Processor>[];
    for (final dialect in dialects) {
      nonBuiltIn.addAll(dialect.processors);
    }
    nonBuiltIn.addAll(customProcessors);

    if (nonBuiltIn.isEmpty) return builtIns;

    // Detect attribute conflicts: non-built-in vs built-in
    final builtInAttrs = <String>{for (final p in builtIns) p.attribute};
    for (final p in nonBuiltIn) {
      if (builtInAttrs.contains(p.attribute)) {
        stderr.writeln(
          'Warning: Processor attribute "${p.attribute}" is provided by both '
          'StandardDialect and a custom/dialect processor. Both will run '
          'according to priority and registration order.',
        );
      }
    }

    // Merge with deterministic ordering:
    // - Priority order follows ProcessorPriority enum order.
    // - Within the same priority, registration order is preserved.
    final all = [...builtIns, ...nonBuiltIn];
    final byPriority = <ProcessorPriority, List<Processor>>{
      for (final priority in ProcessorPriority.values) priority: <Processor>[],
    };
    for (final processor in all) {
      byPriority[processor.priority]!.add(processor);
    }

    final ordered = <Processor>[];
    for (final priority in ProcessorPriority.values) {
      ordered.addAll(byPriority[priority]!);
    }
    return ordered;
  }

  /// Pre-scan a DOM tree to collect fragment definitions before processing.
  ///
  /// For a [Document] root, [templateDocument] returns that document unprocessed when a selector or tag-name target
  /// first needs it. Without one, the root is copied now.
  void collectFragments(Node root, {Document Function()? templateDocument}) {
    if (root is Document) {
      _document = templateDocument == null ? root.clone(true) : null;
      _buildDocument = templateDocument;
    }
    if (root is Element) {
      final fragValue = root.attributes['${attrPrefix}fragment'];
      if (fragValue != null) {
        final (name, paramNames) = parseFragmentDef(fragValue);
        validateFragmentParams(name, paramNames);
        _fragmentRegistry[name] = (root.clone(true), paramNames);
      }
    }
    for (final child in root.children) {
      collectFragments(child);
    }
  }

  /// Query by CSS selector, innermost cross-file document first, then the page's unprocessed copy.
  @override
  Element? querySelectorFromDoc(String selector) {
    for (final scope in _fragmentRegistryStack.reversed) {
      final found = scope.document?.querySelector(selector);
      if (found != null) return found;
    }
    return (_document ??= _buildDocument?.call())?.querySelector(selector);
  }

  /// Look up a fragment by name, innermost pushed registry first, then the page's own.
  @override
  (Element, List<String>)? lookupFragment(String name) {
    for (final scope in _fragmentRegistryStack.reversed) {
      final found = scope.registry[name];
      if (found != null) return found;
    }
    return _fragmentRegistry[name];
  }

  @override
  void pushFragmentRegistry(Map<String, (Element, List<String>)> registry, {Document? document}) {
    _fragmentRegistryStack.add((registry: registry, document: document));
  }

  @override
  void popFragmentRegistry() {
    _fragmentRegistryStack.removeLast();
  }

  /// The temporary parent of the render root being processed by [processRenderRoot]. Its direct children, the root
  /// and any `tl:each` copies of it, are exempt from definition removal.
  Node? _renderHolder;

  /// Process a looked-up fragment as a top-level render root.
  ///
  /// [root] must already have a parent (the caller's temporary holder), because the processors that act on an element
  /// through its parent (`tl:replace`, `tl:each`, `tl:if`, `tl:remove`, `tl:block`) are no-ops on a detached one.
  /// Unlike a definition met in a document, a parameterised render root is rendered, not removed. Its `tl:fragment`
  /// attribute stays in place while processing so a processor registered on it (e.g. `tl:scope`'s) still fires.
  void processRenderRoot(Element root, Map<String, dynamic> context) {
    _renderHolder = root.parentNode;
    try {
      process(root, context);
    } finally {
      _renderHolder = null;
    }
  }

  /// Process an element and its children, applying all `tl:*` directives.
  void process(Element element, Map<String, dynamic> context) {
    var effectiveContext = context;
    var autoProcessChildren = true;
    var unwrap = element.localName == '${attrPrefix}block';
    var fragmentDefChecked = false;

    // Orphan tl:case detection — before running processors
    if (element.attributes.containsKey('${attrPrefix}case')) {
      throw TemplateException('tl:case found outside tl:switch context');
    }

    for (var i = 0; i < _processors.length; i++) {
      final processor = _processors[i];

      // Infrastructure: fragment-def removal between afterConditionals and afterIteration
      if (!fragmentDefChecked && processor.priority.index >= ProcessorPriority.afterIteration.index) {
        fragmentDefChecked = true;
        if (_removeFragmentDefinition(element)) return;
      }

      // Determine if this processor should fire
      final attrValue = _getProcessorAttribute(element, processor);
      if (attrValue == null) continue;

      final processorContext = ProcessorContext(
        variables: effectiveContext,
        evaluator: evaluator,
        attrPrefix: attrPrefix,
        prefix: prefix,
        separator: separator,
        processChildren: process,
        domProcessor: this,
        loader: loader,
      );

      final bool keepElement;
      if (_builtIns.contains(processor)) {
        keepElement = processor.process(element, attrValue, processorContext);
      } else {
        try {
          keepElement = processor.process(element, attrValue, processorContext);
        } on TemplateException {
          rethrow;
        } catch (e) {
          throw TemplateException(
            'Error in custom processor "${processor.attribute}" '
            'on <${element.localName}>: $e',
          );
        }
      }

      // Context-modifying processors update processorContext.variables
      effectiveContext = processorContext.variables;
      // Any processor that manages its own subtree opts the element out; a later processor (e.g. tl:attr after
      // tl:utext) must not opt it back in.
      autoProcessChildren =
          autoProcessChildren && processor.autoProcessChildren && !processorContext.skipsChildRecursion;
      unwrap = unwrap || processorContext.unwrapsAfterChildren;

      if (!keepElement) return;
    }

    // Infrastructure: fragment-def removal (if afterIteration group was never reached)
    if (!fragmentDefChecked && _removeFragmentDefinition(element)) return;

    // Attribute cleanup — remove all tl:* attributes from output
    final keysToRemove = element.attributes.keys.where((key) => key is String && key.startsWith(attrPrefix)).toList();
    for (final key in keysToRemove) {
      element.attributes.remove(key);
    }

    // Child recursion (respecting autoProcessChildren)
    if (autoProcessChildren) {
      for (final child in List<Element>.from(element.children)) {
        process(child, effectiveContext);
      }
    }

    // Unwrap (tl:block, tl:remove="tag"): runs after child recursion so the promoted children are already processed
    if (unwrap) _unwrap(element);
  }

  /// Get the attribute value for a processor, handling special cases.
  String? _getProcessorAttribute(Element element, Processor processor) {
    // AttrProcessor handles multiple attributes internally
    if (processor is AttrProcessor) {
      return hasAttrAttributes(element, attrPrefix) ? '' : null;
    }

    return element.attributes['$attrPrefix${processor.attribute}'];
  }

  /// Remove parameterized fragment definitions from output (step 3.5).
  bool _removeFragmentDefinition(Element element) {
    if (_renderHolder != null && identical(element.parentNode, _renderHolder)) return false;
    final fragDef = element.attributes['${attrPrefix}fragment'];
    if (fragDef != null) {
      final (_, paramNames) = parseFragmentDef(fragDef);
      if (paramNames.isNotEmpty) {
        element.remove();
        return true;
      }
    }
    return false;
  }

  void _unwrap(Element element) {
    final parent = element.parentNode;
    if (parent == null) return;
    for (final child in List<Node>.from(element.nodes)) {
      parent.insertBefore(child, element);
    }
    element.remove();
  }

  /// Process included fragment content with depth guard and cycle detection.
  @override
  void processFragmentContent(Element element, Map<String, dynamic> context, {String? fragmentId}) {
    if (_fragmentDepth >= maxFragmentDepth) {
      throw TemplateException('Fragment inclusion depth exceeded (max: $maxFragmentDepth)');
    }
    if (fragmentId != null && _inclusionStack.contains(fragmentId)) {
      final cycleStart = _inclusionStack.indexOf(fragmentId);
      final cyclePath = [..._inclusionStack.sublist(cycleStart), fragmentId];
      throw TemplateException('Fragment cycle detected: ${cyclePath.join(' → ')}');
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
