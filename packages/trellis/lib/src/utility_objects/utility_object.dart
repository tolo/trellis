import '../exceptions.dart';

/// Base class for expression utility objects accessible via `#name.method(args)`.
///
/// Subclasses implement specific utility domains (strings, numbers, dates, lists).
/// Each utility object dispatches method calls via its [call] method.
///
/// Built-in utility objects: `#strings`, `#numbers`, `#dates`, `#lists`.
abstract class UtilityObject {
  /// The display name of this utility object (e.g., 'strings').
  String get name;

  /// List of available method names, used in error messages.
  List<String> get availableMethods;

  /// Dispatch a method call with the given arguments.
  ///
  /// Returns the result of the method call, or null for null inputs.
  /// Throws [ExpressionException] for unknown methods or invalid arguments.
  dynamic call(String method, List<dynamic> args, String expression);

  /// Validate argument count and throw [ExpressionException] if wrong.
  void expectArgs(String method, List<dynamic> args, int min, [int? max, String expression = '']) {
    final actualMax = max ?? min;
    if (args.length < min || args.length > actualMax) {
      final range = min == actualMax ? '$min' : '$min-$actualMax';
      throw ExpressionException(
        '#$name.$method expects $range argument(s), got ${args.length}',
        expression: expression,
      );
    }
  }

  /// Throw [ExpressionException] for unknown method, listing available methods.
  Never unknownMethod(String method, String expression) {
    throw ExpressionException(
      'Unknown method: #$name.$method. '
      'Available methods: ${availableMethods.join(', ')}',
      expression: expression,
    );
  }
}
