import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('tl:object', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    test('selection expression resolves from Map object', () {
      final result = render(r'<div tl:object="${user}"><span tl:text="*{name}">X</span></div>', {
        'user': {'name': 'Alice'},
      });
      expect(result, contains('<span>Alice</span>'));
    });

    test('nested selection field', () {
      final result = render(r'<div tl:object="${user}"><span tl:text="*{address.city}">X</span></div>', {
        'user': {
          'address': {'city': 'NYC'},
        },
      });
      expect(result, contains('<span>NYC</span>'));
    });

    test('nested tl:object overrides parent', () {
      final result = render(
        r'<div tl:object="${outer}"><div tl:object="${inner}"><span tl:text="*{val}">X</span></div></div>',
        {
          'outer': {
            'val': 'from-outer',
            'inner': {'val': 'from-inner'},
          },
          'inner': {'val': 'from-inner'},
        },
      );
      expect(result, contains('<span>from-inner</span>'));
    });

    test('tl:object attribute removed from output', () {
      final result = render(r'<div tl:object="${user}"><span tl:text="*{name}">X</span></div>', {
        'user': {'name': 'Alice'},
      });
      expect(result, isNot(contains('tl:object')));
    });

    test('selection expression outside tl:object returns null', () {
      final result = render(r'<span tl:text="*{name}">default</span>', {});
      expect(result, contains('<span></span>'));
    });

    test('tl:object with tl:each — selection per item', () {
      final result = render(
        r'<ul><li tl:each="item : ${items}" tl:object="${item}"><span tl:text="*{name}">X</span></li></ul>',
        {
          'items': [
            {'name': 'Alice'},
            {'name': 'Bob'},
          ],
        },
      );
      expect(result, contains('<span>Alice</span>'));
      expect(result, contains('<span>Bob</span>'));
    });

    test('selection with tl:if', () {
      final result = render(r'<div tl:object="${user}"><span tl:if="*{active}" tl:text="*{name}">X</span></div>', {
        'user': {'name': 'Alice', 'active': true},
      });
      expect(result, contains('<span>Alice</span>'));
    });

    test('selection with tl:if false removes element', () {
      final result = render(r'<div tl:object="${user}"><span tl:if="*{active}" tl:text="*{name}">X</span></div>', {
        'user': {'name': 'Alice', 'active': false},
      });
      expect(result, isNot(contains('Alice')));
    });
  });
}
