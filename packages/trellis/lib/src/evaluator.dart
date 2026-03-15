import 'exceptions.dart';
import 'expression/ast.dart';
import 'expression/parser.dart';
import 'message_source.dart';
import 'truthiness.dart';

/// Evaluates trellis template expressions against a context map.
class ExpressionEvaluator {
  /// Reserved context key for the selection object set by tl:object.
  static const selectionKey = '__trellis_selection__';

  final Map<String, Function> _filters;
  final bool _strict;
  final MessageSource? _messageSource;
  final String? _locale;
  final Map<String, Expr>? _expressionCache;

  ExpressionEvaluator({
    Map<String, Function>? filters,
    bool strict = false,
    MessageSource? messageSource,
    String? locale,
    Map<String, Expr>? expressionCache,
  }) : _filters = filters ?? {...builtinFilters},
       _strict = strict,
       _messageSource = messageSource,
       _locale = locale,
       _expressionCache = expressionCache;

  static const builtinFilters = <String, dynamic Function(dynamic)>{
    'upper': _filterUpper,
    'lower': _filterLower,
    'trim': _filterTrim,
    'length': _filterLength,
  };

  static dynamic _filterUpper(dynamic v) => v?.toString().toUpperCase();
  static dynamic _filterLower(dynamic v) => v?.toString().toLowerCase();
  static dynamic _filterTrim(dynamic v) => v?.toString().trim();
  static dynamic _filterLength(dynamic v) => v is Iterable ? v.length : (v?.toString().length ?? 0);

  /// Evaluate an expression string against a context map.
  dynamic evaluate(String expression, Map<String, dynamic> context) {
    try {
      final ast = _expressionCache?[expression] ?? _parseAndCache(expression);
      return _eval(ast, expression, context);
    } on ExpressionException {
      rethrow;
    } on Exception catch (e) {
      throw ExpressionException(e.toString(), expression: expression);
    }
  }

  Expr _parseAndCache(String expression) {
    final ast = Parser(expression).parse();
    _expressionCache?[expression] = ast;
    return ast;
  }

  dynamic _eval(Expr node, String expr, Map<String, dynamic> context) => switch (node) {
    LiteralExpr(:final value) => value,
    VariableExpr(:final name) => _evalVariable(name, expr, context),
    MemberAccessExpr(:final object, :final member) => _evalMember(object, member, expr, context),
    IndexAccessExpr(:final object, :final index) => _evalIndex(object, index, expr, context),
    UnaryExpr(:final op, :final operand) => _evalUnary(op, operand, expr, context),
    BinaryExpr(:final left, :final op, :final right) => _evalBinary(left, op, right, expr, context),
    TernaryExpr(:final condition, :final ifTrue, :final ifFalse) =>
      isTruthy(_eval(condition, expr, context)) ? _eval(ifTrue, expr, context) : _eval(ifFalse, expr, context),
    ElvisExpr(:final left, :final right) => _eval(left, expr, context) ?? _eval(right, expr, context),
    UrlExpr(:final path, :final params) => _evalUrl(path, params, expr, context),
    PipeExpr(:final target, :final filterName, :final args) => _evalPipe(target, filterName, args, expr, context),
    LiteralSubstitutionExpr(:final parts) => parts.map((p) => _eval(p, expr, context)?.toString() ?? '').join(),
    SelectionExpr(:final inner) => _evalSelection(inner, expr, context),
    MessageExpr(:final key, :final args) => _evalMessage(key, args, expr, context),
  };

  dynamic _evalVariable(String name, String expr, Map<String, dynamic> context) {
    if (_strict && !context.containsKey(name)) {
      throw ExpressionException('Undefined variable: "$name"', expression: expr);
    }
    return context[name];
  }

  dynamic _evalMember(Expr object, String member, String expr, Map<String, dynamic> context) {
    final target = _eval(object, expr, context);
    if (target == null) return null; // null-safe traversal
    if (target is Map) {
      if (_strict && !target.containsKey(member)) {
        throw ExpressionException('Undefined member: "$member"', expression: expr);
      }
      return target[member];
    }
    // Auto-convert non-Map objects via toMap() / toJson()
    final converted = _autoConvert(target, expr);
    if (converted != null) {
      if (_strict && !converted.containsKey(member)) {
        throw ExpressionException('Undefined member: "$member"', expression: expr);
      }
      return converted[member];
    }
    throw ExpressionException('Cannot access member "$member" on ${target.runtimeType}', expression: expr);
  }

  dynamic _evalIndex(Expr object, Expr indexExpr, String expr, Map<String, dynamic> context) {
    final target = _eval(object, expr, context);
    final index = _eval(indexExpr, expr, context);
    if (target == null) return null;
    if (target is List) {
      if (index is! int) {
        throw ExpressionException('List index must be an integer, got ${index.runtimeType}', expression: expr);
      }
      if (index < 0 || index >= target.length) return null;
      return target[index];
    }
    if (target is Map) {
      if (_strict && !target.containsKey(index)) {
        throw ExpressionException('Undefined key: "$index"', expression: expr);
      }
      return target[index];
    }
    // Auto-convert non-Map/non-List objects
    final converted = _autoConvert(target, expr);
    if (converted != null) {
      if (_strict && !converted.containsKey(index)) {
        throw ExpressionException('Undefined key: "$index"', expression: expr);
      }
      return converted[index];
    }
    throw ExpressionException('Cannot index into ${target.runtimeType}', expression: expr);
  }

  dynamic _evalUnary(UnaryOp op, Expr operand, String expr, Map<String, dynamic> context) => switch (op) {
    .not_ => !isTruthy(_eval(operand, expr, context)),
    .minus => _evalNegate(operand, expr, context),
  };

  dynamic _evalBinary(Expr left, BinaryOp op, Expr right, String expr, Map<String, dynamic> context) {
    // Short-circuit for boolean ops
    if (op == .and_) {
      return isTruthy(_eval(left, expr, context)) && isTruthy(_eval(right, expr, context));
    }
    if (op == .or_) {
      return isTruthy(_eval(left, expr, context)) || isTruthy(_eval(right, expr, context));
    }

    final leftVal = _eval(left, expr, context);
    final rightVal = _eval(right, expr, context);

    return switch (op) {
      .eq => leftVal == rightVal,
      .notEq => leftVal != rightVal,
      .lt => _compare(leftVal, rightVal, expr) < 0,
      .gt => _compare(leftVal, rightVal, expr) > 0,
      .lte => _compare(leftVal, rightVal, expr) <= 0,
      .gte => _compare(leftVal, rightVal, expr) >= 0,
      .plus => _evalPlus(leftVal, rightVal, expr),
      .minus => _arithmeticOp(leftVal, rightVal, expr, (a, b) => a - b),
      .star => _arithmeticOp(leftVal, rightVal, expr, (a, b) => a * b),
      .slash => _arithmeticOp(leftVal, rightVal, expr, (a, b) => a.toDouble() / b.toDouble()),
      .percent => _arithmeticOp(leftVal, rightVal, expr, _modulo),
      .and_ => throw StateError('unreachable'),
      .or_ => throw StateError('unreachable'),
    };
  }

  int _compare(dynamic a, dynamic b, String expr) {
    if (a is Comparable && b is Comparable && a.runtimeType == b.runtimeType) {
      return a.compareTo(b);
    }
    // Allow cross-type numeric comparison (int vs double)
    if (a is num && b is num) {
      return a.compareTo(b);
    }
    throw ExpressionException('Cannot compare ${a.runtimeType} with ${b.runtimeType}', expression: expr);
  }

  dynamic _evalPlus(dynamic left, dynamic right, String expr) {
    if (left is String || right is String) {
      return '$left$right';
    }
    return _arithmeticOp(left, right, expr, (a, b) => a + b);
  }

  dynamic _arithmeticOp(dynamic left, dynamic right, String expr, num Function(num, num) op) {
    if (left == null || right == null) {
      throw ExpressionException('Cannot perform arithmetic with null', expression: expr);
    }
    if (left is! num || right is! num) {
      throw ExpressionException(
        'Cannot perform arithmetic on ${left.runtimeType} and ${right.runtimeType}',
        expression: expr,
      );
    }
    return op(left, right);
  }

  /// Modulo operation with double promotion to avoid IntegerDivisionByZeroException.
  static num _modulo(num a, num b) {
    if (a is int && b is int && b != 0) return a % b;
    return a.toDouble() % b.toDouble();
  }

  dynamic _evalNegate(Expr operand, String expr, Map<String, dynamic> context) {
    final val = _eval(operand, expr, context);
    if (val == null) {
      throw ExpressionException('Cannot negate null', expression: expr);
    }
    if (val is! num) {
      throw ExpressionException('Cannot negate ${val.runtimeType}', expression: expr);
    }
    return -val;
  }

  dynamic _evalPipe(Expr target, String filterName, List<Expr> args, String expr, Map<String, dynamic> context) {
    final value = _eval(target, expr, context);
    final filter = _filters[filterName];
    if (filter == null) {
      throw ExpressionException('Unknown filter: "$filterName"', expression: expr);
    }

    final evaluatedArgs = args.map((a) => _eval(a, expr, context)).toList();

    if (evaluatedArgs.isEmpty) {
      // No args — try calling with value only (old-style), fallback to empty args list (new-style)
      try {
        return filter(value);
      } on NoSuchMethodError {
        return (filter as dynamic)(value, <dynamic>[]);
      }
    }

    // Args present — try calling with args list [D03]
    try {
      return (filter as dynamic)(value, evaluatedArgs);
    } on NoSuchMethodError {
      // Old-style filter doesn't accept args
      throw ExpressionException("Filter '$filterName' does not accept arguments", expression: expr);
    }
  }

  String _evalUrl(String path, List<(String, Expr)> params, String expr, Map<String, dynamic> context) {
    if (params.isEmpty) return path;
    final queryParts = params.map((param) {
      final (key, valueExpr) = param;
      final value = _eval(valueExpr, expr, context);
      return '${Uri.encodeComponent(key)}=${Uri.encodeComponent('$value')}';
    });
    return '$path?${queryParts.join('&')}';
  }

  dynamic _evalMessage(String key, List<Expr> args, String expr, Map<String, dynamic> context) {
    // Determine locale: context._locale overrides engine default
    final locale = context['_locale'] as String? ?? _locale;

    // Evaluate all args before resolution
    final evaluatedArgs = args.map((a) => _eval(a, expr, context)).toList();

    if (_messageSource == null) {
      if (_strict) {
        throw ExpressionException('No MessageSource configured for message key "$key"', expression: expr);
      }
      return key;
    }

    final resolved = _messageSource.resolve(key, locale: locale, args: evaluatedArgs);
    if (resolved == null) {
      if (_strict) {
        throw ExpressionException('Message key "$key" not found', expression: expr);
      }
      return key;
    }

    return resolved;
  }

  dynamic _evalSelection(Expr inner, String expr, Map<String, dynamic> context) {
    final selectionObj = context[selectionKey];
    if (selectionObj == null) {
      if (_strict) {
        throw ExpressionException('Selection expression *{...} used outside tl:object scope', expression: expr);
      }
      return null;
    }
    Map<String, dynamic> selectionMap;
    if (selectionObj is Map<String, dynamic>) {
      selectionMap = selectionObj;
    } else {
      final converted = _autoConvert(selectionObj, expr);
      if (converted == null) return null;
      selectionMap = converted;
    }
    return _eval(inner, expr, {...context, ...selectionMap});
  }

  /// Auto-convert a non-Map object to Map via toMap() or toJson() dynamic dispatch.
  Map<String, dynamic>? _autoConvert(dynamic target, String expr) {
    // Try toMap() first
    try {
      final result = (target as dynamic).toMap();
      if (result is! Map<String, dynamic>) {
        throw TemplateException(
          'toMap() on ${target.runtimeType} returned ${result.runtimeType}, expected Map<String, dynamic>',
        );
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
        throw TemplateException(
          'toJson() on ${target.runtimeType} returned ${result.runtimeType}, expected Map<String, dynamic>',
        );
      }
      return result;
    } on NoSuchMethodError {
      if (_strict) {
        throw ExpressionException(
          'Cannot access members on ${target.runtimeType} (no toMap() or toJson())',
          expression: expr,
        );
      }
      return null;
    } catch (e) {
      throw TemplateException('toJson() failed on ${target.runtimeType}: $e');
    }
  }
}
