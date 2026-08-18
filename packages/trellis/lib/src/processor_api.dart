import 'package:html/dom.dart';

import 'evaluator.dart';
import 'loaders/template_loader.dart';

/// Priority slots for processor ordering [D02].
/// Multiple processors at same slot: ordered by registration order.
enum ProcessorPriority {
  highest, // tl:with, tl:object, tl:if, tl:unless, tl:switch
  afterLocals, // (custom slot)
  afterConditionals, // tl:each
  afterIteration, // tl:insert, tl:replace
  afterInclusion, // tl:text, tl:utext, tl:inline
  afterContent, // tl:attr + shorthands + classappend + styleappend
  afterAttributes, // tl:remove
  lowest, // (custom slot)
}

/// Base class for processors (built-in and custom) [D01].
abstract class Processor {
  /// Attribute suffix (e.g. 'with' for tl:with, 'text' for tl:text).
  String get attribute;

  /// Priority slot for ordering relative to other processors [D02].
  ProcessorPriority get priority;

  /// Whether children are auto-processed after process() returns true [D04].
  /// Override to false for processors that manage their own subtree.
  bool get autoProcessChildren => true;

  /// Process an element. Returns true if element remains in DOM,
  /// false if element was removed/consumed [D05].
  bool process(Element element, String value, ProcessorContext context);
}

/// The fragment-resolution surface a processor may use, implemented by the
/// engine's DOM processor.
///
/// Exists so [ProcessorContext.domProcessor] can be typed without exposing the
/// whole `DomProcessor`: fragment processors need these six members and
/// nothing else. `ProcessorContext` is public API while `DomProcessor` is not,
/// so this narrow contract is what crosses the boundary.
abstract interface class FragmentHost {
  /// The evaluator used to bind fragment arguments.
  ExpressionEvaluator get evaluator;

  /// Processes a fragment's cloned content, enforcing depth and cycle limits.
  ///
  /// [fragmentId] identifies the invocation for cycle detection.
  void processFragmentContent(Element element, Map<String, dynamic> context, {String? fragmentId});

  /// Queries the stored document by CSS selector, for same-file selector-based
  /// fragment targeting.
  Element? querySelectorFromDoc(String selector);

  /// Looks up a same-file fragment by name, innermost pushed registry first.
  ///
  /// Returns the fragment element and its declared parameter names.
  (Element, List<String>)? lookupFragment(String name);

  /// Pushes a fragment registry, shadowing outer ones for nested resolution.
  void pushFragmentRegistry(Map<String, (Element, List<String>)> registry);

  /// Pops the most recently pushed fragment registry.
  void popFragmentRegistry();
}

/// Context passed to processors during execution [D09].
/// Provides limited API — ExpressionEvaluator remains internal.
class ProcessorContext {
  /// Current context variables. Mutable — context-modifying processors
  /// (tl:with, tl:object) update this directly.
  Map<String, dynamic> variables;

  /// Internal evaluator reference — not part of public API.
  /// Built-in processors in this package may access this directly.
  final ExpressionEvaluator evaluator;

  /// The combined attribute prefix (e.g. 'tl:' or 'data-tl-').
  final String attrPrefix;

  /// The prefix (e.g. 'tl' or 'data-tl').
  final String prefix;

  /// The separator character (':' or '-').
  final String separator;

  final void Function(Element, Map<String, dynamic>) _processChildren;

  /// Fragment-resolution operations provided by the engine's DOM processor.
  final FragmentHost domProcessor;

  /// Reference to the template loader.
  final TemplateLoader loader;

  ProcessorContext({
    required this.variables,
    required this.evaluator,
    required this.attrPrefix,
    required this.prefix,
    required this.separator,
    required void Function(Element, Map<String, dynamic>) processChildren,
    required this.domProcessor,
    required this.loader,
  }) : _processChildren = processChildren;

  /// Evaluate an expression against a context map [D09].
  dynamic evaluate(String expression, Map<String, dynamic> context) {
    return evaluator.evaluate(expression, context);
  }

  /// Process children of an element with the given context [D04].
  void processChildren(Element element, Map<String, dynamic> context) {
    _processChildren(element, context);
  }
}
