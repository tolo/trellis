import 'exceptions.dart';
import 'expression/ast.dart';
import 'expression/parser.dart';
import 'truthiness.dart';

/// Evaluates trellis template expressions against a context map.
class ExpressionEvaluator {
  /// Reserved context key for the selection object set by tl:object.
  static const selectionKey = '__trellis_selection__';

  final Map<String, dynamic Function(dynamic)> _filters;
  final bool _strict;

  ExpressionEvaluator({Map<String, dynamic Function(dynamic)>? filters, bool strict = false})
    : _filters = {..._builtinFilters, ...?filters},
      _strict = strict;

  static const _builtinFilters = <String, dynamic Function(dynamic)>{
    'upper': _filterUpper,
    'lower': _filterLower,
    'trim': _filterTrim,
    'length': _filterLength,
  };

  static dynamic _filterUpper(dynamic v) => v?.toString().toUpperCase();
  static dynamic _filterLower(dynamic v) => v?.toString().toLowerCase();
  static dynamic _filterTrim(dynamic v) => v?.toString().trim();
  static dynamic _filterLength(dynamic v) => v is Iterable ? v.length : (v?.toString().length ?? 0);

  String _currentExpression = '';

  /// Evaluate an expression string against a context map.
  dynamic evaluate(String expression, Map<String, dynamic> context) {
    _currentExpression = expression;
    try {
      final parser = Parser(expression);
      final ast = parser.parse();
      return _eval(ast, context);
    } on ExpressionException {
      rethrow;
    } on Exception catch (e) {
      throw ExpressionException(e.toString(), expression: expression);
    }
  }

  dynamic _eval(Expr node, Map<String, dynamic> context) => switch (node) {
    LiteralExpr(:final value) => value,
    VariableExpr(:final name) => _evalVariable(name, context),
    MemberAccessExpr(:final object, :final member) => _evalMember(object, member, context),
    IndexAccessExpr(:final object, :final index) => _evalIndex(object, index, context),
    UnaryExpr(:final op, :final operand) => _evalUnary(op, operand, context),
    BinaryExpr(:final left, :final op, :final right) => _evalBinary(left, op, right, context),
    TernaryExpr(:final condition, :final ifTrue, :final ifFalse) =>
      isTruthy(_eval(condition, context)) ? _eval(ifTrue, context) : _eval(ifFalse, context),
    ElvisExpr(:final left, :final right) => _eval(left, context) ?? _eval(right, context),
    UrlExpr(:final path, :final params) => _evalUrl(path, params, context),
    PipeExpr(:final target, :final filterName) => _evalPipe(target, filterName, context),
    LiteralSubstitutionExpr(:final parts) => parts.map((p) => _eval(p, context)?.toString() ?? '').join(),
    SelectionExpr(:final inner) => _evalSelection(inner, context),
  };

  dynamic _evalVariable(String name, Map<String, dynamic> context) {
    if (_strict && !context.containsKey(name)) {
      throw ExpressionException('Undefined variable: "$name"', expression: _currentExpression);
    }
    return context[name];
  }

  dynamic _evalMember(Expr object, String member, Map<String, dynamic> context) {
    final target = _eval(object, context);
    if (target == null) return null; // null-safe traversal
    if (target is Map) {
      if (_strict && !target.containsKey(member)) {
        throw ExpressionException('Undefined member: "$member"', expression: _currentExpression);
      }
      return target[member];
    }
    // Auto-convert non-Map objects via toMap() / toJson()
    final converted = _autoConvert(target);
    if (converted != null) {
      if (_strict && !converted.containsKey(member)) {
        throw ExpressionException('Undefined member: "$member"', expression: _currentExpression);
      }
      return converted[member];
    }
    throw ExpressionException(
      'Cannot access member "$member" on ${target.runtimeType}',
      expression: _currentExpression,
    );
  }

  dynamic _evalIndex(Expr object, Expr indexExpr, Map<String, dynamic> context) {
    final target = _eval(object, context);
    final index = _eval(indexExpr, context);
    if (target == null) return null;
    if (target is List) {
      if (index is! int) {
        throw ExpressionException(
          'List index must be an integer, got ${index.runtimeType}',
          expression: _currentExpression,
        );
      }
      if (index < 0 || index >= target.length) return null;
      return target[index];
    }
    if (target is Map) {
      if (_strict && !target.containsKey(index)) {
        throw ExpressionException('Undefined key: "$index"', expression: _currentExpression);
      }
      return target[index];
    }
    // Auto-convert non-Map/non-List objects
    final converted = _autoConvert(target);
    if (converted != null) {
      if (_strict && !converted.containsKey(index)) {
        throw ExpressionException('Undefined key: "$index"', expression: _currentExpression);
      }
      return converted[index];
    }
    throw ExpressionException('Cannot index into ${target.runtimeType}', expression: _currentExpression);
  }

  dynamic _evalUnary(UnaryOp op, Expr operand, Map<String, dynamic> context) => switch (op) {
    UnaryOp.not_ => !isTruthy(_eval(operand, context)),
    UnaryOp.minus => _evalNegate(operand, context),
  };

  dynamic _evalBinary(Expr left, BinaryOp op, Expr right, Map<String, dynamic> context) {
    // Short-circuit for boolean ops
    if (op == BinaryOp.and_) {
      return isTruthy(_eval(left, context)) && isTruthy(_eval(right, context));
    }
    if (op == BinaryOp.or_) {
      return isTruthy(_eval(left, context)) || isTruthy(_eval(right, context));
    }

    final leftVal = _eval(left, context);
    final rightVal = _eval(right, context);

    return switch (op) {
      BinaryOp.eq => leftVal == rightVal,
      BinaryOp.notEq => leftVal != rightVal,
      BinaryOp.lt => _compare(leftVal, rightVal) < 0,
      BinaryOp.gt => _compare(leftVal, rightVal) > 0,
      BinaryOp.lte => _compare(leftVal, rightVal) <= 0,
      BinaryOp.gte => _compare(leftVal, rightVal) >= 0,
      BinaryOp.plus => _evalPlus(leftVal, rightVal),
      BinaryOp.minus => _arithmeticOp(leftVal, rightVal, (a, b) => a - b),
      BinaryOp.star => _arithmeticOp(leftVal, rightVal, (a, b) => a * b),
      BinaryOp.slash => _arithmeticOp(leftVal, rightVal, (a, b) => a.toDouble() / b.toDouble()),
      BinaryOp.percent => _evalModulo(leftVal, rightVal),
      BinaryOp.and_ => throw StateError('unreachable'),
      BinaryOp.or_ => throw StateError('unreachable'),
    };
  }

  int _compare(dynamic a, dynamic b) {
    if (a is Comparable && b is Comparable) {
      return a.compareTo(b);
    }
    throw ExpressionException('Cannot compare ${a.runtimeType} with ${b.runtimeType}', expression: _currentExpression);
  }

  dynamic _evalPlus(dynamic left, dynamic right) {
    if (left is String || right is String) {
      return '$left$right';
    }
    return _arithmeticOp(left, right, (a, b) => a + b);
  }

  dynamic _arithmeticOp(dynamic left, dynamic right, num Function(num, num) op) {
    if (left == null || right == null) {
      throw ExpressionException('Cannot perform arithmetic with null', expression: _currentExpression);
    }
    if (left is! num || right is! num) {
      throw ExpressionException(
        'Cannot perform arithmetic on ${left.runtimeType} and ${right.runtimeType}',
        expression: _currentExpression,
      );
    }
    return op(left, right);
  }

  dynamic _evalModulo(dynamic left, dynamic right) {
    if (left == null || right == null) {
      throw ExpressionException('Cannot perform arithmetic with null', expression: _currentExpression);
    }
    if (left is! num || right is! num) {
      throw ExpressionException(
        'Cannot perform arithmetic on ${left.runtimeType} and ${right.runtimeType}',
        expression: _currentExpression,
      );
    }
    // Promote to double to avoid IntegerDivisionByZeroException when right == 0
    if (left is int && right is int && right != 0) {
      return left % right;
    }
    return left.toDouble() % right.toDouble();
  }

  dynamic _evalNegate(Expr operand, Map<String, dynamic> context) {
    final val = _eval(operand, context);
    if (val == null) {
      throw ExpressionException('Cannot negate null', expression: _currentExpression);
    }
    if (val is! num) {
      throw ExpressionException('Cannot negate ${val.runtimeType}', expression: _currentExpression);
    }
    return val is int ? -val : -(val as double);
  }

  dynamic _evalPipe(Expr target, String filterName, Map<String, dynamic> context) {
    final value = _eval(target, context);
    final filter = _filters[filterName];
    if (filter == null) {
      throw ExpressionException('Unknown filter: "$filterName"', expression: _currentExpression);
    }
    return filter(value);
  }

  String _evalUrl(String path, List<(String, Expr)> params, Map<String, dynamic> context) {
    if (params.isEmpty) return path;
    final queryParts = params.map((param) {
      final (key, valueExpr) = param;
      final value = _eval(valueExpr, context);
      return '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent('$value')}';
    });
    return '$path?${queryParts.join('&')}';
  }

  dynamic _evalSelection(Expr inner, Map<String, dynamic> context) {
    final selectionObj = context[selectionKey];
    if (selectionObj == null) {
      if (_strict) {
        throw ExpressionException(
          'Selection expression *{...} used outside tl:object scope',
          expression: _currentExpression,
        );
      }
      return null;
    }
    Map<String, dynamic> selectionMap;
    if (selectionObj is Map<String, dynamic>) {
      selectionMap = selectionObj;
    } else {
      final converted = _autoConvert(selectionObj);
      if (converted == null) return null;
      selectionMap = converted;
    }
    return _eval(inner, {...context, ...selectionMap});
  }

  /// Auto-convert a non-Map object to Map via toMap() or toJson() dynamic dispatch.
  Map<String, dynamic>? _autoConvert(dynamic target) {
    // Try toMap() first
    try {
      final result = (target as dynamic).toMap();
      if (result is! Map<String, dynamic>) {
        throw TemplateException('toMap() on ${target.runtimeType} returned ${result.runtimeType}, expected Map<String, dynamic>');
      }
      return result;
    } on NoSuchMethodError {
      // toMap() doesn't exist — fall through to toJson()
    } catch (e) {
      // toMap() exists but threw — wrap as TemplateException
      throw TemplateException('toMap() failed on ${target.runtimeType}: $e');
    }
    // Try toJson() fallback
    try {
      final result = (target as dynamic).toJson();
      if (result is! Map<String, dynamic>) {
        throw TemplateException('toJson() on ${target.runtimeType} returned ${result.runtimeType}, expected Map<String, dynamic>');
      }
      return result;
    } on NoSuchMethodError {
      if (_strict) {
        throw ExpressionException(
          'Cannot access members on ${target.runtimeType} (no toMap() or toJson())',
          expression: _currentExpression,
        );
      }
      return null;
    } catch (e) {
      throw TemplateException('toJson() failed on ${target.runtimeType}: $e');
    }
  }
}
