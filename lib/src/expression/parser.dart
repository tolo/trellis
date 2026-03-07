import 'ast.dart';
import 'scanner.dart';
import '../exceptions.dart';

/// Recursive descent parser producing an AST from a trellis expression string.
final class Parser {
  final Scanner _scanner;
  final String _source;

  /// Tracks whether we're inside a bracket `[...]` index sub-expression.
  /// Prevents nested `${...}` which is invalid per F03 spec.
  bool _inBracketContext = false;

  Parser(String source) : _source = source, _scanner = Scanner(source);

  /// Parse the full expression and expect EOF.
  Expr parse() {
    final expr = _parsePipe();
    _expect(.eof, 'Expected end of expression');
    return expr;
  }

  // Precedence 0 (lowest): | pipe chains, left-associative
  Expr _parsePipe() {
    var expr = _parseTernary();
    while (_match(.pipe)) {
      final name = _expect(.identifier, 'Expected filter name after "|"');
      final args = <Expr>[];
      while (_match(.colon)) {
        args.add(_parseFilterArg());
      }
      expr = PipeExpr(expr, name.value as String, args);
    }
    return expr;
  }

  /// Parse a single filter argument: literal, boolean, null, or bare identifier.
  Expr _parseFilterArg() {
    final token = _scanner.peek();
    switch (token.type) {
      case .string:
      case .integer:
      case .double_:
        _scanner.next();
        return LiteralExpr(token.value);
      case .true_:
        _scanner.next();
        return LiteralExpr(true);
      case .false_:
        _scanner.next();
        return LiteralExpr(false);
      case .null_:
        _scanner.next();
        return LiteralExpr(null);
      case .identifier:
        _scanner.next();
        return VariableExpr(token.value as String);
      default:
        throw ExpressionException('Expected filter argument', expression: _source, position: token.offset);
    }
  }

  // Precedence 1: ternary ? : (right-associative)
  Expr _parseTernary() {
    final expr = _parseElvis();
    if (_match(.question)) {
      final ifTrue = _parseTernary(); // right-associative
      _expect(.colon, "Expected ':' in ternary expression");
      final ifFalse = _parseTernary(); // right-associative
      return TernaryExpr(expr, ifTrue, ifFalse);
    }
    return expr;
  }

  // Precedence 2: elvis ?:
  Expr _parseElvis() {
    var expr = _parseOr();
    while (_match(.elvisOp)) {
      expr = ElvisExpr(expr, _parseOr());
    }
    return expr;
  }

  // Precedence 3: or
  Expr _parseOr() {
    var expr = _parseAnd();
    while (_match(.or_)) {
      expr = BinaryExpr(expr, .or_, _parseAnd());
    }
    return expr;
  }

  // Precedence 4: and
  Expr _parseAnd() {
    var expr = _parseEquality();
    while (_match(.and_)) {
      expr = BinaryExpr(expr, .and_, _parseEquality());
    }
    return expr;
  }

  // Precedence 5: == !=
  Expr _parseEquality() {
    var expr = _parseComparison();
    while (true) {
      if (_match(.eq)) {
        expr = BinaryExpr(expr, .eq, _parseComparison());
      } else if (_match(.notEq)) {
        expr = BinaryExpr(expr, .notEq, _parseComparison());
      } else {
        break;
      }
    }
    return expr;
  }

  // Precedence 6: < > <= >=
  Expr _parseComparison() {
    var expr = _parseAdditive();
    while (true) {
      if (_match(.lt)) {
        expr = BinaryExpr(expr, .lt, _parseAdditive());
      } else if (_match(.gt)) {
        expr = BinaryExpr(expr, .gt, _parseAdditive());
      } else if (_match(.lte)) {
        expr = BinaryExpr(expr, .lte, _parseAdditive());
      } else if (_match(.gte)) {
        expr = BinaryExpr(expr, .gte, _parseAdditive());
      } else {
        break;
      }
    }
    return expr;
  }

  // Precedence 7: + - (additive)
  Expr _parseAdditive() {
    var expr = _parseMultiplicative();
    while (true) {
      if (_match(.plus)) {
        expr = BinaryExpr(expr, .plus, _parseMultiplicative());
      } else if (_match(.minus)) {
        expr = BinaryExpr(expr, .minus, _parseMultiplicative());
      } else {
        break;
      }
    }
    return expr;
  }

  // Precedence 8: * / % (multiplicative)
  Expr _parseMultiplicative() {
    var expr = _parseUnary();
    while (true) {
      if (_match(.star)) {
        expr = BinaryExpr(expr, .star, _parseUnary());
      } else if (_match(.slash)) {
        expr = BinaryExpr(expr, .slash, _parseUnary());
      } else if (_match(.percent)) {
        expr = BinaryExpr(expr, .percent, _parseUnary());
      } else {
        break;
      }
    }
    return expr;
  }

  // Precedence 9: not, - (unary)
  Expr _parseUnary() {
    if (_match(.not_)) {
      return UnaryExpr(.not_, _parseUnary());
    }
    if (_match(.minus)) {
      return UnaryExpr(.minus, _parseUnary());
    }
    return _parsePostfix();
  }

  // Precedence 10: . member access and [n] index (postfix)
  Expr _parsePostfix() {
    var expr = _parsePrimary();
    while (true) {
      if (_match(.dot)) {
        final token = _scanner.next();
        final name = Parser._memberName(token);
        if (name == null) {
          throw ExpressionException(
            'Expected member name after ".", got ${token.type}',
            expression: _source,
            position: token.offset,
          );
        }
        expr = MemberAccessExpr(expr, name);
      } else if (_match(.lBracket)) {
        final wasInBracket = _inBracketContext;
        _inBracketContext = true;
        final index = _parsePipe();
        _inBracketContext = wasInBracket;
        _expect(.rBracket, 'Expected "]"');
        expr = IndexAccessExpr(expr, index);
      } else {
        break;
      }
    }
    return expr;
  }

  // Precedence 11 (highest): literals, ${}, @{}, grouping
  Expr _parsePrimary() {
    final token = _scanner.peek();

    switch (token.type) {
      case .string:
      case .integer:
      case .double_:
        _scanner.next();
        return LiteralExpr(token.value);
      case .true_:
        _scanner.next();
        return LiteralExpr(true);
      case .false_:
        _scanner.next();
        return LiteralExpr(false);
      case .null_:
        _scanner.next();
        return LiteralExpr(null);
      case .identifier:
        _scanner.next();
        return VariableExpr(token.value as String);
      case .dollarLBrace:
        if (_inBracketContext) {
          throw ExpressionException(
            'Nested \${} not allowed inside bracket index; use \${items[i]} instead of \${items[\${i}]}',
            expression: _source,
            position: token.offset,
          );
        }
        return _parseDollarExpr();
      case .atLBrace:
        return _parseUrlExpr();
      case .hashLBrace:
        return _parseMessageExpr();
      case .starLBrace:
        return _parseSelectionExpr();
      case .pipe:
        _scanner.next(); // consume opening |
        return _parseLiteralSub();
      case .lParen:
        _scanner.next();
        final expr = _parseTernary();
        _expect(.rParen, 'Expected ")"');
        return expr;
      default:
        throw ExpressionException('Unexpected token: ${token.type}', expression: _source, position: token.offset);
    }
  }

  /// Parse a full expression inside `${ ... }`.
  Expr _parseDollarExpr() {
    _scanner.next(); // consume ${
    final expr = _parsePipe();
    _expect(.rBrace, 'Expected "}" to close variable expression');
    return expr;
  }

  /// Parse selection expression: `*{field}` or `*{field.nested}`.
  Expr _parseSelectionExpr() {
    _scanner.next(); // consume *{
    final expr = _parsePipe();
    _expect(.rBrace, 'Expected "}" to close selection expression');
    return SelectionExpr(expr);
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
    if (_match(.lParen)) {
      if (!_check(.rParen)) {
        do {
          final key = _expect(.identifier, 'Expected parameter name');
          _expect(.assign, 'Expected "=" after parameter name');
          final value = _parseTernary();
          params.add((key.value as String, value));
        } while (_match(.comma));
      }
      _expect(.rParen, 'Expected ")" to close URL parameters');
    }

    _expect(.rBrace, 'Expected "}" to close URL expression');
    return UrlExpr(path, params);
  }

  /// Parse message expression: `#{key}` or `#{key(arg1, arg2)}`.
  Expr _parseMessageExpr() {
    _scanner.next(); // consume #{

    // Read message key as raw text until ( or }
    // 0x28 = '(', 0x7D = '}'
    final key = _scanner.scanRawUntil({0x28, 0x7D}).trim();
    if (key.isEmpty) {
      throw ExpressionException('Expected message key after "#{"', expression: _source, position: _scanner.position);
    }

    final args = <Expr>[];
    if (_match(.lParen)) {
      if (!_check(.rParen)) {
        do {
          args.add(_parsePipe());
        } while (_match(.comma));
      }
      _expect(.rParen, 'Expected ")" after message arguments');
    }

    _expect(.rBrace, 'Expected "}" to close message expression');
    return MessageExpr(key, args);
  }

  /// Parse literal substitution: `|text ${expr} more text|`.
  Expr _parseLiteralSub() {
    final parts = <Expr>[];

    while (true) {
      final text = _scanner.scanLiteralSubSegment();
      if (text.isNotEmpty) {
        parts.add(LiteralExpr(text));
      }

      final token = _scanner.peek();
      if (token.type == .pipe) {
        _scanner.next(); // consume closing |
        return LiteralSubstitutionExpr(parts);
      } else if (token.type == .dollarLBrace) {
        parts.add(_parseDollarExpr());
      } else if (token.type == .eof) {
        throw ExpressionException('Unterminated literal substitution', expression: _source, position: token.offset);
      } else {
        throw ExpressionException(
          'Unexpected token inside literal substitution: ${token.type}',
          expression: _source,
          position: token.offset,
        );
      }
    }
  }

  // --- Helpers ---

  /// Maps keyword/operator tokens back to their word form for member access.
  /// Note: gte→'ge' and lte→'le' because the scanner maps the words `ge`/`le`
  /// to TokenType.gte/lte (the token names reflect the operator, not the alias).
  static const _tokenToName = <TokenType, String>{
    .gt: 'gt',
    .lt: 'lt',
    .gte: 'ge',
    .lte: 'le',
    .eq: 'eq',
    .notEq: 'ne',
    .and_: 'and',
    .or_: 'or',
    .not_: 'not',
    .true_: 'true',
    .false_: 'false',
    .null_: 'null',
  };

  /// Returns the member name string for a token, or null if not a valid member name.
  static String? _memberName(Token token) {
    if (token.type == .identifier) return token.value as String;
    return _tokenToName[token.type];
  }

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
