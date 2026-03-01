import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Strict mode', () {
    late Trellis strict;

    setUp(() {
      strict = Trellis(loader: MapLoader({}), cache: false, strict: true);
    });

    group('undefined variable', () {
      test('throws ExpressionException for missing variable', () {
        expect(
          () => strict.render('<p tl:text="\${missing}">x</p>', {}),
          throwsA(isA<ExpressionException>().having((e) => e.message, 'message', contains('Undefined variable'))),
        );
      });

      test('throws in tl:if with missing variable', () {
        expect(() => strict.render('<p tl:if="\${missing}">x</p>', {}), throwsA(isA<ExpressionException>()));
      });
    });

    group('explicit null valid', () {
      test('null value in context does not throw', () {
        final result = strict.render('<p tl:text="\${name}">x</p>', {'name': null});
        expect(result, contains('<p></p>'));
      });
    });

    group('defined variable', () {
      test('renders normally', () {
        final result = strict.render('<p tl:text="\${name}">x</p>', {'name': 'Alice'});
        expect(result, contains('<p>Alice</p>'));
      });
    });

    group('undefined member', () {
      test('throws for missing map key via dot access', () {
        expect(
          () => strict.render('<p tl:text="\${user.email}">x</p>', {
            'user': {'name': 'Alice'},
          }),
          throwsA(isA<ExpressionException>().having((e) => e.message, 'message', contains('Undefined member'))),
        );
      });
    });

    group('null-safe traversal', () {
      test('null value with member access returns null (no throw)', () {
        final result = strict.render('<p tl:text="\${user.name}">x</p>', {'user': null});
        expect(result, contains('<p></p>'));
      });
    });

    group('selection expression', () {
      test('*{field} outside tl:object throws', () {
        expect(
          () => strict.render('<p tl:text="*{field}">x</p>', {}),
          throwsA(isA<ExpressionException>().having((e) => e.message, 'message', contains('outside tl:object'))),
        );
      });

      test('*{field} inside tl:object works', () {
        final result = strict.render('<div tl:object="\${item}"><p tl:text="*{name}">x</p></div>', {
          'item': {'name': 'Bob'},
        });
        expect(result, contains('<p>Bob</p>'));
      });
    });

    group('auto-convert', () {
      test('object without toMap/toJson throws', () {
        expect(
          () => strict.render('<p tl:text="\${obj.field}">x</p>', {'obj': Object()}),
          throwsA(isA<ExpressionException>().having((e) => e.message, 'message', contains('no toMap() or toJson()'))),
        );
      });
    });

    group('map index', () {
      test('undefined key throws', () {
        expect(
          () => strict.render('<p tl:text="\${map[key]}">x</p>', {
            'map': {'a': 1},
            'key': 'b',
          }),
          throwsA(isA<ExpressionException>().having((e) => e.message, 'message', contains('Undefined key'))),
        );
      });

      test('existing key works', () {
        final result = strict.render('<p tl:text="\${map[key]}">x</p>', {
          'map': {'a': 1},
          'key': 'a',
        });
        expect(result, contains('<p>1</p>'));
      });
    });

    group('default lenient', () {
      test('Trellis() does not throw for missing variable', () {
        final lenient = Trellis(loader: MapLoader({}), cache: false);
        final result = lenient.render('<p tl:text="\${missing}">x</p>', {});
        expect(result, contains('<p></p>'));
      });
    });

    group('iteration variables', () {
      test('tl:each item variable works in strict mode', () {
        final result = strict.render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {
          'items': ['a', 'b'],
        });
        expect(result, contains('<li>a</li>'));
        expect(result, contains('<li>b</li>'));
      });
    });

    group('auto-converted object member access', () {
      test('throws for missing key on auto-converted object in strict mode', () {
        final obj = _ConvertibleObject({'name': 'Alice'});
        expect(
          () => strict.render('<p tl:text="\${obj.missing}">x</p>', {'obj': obj}),
          throwsA(isA<ExpressionException>().having((e) => e.message, 'message', contains('Undefined member'))),
        );
      });

      test('returns value for present key on auto-converted object', () {
        final obj = _ConvertibleObject({'name': 'Alice'});
        final result = strict.render('<p tl:text="\${obj.name}">x</p>', {'obj': obj});
        expect(result, contains('Alice'));
      });
    });

    group('tl:with variables', () {
      test('tl:with bound variable works in strict mode', () {
        final result = strict.render('<div tl:with="x=\${val}"><p tl:text="\${x}">x</p></div>', {'val': 'hello'});
        expect(result, contains('<p>hello</p>'));
      });
    });

    group('auto-converted object index access', () {
      test('throws for missing index on auto-converted object in strict mode', () {
        final obj = _ConvertibleObject({'a': 1});
        expect(
          () => strict.render(r'<p tl:text="${obj[key]}">x</p>', {'obj': obj, 'key': 'missing'}),
          throwsA(isA<ExpressionException>()),
        );
      });
    });

    group('fragment param variables', () {
      test('parameterized fragment binds params in strict mode', () {
        final result = strict.render(
          '<span tl:fragment="greet(name)"><b tl:text="\${name}">x</b></span>'
          '<div tl:insert="greet(\${user})"></div>',
          {'user': 'Alice'},
        );
        expect(result, contains('<b>Alice</b>'));
      });
    });
  });
}

class _ConvertibleObject {
  final Map<String, dynamic> _data;
  _ConvertibleObject(this._data);
  Map<String, dynamic> toMap() => _data;
}
