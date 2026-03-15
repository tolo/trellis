import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'dialect.dart';
import 'exceptions.dart';
import 'expression/parser.dart';
import 'loaders/template_loader.dart';
import 'processor_api.dart';
import 'processors/attr_processor.dart';
import 'processors/fragment_processor.dart' show parseFragmentDef;
import 'utils/binding_parser.dart';
import 'utils/html_normalizer.dart';

/// Severity assigned to a [ValidationError].
enum ValidationSeverity { error, warning }

/// A single template validation issue.
final class ValidationError {
  /// Human-readable validation message.
  final String message;

  /// Element tag name, when available.
  final String? element;

  /// Full template attribute name, when available.
  final String? attribute;

  /// Validation severity.
  final ValidationSeverity severity;

  /// Source line number, 1-based when available.
  final int? line;

  const ValidationError({required this.message, required this.severity, this.element, this.attribute, this.line});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationError &&
          other.message == message &&
          other.element == element &&
          other.attribute == attribute &&
          other.severity == severity &&
          other.line == line;

  @override
  int get hashCode => Object.hash(message, element, attribute, severity, line);

  @override
  String toString() =>
      'ValidationError(message: $message, element: $element, attribute: $attribute, severity: $severity, line: $line)';
}

/// Static validator for trellis templates.
///
/// The configuration mirrors [Trellis] so validation can use the same prefix
/// and processor set as the runtime engine.
final class TemplateValidator {
  /// Template attribute prefix, for example `tl` or `data-tl`.
  final String prefix;

  /// Engine dialects contributing known processors and filters.
  final List<Dialect> dialects;

  /// Directly registered processors.
  final List<Processor> processors;

  /// Engine filters. Included to mirror [Trellis] configuration.
  final Map<String, Function> filters;

  /// Whether standard trellis processors are considered enabled.
  final bool includeStandard;

  late final String _separator = prefix.contains('-') ? '-' : ':';
  late final String _attrPrefix = '$prefix$_separator';
  late final Set<String> _knownAttributes = _buildKnownAttributes();

  TemplateValidator({
    this.prefix = 'tl',
    List<Dialect>? dialects,
    List<Processor>? processors,
    Map<String, Function>? filters,
    this.includeStandard = true,
  }) : dialects = dialects ?? const [],
       processors = processors ?? const [],
       filters = filters ?? const {};

  /// Validate a template source string.
  ///
  /// Never throws. All issues are returned as [ValidationError] values.
  List<ValidationError> validate(String source) {
    try {
      final normalized = fixSelfClosingBlocks(source, prefix: prefix, separator: _separator);
      final doc = html_parser.parse(normalized);
      final errors = <ValidationError>[];
      final defineNames = <String>{};
      final root = doc.documentElement;
      if (root != null) {
        _walk(root, errors, defineNames: defineNames);
      }
      return errors;
    } catch (error) {
      return [ValidationError(message: 'Validator failed: $error', severity: ValidationSeverity.error)];
    }
  }

  /// Load and validate a named template from [loader].
  ///
  /// Never throws. Load failures are returned as [ValidationError] values.
  Future<List<ValidationError>> validateFile(String name, TemplateLoader loader) async {
    try {
      return validate(await loader.load(name));
    } catch (error) {
      return [ValidationError(message: 'Failed to load template "$name": $error', severity: ValidationSeverity.error)];
    }
  }

  Set<String> _buildKnownAttributes() {
    final known = <String>{'fragment', 'case', 'extends', 'define'};
    for (final processor in _configuredProcessors()) {
      known.add(processor.attribute);
      if (processor is AttrProcessor) {
        known.addAll(_attrShorthands);
      }
    }
    return known;
  }

  Iterable<Processor> _configuredProcessors() sync* {
    if (includeStandard) {
      yield* StandardDialect().processors;
    }
    for (final dialect in dialects) {
      yield* dialect.processors;
    }
    yield* processors;
  }

  void _walk(Element element, List<ValidationError> errors, {required Set<String> defineNames}) {
    for (final entry in element.attributes.entries) {
      if (entry.key is! String) {
        continue;
      }

      final attribute = entry.key as String;
      if (!attribute.startsWith(_attrPrefix)) {
        continue;
      }

      final suffix = attribute.substring(_attrPrefix.length);
      if (!_knownAttributes.contains(suffix)) {
        errors.add(
          ValidationError(
            message: 'Unknown trellis attribute "$attribute"',
            element: element.localName,
            attribute: attribute,
            severity: ValidationSeverity.warning,
            line: _lineFor(element),
          ),
        );
        continue;
      }

      _validateAttribute(element, attribute, suffix, entry.value, errors, defineNames: defineNames);
    }

    for (final child in element.children) {
      _walk(child, errors, defineNames: defineNames);
    }
  }

  void _validateAttribute(
    Element element,
    String attribute,
    String suffix,
    String value,
    List<ValidationError> errors, {
    required Set<String> defineNames,
  }) {
    if (_expressionAttributes.contains(suffix)) {
      _validateExpression(element, attribute, value, errors);
      return;
    }

    if (_bindingAttributes.contains(suffix)) {
      _validateBindings(element, attribute, value, errors);
      return;
    }

    if (_singleExpressionAttributes.contains(suffix)) {
      _validateExpression(element, attribute, value, errors);
      return;
    }

    switch (suffix) {
      case 'each':
        _validateEach(element, attribute, value, errors);
      case 'inline':
        if (!_inlineValues.contains(value.trim())) {
          _addError(errors, element: element, attribute: attribute, message: 'Invalid inline mode "$value"');
        }
      case 'remove':
        final trimmed = value.trim();
        if (!_removeValues.contains(trimmed)) {
          _validateExpression(element, attribute, value, errors);
        }
      case 'fragment':
        _validateFragmentDefinition(element, attribute, value, errors);
      case 'insert':
      case 'replace':
        _validateFragmentReference(element, attribute, value, errors);
      case 'case':
        if (value.trim() != '*') {
          _validateExpression(element, attribute, value, errors);
        }
      case 'extends':
        if (value.trim().isEmpty) {
          _addError(errors, element: element, attribute: attribute, message: 'tl:extends value cannot be empty');
        }
      case 'define':
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          _addError(errors, element: element, attribute: attribute, message: 'tl:define value cannot be empty');
        } else if (!defineNames.add(trimmed)) {
          errors.add(
            ValidationError(
              message: 'Duplicate tl:define block name "$trimmed"',
              element: element.localName,
              attribute: attribute,
              severity: ValidationSeverity.warning,
              line: _lineFor(element),
            ),
          );
        }
    }
  }

  void _validateExpression(Element element, String attribute, String value, List<ValidationError> errors) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _addError(errors, element: element, attribute: attribute, message: 'Expression value cannot be empty');
      return;
    }

    try {
      Parser(trimmed).parse();
    } on ExpressionException catch (error) {
      _addError(errors, element: element, attribute: attribute, message: error.message);
    } on Exception catch (error) {
      _addError(errors, element: element, attribute: attribute, message: '$error');
    }
  }

  void _validateBindings(Element element, String attribute, String value, List<ValidationError> errors) {
    try {
      for (final (_, expression) in parseBindings(value)) {
        _validateExpression(element, attribute, expression, errors);
      }
    } on TemplateException catch (error) {
      _addError(errors, element: element, attribute: attribute, message: error.message);
    } on Exception catch (error) {
      _addError(errors, element: element, attribute: attribute, message: '$error');
    }
  }

  void _validateEach(Element element, String attribute, String value, List<ValidationError> errors) {
    final colonIndex = findTopLevelDelimiter(value, ':');
    if (colonIndex == -1) {
      _addError(
        errors,
        element: element,
        attribute: attribute,
        message: 'Invalid tl:each syntax: expected "item : \${collection}"',
      );
      return;
    }

    final leftSide = value.substring(0, colonIndex).trim();
    final rightSide = value.substring(colonIndex + 1).trim();
    if (leftSide.isEmpty || rightSide.isEmpty) {
      _addError(
        errors,
        element: element,
        attribute: attribute,
        message: 'Invalid tl:each syntax: expected "item : \${collection}"',
      );
      return;
    }

    _validateExpression(element, attribute, rightSide, errors);
  }

  void _validateFragmentDefinition(Element element, String attribute, String value, List<ValidationError> errors) {
    try {
      final (name, params) = parseFragmentDef(value);
      if (name.isEmpty) {
        _addError(errors, element: element, attribute: attribute, message: 'Fragment name cannot be empty');
      }
      if (params.any((param) => param.isEmpty)) {
        _addError(errors, element: element, attribute: attribute, message: 'Fragment parameters cannot be empty');
      }
    } on Exception catch (error) {
      _addError(errors, element: element, attribute: attribute, message: '$error');
    }
  }

  void _validateFragmentReference(Element element, String attribute, String value, List<ValidationError> errors) {
    try {
      final (_, args) = _parseFragmentReference(value);
      for (final expression in args) {
        _validateExpression(element, attribute, expression, errors);
      }
    } on FormatException catch (error) {
      _addError(errors, element: element, attribute: attribute, message: error.message);
    } on Exception catch (error) {
      _addError(errors, element: element, attribute: attribute, message: '$error');
    }
  }

  int? _lineFor(Element element) {
    final line = element.sourceSpan?.start.line;
    return line == null ? null : line + 1;
  }

  void _addError(
    List<ValidationError> errors, {
    required Element element,
    required String attribute,
    required String message,
  }) {
    errors.add(
      ValidationError(
        message: message,
        element: element.localName,
        attribute: attribute,
        severity: ValidationSeverity.error,
        line: _lineFor(element),
      ),
    );
  }
}

const _expressionAttributes = {'text', 'utext', 'if', 'unless', 'switch', 'object'};
const _bindingAttributes = {'with', 'attr'};
const _singleExpressionAttributes = {'classappend', 'styleappend', 'href', 'src', 'value', 'class', 'id'};
const _attrShorthands = {'href', 'src', 'value', 'class', 'id', 'classappend', 'styleappend'};
const _inlineValues = {'text', 'javascript', 'css', 'none'};
const _removeValues = {'all', 'body', 'tag', 'all-but-first', 'none'};

(String target, List<String> argExprs) _parseFragmentReference(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('~{')) {
    return _parseFragmentInvocation(trimmed);
  }

  if (!trimmed.endsWith('}')) {
    throw const FormatException('Fragment reference must use ~{...} syntax');
  }

  final inner = trimmed.substring(2, trimmed.length - 1).trim();
  if (inner.isEmpty) {
    throw const FormatException('Fragment reference cannot be empty');
  }

  final separatorIndex = _findFragmentSeparator(inner);
  final target = separatorIndex == -1 ? inner : inner.substring(separatorIndex + 2).trim();
  if (target.isEmpty) {
    throw const FormatException('Fragment target cannot be empty');
  }

  return _parseFragmentInvocation(target);
}

int _findFragmentSeparator(String input) {
  var braceDepth = 0;
  var parenDepth = 0;
  String? quote;

  for (var i = 0; i < input.length - 1; i++) {
    final char = input[i];
    if (quote != null) {
      if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char == '{') {
      braceDepth++;
      continue;
    }
    if (char == '}') {
      braceDepth--;
      continue;
    }
    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')') {
      parenDepth--;
      continue;
    }
    if (char == ':' && input[i + 1] == ':' && braceDepth == 0 && parenDepth == 0) {
      return i;
    }
  }

  return -1;
}

(String target, List<String> argExprs) _parseFragmentInvocation(String value) {
  final parenIndex = value.indexOf('(');
  if (parenIndex == -1) {
    return (value.trim(), const []);
  }

  final closeIndex = value.lastIndexOf(')');
  if (closeIndex == -1 || closeIndex < parenIndex) {
    throw const FormatException('Malformed fragment arguments');
  }

  final target = value.substring(0, parenIndex).trim();
  if (target.isEmpty) {
    throw const FormatException('Fragment target cannot be empty');
  }

  final inner = value.substring(parenIndex + 1, closeIndex).trim();
  if (inner.isEmpty) {
    return (target, const []);
  }
  return (target, splitTopLevel(inner));
}
