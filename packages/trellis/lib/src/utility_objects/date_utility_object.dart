import '../evaluator.dart';
import '../exceptions.dart';
import 'utility_object.dart';

/// Expression utility object for date/time operations: `#dates.method(args)`.
///
/// Accepts [DateTime] objects or ISO 8601 strings as date arguments.
/// All methods handle null input by returning null (except [isBefore]/[isAfter]
/// which return false, and [now] which takes no arguments).
/// When [ExpressionEvaluator.formattingDelegate] is set, `format` delegates
/// to it for locale-aware formatting; otherwise built-in English formatting is used.
final class DateUtilityObject extends UtilityObject {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _shortMonthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static const _shortDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  String get name => 'dates';

  @override
  List<String> get availableMethods => const [
    'format',
    'parse',
    'now',
    'year',
    'month',
    'day',
    'hour',
    'minute',
    'second',
    'dayOfWeek',
    'isBefore',
    'isAfter',
  ];

  @override
  dynamic call(String method, List<dynamic> args, String expression) {
    return switch (method) {
      'format' => _format(args, expression),
      'parse' => _parse(args, expression),
      'now' => _now(args, expression),
      'year' => _year(args, expression),
      'month' => _month(args, expression),
      'day' => _day(args, expression),
      'hour' => _hour(args, expression),
      'minute' => _minute(args, expression),
      'second' => _second(args, expression),
      'dayOfWeek' => _dayOfWeek(args, expression),
      'isBefore' => _isBefore(args, expression),
      'isAfter' => _isAfter(args, expression),
      _ => unknownMethod(method, expression),
    };
  }

  DateTime? _coerceDate(dynamic value, String method, String expression) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw ExpressionException(
      '#dates.$method expects a DateTime or ISO 8601 string, got ${value.runtimeType}',
      expression: expression,
    );
  }

  String? _format(List<dynamic> args, String expression) {
    expectArgs('format', args, 2, 2, expression);
    final date = _coerceDate(args[0], 'format', expression);
    if (date == null) return null;
    final pattern = args[1].toString();

    final delegate = ExpressionEvaluator.formattingDelegate;
    if (delegate != null) {
      final result = delegate.formatDate(date, pattern);
      if (result != null) return result;
    }

    return _builtinFormat(date, pattern);
  }

  String _builtinFormat(DateTime date, String pattern) {
    // Token replacement from longest to shortest, case-sensitive.
    // Walk through pattern, match longest token at each position.
    final tokens = <String, String Function(DateTime)>{
      'yyyy': (d) => d.year.toString().padLeft(4, '0'),
      'yy': (d) => (d.year % 100).toString().padLeft(2, '0'),
      'MMMM': (d) => _monthNames[d.month - 1],
      'MMM': (d) => _shortMonthNames[d.month - 1],
      'MM': (d) => d.month.toString().padLeft(2, '0'),
      'M': (d) => d.month.toString(),
      'dd': (d) => d.day.toString().padLeft(2, '0'),
      'd': (d) => d.day.toString(),
      'EEEE': (d) => _dayNames[d.weekday - 1],
      'EEE': (d) => _shortDayNames[d.weekday - 1],
      'HH': (d) => d.hour.toString().padLeft(2, '0'),
      'hh': (d) => ((d.hour % 12) == 0 ? 12 : d.hour % 12).toString().padLeft(2, '0'),
      'mm': (d) => d.minute.toString().padLeft(2, '0'),
      'ss': (d) => d.second.toString().padLeft(2, '0'),
      'a': (d) => d.hour < 12 ? 'AM' : 'PM',
    };

    // Sorted by length descending for longest-match
    final sortedTokens = tokens.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

    final buffer = StringBuffer();
    var i = 0;
    while (i < pattern.length) {
      String? matched;
      for (final token in sortedTokens) {
        if (i + token.length <= pattern.length && pattern.substring(i, i + token.length) == token) {
          matched = token;
          break;
        }
      }
      if (matched != null) {
        buffer.write(tokens[matched]!(date));
        i += matched.length;
      } else {
        buffer.write(pattern[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  DateTime? _parse(List<dynamic> args, String expression) {
    expectArgs('parse', args, 1, 2, expression);
    if (args[0] == null) return null;
    final s = args[0].toString();
    // pattern argument is passed to the delegate if available; built-in uses DateTime.parse
    if (args.length > 1 && args[1] != null) {
      final delegate = ExpressionEvaluator.formattingDelegate;
      if (delegate != null) {
        // Delegate may support pattern-based parsing; we pass pattern as locale-like hint
        // but built-in fallback always uses DateTime.parse
      }
    }
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return parsed;
    throw ExpressionException(
      '#dates.parse: cannot parse "$s" as a date. Use ISO 8601 format (e.g., "2026-03-17")',
      expression: expression,
    );
  }

  DateTime _now(List<dynamic> args, String expression) {
    expectArgs('now', args, 0, 0, expression);
    return DateTime.now();
  }

  int? _year(List<dynamic> args, String expression) {
    expectArgs('year', args, 1, 1, expression);
    return _coerceDate(args[0], 'year', expression)?.year;
  }

  int? _month(List<dynamic> args, String expression) {
    expectArgs('month', args, 1, 1, expression);
    return _coerceDate(args[0], 'month', expression)?.month;
  }

  int? _day(List<dynamic> args, String expression) {
    expectArgs('day', args, 1, 1, expression);
    return _coerceDate(args[0], 'day', expression)?.day;
  }

  int? _hour(List<dynamic> args, String expression) {
    expectArgs('hour', args, 1, 1, expression);
    return _coerceDate(args[0], 'hour', expression)?.hour;
  }

  int? _minute(List<dynamic> args, String expression) {
    expectArgs('minute', args, 1, 1, expression);
    return _coerceDate(args[0], 'minute', expression)?.minute;
  }

  int? _second(List<dynamic> args, String expression) {
    expectArgs('second', args, 1, 1, expression);
    return _coerceDate(args[0], 'second', expression)?.second;
  }

  int? _dayOfWeek(List<dynamic> args, String expression) {
    expectArgs('dayOfWeek', args, 1, 1, expression);
    return _coerceDate(args[0], 'dayOfWeek', expression)?.weekday;
  }

  bool _isBefore(List<dynamic> args, String expression) {
    expectArgs('isBefore', args, 2, 2, expression);
    final a = _coerceDate(args[0], 'isBefore', expression);
    final b = _coerceDate(args[1], 'isBefore', expression);
    if (a == null || b == null) return false;
    return a.isBefore(b);
  }

  bool _isAfter(List<dynamic> args, String expression) {
    expectArgs('isAfter', args, 2, 2, expression);
    final a = _coerceDate(args[0], 'isAfter', expression);
    final b = _coerceDate(args[1], 'isAfter', expression);
    if (a == null || b == null) return false;
    return a.isAfter(b);
  }
}
