import '../exceptions.dart';
import 'utility_object.dart';

/// Expression utility object for list operations: `#lists.method(args)`.
///
/// All methods handle null input by returning null (except [isEmpty] which
/// returns true for null). Non-list inputs throw [ExpressionException]
/// (except [isEmpty]).
final class ListUtilityObject extends UtilityObject {
  @override
  String get name => 'lists';

  @override
  List<String> get availableMethods => const [
    'size',
    'isEmpty',
    'contains',
    'sort',
    'reverse',
    'first',
    'last',
    'take',
    'skip',
    'where',
    'map',
    'flatten',
    'distinct',
    'join',
  ];

  @override
  dynamic call(String method, List<dynamic> args, String expression) {
    return switch (method) {
      'size' => _size(args, expression),
      'isEmpty' => _isEmpty(args, expression),
      'contains' => _contains(args, expression),
      'sort' => _sort(args, expression),
      'reverse' => _reverse(args, expression),
      'first' => _first(args, expression),
      'last' => _last(args, expression),
      'take' => _take(args, expression),
      'skip' => _skip(args, expression),
      'where' => _where(args, expression),
      'map' => _map(args, expression),
      'flatten' => _flatten(args, expression),
      'distinct' => _distinct(args, expression),
      'join' => _join(args, expression),
      _ => unknownMethod(method, expression),
    };
  }

  List<dynamic> _requireList(dynamic value, String method, String expression) {
    if (value is! List) {
      throw ExpressionException('#lists.$method expects a list, got ${value.runtimeType}', expression: expression);
    }
    return value;
  }

  int? _size(List<dynamic> args, String expression) {
    expectArgs('size', args, 1, 1, expression);
    if (args[0] == null) return null;
    return _requireList(args[0], 'size', expression).length;
  }

  bool _isEmpty(List<dynamic> args, String expression) {
    expectArgs('isEmpty', args, 1, 1, expression);
    final value = args[0];
    if (value == null) return true;
    if (value is! List) return true;
    return value.isEmpty;
  }

  bool _contains(List<dynamic> args, String expression) {
    expectArgs('contains', args, 2, 2, expression);
    if (args[0] == null) return false;
    return _requireList(args[0], 'contains', expression).contains(args[1]);
  }

  List<dynamic>? _sort(List<dynamic> args, String expression) {
    expectArgs('sort', args, 1, 2, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'sort', expression);
    final result = List<dynamic>.from(list);
    if (args.length > 1 && args[1] != null) {
      final key = args[1].toString();
      result.sort((a, b) {
        if (a is! Map || b is! Map) return 0;
        final av = a[key];
        final bv = b[key];
        if (av == null && bv == null) return 0;
        if (av == null) return -1;
        if (bv == null) return 1;
        if (av is Comparable && bv is Comparable) return Comparable.compare(av, bv);
        return 0;
      });
    } else {
      result.sort((a, b) {
        if (a is Comparable && b is Comparable) return Comparable.compare(a, b);
        return 0;
      });
    }
    return result;
  }

  List<dynamic>? _reverse(List<dynamic> args, String expression) {
    expectArgs('reverse', args, 1, 1, expression);
    if (args[0] == null) return null;
    return _requireList(args[0], 'reverse', expression).reversed.toList();
  }

  dynamic _first(List<dynamic> args, String expression) {
    expectArgs('first', args, 1, 1, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'first', expression);
    return list.isEmpty ? null : list.first;
  }

  dynamic _last(List<dynamic> args, String expression) {
    expectArgs('last', args, 1, 1, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'last', expression);
    return list.isEmpty ? null : list.last;
  }

  List<dynamic>? _take(List<dynamic> args, String expression) {
    expectArgs('take', args, 2, 2, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'take', expression);
    final n = (args[1] as num).toInt();
    return list.take(n).toList();
  }

  List<dynamic>? _skip(List<dynamic> args, String expression) {
    expectArgs('skip', args, 2, 2, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'skip', expression);
    final n = (args[1] as num).toInt();
    return list.skip(n).toList();
  }

  List<dynamic>? _where(List<dynamic> args, String expression) {
    expectArgs('where', args, 3, 4, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'where', expression);
    final property = args[1] as String;

    if (args.length == 3) {
      // Equality filter: where(list, property, value)
      final value = args[2];
      return list.where((item) {
        if (item is! Map) return false;
        return item[property] == value;
      }).toList();
    }

    // Operator filter: where(list, property, operator, value)
    final op = args[2] as String;
    final value = args[3];
    return list.where((item) {
      if (item is! Map) return false;
      return _compareWithOp(item[property], op, value, expression);
    }).toList();
  }

  bool _compareWithOp(dynamic a, String op, dynamic b, String expression) {
    switch (op) {
      case '==':
        return a == b;
      case '!=':
        return a != b;
      case '>':
      case '<':
      case '>=':
      case '<=':
        if (a is! Comparable || b is! Comparable) {
          throw ExpressionException(
            '#lists.where: cannot compare ${a.runtimeType} with ${b.runtimeType} using "$op"',
            expression: expression,
          );
        }
        final int cmp;
        try {
          cmp = a.compareTo(b);
        } on TypeError {
          throw ExpressionException(
            '#lists.where: cannot compare ${a.runtimeType} with ${b.runtimeType} using "$op"',
            expression: expression,
          );
        }
        return switch (op) {
          '>' => cmp > 0,
          '<' => cmp < 0,
          '>=' => cmp >= 0,
          '<=' => cmp <= 0,
          _ => false,
        };
      default:
        throw ExpressionException(
          '#lists.where: unknown operator "$op". Supported: ==, !=, >, <, >=, <=',
          expression: expression,
        );
    }
  }

  List<dynamic>? _map(List<dynamic> args, String expression) {
    expectArgs('map', args, 2, 2, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'map', expression);
    final property = args[1] as String;
    return list.map((item) {
      if (item is Map) return item[property];
      return null;
    }).toList();
  }

  List<dynamic>? _flatten(List<dynamic> args, String expression) {
    expectArgs('flatten', args, 1, 1, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'flatten', expression);
    return _flattenList(list);
  }

  List<dynamic> _flattenList(List<dynamic> list) {
    final result = <dynamic>[];
    for (final item in list) {
      if (item is List) {
        result.addAll(_flattenList(item));
      } else {
        result.add(item);
      }
    }
    return result;
  }

  List<dynamic>? _distinct(List<dynamic> args, String expression) {
    expectArgs('distinct', args, 1, 1, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'distinct', expression);
    final seen = <dynamic>{};
    return list.where(seen.add).toList();
  }

  String? _join(List<dynamic> args, String expression) {
    expectArgs('join', args, 1, 2, expression);
    if (args[0] == null) return null;
    final list = _requireList(args[0], 'join', expression);
    final delimiter = args.length > 1 && args[1] != null ? args[1].toString() : ', ';
    return list.map((e) => e?.toString() ?? '').join(delimiter);
  }
}
