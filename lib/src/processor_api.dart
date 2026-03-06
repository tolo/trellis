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

  /// Reference to DomProcessor for fragment-related operations (package-private).
  /// Typed as dynamic to avoid circular import; cast in processor implementations.
  final dynamic domProcessor;

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
