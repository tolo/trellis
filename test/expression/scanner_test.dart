import 'package:test/test.dart';
import 'package:trellis/src/expression/scanner.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Scanner', () {
    List<Token> tokenize(String source) {
      final scanner = Scanner(source);
      final tokens = <Token>[];
      while (true) {
        final token = scanner.next();
        tokens.add(token);
        if (token.type == TokenType.eof) break;
      }
      return tokens;
    }

    group('string literals', () {
      test('simple string', () {
        final tokens = tokenize("'hello'");
        expect(tokens[0].type, TokenType.string);
        expect(tokens[0].value, 'hello');
      });

      test('escaped single quote', () {
        final tokens = tokenize(r"'it\'s'");
        expect(tokens[0].type, TokenType.string);
        expect(tokens[0].value, "it's");
      });

      test('empty string', () {
        final tokens = tokenize("''");
        expect(tokens[0].type, TokenType.string);
        expect(tokens[0].value, '');
      });
    });

    group('numeric literals', () {
      test('integer', () {
        final tokens = tokenize('42');
        expect(tokens[0].type, TokenType.integer);
        expect(tokens[0].value, 42);
      });

      test('double', () {
        final tokens = tokenize('3.14');
        expect(tokens[0].type, TokenType.double_);
        expect(tokens[0].value, 3.14);
      });

      test('zero', () {
        final tokens = tokenize('0');
        expect(tokens[0].type, TokenType.integer);
        expect(tokens[0].value, 0);
      });
    });

    group('boolean and null', () {
      test('true', () {
        final tokens = tokenize('true');
        expect(tokens[0].type, TokenType.true_);
        expect(tokens[0].value, true);
      });

      test('false', () {
        final tokens = tokenize('false');
        expect(tokens[0].type, TokenType.false_);
        expect(tokens[0].value, false);
      });

      test('null', () {
        final tokens = tokenize('null');
        expect(tokens[0].type, TokenType.null_);
        expect(tokens[0].value, isNull);
      });
    });

    group('identifiers', () {
      test('simple identifier', () {
        final tokens = tokenize('name');
        expect(tokens[0].type, TokenType.identifier);
        expect(tokens[0].value, 'name');
      });

      test('camelCase identifier', () {
        final tokens = tokenize('itemStat');
        expect(tokens[0].type, TokenType.identifier);
        expect(tokens[0].value, 'itemStat');
      });
    });

    group('operators', () {
      test('==', () {
        final tokens = tokenize('==');
        expect(tokens[0].type, TokenType.eq);
      });

      test('!=', () {
        final tokens = tokenize('!=');
        expect(tokens[0].type, TokenType.notEq);
      });

      test('<', () {
        final tokens = tokenize('<');
        expect(tokens[0].type, TokenType.lt);
      });

      test('>', () {
        final tokens = tokenize('>');
        expect(tokens[0].type, TokenType.gt);
      });

      test('<=', () {
        final tokens = tokenize('<=');
        expect(tokens[0].type, TokenType.lte);
      });

      test('>=', () {
        final tokens = tokenize('>=');
        expect(tokens[0].type, TokenType.gte);
      });

      test('+', () {
        final tokens = tokenize('+');
        expect(tokens[0].type, TokenType.plus);
      });

      test('! as unary not', () {
        final tokens = tokenize('!');
        expect(tokens[0].type, TokenType.not_);
      });

      test('! followed by identifier', () {
        final tokens = tokenize('!active');
        expect(tokens[0].type, TokenType.not_);
        expect(tokens[1].type, TokenType.identifier);
        expect(tokens[1].value, 'active');
      });

      test('!= is notEq, not (not_ + assign)', () {
        final tokens = tokenize('!=');
        expect(tokens, hasLength(2)); // notEq + eof
        expect(tokens[0].type, TokenType.notEq);
      });
    });

    group('arithmetic tokens', () {
      test('-', () {
        final tokens = tokenize('-');
        expect(tokens[0].type, TokenType.minus);
      });

      test('*', () {
        final tokens = tokenize('*');
        expect(tokens[0].type, TokenType.star);
      });

      test('/', () {
        final tokens = tokenize('/');
        expect(tokens[0].type, TokenType.slash);
      });

      test('%', () {
        final tokens = tokenize('%');
        expect(tokens[0].type, TokenType.percent);
      });

      test('sequence: - * / %', () {
        final tokens = tokenize('- * / %');
        expect(tokens[0].type, TokenType.minus);
        expect(tokens[1].type, TokenType.star);
        expect(tokens[2].type, TokenType.slash);
        expect(tokens[3].type, TokenType.percent);
        expect(tokens[4].type, TokenType.eof);
      });

      test('minus before integer emits separate tokens', () {
        final tokens = tokenize('-42');
        expect(tokens[0].type, TokenType.minus);
        expect(tokens[1].type, TokenType.integer);
        expect(tokens[1].value, 42);
      });
    });

    group('boolean keywords', () {
      test('and', () {
        final tokens = tokenize('and');
        expect(tokens[0].type, TokenType.and_);
      });

      test('or', () {
        final tokens = tokenize('or');
        expect(tokens[0].type, TokenType.or_);
      });

      test('not', () {
        final tokens = tokenize('not');
        expect(tokens[0].type, TokenType.not_);
      });
    });

    group('delimiters', () {
      test('.', () => expect(tokenize('.')[0].type, TokenType.dot));
      test(',', () => expect(tokenize(',')[0].type, TokenType.comma));
      test(':', () => expect(tokenize(':')[0].type, TokenType.colon));
      test('(', () => expect(tokenize('(')[0].type, TokenType.lParen));
      test(')', () => expect(tokenize(')')[0].type, TokenType.rParen));
      test('[', () => expect(tokenize('[')[0].type, TokenType.lBracket));
      test(']', () => expect(tokenize(']')[0].type, TokenType.rBracket));
    });

    group('expression wrappers', () {
      test(r'${', () => expect(tokenize(r'${')[0].type, TokenType.dollarLBrace));
      test('@{', () => expect(tokenize('@{')[0].type, TokenType.atLBrace));
      test('}', () => expect(tokenize('}')[0].type, TokenType.rBrace));
    });

    group('elvis vs question', () {
      test('?: produces elvisOp', () {
        final tokens = tokenize('?:');
        expect(tokens[0].type, TokenType.elvisOp);
      });

      test('? alone produces question', () {
        final tokens = tokenize('? ');
        expect(tokens[0].type, TokenType.question);
      });
    });

    group('whitespace', () {
      test('skips whitespace between tokens', () {
        final tokens = tokenize('  42  +  3  ');
        expect(tokens[0].type, TokenType.integer);
        expect(tokens[1].type, TokenType.plus);
        expect(tokens[2].type, TokenType.integer);
        expect(tokens[3].type, TokenType.eof);
      });
    });

    group('errors', () {
      test('unexpected character throws ExpressionException', () {
        expect(() => tokenize('~'), throwsA(isA<ExpressionException>()));
      });
    });

    group('peek', () {
      test('peek does not advance', () {
        final scanner = Scanner('42');
        final first = scanner.peek();
        final second = scanner.peek();
        expect(first.type, second.type);
        expect(first.value, second.value);
      });
    });

    group('comparison aliases', () {
      test('gt → TokenType.gt', () {
        expect(tokenize('gt')[0].type, TokenType.gt);
      });

      test('lt → TokenType.lt', () {
        expect(tokenize('lt')[0].type, TokenType.lt);
      });

      test('ge → TokenType.gte', () {
        expect(tokenize('ge')[0].type, TokenType.gte);
      });

      test('le → TokenType.lte', () {
        expect(tokenize('le')[0].type, TokenType.lte);
      });

      test('eq → TokenType.eq', () {
        expect(tokenize('eq')[0].type, TokenType.eq);
      });

      test('ne → TokenType.notEq', () {
        expect(tokenize('ne')[0].type, TokenType.notEq);
      });

      test('longer identifier "greater" is not aliased', () {
        final tokens = tokenize('greater');
        expect(tokens[0].type, TokenType.identifier);
        expect(tokens[0].value, 'greater');
      });

      test('aliases in expression context', () {
        final tokens = tokenize('a gt b');
        expect(tokens[0].type, TokenType.identifier);
        expect(tokens[1].type, TokenType.gt);
        expect(tokens[2].type, TokenType.identifier);
      });
    });

    group('star-brace token', () {
      test('*{ produces starLBrace', () {
        final tokens = tokenize('*{');
        expect(tokens[0].type, TokenType.starLBrace);
      });

      test('* alone produces star (multiplication)', () {
        final tokens = tokenize('* ');
        expect(tokens[0].type, TokenType.star);
      });

      test('*{ followed by identifier and }', () {
        final tokens = tokenize('*{name}');
        expect(tokens[0].type, TokenType.starLBrace);
        expect(tokens[1].type, TokenType.identifier);
        expect(tokens[1].value, 'name');
        expect(tokens[2].type, TokenType.rBrace);
      });
    });

    group('pipe operator', () {
      test('| produces pipe token', () {
        final tokens = tokenize('|');
        expect(tokens[0].type, TokenType.pipe);
      });

      test('pipe between identifiers', () {
        final tokens = tokenize('name | upper');
        expect(tokens[0].type, TokenType.identifier);
        expect(tokens[1].type, TokenType.pipe);
        expect(tokens[2].type, TokenType.identifier);
        expect(tokens[2].value, 'upper');
      });
    });
  });
}
