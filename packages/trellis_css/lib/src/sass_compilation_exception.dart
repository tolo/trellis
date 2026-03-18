import 'package:sass/sass.dart' as sass;

/// Exception thrown when SASS/SCSS compilation fails.
///
/// Wraps the underlying SASS compiler error with file path, line, and
/// column information for clear error reporting.
class SassCompilationException implements Exception {
  /// Human-readable error message from the SASS compiler.
  final String message;

  /// The source file path where the error occurred, if available.
  final String? path;

  /// The line number where the error occurred (1-based), if available.
  final int? line;

  /// The column number where the error occurred (1-based), if available.
  final int? column;

  /// The original exception from `package:sass`.
  final Object? cause;

  /// Creates a [SassCompilationException] with the given fields.
  const SassCompilationException(this.message, {this.path, this.line, this.column, this.cause});

  /// Creates a [SassCompilationException] from a `package:sass` [SassException].
  ///
  /// Extracts the message and span information (file, line, column) from [error].
  factory SassCompilationException.fromSassException(Object error) {
    if (error is sass.SassException) {
      final span = error.span;
      final start = span.start;
      final sourceUrl = span.sourceUrl;
      return SassCompilationException(
        error.message,
        path: sourceUrl?.toFilePath(),
        line: start.line + 1,
        column: start.column + 1,
        cause: error,
      );
    }
    return SassCompilationException(error.toString(), cause: error);
  }

  @override
  String toString() => 'SassCompilationException: $message';
}
