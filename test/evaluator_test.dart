import 'package:trellis/trellis.dart';
import 'package:test/test.dart';

void main() {
  group('ExpressionEvaluator', () {
    late ExpressionEvaluator evaluator;

    setUp(() {
      evaluator = ExpressionEvaluator();
    });

    dynamic eval(String expr, [Map<String, dynamic> context = const {}]) => evaluator.evaluate(expr, context);

    group('variable resolution', () {
      test('simple variable', () {
        expect(eval(r'${name}', {'name': 'Alice'}), 'Alice');
      });

      test('nested path', () {
        expect(
          eval(r'${user.name}', {
            'user': {'name': 'Bob'},
          }),
          'Bob',
        );
      });

      test('missing variable returns null', () {
        expect(eval(r'${missing}', {}), isNull);
      });

      test('deeply nested path', () {
        expect(
          eval(r'${a.b.c}', {
            'a': {
              'b': {'c': 42},
            },
          }),
          42,
        );
      });
    });

    group('index access', () {
      test('list index', () {
        expect(
          eval(r'${items[0]}', {
            'items': ['first', 'second'],
          }),
          'first',
        );
      });

      test('out of bounds returns null', () {
        expect(
          eval(r'${items[5]}', {
            'items': ['a'],
          }),
          isNull,
        );
      });
    });

    group('null-safe traversal', () {
      test('null object member returns null', () {
        expect(eval(r'${user.name}', {'user': null}), isNull);
      });

      test('null intermediate returns null', () {
        expect(
          eval(r'${a.b.c}', {
            'a': {'b': null},
          }),
          isNull,
        );
      });
    });

    group('literals', () {
      test('string literal', () => expect(eval("'text'"), 'text'));
      test('true', () => expect(eval('true'), true));
      test('false', () => expect(eval('false'), false));
      test('integer', () => expect(eval('42'), 42));
      test('double', () => expect(eval('3.14'), 3.14));
      test('null', () => expect(eval('null'), isNull));
    });

    group('comparisons', () {
      test(r'comparison inside ${...}', () {
        expect(eval(r'${age >= 18}', {'age': 21}), true);
        expect(eval(r'${age >= 18}', {'age': 17}), false);
      });

      test('>= with numbers', () {
        expect(eval(r'${age} >= 18', {'age': 21}), true);
        expect(eval(r'${age} >= 18', {'age': 10}), false);
      });

      test('== with strings', () {
        expect(eval(r"${name} == 'Alice'", {'name': 'Alice'}), true);
        expect(eval(r"${name} == 'Alice'", {'name': 'Bob'}), false);
      });

      test('!=', () {
        expect(eval(r'${a} != ${b}', {'a': 1, 'b': 2}), true);
        expect(eval(r'${a} != ${b}', {'a': 1, 'b': 1}), false);
      });
    });

    group('boolean ops — isTruthy semantics', () {
      test('not null evaluates to true (null is falsy)', () {
        expect(eval(r'not ${val}', {'val': null}), true);
      });

      test('not non-empty string evaluates to false (truthy)', () {
        expect(eval(r'not ${val}', {'val': 'hello'}), false);
      });

      test('and with non-bool truthy values', () {
        expect(eval(r'${a} and ${b}', {'a': 1, 'b': 'yes'}), true);
        expect(eval(r'${a} and ${b}', {'a': 0, 'b': 'yes'}), false);
      });

      test('or with non-bool values', () {
        expect(eval(r'${a} or ${b}', {'a': null, 'b': 'value'}), true);
        expect(eval(r'${a} or ${b}', {'a': null, 'b': null}), false);
      });
    });

    group('boolean ops', () {
      test(r'boolean expression inside ${...}', () {
        expect(
          eval(r'${user.age >= 18 and user.active}', {
            'user': {'age': 21, 'active': true},
          }),
          true,
        );
      });

      test('and', () {
        expect(eval(r'${a} and ${b}', {'a': true, 'b': true}), true);
        expect(eval(r'${a} and ${b}', {'a': true, 'b': false}), false);
      });

      test('or', () {
        expect(eval(r'${a} or ${b}', {'a': false, 'b': true}), true);
        expect(eval(r'${a} or ${b}', {'a': false, 'b': false}), false);
      });

      test('not', () {
        expect(eval(r'not ${a}', {'a': true}), false);
        expect(eval(r'not ${a}', {'a': false}), true);
      });
    });

    group('string concat', () {
      test('concatenates variables', () {
        expect(eval(r"${first} + ' ' + ${last}", {'first': 'John', 'last': 'Doe'}), 'John Doe');
      });
    });

    group('ternary', () {
      test('true branch', () {
        expect(eval(r"${show} ? 'yes' : 'no'", {'show': true}), 'yes');
      });

      test('false branch', () {
        expect(eval(r"${show} ? 'yes' : 'no'", {'show': false}), 'no');
      });

      test('nested ternary', () {
        expect(eval(r"${a} ? 'A' : ${b} ? 'B' : 'C'", {'a': false, 'b': true}), 'B');
      });
    });

    group('elvis', () {
      test('null falls through to default', () {
        expect(eval(r"${val} ?: 'fallback'", {'val': null}), 'fallback');
      });

      test('non-null passes through', () {
        expect(eval(r"${val} ?: 'fallback'", {'val': 'present'}), 'present');
      });

      test('false is NOT null — passes through', () {
        expect(eval(r"${val} ?: 'fallback'", {'val': false}), false);
      });
    });

    group('URL expressions', () {
      test('simple URL with param', () {
        expect(eval(r'@{/users(id=${userId})}', {'userId': 42}), '/users?id=42');
      });

      test('multiple params', () {
        final result = eval(r'@{/search(q=${query}, page=${page})}', {'query': 'dart', 'page': 1});
        expect(result, '/search?q=dart&page=1');
      });

      test('percent-encoding special chars', () {
        expect(eval(r'@{/search(q=${query})}', {'query': 'hello world'}), '/search?q=hello+world');
      });

      test('URL without params', () {
        expect(eval('@{/home}'), '/home');
      });
    });

    group('operator precedence', () {
      test('and binds tighter than or', () {
        // ${a} or ${b} and ${c}  →  a or (b and c)
        expect(eval(r'${a} or ${b} and ${c}', {'a': true, 'b': false, 'c': false}), true);
      });

      test('== binds tighter than and', () {
        // ${x} == ${y} and ${z}  →  (x == y) and z
        expect(eval(r'${x} == ${y} and ${z}', {'x': 1, 'y': 1, 'z': true}), true);
      });
    });

    group('error handling', () {
      test('malformed expression throws ExpressionException', () {
        expect(() => eval(r'${'), throwsA(isA<ExpressionException>().having((e) => e.expression, 'expression', r'${')));
      });

      test('ExpressionException has position info', () {
        try {
          eval('~invalid');
          fail('Should have thrown');
        } on ExpressionException catch (e) {
          expect(e.position, isNotNull);
        }
      });
    });

    group('edge cases', () {
      test('empty expression throws ExpressionException', () {
        expect(() => eval(''), throwsA(isA<ExpressionException>()));
      });

      test('deeply nested member access', () {
        expect(
          eval(r'${a.b.c.d}', {
            'a': {
              'b': {
                'c': {'d': 'deep'},
              },
            },
          }),
          'deep',
        );
      });
    });

    group('pipe filters', () {
      test('built-in upper: string → uppercase', () {
        expect(eval(r"${'hello' | upper}"), 'HELLO');
      });

      test('built-in upper: null → null', () {
        expect(eval(r'${name | upper}', {'name': null}), isNull);
      });

      test('built-in lower: string → lowercase', () {
        expect(eval(r"${'HELLO' | lower}"), 'hello');
      });

      test('built-in trim: whitespace stripped', () {
        expect(eval(r"${'  hi  ' | trim}"), 'hi');
      });

      test('built-in length on string', () {
        expect(eval(r"${'abc' | length}"), 3);
      });

      test('built-in length on list', () {
        expect(eval(r'${items | length}', {'items': [1, 2, 3]}), 3);
      });

      test('chained filters applied left-to-right', () {
        expect(eval(r'${name | trim | upper}', {'name': ' hello '}), 'HELLO');
      });

      test('unknown filter throws ExpressionException', () {
        expect(() => eval(r'${name | nonexistent}', {'name': 'x'}), throwsA(isA<ExpressionException>()));
      });

      test('custom filter via constructor', () {
        final customEval = ExpressionEvaluator(filters: {'double': (v) => '$v$v'});
        expect(customEval.evaluate(r"${'ab' | double}", {}), 'abab');
      });

      test('custom filter overrides built-in', () {
        final customEval = ExpressionEvaluator(filters: {'upper': (v) => 'CUSTOM'});
        expect(customEval.evaluate(r"${'x' | upper}", {}), 'CUSTOM');
      });
    });
  });
}
