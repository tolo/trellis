import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Each processor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    group('basic iteration', () {
      test('replicates element per item', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {
          'items': ['a', 'b', 'c'],
        });
        expect(result, contains('<li>a</li>'));
        expect(result, contains('<li>b</li>'));
        expect(result, contains('<li>c</li>'));
      });

      test('preserves correct order', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {
          'items': ['first', 'second', 'third'],
        });
        final firstIdx = result.indexOf('first');
        final secondIdx = result.indexOf('second');
        final thirdIdx = result.indexOf('third');
        expect(firstIdx, lessThan(secondIdx));
        expect(secondIdx, lessThan(thirdIdx));
      });

      test('original element removed from output', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">placeholder</li></ul>', {
          'items': ['a'],
        });
        expect(result, isNot(contains('placeholder')));
      });

      test('tl:each attribute removed from output', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {
          'items': ['a'],
        });
        expect(result, isNot(contains('tl:each')));
      });

      test('single item produces one element', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {
          'items': ['only'],
        });
        expect('<li>only</li>'.allMatches(result).length, equals(1));
      });

      test('supports syntax without spaces around colon', () {
        final result = render('<ul><li tl:each="item:\${items}" tl:text="\${item}">x</li></ul>', {
          'items': ['a', 'b'],
        });
        expect(result, contains('<li>a</li>'));
        expect(result, contains('<li>b</li>'));
      });

      test('supports ternary collection expression', () {
        final result = render('<ul><li tl:each="item:\${useA} ? \${a} : \${b}" tl:text="\${item}">x</li></ul>', {
          'useA': true,
          'a': ['left'],
          'b': ['right'],
        });
        expect(result, contains('<li>left</li>'));
        expect(result, isNot(contains('<li>right</li>')));
      });
    });

    group('status variable (default name)', () {
      test('index is 0-based', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${itemStat.index}">x</li></ul>', {
          'items': ['a', 'b', 'c'],
        });
        expect(result, contains('<li>0</li>'));
        expect(result, contains('<li>1</li>'));
        expect(result, contains('<li>2</li>'));
      });

      test('count is 1-based', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${itemStat.count}">x</li></ul>', {
          'items': ['a', 'b', 'c'],
        });
        expect(result, contains('<li>1</li>'));
        expect(result, contains('<li>2</li>'));
        expect(result, contains('<li>3</li>'));
      });

      test('size is total count', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${itemStat.size}">x</li></ul>', {
          'items': ['a', 'b', 'c'],
        });
        // All three elements should show size 3
        expect('<li>3</li>'.allMatches(result).length, equals(3));
      });

      test('first is true only for first item', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${itemStat.first}">x</li></ul>', {
          'items': ['a', 'b', 'c'],
        });
        expect(result, contains('<li>true</li>'));
        expect('<li>false</li>'.allMatches(result).length, equals(2));
      });

      test('last is true only for last item', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${itemStat.last}">x</li></ul>', {
          'items': ['a', 'b', 'c'],
        });
        final trueCount = '<li>true</li>'.allMatches(result).length;
        final falseCount = '<li>false</li>'.allMatches(result).length;
        expect(trueCount, equals(1));
        expect(falseCount, equals(2));
      });

      test('odd/even are 0-based', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${itemStat.even}">x</li></ul>', {
          'items': ['a', 'b', 'c'],
        });
        // index 0 -> even=true, index 1 -> even=false, index 2 -> even=true
        final lines = '<li>true</li>'.allMatches(result).length;
        expect(lines, equals(2)); // indices 0 and 2 are even
      });

      test('current equals item value', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${itemStat.current}">x</li></ul>', {
          'items': ['alpha', 'beta'],
        });
        expect(result, contains('<li>alpha</li>'));
        expect(result, contains('<li>beta</li>'));
      });
    });

    group('explicit status variable name', () {
      test('custom status var name works', () {
        final result = render('<ul><li tl:each="item, s : \${items}" tl:text="\${s.index}">x</li></ul>', {
          'items': ['a', 'b'],
        });
        expect(result, contains('<li>0</li>'));
        expect(result, contains('<li>1</li>'));
      });

      test('custom status var provides all fields', () {
        final result = render('<ul><li tl:each="item, st : \${items}" tl:text="\${st.first}">x</li></ul>', {
          'items': ['a', 'b'],
        });
        expect(result, contains('<li>true</li>'));
        expect(result, contains('<li>false</li>'));
      });
    });

    group('empty collection', () {
      test('empty list removes element', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {
          'items': <String>[],
        });
        expect(result, isNot(contains('<li>')));
        expect(result, contains('<ul>'));
      });

      test('empty set removes element', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {
          'items': <String>{},
        });
        expect(result, isNot(contains('<li>')));
      });

      test('empty map removes element', () {
        final result = render('<ul><li tl:each="entry : \${map}" tl:text="\${entry.key}">x</li></ul>', {
          'map': <String, dynamic>{},
        });
        expect(result, isNot(contains('<li>')));
      });

      test('null iterable removes element (treated as empty)', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {'items': null});
        expect(result, isNot(contains('<li>')));
        expect(result, contains('<ul>'));
      });

      test('missing variable removes element (treated as empty)', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {});
        expect(result, isNot(contains('<li>')));
        expect(result, contains('<ul>'));
      });
    });

    group('non-iterable', () {
      test('integer throws TemplateException', () {
        expect(
          () => render('<ul><li tl:each="item : \${val}">x</li></ul>', {'val': 42}),
          throwsA(isA<TemplateException>()),
        );
      });

      test('bool throws TemplateException', () {
        expect(
          () => render('<ul><li tl:each="item : \${val}">x</li></ul>', {'val': true}),
          throwsA(isA<TemplateException>()),
        );
      });

      test('malformed loop variables throw TemplateException', () {
        expect(
          () => render('<ul><li tl:each="item,,stat : \${items}">x</li></ul>', {
            'items': [1, 2],
          }),
          throwsA(isA<TemplateException>()),
        );
      });
    });

    group('Map iteration', () {
      test('iterates map entries with key/value', () {
        final result = render('<ul><li tl:each="entry : \${map}" tl:text="\${entry.key}">x</li></ul>', {
          'map': {'a': 1, 'b': 2},
        });
        expect(result, contains('<li>a</li>'));
        expect(result, contains('<li>b</li>'));
      });

      test('map entry value accessible', () {
        final result = render('<ul><li tl:each="entry : \${map}" tl:text="\${entry.value}">x</li></ul>', {
          'map': {'x': 10, 'y': 20},
        });
        expect(result, contains('<li>10</li>'));
        expect(result, contains('<li>20</li>'));
      });

      test('map iteration has correct status var size', () {
        final result = render('<ul><li tl:each="entry : \${map}" tl:text="\${entryStat.size}">x</li></ul>', {
          'map': {'a': 1, 'b': 2, 'c': 3},
        });
        expect('<li>3</li>'.allMatches(result).length, equals(3));
      });
    });

    group('nested iteration', () {
      test('inner loop iterates per outer item', () {
        final result = render(
          '<div tl:each="group : \${groups}">'
          '<span tl:each="item : \${group}" tl:text="\${item}">x</span>'
          '</div>',
          {
            'groups': [
              ['a', 'b'],
              ['c', 'd'],
            ],
          },
        );
        expect(result, contains('<span>a</span>'));
        expect(result, contains('<span>b</span>'));
        expect(result, contains('<span>c</span>'));
        expect(result, contains('<span>d</span>'));
      });

      test('outer variables accessible in inner scope', () {
        final result = render(
          '<div tl:each="group : \${groups}">'
          '<span tl:each="item : \${group.items}" tl:text="\${group.name}">x</span>'
          '</div>',
          {
            'groups': [
              {
                'name': 'G1',
                'items': ['a'],
              },
              {
                'name': 'G2',
                'items': ['b'],
              },
            ],
          },
        );
        expect(result, contains('<span>G1</span>'));
        expect(result, contains('<span>G2</span>'));
      });
    });

    group('interaction with other processors', () {
      test('tl:each + tl:text on same element renders per iteration', () {
        final result = render('<ul><li tl:each="n : \${nums}" tl:text="\${n}">x</li></ul>', {
          'nums': [1, 2, 3],
        });
        expect(result, contains('<li>1</li>'));
        expect(result, contains('<li>2</li>'));
        expect(result, contains('<li>3</li>'));
      });

      test('tl:each + tl:text on child elements', () {
        final result = render('<ul><li tl:each="item : \${items}"><span tl:text="\${item}">x</span></li></ul>', {
          'items': ['hello', 'world'],
        });
        expect(result, contains('<span>hello</span>'));
        expect(result, contains('<span>world</span>'));
      });
    });

    group('Set and Iterable', () {
      test('Set iteration works', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {
          'items': {'a', 'b', 'c'},
        });
        expect(result, contains('<li>a</li>'));
        expect(result, contains('<li>b</li>'));
        expect(result, contains('<li>c</li>'));
      });

      test('Iterable from where() works', () {
        final result = render('<ul><li tl:each="item : \${items}" tl:text="\${item}">x</li></ul>', {
          'items': [1, 2, 3, 4, 5].where((x) => x > 3),
        });
        expect(result, contains('<li>4</li>'));
        expect(result, contains('<li>5</li>'));
        expect(result, isNot(contains('<li>1</li>')));
      });
    });
  });
}
