import 'dart:math' as math;

import '../evaluator.dart';
import '../exceptions.dart';
import 'utility_object.dart';

/// Expression utility object for numeric operations: `#numbers.method(args)`.
///
/// All methods handle null input by returning null.
/// Non-number string inputs are coerced via [num.tryParse].
/// When [ExpressionEvaluator.formattingDelegate] is set, `format` delegates
/// to it for locale-aware formatting; otherwise built-in English formatting is used.
final class NumberUtilityObject extends UtilityObject {
  @override
  String get name => 'numbers';

  @override
  List<String> get availableMethods => const [
    'format',
    'formatPercent',
    'formatCurrency',
    'abs',
    'ceil',
    'floor',
    'round',
    'min',
    'max',
    'clamp',
  ];

  @override
  dynamic call(String method, List<dynamic> args, String expression) {
    return switch (method) {
      'format' => _format(args, expression),
      'formatPercent' => _formatPercent(args, expression),
      'formatCurrency' => _formatCurrency(args, expression),
      'abs' => _abs(args, expression),
      'ceil' => _ceil(args, expression),
      'floor' => _floor(args, expression),
      'round' => _round(args, expression),
      'min' => _min(args, expression),
      'max' => _max(args, expression),
      'clamp' => _clamp(args, expression),
      _ => unknownMethod(method, expression),
    };
  }

  num _coerce(dynamic value, String method, String expression) {
    if (value is num) return value;
    final parsed = num.tryParse(value.toString());
    if (parsed != null) return parsed;
    throw ExpressionException('#numbers.$method expects a number, got ${value.runtimeType}', expression: expression);
  }

  String? _format(List<dynamic> args, String expression) {
    expectArgs('format', args, 1, 2, expression);
    if (args[0] == null) return null;
    final value = _coerce(args[0], 'format', expression);
    final pattern = args.length > 1 ? args[1]?.toString() : null;

    if (pattern != null) {
      final delegate = ExpressionEvaluator.formattingDelegate;
      if (delegate != null) {
        final result = delegate.formatNumber(value, pattern);
        if (result != null) return result;
      }
      return _builtinFormat(value, pattern);
    }
    return value.toString();
  }

  String _builtinFormat(num value, String pattern) {
    if (pattern == '0.00' || RegExp(r'^0+\.0+$').hasMatch(pattern)) {
      final decimals = pattern.contains('.') ? pattern.split('.').last.length : 0;
      return value.toStringAsFixed(decimals);
    }
    if (pattern == '#,###') {
      return _formatWithGrouping(value.truncate().toString(), null);
    }
    if (pattern == '#,##0.00' || pattern == '#,##0.0') {
      final decimals = pattern.contains('.') ? pattern.split('.').last.length : 0;
      final parts = value.toStringAsFixed(decimals).split('.');
      return '${_formatWithGrouping(parts[0], null)}.${parts[1]}';
    }
    // Fallback: check if pattern has decimal places specified
    if (pattern.contains('.')) {
      final parts = pattern.split('.');
      final decimals = parts.last.replaceAll(RegExp(r'[^0#]'), '').length;
      if (pattern.contains(',')) {
        final formatted = value.toStringAsFixed(decimals).split('.');
        return '${_formatWithGrouping(formatted[0], null)}.${formatted[1]}';
      }
      return value.toStringAsFixed(decimals);
    }
    return value.toString();
  }

  String _formatWithGrouping(String intPart, String? sign) {
    final isNegative = intPart.startsWith('-');
    final digits = isNegative ? intPart.substring(1) : intPart;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return isNegative ? '-$buffer' : buffer.toString();
  }

  String? _formatPercent(List<dynamic> args, String expression) {
    expectArgs('formatPercent', args, 1, 2, expression);
    if (args[0] == null) return null;
    final value = _coerce(args[0], 'formatPercent', expression);
    final decimals = args.length > 1 && args[1] != null ? (args[1] as num).toInt() : 0;
    return '${(value * 100).toStringAsFixed(decimals)}%';
  }

  String? _formatCurrency(List<dynamic> args, String expression) {
    expectArgs('formatCurrency', args, 1, 2, expression);
    if (args[0] == null) return null;
    final value = _coerce(args[0], 'formatCurrency', expression);
    final code = args.length > 1 && args[1] != null ? args[1].toString() : 'USD';
    return '$code ${value.toStringAsFixed(2)}';
  }

  num? _abs(List<dynamic> args, String expression) {
    expectArgs('abs', args, 1, 1, expression);
    if (args[0] == null) return null;
    return _coerce(args[0], 'abs', expression).abs();
  }

  int? _ceil(List<dynamic> args, String expression) {
    expectArgs('ceil', args, 1, 1, expression);
    if (args[0] == null) return null;
    return _coerce(args[0], 'ceil', expression).ceil();
  }

  int? _floor(List<dynamic> args, String expression) {
    expectArgs('floor', args, 1, 1, expression);
    if (args[0] == null) return null;
    return _coerce(args[0], 'floor', expression).floor();
  }

  num? _round(List<dynamic> args, String expression) {
    expectArgs('round', args, 1, 2, expression);
    if (args[0] == null) return null;
    final value = _coerce(args[0], 'round', expression);
    if (args.length > 1 && args[1] != null) {
      final decimals = (args[1] as num).toInt();
      return double.parse(value.toStringAsFixed(decimals));
    }
    return value.round();
  }

  num? _min(List<dynamic> args, String expression) {
    expectArgs('min', args, 2, 2, expression);
    if (args[0] == null || args[1] == null) return null;
    final a = _coerce(args[0], 'min', expression);
    final b = _coerce(args[1], 'min', expression);
    return math.min(a, b);
  }

  num? _max(List<dynamic> args, String expression) {
    expectArgs('max', args, 2, 2, expression);
    if (args[0] == null || args[1] == null) return null;
    final a = _coerce(args[0], 'max', expression);
    final b = _coerce(args[1], 'max', expression);
    return math.max(a, b);
  }

  num? _clamp(List<dynamic> args, String expression) {
    expectArgs('clamp', args, 3, 3, expression);
    if (args[0] == null) return null;
    final value = _coerce(args[0], 'clamp', expression);
    final minVal = _coerce(args[1], 'clamp', expression);
    final maxVal = _coerce(args[2], 'clamp', expression);
    return value.clamp(minVal, maxVal);
  }
}
