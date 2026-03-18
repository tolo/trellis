import '../exceptions.dart';
import 'utility_object.dart';

/// Expression utility object for string operations: `#strings.method(args)`.
///
/// All methods handle null input gracefully — most return null for null input,
/// except [isEmpty] which returns true, and [contains]/[startsWith]/[endsWith]
/// which return false. Non-string inputs are coerced via toString().
final class StringUtilityObject extends UtilityObject {
  @override
  String get name => 'strings';

  @override
  List<String> get availableMethods => const [
    'isEmpty',
    'length',
    'capitalize',
    'upper',
    'lower',
    'trim',
    'contains',
    'startsWith',
    'endsWith',
    'substring',
    'replace',
    'split',
    'join',
    'abbreviate',
    'pad',
    'repeat',
  ];

  @override
  dynamic call(String method, List<dynamic> args, String expression) {
    return switch (method) {
      'isEmpty' => _isEmpty(args, expression),
      'length' => _length(args, expression),
      'capitalize' => _capitalize(args, expression),
      'upper' => _upper(args, expression),
      'lower' => _lower(args, expression),
      'trim' => _trim(args, expression),
      'contains' => _contains(args, expression),
      'startsWith' => _startsWith(args, expression),
      'endsWith' => _endsWith(args, expression),
      'substring' => _substring(args, expression),
      'replace' => _replace(args, expression),
      'split' => _split(args, expression),
      'join' => _join(args, expression),
      'abbreviate' => _abbreviate(args, expression),
      'pad' => _pad(args, expression),
      'repeat' => _repeat(args, expression),
      _ => unknownMethod(method, expression),
    };
  }

  bool _isEmpty(List<dynamic> args, String expression) {
    expectArgs('isEmpty', args, 1, 1, expression);
    final value = args[0];
    return value == null || value.toString().trim().isEmpty;
  }

  int? _length(List<dynamic> args, String expression) {
    expectArgs('length', args, 1, 1, expression);
    final value = args[0];
    return value?.toString().length;
  }

  String? _capitalize(List<dynamic> args, String expression) {
    expectArgs('capitalize', args, 1, 1, expression);
    final value = args[0];
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String? _upper(List<dynamic> args, String expression) {
    expectArgs('upper', args, 1, 1, expression);
    return args[0]?.toString().toUpperCase();
  }

  String? _lower(List<dynamic> args, String expression) {
    expectArgs('lower', args, 1, 1, expression);
    return args[0]?.toString().toLowerCase();
  }

  String? _trim(List<dynamic> args, String expression) {
    expectArgs('trim', args, 1, 1, expression);
    return args[0]?.toString().trim();
  }

  bool _contains(List<dynamic> args, String expression) {
    expectArgs('contains', args, 2, 2, expression);
    final value = args[0];
    if (value == null) return false;
    return value.toString().contains(args[1].toString());
  }

  bool _startsWith(List<dynamic> args, String expression) {
    expectArgs('startsWith', args, 2, 2, expression);
    final value = args[0];
    if (value == null) return false;
    return value.toString().startsWith(args[1].toString());
  }

  bool _endsWith(List<dynamic> args, String expression) {
    expectArgs('endsWith', args, 2, 2, expression);
    final value = args[0];
    if (value == null) return false;
    return value.toString().endsWith(args[1].toString());
  }

  String? _substring(List<dynamic> args, String expression) {
    expectArgs('substring', args, 2, 3, expression);
    final value = args[0];
    if (value == null) return null;
    final s = value.toString();
    final start = (args[1] as num).toInt().clamp(0, s.length);
    final end = args.length > 2 ? (args[2] as num).toInt().clamp(start, s.length) : s.length;
    return s.substring(start, end);
  }

  String? _replace(List<dynamic> args, String expression) {
    expectArgs('replace', args, 3, 3, expression);
    final value = args[0];
    if (value == null) return null;
    return value.toString().replaceAll(args[1].toString(), args[2].toString());
  }

  List<String>? _split(List<dynamic> args, String expression) {
    expectArgs('split', args, 2, 2, expression);
    final value = args[0];
    if (value == null) return null;
    return value.toString().split(args[1].toString());
  }

  String? _join(List<dynamic> args, String expression) {
    expectArgs('join', args, 2, 2, expression);
    final value = args[0];
    if (value == null) return null;
    if (value is! List) {
      throw ExpressionException(
        '#strings.join expects a list as first argument, got ${value.runtimeType}',
        expression: expression,
      );
    }
    return value.map((e) => e?.toString() ?? '').join(args[1].toString());
  }

  String? _abbreviate(List<dynamic> args, String expression) {
    expectArgs('abbreviate', args, 2, 2, expression);
    final value = args[0];
    if (value == null) return null;
    final s = value.toString();
    final maxLength = (args[1] as num).toInt();
    if (maxLength < 4) {
      throw ExpressionException(
        '#strings.abbreviate: maxLength must be at least 4, got $maxLength',
        expression: expression,
      );
    }
    if (s.length <= maxLength) return s;
    return '${s.substring(0, maxLength - 3)}...';
  }

  String? _pad(List<dynamic> args, String expression) {
    expectArgs('pad', args, 2, 3, expression);
    final value = args[0];
    if (value == null) return null;
    final s = value.toString();
    final length = (args[1] as num).toInt();
    final char = args.length > 2 ? args[2].toString() : ' ';
    return s.padRight(length, char);
  }

  String? _repeat(List<dynamic> args, String expression) {
    expectArgs('repeat', args, 2, 2, expression);
    final value = args[0];
    if (value == null) return null;
    final times = (args[1] as num).toInt();
    return value.toString() * times;
  }
}
