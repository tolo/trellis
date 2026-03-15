import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('DomProcessor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, [Map<String, dynamic> context = const {}]) => engine.render(template, context);

    test('plain HTML passes through unchanged', () {
      final result = render('<div><p>Hello</p></div>');
      expect(result, contains('<div><p>Hello</p></div>'));
    });

    test('tl:* attributes removed from output', () {
      final result = render('<p tl:foo="bar">text</p>');
      expect(result, isNot(contains('tl:foo')));
      expect(result, contains('<p>text</p>'));
    });

    test('recursive processing — nested elements with tl:text', () {
      final result = render('<div tl:text="\${outer}"><span tl:text="\${inner}">x</span></div>', {
        'outer': 'O',
        'inner': 'I',
      });
      // tl:text on div replaces all children (including span) with text "O"
      expect(result, contains('<div>O</div>'));
    });

    test('multiple tl:* attrs — tl:text processed, all removed', () {
      final result = render('<p tl:text="\${name}" tl:foo="bar">x</p>', {'name': 'Alice'});
      expect(result, contains('<p>Alice</p>'));
      expect(result, isNot(contains('tl:text')));
      expect(result, isNot(contains('tl:foo')));
    });

    test('child elements processed recursively', () {
      final result = render('<div><p tl:text="\${a}">x</p><p tl:text="\${b}">y</p></div>', {
        'a': 'first',
        'b': 'second',
      });
      expect(result, contains('<p>first</p>'));
      expect(result, contains('<p>second</p>'));
    });
  });
}
