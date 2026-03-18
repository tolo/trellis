/// Delegate for locale-aware number and date formatting.
///
/// Register via [ExpressionEvaluator.formattingDelegate] to enable
/// locale-aware formatting in `#numbers.format` and `#dates.format`.
///
/// When null (the default), built-in English-only formatting is used.
///
/// Example using package:intl:
/// ```dart
/// ExpressionEvaluator.formattingDelegate = MyIntlFormattingDelegate();
/// ```
abstract class FormattingDelegate {
  /// Format a number using the given pattern and optional locale.
  ///
  /// Returns null if formatting is not supported for the given pattern/locale.
  String? formatNumber(num value, String pattern, {String? locale});

  /// Format a date using the given pattern and optional locale.
  ///
  /// Returns null if formatting is not supported for the given pattern/locale.
  String? formatDate(DateTime date, String pattern, {String? locale});
}
