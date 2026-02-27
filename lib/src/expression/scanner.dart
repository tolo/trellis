import 'package:string_scanner/string_scanner.dart';

import '../exceptions.dart';

/// Token types produced by the expression scanner.
enum TokenType {
  // Literals
  string,
  integer,
  double_,
  true_,
  false_,
  null_,
  // Identifiers
  identifier,
  // Operators
  plus,
  assign,
  eq,
  notEq,
  lt,
  gt,
  lte,
  gte,
  and_,
  or_,
  not_,
  pipe,
  // Delimiters
  dot,
  comma,
  colon,
  question,
  elvisOp,
  lParen,
  rParen,
  lBracket,
  rBracket,
  dollarLBrace,
  atLBrace,
  rBrace,
  // Control
  eof,
}

/// A single token produced by [Scanner].
class Token {
  final TokenType type;
  final dynamic value;
  final int offset;

  Token(this.type, this.value, this.offset);

  @override
  String toString() => 'Token($type, $value, @$offset)';
}

/// Tokenizer for trellis expressions, wrapping [StringScanner].
class Scanner {
  final StringScanner _scanner;
  final String _source;
  Token? _peeked;

  Scanner(String source) : _source = source, _scanner = StringScanner(source);

  /// Current position in the source string.
  int get position => _scanner.position;

  /// Read raw text until one of [stopChars] is encountered or end of input.
  /// Consumes any peeked token first if present. Used for URL path scanning.
  String scanRawUntil(Set<int> stopChars) {
    // Discard any peeked token — we're switching to raw mode
    _peeked = null;
    _skipWhitespace();
    final start = _scanner.position;
    while (!_scanner.isDone && !stopChars.contains(_scanner.peekChar()!)) {
      _scanner.readChar();
    }
    return _source.substring(start, _scanner.position);
  }

  /// Returns the next token without advancing.
  Token peek() => _peeked ??= _advance();

  /// Returns the next token and advances.
  Token next() {
    if (_peeked != null) {
      final token = _peeked!;
      _peeked = null;
      return token;
    }
    return _advance();
  }

  Token _advance() {
    _skipWhitespace();

    if (_scanner.isDone) {
      return Token(TokenType.eof, null, _scanner.position);
    }

    final offset = _scanner.position;

    // Two-char operators and delimiters
    if (_scanner.scan(r'${')) return Token(TokenType.dollarLBrace, null, offset);
    if (_scanner.scan('@{')) return Token(TokenType.atLBrace, null, offset);
    if (_scanner.scan('==')) return Token(TokenType.eq, null, offset);
    if (_scanner.scan('!=')) return Token(TokenType.notEq, null, offset);
    if (_scanner.scan('<=')) return Token(TokenType.lte, null, offset);
    if (_scanner.scan('>=')) return Token(TokenType.gte, null, offset);
    if (_scanner.scan('=')) return Token(TokenType.assign, null, offset);

    // Elvis ?: vs question ?
    if (_scanner.scan('?')) {
      if (_scanner.scan(':')) return Token(TokenType.elvisOp, null, offset);
      return Token(TokenType.question, null, offset);
    }

    // Single-char tokens
    if (_scanner.scan('|')) return Token(TokenType.pipe, null, offset);
    if (_scanner.scan('+')) return Token(TokenType.plus, null, offset);
    if (_scanner.scan('<')) return Token(TokenType.lt, null, offset);
    if (_scanner.scan('>')) return Token(TokenType.gt, null, offset);
    if (_scanner.scan('.')) return Token(TokenType.dot, null, offset);
    if (_scanner.scan(',')) return Token(TokenType.comma, null, offset);
    if (_scanner.scan(':')) return Token(TokenType.colon, null, offset);
    if (_scanner.scan('(')) return Token(TokenType.lParen, null, offset);
    if (_scanner.scan(')')) return Token(TokenType.rParen, null, offset);
    if (_scanner.scan('[')) return Token(TokenType.lBracket, null, offset);
    if (_scanner.scan(']')) return Token(TokenType.rBracket, null, offset);
    if (_scanner.scan('}')) return Token(TokenType.rBrace, null, offset);

    // String literal
    if (_scanner.scan("'")) return _scanString(offset);

    // Numeric literal
    if (_isDigit(_scanner.peekChar()!)) return _scanNumber(offset);

    // Identifier or keyword
    if (_isIdentStart(_scanner.peekChar()!)) return _scanIdentifier(offset);

    throw ExpressionException(
      'Unexpected character: ${String.fromCharCode(_scanner.peekChar()!)}',
      expression: _source,
      position: offset,
    );
  }

  Token _scanString(int offset) {
    final buffer = StringBuffer();
    while (!_scanner.isDone) {
      if (_scanner.scan(r"\'")) {
        buffer.write("'");
      } else if (_scanner.scan("'")) {
        return Token(TokenType.string, buffer.toString(), offset);
      } else {
        buffer.writeCharCode(_scanner.readChar());
      }
    }
    throw ExpressionException('Unterminated string literal', expression: _source, position: offset);
  }

  Token _scanNumber(int offset) {
    final start = _scanner.position;
    while (!_scanner.isDone && _isDigit(_scanner.peekChar()!)) {
      _scanner.readChar();
    }
    if (!_scanner.isDone && _scanner.peekChar() == 0x2E /* . */ ) {
      // Check it's a decimal point, not a member access dot
      final dotPos = _scanner.position;
      _scanner.readChar(); // consume .
      if (!_scanner.isDone && _isDigit(_scanner.peekChar()!)) {
        while (!_scanner.isDone && _isDigit(_scanner.peekChar()!)) {
          _scanner.readChar();
        }
        final text = _source.substring(start, _scanner.position);
        return Token(TokenType.double_, double.parse(text), offset);
      }
      // Not a decimal — backtrack the dot
      _scanner.position = dotPos;
    }
    final text = _source.substring(start, _scanner.position);
    return Token(TokenType.integer, int.parse(text), offset);
  }

  Token _scanIdentifier(int offset) {
    final start = _scanner.position;
    _scanner.readChar(); // consume first char
    while (!_scanner.isDone && _isIdentPart(_scanner.peekChar()!)) {
      _scanner.readChar();
    }
    final text = _source.substring(start, _scanner.position);
    return switch (text) {
      'true' => Token(TokenType.true_, true, offset),
      'false' => Token(TokenType.false_, false, offset),
      'null' => Token(TokenType.null_, null, offset),
      'and' => Token(TokenType.and_, null, offset),
      'or' => Token(TokenType.or_, null, offset),
      'not' => Token(TokenType.not_, null, offset),
      _ => Token(TokenType.identifier, text, offset),
    };
  }

  void _skipWhitespace() {
    while (!_scanner.isDone && _isWhitespace(_scanner.peekChar()!)) {
      _scanner.readChar();
    }
  }

  bool _isDigit(int char) => char >= 0x30 && char <= 0x39;

  bool _isIdentStart(int char) =>
      (char >= 0x41 && char <= 0x5A) || // A-Z
      (char >= 0x61 && char <= 0x7A) || // a-z
      char == 0x5F; // _

  bool _isIdentPart(int char) => _isIdentStart(char) || _isDigit(char);

  bool _isWhitespace(int char) => char == 0x20 || char == 0x09 || char == 0x0A || char == 0x0D;
}
