import 'ast.dart';
import 'scanner.dart';
import '../exceptions.dart';

/// Recursive descent parser producing an AST from a trellis expression string.
class Parser {
  final Scanner _scanner;
  final String _source;

  Parser(String source) : _source = source, _scanner = Scanner(source);

  /// Parse the full expression and expect EOF.
  Expr parse() {
    final expr = _parsePipe();
    _expect(TokenType.eof, 'Expected end of expression');
    return expr;
  }

  // Precedence 0 (lowest): | pipe chains, left-associative
  Expr _parsePipe() {
    var expr = _parseTernary();
    while (_match(TokenType.pipe)) {
      final name = _expect(TokenType.identifier, 'Expected filter name after "|"');
      expr = PipeExpr(expr, name.value as String);
    }
    return expr;
  }

  // Precedence 1: ternary ? : (right-associative)
  Expr _parseTernary() {
    final expr = _parseElvis();
    if (_match(TokenType.question)) {
      final ifTrue = _parseTernary(); // right-associative
      _expect(TokenType.colon, "Expected ':' in ternary expression");
      final ifFalse = _parseTernary(); // right-associative
      return TernaryExpr(expr, ifTrue, ifFalse);
    }
    return expr;
  }

  // Precedence 2: elvis ?:
  Expr _parseElvis() {
    var expr = _parseOr();
    while (_match(TokenType.elvisOp)) {
      expr = ElvisExpr(expr, _parseOr());
    }
    return expr;
  }

  // Precedence 3: or
  Expr _parseOr() {
    var expr = _parseAnd();
    while (_match(TokenType.or_)) {
      expr = BinaryExpr(expr, BinaryOp.or_, _parseAnd());
    }
    return expr;
  }

  // Precedence 4: and
  Expr _parseAnd() {
    var expr = _parseEquality();
    while (_match(TokenType.and_)) {
      expr = BinaryExpr(expr, BinaryOp.and_, _parseEquality());
    }
    return expr;
  }

  // Precedence 5: == !=
  Expr _parseEquality() {
    var expr = _parseComparison();
    while (true) {
      if (_match(TokenType.eq)) {
        expr = BinaryExpr(expr, BinaryOp.eq, _parseComparison());
      } else if (_match(TokenType.notEq)) {
        expr = BinaryExpr(expr, BinaryOp.notEq, _parseComparison());
      } else {
        break;
      }
    }
    return expr;
  }

  // Precedence 6: < > <= >=
  Expr _parseComparison() {
    var expr = _parseConcat();
    while (true) {
      if (_match(TokenType.lt)) {
        expr = BinaryExpr(expr, BinaryOp.lt, _parseConcat());
      } else if (_match(TokenType.gt)) {
        expr = BinaryExpr(expr, BinaryOp.gt, _parseConcat());
      } else if (_match(TokenType.lte)) {
        expr = BinaryExpr(expr, BinaryOp.lte, _parseConcat());
      } else if (_match(TokenType.gte)) {
        expr = BinaryExpr(expr, BinaryOp.gte, _parseConcat());
      } else {
        break;
      }
    }
    return expr;
  }

  // Precedence 7: + (string concat)
  Expr _parseConcat() {
    var expr = _parseUnary();
    while (_match(TokenType.plus)) {
      expr = BinaryExpr(expr, BinaryOp.plus, _parseUnary());
    }
    return expr;
  }

  // Precedence 8: not (unary)
  Expr _parseUnary() {
    if (_match(TokenType.not_)) {
      return UnaryExpr(UnaryOp.not_, _parseUnary());
    }
    return _parsePostfix();
  }

  // Precedence 9: . member access and [n] index (postfix)
  Expr _parsePostfix() {
    var expr = _parsePrimary();
    while (true) {
      if (_match(TokenType.dot)) {
        final name = _expect(TokenType.identifier, 'Expected member name after "."');
        expr = MemberAccessExpr(expr, name.value as String);
      } else if (_match(TokenType.lBracket)) {
        final index = _expect(TokenType.integer, 'Expected integer index');
        _expect(TokenType.rBracket, 'Expected "]"');
        expr = IndexAccessExpr(expr, index.value as int);
      } else {
        break;
      }
    }
    return expr;
  }

  // Precedence 10 (highest): literals, ${}, @{}, grouping
  Expr _parsePrimary() {
    final token = _scanner.peek();

    switch (token.type) {
      case TokenType.string:
        _scanner.next();
        return LiteralExpr(token.value);
      case TokenType.integer:
        _scanner.next();
        return LiteralExpr(token.value);
      case TokenType.double_:
        _scanner.next();
        return LiteralExpr(token.value);
      case TokenType.true_:
        _scanner.next();
        return LiteralExpr(true);
      case TokenType.false_:
        _scanner.next();
        return LiteralExpr(false);
      case TokenType.null_:
        _scanner.next();
        return LiteralExpr(null);
      case TokenType.identifier:
        _scanner.next();
        return VariableExpr(token.value as String);
      case TokenType.dollarLBrace:
        return _parseDollarExpr();
      case TokenType.atLBrace:
        return _parseUrlExpr();
      case TokenType.lParen:
        _scanner.next();
        final expr = _parseTernary();
        _expect(TokenType.rParen, 'Expected ")"');
        return expr;
      default:
        throw ExpressionException('Unexpected token: ${token.type}', expression: _source, position: token.offset);
    }
  }

  /// Parse a full expression inside `${ ... }`.
  Expr _parseDollarExpr() {
    _scanner.next(); // consume ${
    final expr = _parsePipe();
    _expect(TokenType.rBrace, 'Expected "}" to close variable expression');
    return expr;
  }

  /// Parse `@{/path(key=${val}, ...)}`.
  Expr _parseUrlExpr() {
    final startOffset = _scanner.next().offset; // consume @{

    // Read path as raw text until ( or }
    // 0x28 = '(', 0x7D = '}'
    final path = _scanner.scanRawUntil({0x28, 0x7D});
    if (path.isEmpty) {
      throw ExpressionException('Expected URL path', expression: _source, position: startOffset);
    }

    final params = <(String, Expr)>[];

    // Parse optional params
    if (_match(TokenType.lParen)) {
      if (!_check(TokenType.rParen)) {
        do {
          final key = _expect(TokenType.identifier, 'Expected parameter name');
          _expect(TokenType.assign, 'Expected "=" after parameter name');
          final value = _parseTernary();
          params.add((key.value as String, value));
        } while (_match(TokenType.comma));
      }
      _expect(TokenType.rParen, 'Expected ")" to close URL parameters');
    }

    _expect(TokenType.rBrace, 'Expected "}" to close URL expression');
    return UrlExpr(path, params);
  }

  // --- Helpers ---

  bool _match(TokenType type) {
    if (_scanner.peek().type == type) {
      _scanner.next();
      return true;
    }
    return false;
  }

  bool _check(TokenType type) => _scanner.peek().type == type;

  Token _expect(TokenType type, String message) {
    final token = _scanner.next();
    if (token.type != type) {
      throw ExpressionException('$message, got ${token.type}', expression: _source, position: token.offset);
    }
    return token;
  }
}
