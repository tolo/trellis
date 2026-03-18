import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

String renderTemplate(String html, Map<String, dynamic> context) =>
    Trellis(loader: MapLoader({}), cache: false).render(html, context);

void main() {
  late ExpressionEvaluator eval;

  setUp(() {
    eval = ExpressionEvaluator();
  });

  group('Utility call dispatch', () {
    group('parser', () {
      test('#strings.capitalize parses and evaluates', () {
        expect(eval.evaluate(r'${#strings.capitalize(name)}', {'name': 'world'}), equals('World'));
      });

      test('#dates.now() with zero args', () {
        final result = eval.evaluate(r'${#dates.now()}', {});
        expect(result, isA<DateTime>());
      });

      test('#lists.where with string operator arg', () {
        final items = [
          {'price': 5},
          {'price': 15},
          {'price': 20},
        ];
        final result = eval.evaluate(r"${#lists.where(items, 'price', '>', 10)}", {'items': items}) as List;
        expect(result.length, equals(2));
      });

      test('nested utility calls', () {
        expect(eval.evaluate(r'${#strings.upper(#strings.trim(v))}', {'v': '  hello  '}), equals('HELLO'));
      });

      test('utility call in binary expression', () {
        expect(eval.evaluate(r'${#strings.length(v) > 3}', {'v': 'hello'}), isTrue);
        expect(eval.evaluate(r'${#strings.length(v) > 3}', {'v': 'hi'}), isFalse);
      });

      test('utility call in ternary expression', () {
        expect(eval.evaluate(r"${#strings.isEmpty(v) ? 'default' : v}", {'v': ''}), equals('default'));
        expect(eval.evaluate(r"${#strings.isEmpty(v) ? 'default' : v}", {'v': 'hello'}), equals('hello'));
      });

      test('#{key} message expression still works (no interference)', () {
        final evalWithMessages = ExpressionEvaluator(
          messageSource: MapMessageSource(
            messages: {
              'en': {'greeting': 'Hello!'},
            },
          ),
        );
        expect(evalWithMessages.evaluate('#{greeting}', {}), equals('Hello!'));
      });

      test('utility call as argument to another utility', () {
        expect(eval.evaluate(r'${#strings.length(#strings.trim(v))}', {'v': '  hi  '}), equals(2));
      });
    });

    group('error handling', () {
      test('unknown utility object throws ExpressionException', () {
        expect(
          () => eval.evaluate(r'${#foo.bar()}', {}),
          throwsA(
            isA<ExpressionException>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('Unknown utility object: #foo'), contains('Available:')),
            ),
          ),
        );
      });

      test('error lists all available utility objects', () {
        expect(
          () => eval.evaluate(r'${#foo.bar()}', {}),
          throwsA(
            isA<ExpressionException>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('#strings'), contains('#numbers'), contains('#dates'), contains('#lists')),
            ),
          ),
        );
      });

      test('unknown method throws with available methods list', () {
        expect(
          () => eval.evaluate(r'${#strings.unknown()}', {}),
          throwsA(
            isA<ExpressionException>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('Unknown method: #strings.unknown'), contains('capitalize')),
            ),
          ),
        );
      });

      test('missing parens causes parse error', () {
        expect(() => eval.evaluate(r'${#strings.upper}', {}), throwsA(isA<ExpressionException>()));
      });

      test('missing dot causes parse error', () {
        expect(() => eval.evaluate(r'${#strings()}', {}), throwsA(isA<ExpressionException>()));
      });

      test('missing method name causes parse error', () {
        expect(() => eval.evaluate(r'${#strings.}', {}), throwsA(isA<ExpressionException>()));
      });
    });

    group('integration with tl:* contexts', () {
      test('tl:text', () {
        final result = renderTemplate('<p tl:text="\${#strings.upper(v)}">x</p>', {'v': 'hello'});
        expect(result, contains('<p>HELLO</p>'));
      });

      test('tl:if with utility returning bool', () {
        final result = renderTemplate('<span tl:if="\${#strings.isEmpty(v)}">empty</span>', {'v': ''});
        expect(result, contains('<span>empty</span>'));
      });

      test('tl:if false hides element', () {
        final result = renderTemplate('<span tl:if="\${#strings.isEmpty(v)}">empty</span>', {'v': 'hello'});
        expect(result, isNot(contains('<span>')));
      });

      test('tl:each with utility returning list', () {
        final result = renderTemplate('<ul><li tl:each="n : \${#lists.sort(v)}" tl:text="\${n}">x</li></ul>', {
          'v': [3, 1, 2],
        });
        // sorted order: 1 appears before 2 appears before 3
        expect(result.indexOf('>1<'), lessThan(result.indexOf('>2<')));
        expect(result.indexOf('>2<'), lessThan(result.indexOf('>3<')));
      });

      test('tl:with binding using utility call', () {
        final result = renderTemplate(
          '<div tl:with="upper=\${#strings.upper(v)}"><span tl:text="\${upper}">x</span></div>',
          {'v': 'hello'},
        );
        expect(result, contains('<span>HELLO</span>'));
      });

      test('tl:attr with utility call', () {
        final result = renderTemplate('<a tl:attr="title=\${#strings.capitalize(v)}">link</a>', {'v': 'click here'});
        expect(result, contains('title="Click here"'));
      });

      test('literal substitution with utility call', () {
        final result = renderTemplate('<p tl:text="|\${#strings.capitalize(name)} rocks!|">x</p>', {'name': 'trellis'});
        expect(result, contains('<p>Trellis rocks!</p>'));
      });

      test('URL expression with utility call param', () {
        final result = renderTemplate('<a tl:href="@{/search(q=\${#strings.lower(q)})}">search</a>', {'q': 'HELLO'});
        expect(result, contains('href="/search?q=hello"'));
      });

      test('pipe filter after utility call', () {
        final result = renderTemplate('<p tl:text="\${#strings.capitalize(v) | upper}">x</p>', {'v': 'hello'});
        expect(result, contains('<p>HELLO</p>'));
      });
    });
  });
}
