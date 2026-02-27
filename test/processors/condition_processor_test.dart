import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Condition processor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    group('tl:if', () {
      test('truthy — element present', () {
        final result = render('<p tl:if="\${show}">visible</p>', {'show': true});
        expect(result, contains('<p>visible</p>'));
      });

      test('falsy false — element removed', () {
        final result = render('<p tl:if="\${show}">hidden</p>', {'show': false});
        expect(result, isNot(contains('<p>')));
        expect(result, isNot(contains('hidden')));
      });

      test('falsy null — element removed', () {
        final result = render('<p tl:if="\${show}">hidden</p>', {'show': null});
        expect(result, isNot(contains('<p>')));
      });

      test('falsy zero — element removed', () {
        final result = render('<p tl:if="\${show}">hidden</p>', {'show': 0});
        expect(result, isNot(contains('<p>')));
      });

      test('falsy string "false" — element removed', () {
        final result = render('<p tl:if="\${show}">hidden</p>', {'show': 'false'});
        expect(result, isNot(contains('<p>')));
      });

      test('falsy string "off" — element removed', () {
        final result = render('<p tl:if="\${show}">hidden</p>', {'show': 'off'});
        expect(result, isNot(contains('<p>')));
      });

      test('falsy string "no" — element removed', () {
        final result = render('<p tl:if="\${show}">hidden</p>', {'show': 'no'});
        expect(result, isNot(contains('<p>')));
      });

      test('truthy empty string — element present', () {
        final result = render('<p tl:if="\${show}">visible</p>', {'show': ''});
        expect(result, contains('<p>visible</p>'));
      });

      test('truthy empty list — element present', () {
        final result = render('<p tl:if="\${show}">visible</p>', {'show': []});
        expect(result, contains('<p>visible</p>'));
      });

      test('missing var resolves to null — element removed', () {
        final result = render('<p tl:if="\${missing}">hidden</p>', {});
        expect(result, isNot(contains('<p>')));
      });

      test('with expression comparison', () {
        final result = render('<p tl:if="\${age} >= 18">adult</p>', {'age': 21});
        expect(result, contains('<p>adult</p>'));

        final result2 = render('<p tl:if="\${age} >= 18">adult</p>', {'age': 15});
        expect(result2, isNot(contains('<p>')));
      });
    });

    group('tl:unless', () {
      test('truthy — element removed', () {
        final result = render('<p tl:unless="\${show}">hidden</p>', {'show': true});
        expect(result, isNot(contains('<p>')));
      });

      test('falsy — element kept', () {
        final result = render('<p tl:unless="\${show}">visible</p>', {'show': false});
        expect(result, contains('<p>visible</p>'));
      });
    });

    group('children removal', () {
      test('children removed with parent', () {
        final result = render('<div tl:if="\${show}"><p>child</p></div>', {'show': false});
        expect(result, isNot(contains('<div>')));
        expect(result, isNot(contains('<p>')));
        expect(result, isNot(contains('child')));
      });
    });

    group('interaction with other processors', () {
      test('tl:if + tl:text — truthy renders text', () {
        final result = render('<p tl:if="\${show}" tl:text="\${msg}">x</p>', {'show': true, 'msg': 'Hello'});
        expect(result, contains('<p>Hello</p>'));
      });

      test('tl:if + tl:text — falsy renders nothing', () {
        final result = render('<p tl:if="\${show}" tl:text="\${msg}">x</p>', {'show': false, 'msg': 'Hello'});
        expect(result, isNot(contains('<p>')));
      });
    });

    group('attribute removal', () {
      test('tl:if removed from output when truthy', () {
        final result = render('<p tl:if="\${show}">text</p>', {'show': true});
        expect(result, isNot(contains('tl:if')));
      });

      test('tl:unless removed from output when falsy', () {
        final result = render('<p tl:unless="\${show}">text</p>', {'show': false});
        expect(result, isNot(contains('tl:unless')));
      });
    });
  });
}
