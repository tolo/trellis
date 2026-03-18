import 'package:test/test.dart';
import 'package:trellis/testing.dart';

void main() {
  group('hasTextContent', () {
    test('matches text content (tags stripped)', () {
      expect('<h1>Hello World</h1>', hasTextContent('Hello World'));
    });

    test('does not match when text not present', () {
      expect('<h1>Goodbye</h1>', isNot(hasTextContent('Hello World')));
    });

    test('partial match works (contains, not equals)', () {
      expect('<h1>Hello World</h1>', hasTextContent('Hello'));
    });

    test('handles nested elements', () {
      expect('<div><p>Hello</p><span> World</span></div>', hasTextContent('Hello'));
    });

    test('matches text across nested elements', () {
      expect('<div><p>Hello</p><span> World</span></div>', hasTextContent('World'));
    });

    test('is case-sensitive', () {
      expect('<h1>Hello</h1>', isNot(hasTextContent('hello')));
    });

    test('describe produces readable message', () {
      final description = hasTextContent('Hello').describe(StringDescription()).toString();
      expect(description, contains('Hello'));
    });

    test('describeMismatch shows actual text', () {
      final matchState = <Object?, Object?>{};
      final matcher = hasTextContent('Expected');
      matcher.matches('<p>Actual content</p>', matchState);
      final desc = matcher.describeMismatch('<p>Actual content</p>', StringDescription(), matchState, false).toString();
      expect(desc, contains('Actual content'));
    });

    test('truncates very long text in mismatch description', () {
      final longHtml = '<p>${'x' * 300}</p>';
      final matchState = <Object?, Object?>{};
      final matcher = hasTextContent('Expected');
      matcher.matches(longHtml, matchState);
      final desc = matcher.describeMismatch(longHtml, StringDescription(), matchState, false).toString();
      expect(desc, contains('...'));
    });
  });
}
