import 'package:test/test.dart';
import 'package:trellis/testing.dart';

void main() {
  group('elementCount', () {
    const html = '<ul><li>One</li><li>Two</li><li>Three</li></ul>';

    test('matches exact count', () {
      expect(html, elementCount('li', 3));
    });

    test('does not match when count differs', () {
      expect(html, isNot(elementCount('li', 2)));
    });

    test('elementCount with 0 matches empty list', () {
      expect('<p>No items</p>', elementCount('li', 0));
    });

    test('does not match 0 when elements are present', () {
      expect(html, isNot(elementCount('li', 0)));
    });

    test('matches single element', () {
      expect('<h1>Title</h1>', elementCount('h1', 1));
    });

    test('describe produces readable message', () {
      final description = elementCount('li', 3).describe(StringDescription()).toString();
      expect(description, contains('3'));
      expect(description, contains('li'));
    });

    test('describeMismatch reports actual count', () {
      final matchState = <Object?, Object?>{};
      final matcher = elementCount('li', 5);
      matcher.matches(html, matchState);
      final desc = matcher.describeMismatch(html, StringDescription(), matchState, false).toString();
      expect(desc, contains('3'));
      expect(desc, contains('li'));
    });
  });
}
