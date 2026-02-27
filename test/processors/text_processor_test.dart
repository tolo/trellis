import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Text processor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    group('tl:text', () {
      test('replaces placeholder text with value', () {
        final result = render('<p tl:text="\${name}">placeholder</p>', {'name': 'Alice'});
        expect(result, contains('<p>Alice</p>'));
      });

      test('escapes HTML special characters', () {
        final result = render('<p tl:text="\${val}">x</p>', {'val': '<script>alert("xss")</script>'});
        expect(result, contains('&lt;script&gt;'));
        expect(result, isNot(contains('<script>')));
      });

      test('escapes ampersand', () {
        final result = render('<p tl:text="\${val}">x</p>', {'val': 'a&b'});
        expect(result, contains('a&amp;b'));
      });

      test('quotes in text content are safe (HTML5 text escaping)', () {
        // In HTML5 text content, " and ' do not need escaping (only < > & do).
        // package:html correctly follows this spec.
        final result = render('<p tl:text="\${val}">x</p>', {'val': 'a"b\'c'});
        expect(result, contains('a"b\'c'));
      });

      test('null renders empty string', () {
        final result = render('<p tl:text="\${missing}">placeholder</p>', {});
        expect(result, contains('<p></p>'));
      });

      test('non-string value calls toString()', () {
        final result = render('<p tl:text="\${num}">x</p>', {'num': 42});
        expect(result, contains('<p>42</p>'));
      });

      test('boolean toString', () {
        final result = render('<p tl:text="\${flag}">x</p>', {'flag': true});
        expect(result, contains('<p>true</p>'));
      });

      test('nested path expression', () {
        final result = render('<p tl:text="\${user.name}">x</p>', {
          'user': {'name': 'Bob'},
        });
        expect(result, contains('<p>Bob</p>'));
      });
    });

    group('tl:utext', () {
      test('inserts raw HTML', () {
        final result = render('<div tl:utext="\${html}">placeholder</div>', {'html': '<b>bold</b>'});
        expect(result, contains('<div><b>bold</b></div>'));
      });

      test('null renders empty element', () {
        final result = render('<div tl:utext="\${missing}">placeholder</div>', {});
        expect(result, contains('<div></div>'));
      });

      test('preserves HTML tags in output', () {
        final result = render('<div tl:utext="\${html}">x</div>', {'html': '<em>italic</em> <a href="#">link</a>'});
        expect(result, contains('<em>italic</em>'));
        expect(result, contains('<a href="#">link</a>'));
      });
    });

    group('attribute removal', () {
      test('tl:text attribute removed from output', () {
        final result = render('<p tl:text="\${name}">x</p>', {'name': 'Alice'});
        expect(result, isNot(contains('tl:text')));
      });

      test('tl:utext attribute removed from output', () {
        final result = render('<div tl:utext="\${html}">x</div>', {'html': '<b>hi</b>'});
        expect(result, isNot(contains('tl:utext')));
      });
    });
  });
}
