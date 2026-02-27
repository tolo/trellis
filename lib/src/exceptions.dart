/// Base exception for all trellis template errors.
class TemplateException implements Exception {
  final String message;

  TemplateException(this.message);

  @override
  String toString() => 'TemplateException: $message';
}

/// Exception thrown when a named fragment is not found in a template.
class FragmentNotFoundException extends TemplateException {
  final String fragmentName;
  final String? templateName;

  FragmentNotFoundException(this.fragmentName, {this.templateName})
    : super(
        templateName != null
            ? 'Fragment "$fragmentName" not found in template "$templateName"'
            : 'Fragment "$fragmentName" not found',
      );
}

/// Exception thrown when a template cannot be loaded by name.
class TemplateNotFoundException extends TemplateException {
  final String templateName;

  TemplateNotFoundException(this.templateName) : super('Template "$templateName" not found');
}

/// Exception thrown when a security boundary is violated (e.g. path traversal).
class TemplateSecurityException extends TemplateException {
  TemplateSecurityException(super.message);

  @override
  String toString() => 'TemplateSecurityException: $message';
}

/// Exception thrown when an expression cannot be parsed or evaluated.
class ExpressionException extends TemplateException {
  final String expression;
  final int? position;

  ExpressionException(super.message, {required this.expression, this.position});

  @override
  String toString() {
    final buffer = StringBuffer('ExpressionException: $message');
    if (position != null) {
      buffer.writeln();
      buffer.writeln('  $expression');
      buffer.write('  ${''.padLeft(position!, ' ')}^');
    }
    return buffer.toString();
  }
}
