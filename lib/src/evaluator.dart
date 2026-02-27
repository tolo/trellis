import 'exceptions.dart';
import 'expression/ast.dart';
import 'expression/parser.dart';
import 'truthiness.dart';

/// Evaluates trellis template expressions against a context map.
class ExpressionEvaluator {
  final Map<String, dynamic Function(dynamic)> _filters;

  ExpressionEvaluator({Map<String, dynamic Function(dynamic)>? filters})
    : _filters = {..._builtinFilters, ...?filters};

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
    VariableExpr(:final name) => context[name],
    MemberAccessExpr(:final object, :final member) => _evalMember(object, member, context),
    IndexAccessExpr(:final object, :final index) => _evalIndex(object, index, context),
    UnaryExpr(:final op, :final operand) => _evalUnary(op, operand, context),
    BinaryExpr(:final left, :final op, :final right) => _evalBinary(left, op, right, context),
    TernaryExpr(:final condition, :final ifTrue, :final ifFalse) =>
      _eval(condition, context) == true ? _eval(ifTrue, context) : _eval(ifFalse, context),
    ElvisExpr(:final left, :final right) => _eval(left, context) ?? _eval(right, context),
    UrlExpr(:final path, :final params) => _evalUrl(path, params, context),
    PipeExpr(:final target, :final filterName) => _evalPipe(target, filterName, context),
  };

  dynamic _evalMember(Expr object, String member, Map<String, dynamic> context) {
    final target = _eval(object, context);
    if (target == null) return null;
    if (target is Map) return target[member];
    throw ExpressionException(
      'Cannot access member "$member" on ${target.runtimeType}',
      expression: _currentExpression,
    );
  }

  dynamic _evalIndex(Expr object, int index, Map<String, dynamic> context) {
    final target = _eval(object, context);
    if (target == null) return null;
    if (target is List) {
      if (index < 0 || index >= target.length) return null;
      return target[index];
    }
    throw ExpressionException('Cannot index into ${target.runtimeType}', expression: _currentExpression);
  }

  dynamic _evalUnary(UnaryOp op, Expr operand, Map<String, dynamic> context) => switch (op) {
    UnaryOp.not_ => !isTruthy(_eval(operand, context)),
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
      BinaryOp.plus => '$leftVal$rightVal',
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
}
