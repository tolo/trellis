import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

String renderTemplate(String html, Map<String, dynamic> context) =>
    Trellis(loader: MapLoader({}), cache: false).render(html, context);

void main() {
  late ExpressionEvaluator eval;

  setUp(() {
    eval = ExpressionEvaluator();
  });

  group('#lists', () {
    group('size', () {
      test('returns list length', () {
        expect(
          eval.evaluate(r'${#lists.size(v)}', {
            'v': [1, 2, 3],
          }),
          equals(3),
        );
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#lists.size(v)}', {'v': null}), isNull);
      });

      test('empty list returns 0', () {
        expect(eval.evaluate(r'${#lists.size(v)}', {'v': <dynamic>[]}), equals(0));
      });

      test('non-list throws', () {
        expect(() => eval.evaluate(r'${#lists.size(v)}', {'v': 'not a list'}), throwsA(isA<ExpressionException>()));
      });
    });

    group('isEmpty', () {
      test('null returns true', () {
        expect(eval.evaluate(r'${#lists.isEmpty(v)}', {'v': null}), isTrue);
      });

      test('empty list returns true', () {
        expect(eval.evaluate(r'${#lists.isEmpty(v)}', {'v': <dynamic>[]}), isTrue);
      });

      test('non-empty list returns false', () {
        expect(
          eval.evaluate(r'${#lists.isEmpty(v)}', {
            'v': [1],
          }),
          isFalse,
        );
      });

      test('non-list returns true', () {
        expect(eval.evaluate(r'${#lists.isEmpty(v)}', {'v': 'x'}), isTrue);
      });
    });

    group('contains', () {
      test('returns true when element found', () {
        expect(
          eval.evaluate(r'${#lists.contains(v, 2)}', {
            'v': [1, 2, 3],
          }),
          isTrue,
        );
      });

      test('returns false when not found', () {
        expect(
          eval.evaluate(r'${#lists.contains(v, 5)}', {
            'v': [1, 2, 3],
          }),
          isFalse,
        );
      });

      test('null list returns false', () {
        expect(eval.evaluate(r'${#lists.contains(v, 1)}', {'v': null}), isFalse);
      });
    });

    group('sort', () {
      test('natural sort of ints', () {
        expect(
          eval.evaluate(r'${#lists.sort(v)}', {
            'v': [3, 1, 2],
          }),
          equals([1, 2, 3]),
        );
      });

      test('natural sort of strings', () {
        expect(
          eval.evaluate(r'${#lists.sort(v)}', {
            'v': ['banana', 'apple', 'cherry'],
          }),
          equals(['apple', 'banana', 'cherry']),
        );
      });

      test('sort by map property', () {
        final items = [
          {'name': 'Charlie'},
          {'name': 'Alice'},
          {'name': 'Bob'},
        ];
        final result = eval.evaluate(r"${#lists.sort(v, 'name')}", {'v': items}) as List;
        expect(result.map((e) => (e as Map)['name']).toList(), equals(['Alice', 'Bob', 'Charlie']));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#lists.sort(v)}', {'v': null}), isNull);
      });

      test('original list not mutated', () {
        final original = [3, 1, 2];
        eval.evaluate(r'${#lists.sort(v)}', {'v': original});
        expect(original, equals([3, 1, 2]));
      });
    });

    group('reverse', () {
      test('reverses list', () {
        expect(
          eval.evaluate(r'${#lists.reverse(v)}', {
            'v': [1, 2, 3],
          }),
          equals([3, 2, 1]),
        );
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#lists.reverse(v)}', {'v': null}), isNull);
      });

      test('empty list returns empty', () {
        expect(eval.evaluate(r'${#lists.reverse(v)}', {'v': <dynamic>[]}), equals(<dynamic>[]));
      });
    });

    group('first / last', () {
      test('first returns first element', () {
        expect(
          eval.evaluate(r'${#lists.first(v)}', {
            'v': [10, 20, 30],
          }),
          equals(10),
        );
      });

      test('last returns last element', () {
        expect(
          eval.evaluate(r'${#lists.last(v)}', {
            'v': [10, 20, 30],
          }),
          equals(30),
        );
      });

      test('first on empty list returns null', () {
        expect(eval.evaluate(r'${#lists.first(v)}', {'v': <dynamic>[]}), isNull);
      });

      test('last on empty list returns null', () {
        expect(eval.evaluate(r'${#lists.last(v)}', {'v': <dynamic>[]}), isNull);
      });

      test('null list returns null', () {
        expect(eval.evaluate(r'${#lists.first(v)}', {'v': null}), isNull);
        expect(eval.evaluate(r'${#lists.last(v)}', {'v': null}), isNull);
      });
    });

    group('take / skip', () {
      test('take first n elements', () {
        expect(
          eval.evaluate(r'${#lists.take(v, 2)}', {
            'v': [1, 2, 3, 4],
          }),
          equals([1, 2]),
        );
      });

      test('take more than list length returns all', () {
        expect(
          eval.evaluate(r'${#lists.take(v, 10)}', {
            'v': [1, 2],
          }),
          equals([1, 2]),
        );
      });

      test('skip first n elements', () {
        expect(
          eval.evaluate(r'${#lists.skip(v, 2)}', {
            'v': [1, 2, 3, 4],
          }),
          equals([3, 4]),
        );
      });

      test('skip more than list length returns empty', () {
        expect(
          eval.evaluate(r'${#lists.skip(v, 10)}', {
            'v': [1, 2],
          }),
          equals(<dynamic>[]),
        );
      });

      test('null list returns null', () {
        expect(eval.evaluate(r'${#lists.take(v, 2)}', {'v': null}), isNull);
        expect(eval.evaluate(r'${#lists.skip(v, 2)}', {'v': null}), isNull);
      });
    });

    group('where', () {
      final items = [
        {'name': 'Alice', 'age': 30, 'active': true},
        {'name': 'Bob', 'age': 25, 'active': false},
        {'name': 'Charlie', 'age': 35, 'active': true},
      ];

      test('3-arg equality filter', () {
        final result = eval.evaluate(r"${#lists.where(v, 'active', true)}", {'v': items}) as List;
        expect(result.length, equals(2));
        expect((result[0] as Map)['name'], equals('Alice'));
      });

      test('4-arg greater-than filter', () {
        final result = eval.evaluate(r"${#lists.where(v, 'age', '>', 28)}", {'v': items}) as List;
        expect(result.length, equals(2));
        expect((result.map((e) => (e as Map)['name'])).toList(), containsAll(['Alice', 'Charlie']));
      });

      test('4-arg less-than filter', () {
        final result = eval.evaluate(r"${#lists.where(v, 'age', '<', 30)}", {'v': items}) as List;
        expect(result.length, equals(1));
        expect((result[0] as Map)['name'], equals('Bob'));
      });

      test('4-arg >= filter', () {
        final result = eval.evaluate(r"${#lists.where(v, 'age', '>=', 30)}", {'v': items}) as List;
        expect(result.length, equals(2));
      });

      test('4-arg <= filter', () {
        final result = eval.evaluate(r"${#lists.where(v, 'age', '<=', 30)}", {'v': items}) as List;
        expect(result.length, equals(2));
      });

      test('4-arg != filter', () {
        final result = eval.evaluate(r"${#lists.where(v, 'active', '!=', true)}", {'v': items}) as List;
        expect(result.length, equals(1));
        expect((result[0] as Map)['name'], equals('Bob'));
      });

      test('null list returns null', () {
        expect(eval.evaluate(r"${#lists.where(v, 'x', 'y')}", {'v': null}), isNull);
      });

      test('unknown operator throws', () {
        expect(
          () => eval.evaluate(r"${#lists.where(v, 'age', '~=', 30)}", {'v': items}),
          throwsA(isA<ExpressionException>().having((e) => e.toString(), 'message', contains('unknown operator'))),
        );
      });

      test('incomparable types with > throws', () {
        final mixed = [
          {'val': 'abc'},
          {'val': 1},
        ];
        expect(
          () => eval.evaluate(r"${#lists.where(v, 'val', '>', 'a')}", {'v': mixed}),
          throwsA(isA<ExpressionException>()),
        );
      });
    });

    group('map', () {
      test('extracts property from each map element', () {
        final items = [
          {'name': 'Alice'},
          {'name': 'Bob'},
          {'name': 'Charlie'},
        ];
        expect(eval.evaluate(r"${#lists.map(v, 'name')}", {'v': items}), equals(['Alice', 'Bob', 'Charlie']));
      });

      test('null list returns null', () {
        expect(eval.evaluate(r"${#lists.map(v, 'name')}", {'v': null}), isNull);
      });

      test('non-map elements return null', () {
        expect(
          eval.evaluate(r"${#lists.map(v, 'x')}", {
            'v': [1, 2, 3],
          }),
          equals([null, null, null]),
        );
      });
    });

    group('flatten', () {
      test('flattens nested list', () {
        expect(
          eval.evaluate(r'${#lists.flatten(v)}', {
            'v': [
              [1, 2],
              [3, 4],
            ],
          }),
          equals([1, 2, 3, 4]),
        );
      });

      test('flattens deeply nested', () {
        expect(
          eval.evaluate(r'${#lists.flatten(v)}', {
            'v': [
              [
                1,
                [2, 3],
              ],
              [4],
            ],
          }),
          equals([1, 2, 3, 4]),
        );
      });

      test('already flat list unchanged', () {
        expect(
          eval.evaluate(r'${#lists.flatten(v)}', {
            'v': [1, 2, 3],
          }),
          equals([1, 2, 3]),
        );
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#lists.flatten(v)}', {'v': null}), isNull);
      });
    });

    group('distinct', () {
      test('removes duplicates', () {
        expect(
          eval.evaluate(r'${#lists.distinct(v)}', {
            'v': [1, 2, 1, 3, 2],
          }),
          equals([1, 2, 3]),
        );
      });

      test('preserves first occurrence order', () {
        expect(
          eval.evaluate(r'${#lists.distinct(v)}', {
            'v': ['c', 'a', 'b', 'a', 'c'],
          }),
          equals(['c', 'a', 'b']),
        );
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#lists.distinct(v)}', {'v': null}), isNull);
      });

      test('no duplicates unchanged', () {
        expect(
          eval.evaluate(r'${#lists.distinct(v)}', {
            'v': [1, 2, 3],
          }),
          equals([1, 2, 3]),
        );
      });
    });

    group('join', () {
      test('joins with default delimiter', () {
        expect(
          eval.evaluate(r'${#lists.join(v)}', {
            'v': ['a', 'b', 'c'],
          }),
          equals('a, b, c'),
        );
      });

      test('joins with custom delimiter', () {
        expect(
          eval.evaluate(r"${#lists.join(v, '-')}", {
            'v': ['a', 'b', 'c'],
          }),
          equals('a-b-c'),
        );
      });

      test('null list returns null', () {
        expect(eval.evaluate(r'${#lists.join(v)}', {'v': null}), isNull);
      });

      test('null elements rendered as empty string', () {
        expect(
          eval.evaluate(r'${#lists.join(v)}', {
            'v': ['a', null, 'c'],
          }),
          equals('a, , c'),
        );
      });
    });

    group('error handling', () {
      test('unknown method throws', () {
        expect(() => eval.evaluate(r'${#lists.unknown()}', {}), throwsA(isA<ExpressionException>()));
      });

      test('non-list input on size throws', () {
        expect(
          () => eval.evaluate(r'${#lists.size(v)}', {'v': 'abc'}),
          throwsA(
            isA<ExpressionException>().having((e) => e.toString(), 'message', contains('#lists.size expects a list')),
          ),
        );
      });
    });

    group('integration', () {
      test('tl:each with sorted list', () {
        final result = renderTemplate('<ul><li tl:each="n : \${#lists.sort(v)}" tl:text="\${n}">x</li></ul>', {
          'v': ['banana', 'apple', 'cherry'],
        });
        expect(result.indexOf('apple'), lessThan(result.indexOf('banana')));
        expect(result.indexOf('banana'), lessThan(result.indexOf('cherry')));
      });
    });
  });
}
