import 'package:trellis/trellis.dart';
import 'package:test/test.dart';

// Test helper classes for auto-conversion
class _User {
  final String name;
  final int age;
  _User(this.name, this.age);
  Map<String, dynamic> toMap() => {'name': name, 'age': age};
}

class _UserJson {
  final String name;
  _UserJson(this.name);
  Map<String, dynamic> toJson() => {'name': name};
}

class _Address {
  final String city;
  _Address(this.city);
  Map<String, dynamic> toMap() => {'city': city};
}

class _UserWithAddress {
  final String name;
  final _Address address;
  _UserWithAddress(this.name, this.address);
  Map<String, dynamic> toMap() => {'name': name, 'address': address};
}

class _PlainObject {
  final String value;
  _PlainObject(this.value);
}

class _BrokenToMap {
  Map<String, dynamic> toMap() => throw StateError('broken');
}

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

      test('! operator (alias for not)', () {
        expect(eval(r'!${a}', {'a': true}), false);
        expect(eval(r'!${a}', {'a': false}), true);
      });

      test('! with compound expressions', () {
        expect(eval(r'!${a} and ${b}', {'a': false, 'b': true}), true);
        expect(eval(r'!${a} or ${b}', {'a': true, 'b': false}), false);
      });

      test('! preserves != operator', () {
        expect(eval(r'${a} != ${b}', {'a': 1, 'b': 2}), true);
        expect(eval(r'${a} != ${b}', {'a': 1, 'b': 1}), false);
      });
    });

    group('arithmetic operators', () {
      group('basic int arithmetic', () {
        test('addition', () => expect(eval(r'${a + b}', {'a': 3, 'b': 4}), 7));
        test('subtraction', () => expect(eval(r'${a - b}', {'a': 10, 'b': 3}), 7));
        test('multiplication', () => expect(eval(r'${a * b}', {'a': 3, 'b': 4}), 12));
        test('division returns double', () {
          final result = eval(r'${a / b}', {'a': 10, 'b': 3});
          expect(result, isA<double>());
          expect(result, closeTo(3.333, 0.01));
        });
        test('modulo', () => expect(eval(r'${a % b}', {'a': 10, 'b': 3}), 1));
      });

      group('double arithmetic', () {
        test('double + double', () => expect(eval(r'${a + b}', {'a': 1.5, 'b': 2.5}), 4.0));
        test('int * double promotion', () => expect(eval(r'${a * b}', {'a': 2, 'b': 3.5}), 7.0));
      });

      group('division edge cases', () {
        test('division by zero returns infinity', () {
          expect(eval(r'${a / b}', {'a': 10, 'b': 0}), double.infinity);
        });
        test('modulo by zero returns NaN', () {
          expect(eval(r'${a % b}', {'a': 10, 'b': 0}), isNaN);
        });
        test('0/0 returns NaN', () {
          expect(eval(r'${a / b}', {'a': 0, 'b': 0}), isNaN);
        });
      });

      group('precedence', () {
        test('2 + 3 * 4 = 14', () => expect(eval(r'${2 + 3 * 4}'), 14));
        test('(2 + 3) * 4 = 20', () => expect(eval(r'${(2 + 3) * 4}'), 20));
        test('10 - 2 * 3 = 4', () => expect(eval(r'${10 - 2 * 3}'), 4));
        test('10 / 2 + 3 = 8.0', () => expect(eval(r'${10 / 2 + 3}'), 8.0));
      });

      group('unary minus', () {
        test('negate int', () => expect(eval(r'${-a}', {'a': 5}), -5));
        test('negate double', () => expect(eval(r'${-a}', {'a': 3.14}), -3.14));
        test('multiply with unary minus', () {
          expect(eval(r'${a * -b}', {'a': 3, 'b': 4}), -12);
        });
      });

      group('string + num concatenation', () {
        test('string + num', () {
          expect(eval(r'${str + num}', {'str': 'val', 'num': 42}), 'val42');
        });
        test('num + string', () {
          expect(eval(r'${num + str}', {'num': 42, 'str': 'val'}), '42val');
        });
      });

      group('null arithmetic errors', () {
        test('num + null throws', () {
          expect(() => eval(r'${a + b}', {'a': 1, 'b': null}), throwsA(isA<ExpressionException>()));
        });
        test('null - num throws', () {
          expect(() => eval(r'${a - b}', {'a': null, 'b': 1}), throwsA(isA<ExpressionException>()));
        });
        test('negate null throws', () {
          expect(() => eval(r'${-a}', {'a': null}), throwsA(isA<ExpressionException>()));
        });
      });

      group('type errors', () {
        test('string * num throws', () {
          expect(() => eval(r'${a * b}', {'a': 'text', 'b': 3}), throwsA(isA<ExpressionException>()));
        });
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

      test('truthy non-boolean condition', () {
        expect(eval(r"${x} ? 'yes' : 'no'", {'x': 1}), 'yes');
        expect(eval(r"${x} ? 'yes' : 'no'", {'x': 0}), 'no');
        expect(eval(r"${x} ? 'yes' : 'no'", {'x': 'hello'}), 'yes');
        expect(eval(r"${x} ? 'yes' : 'no'", {'x': null}), 'no');
        expect(eval(r"${x} ? 'yes' : 'no'", {'x': 'false'}), 'no');
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

      test('all alias/keyword words as member names', () {
        final obj = {
          'gt': 1,
          'lt': 2,
          'ge': 3,
          'le': 4,
          'eq': 5,
          'ne': 6,
          'and': 7,
          'or': 8,
          'not': 9,
          'true': 10,
          'false': 11,
          'null': 12,
        };
        final ctx = {'obj': obj};
        expect(eval(r'${obj.gt}', ctx), 1);
        expect(eval(r'${obj.lt}', ctx), 2);
        expect(eval(r'${obj.ge}', ctx), 3);
        expect(eval(r'${obj.le}', ctx), 4);
        expect(eval(r'${obj.eq}', ctx), 5);
        expect(eval(r'${obj.ne}', ctx), 6);
        expect(eval(r'${obj.and}', ctx), 7);
        expect(eval(r'${obj.or}', ctx), 8);
        expect(eval(r'${obj.not}', ctx), 9);
        expect(eval(r'${obj.true}', ctx), 10);
        expect(eval(r'${obj.false}', ctx), 11);
        expect(eval(r'${obj.null}', ctx), 12);
      });

      test('chained keyword members (a.not.gt)', () {
        expect(
          eval(r'${a.not.gt}', {
            'a': {
              'not': {'gt': 'found'},
            },
          }),
          'found',
        );
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

    group('literal substitution', () {
      test('text with expression', () {
        expect(eval(r'|Welcome, ${name}!|', {'name': 'World'}), 'Welcome, World!');
      });

      test('multiple expressions', () {
        expect(eval(r'|${first} ${last}|', {'first': 'John', 'last': 'Doe'}), 'John Doe');
      });

      test('empty literal sub', () {
        expect(eval('||'), '');
      });

      test('plain text only', () {
        expect(eval('|just text|'), 'just text');
      });

      test('null expression evaluates to empty string', () {
        expect(eval(r'|Hello, ${name}!|', {'name': null}), 'Hello, !');
      });

      test('preserves whitespace', () {
        expect(eval(r'|  ${x}  |', {'x': 'hi'}), '  hi  ');
      });
    });

    group('dynamic index', () {
      test('variable index on list', () {
        expect(
          eval(r'${list[idx]}', {
            'list': [10, 20, 30],
            'idx': 1,
          }),
          20,
        );
      });

      test('expression index on list', () {
        expect(
          eval(r'${list[offset + 1]}', {
            'list': [10, 20, 30],
            'offset': 0,
          }),
          20,
        );
      });

      test('nested index (matrix)', () {
        expect(
          eval(r'${matrix[row][col]}', {
            'matrix': [
              [1, 2],
              [3, 4],
            ],
            'row': 1,
            'col': 0,
          }),
          3,
        );
      });

      test('non-int index on list throws', () {
        expect(
          () => eval(r'${list[key]}', {
            'list': [1, 2],
            'key': 'a',
          }),
          throwsA(isA<ExpressionException>()),
        );
      });

      test('out of bounds returns null', () {
        expect(
          eval(r'${list[idx]}', {
            'list': [1],
            'idx': 5,
          }),
          isNull,
        );
      });

      test('dynamic key on map', () {
        expect(
          eval(r'${map[key]}', {
            'map': {'a': 1, 'b': 2},
            'key': 'a',
          }),
          1,
        );
      });

      test('int key on map', () {
        expect(
          eval(r'${map[key]}', {
            'map': {0: 'zero', 1: 'one'},
            'key': 0,
          }),
          'zero',
        );
      });

      test('null target returns null', () {
        expect(eval(r'${x[0]}', {'x': null}), isNull);
      });
    });

    group('comparison aliases', () {
      test('gt equivalent to >', () {
        expect(eval(r'${a gt b}', {'a': 5, 'b': 3}), true);
        expect(eval(r'${a gt b}', {'a': 1, 'b': 3}), false);
      });

      test('lt equivalent to <', () {
        expect(eval(r'${a lt b}', {'a': 1, 'b': 3}), true);
      });

      test('ge equivalent to >=', () {
        expect(eval(r'${a ge b}', {'a': 3, 'b': 3}), true);
        expect(eval(r'${a ge b}', {'a': 2, 'b': 3}), false);
      });

      test('le equivalent to <=', () {
        expect(eval(r'${a le b}', {'a': 3, 'b': 3}), true);
      });

      test('eq equivalent to ==', () {
        expect(eval(r'${a eq b}', {'a': 1, 'b': 1}), true);
        expect(eval(r'${a eq b}', {'a': 1, 'b': 2}), false);
      });

      test('ne equivalent to !=', () {
        expect(eval(r'${a ne b}', {'a': 1, 'b': 2}), true);
        expect(eval(r'${a ne b}', {'a': 1, 'b': 1}), false);
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
        expect(
          eval(r'${items | length}', {
            'items': [1, 2, 3],
          }),
          3,
        );
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

    group('object auto-conversion', () {
      test('dot access via toMap()', () {
        expect(eval(r'${user.name}', {'user': _User('Alice', 30)}), 'Alice');
      });

      test('dot access numeric field via toMap()', () {
        expect(eval(r'${user.age}', {'user': _User('Alice', 30)}), 30);
      });

      test('dot access via toJson() fallback', () {
        expect(eval(r'${user.name}', {'user': _UserJson('Bob')}), 'Bob');
      });

      test('nested auto-convert (user.address.city)', () {
        expect(eval(r'${user.address.city}', {'user': _UserWithAddress('A', _Address('NYC'))}), 'NYC');
      });

      test('top-level reference returns object as-is', () {
        final user = _User('Alice', 30);
        expect(eval(r'${user}', {'user': user}), same(user));
      });

      test('no toMap/toJson throws ExpressionException', () {
        expect(() => eval(r'${obj.field}', {'obj': _PlainObject('x')}), throwsA(isA<ExpressionException>()));
      });

      test('toMap() throws domain error wraps as TemplateException', () {
        expect(() => eval(r'${obj.field}', {'obj': _BrokenToMap()}), throwsA(isA<TemplateException>()));
      });

      test('null target returns null', () {
        expect(eval(r'${user.name}', {'user': null}), isNull);
      });

      test('bracket access with auto-conversion', () {
        expect(eval(r'${user[key]}', {'user': _User('Alice', 30), 'key': 'name'}), 'Alice');
      });
    });

    group('selection expressions', () {
      test('simple selection from Map', () {
        expect(
          eval(r'*{name}', {
            ExpressionEvaluator.selectionKey: {'name': 'Alice'},
          }),
          'Alice',
        );
      });

      test('nested selection field', () {
        expect(
          eval(r'*{address.city}', {
            ExpressionEvaluator.selectionKey: {
              'address': {'city': 'NYC'},
            },
          }),
          'NYC',
        );
      });

      test('selection without tl:object returns null', () {
        expect(eval(r'*{name}', {}), isNull);
      });

      test('selection with auto-converting object', () {
        expect(eval(r'*{name}', {ExpressionEvaluator.selectionKey: _User('Alice', 30)}), 'Alice');
      });

      test('selection preserves outer context', () {
        expect(
          eval(r"*{name} + ' ' + ${greeting}", {
            ExpressionEvaluator.selectionKey: {'name': 'Alice'},
            'greeting': 'Hello',
          }),
          'Alice Hello',
        );
      });
    });
  });
}
