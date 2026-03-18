import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

String renderTemplate(String html, Map<String, dynamic> context) =>
    Trellis(loader: MapLoader({}), cache: false).render(html, context);

void main() {
  late ExpressionEvaluator eval;

  setUp(() {
    eval = ExpressionEvaluator();
  });

  group('#strings', () {
    group('isEmpty', () {
      test('null returns true', () {
        expect(eval.evaluate(r'${#strings.isEmpty(v)}', {'v': null}), isTrue);
      });

      test('empty string returns true', () {
        expect(eval.evaluate(r'${#strings.isEmpty(v)}', {'v': ''}), isTrue);
      });

      test('whitespace-only returns true', () {
        expect(eval.evaluate(r'${#strings.isEmpty(v)}', {'v': '   '}), isTrue);
      });

      test('non-empty string returns false', () {
        expect(eval.evaluate(r'${#strings.isEmpty(v)}', {'v': 'hello'}), isFalse);
      });

      test('single space returns true', () {
        expect(eval.evaluate(r'${#strings.isEmpty(v)}', {'v': ' '}), isTrue);
      });
    });

    group('length', () {
      test('returns string length', () {
        expect(eval.evaluate(r'${#strings.length(v)}', {'v': 'hello'}), equals(5));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#strings.length(v)}', {'v': null}), isNull);
      });

      test('empty string returns 0', () {
        expect(eval.evaluate(r'${#strings.length(v)}', {'v': ''}), equals(0));
      });

      test('non-string input coerced via toString', () {
        expect(eval.evaluate(r'${#strings.length(v)}', {'v': 123}), equals(3));
      });
    });

    group('capitalize', () {
      test('capitalizes first char', () {
        expect(eval.evaluate(r'${#strings.capitalize(v)}', {'v': 'hello'}), equals('Hello'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#strings.capitalize(v)}', {'v': null}), isNull);
      });

      test('empty string returns empty', () {
        expect(eval.evaluate(r'${#strings.capitalize(v)}', {'v': ''}), equals(''));
      });

      test('already capitalized unchanged', () {
        expect(eval.evaluate(r'${#strings.capitalize(v)}', {'v': 'Hello'}), equals('Hello'));
      });

      test('single char', () {
        expect(eval.evaluate(r'${#strings.capitalize(v)}', {'v': 'a'}), equals('A'));
      });
    });

    group('upper', () {
      test('converts to uppercase', () {
        expect(eval.evaluate(r'${#strings.upper(v)}', {'v': 'hello'}), equals('HELLO'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#strings.upper(v)}', {'v': null}), isNull);
      });

      test('non-string coerced via toString', () {
        expect(eval.evaluate(r'${#strings.upper(v)}', {'v': 'foo'}), equals('FOO'));
      });
    });

    group('lower', () {
      test('converts to lowercase', () {
        expect(eval.evaluate(r'${#strings.lower(v)}', {'v': 'HELLO'}), equals('hello'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#strings.lower(v)}', {'v': null}), isNull);
      });
    });

    group('trim', () {
      test('trims whitespace', () {
        expect(eval.evaluate(r'${#strings.trim(v)}', {'v': '  hello  '}), equals('hello'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#strings.trim(v)}', {'v': null}), isNull);
      });

      test('no whitespace unchanged', () {
        expect(eval.evaluate(r'${#strings.trim(v)}', {'v': 'hello'}), equals('hello'));
      });
    });

    group('contains', () {
      test('returns true when found', () {
        expect(eval.evaluate(r"${#strings.contains(v, 'ell')}", {'v': 'hello'}), isTrue);
      });

      test('returns false when not found', () {
        expect(eval.evaluate(r"${#strings.contains(v, 'xyz')}", {'v': 'hello'}), isFalse);
      });

      test('null value returns false', () {
        expect(eval.evaluate(r"${#strings.contains(v, 'x')}", {'v': null}), isFalse);
      });
    });

    group('startsWith', () {
      test('returns true when starts with prefix', () {
        expect(eval.evaluate(r"${#strings.startsWith(v, 'he')}", {'v': 'hello'}), isTrue);
      });

      test('returns false otherwise', () {
        expect(eval.evaluate(r"${#strings.startsWith(v, 'lo')}", {'v': 'hello'}), isFalse);
      });

      test('null returns false', () {
        expect(eval.evaluate(r"${#strings.startsWith(v, 'h')}", {'v': null}), isFalse);
      });
    });

    group('endsWith', () {
      test('returns true when ends with suffix', () {
        expect(eval.evaluate(r"${#strings.endsWith(v, 'lo')}", {'v': 'hello'}), isTrue);
      });

      test('returns false otherwise', () {
        expect(eval.evaluate(r"${#strings.endsWith(v, 'he')}", {'v': 'hello'}), isFalse);
      });

      test('null returns false', () {
        expect(eval.evaluate(r"${#strings.endsWith(v, 'o')}", {'v': null}), isFalse);
      });
    });

    group('substring', () {
      test('basic substring', () {
        expect(eval.evaluate(r'${#strings.substring(v, 1, 3)}', {'v': 'hello'}), equals('el'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#strings.substring(v, 0, 2)}', {'v': null}), isNull);
      });

      test('start only (no end)', () {
        expect(eval.evaluate(r'${#strings.substring(v, 2)}', {'v': 'hello'}), equals('llo'));
      });

      test('out-of-range start clamped to 0', () {
        expect(eval.evaluate(r'${#strings.substring(v, -5, 3)}', {'v': 'hello'}), equals('hel'));
      });

      test('out-of-range end clamped to length', () {
        expect(eval.evaluate(r'${#strings.substring(v, 0, 100)}', {'v': 'hello'}), equals('hello'));
      });
    });

    group('replace', () {
      test('replaces all occurrences', () {
        expect(eval.evaluate(r"${#strings.replace(v, 'l', 'r')}", {'v': 'hello'}), equals('herro'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r"${#strings.replace(v, 'a', 'b')}", {'v': null}), isNull);
      });
    });

    group('split', () {
      test('splits by delimiter', () {
        expect(eval.evaluate(r"${#strings.split(v, ',')}", {'v': 'a,b,c'}), equals(['a', 'b', 'c']));
      });

      test('null returns null', () {
        expect(eval.evaluate(r"${#strings.split(v, ',')}", {'v': null}), isNull);
      });
    });

    group('join', () {
      test('joins list with delimiter', () {
        expect(
          eval.evaluate(r"${#strings.join(v, ', ')}", {
            'v': ['a', 'b', 'c'],
          }),
          equals('a, b, c'),
        );
      });

      test('null list returns null', () {
        expect(eval.evaluate(r"${#strings.join(v, ', ')}", {'v': null}), isNull);
      });

      test('list with mixed types', () {
        expect(
          eval.evaluate(r"${#strings.join(v, '-')}", {
            'v': [1, 'two', null, 3],
          }),
          equals('1-two--3'),
        );
      });

      test('non-list throws', () {
        expect(
          () => eval.evaluate(r"${#strings.join(v, ', ')}", {'v': 'not a list'}),
          throwsA(isA<ExpressionException>()),
        );
      });
    });

    group('abbreviate', () {
      test('shortens long strings', () {
        expect(eval.evaluate(r'${#strings.abbreviate(v, 8)}', {'v': 'hello world'}), equals('hello...'));
      });

      test('short string returned unchanged', () {
        expect(eval.evaluate(r'${#strings.abbreviate(v, 20)}', {'v': 'hello'}), equals('hello'));
      });

      test('exact max length returned unchanged', () {
        expect(eval.evaluate(r'${#strings.abbreviate(v, 5)}', {'v': 'hello'}), equals('hello'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#strings.abbreviate(v, 10)}', {'v': null}), isNull);
      });

      test('maxLength < 4 throws', () {
        expect(
          () => eval.evaluate(r'${#strings.abbreviate(v, 3)}', {'v': 'hello'}),
          throwsA(isA<ExpressionException>()),
        );
      });
    });

    group('pad', () {
      test('pads to given length', () {
        expect(eval.evaluate(r'${#strings.pad(v, 8)}', {'v': 'hello'}), equals('hello   '));
      });

      test('custom pad character', () {
        expect(eval.evaluate(r"${#strings.pad(v, 8, '0')}", {'v': '42'}), equals('42000000'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#strings.pad(v, 8)}', {'v': null}), isNull);
      });
    });

    group('repeat', () {
      test('repeats string', () {
        expect(eval.evaluate(r'${#strings.repeat(v, 3)}', {'v': 'ab'}), equals('ababab'));
      });

      test('repeat 0 times returns empty', () {
        expect(eval.evaluate(r'${#strings.repeat(v, 0)}', {'v': 'ab'}), equals(''));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#strings.repeat(v, 3)}', {'v': null}), isNull);
      });
    });

    group('error handling', () {
      test('unknown method throws ExpressionException', () {
        expect(
          () => eval.evaluate(r'${#strings.unknown()}', {}),
          throwsA(
            isA<ExpressionException>().having(
              (e) => e.toString(),
              'message',
              contains('Unknown method: #strings.unknown'),
            ),
          ),
        );
      });

      test('error message lists available methods', () {
        expect(
          () => eval.evaluate(r'${#strings.unknown()}', {}),
          throwsA(isA<ExpressionException>().having((e) => e.toString(), 'message', contains('capitalize'))),
        );
      });

      test('wrong arg count throws', () {
        expect(() => eval.evaluate(r'${#strings.upper()}', {}), throwsA(isA<ExpressionException>()));
      });
    });

    group('integration', () {
      test('tl:text with #strings.capitalize', () {
        final result = renderTemplate('<p tl:text="\${#strings.capitalize(name)}">x</p>', {'name': 'world'});
        expect(result, contains('<p>World</p>'));
      });

      test('tl:if with #strings.isEmpty', () {
        final result = renderTemplate('<span tl:if="\${#strings.isEmpty(val)}">empty</span>', {'val': ''});
        expect(result, contains('<span>empty</span>'));
      });

      test('nested utility calls', () {
        expect(eval.evaluate(r'${#strings.upper(#strings.trim(v))}', {'v': '  hello  '}), equals('HELLO'));
      });

      test('utility call in binary expression', () {
        expect(eval.evaluate(r'${#strings.length(v) > 3}', {'v': 'hello'}), isTrue);
      });
    });
  });
}
