import 'package:test/test.dart';
import 'package:trellis/testing.dart';

void main() {
  group('hasElement', () {
    const fullHtml =
        '<html><body><h1>Hello</h1><p class="item">A</p><p class="item">B</p><p class="item">C</p></body></html>';
    const fragmentHtml = '<h1>Hello</h1><ul><li>One</li><li>Two</li></ul>';

    test('matches when element is present', () {
      expect('<h1>Hello</h1>', hasElement('h1'));
    });

    test('does not match when element is absent', () {
      expect('<p>Hello</p>', isNot(hasElement('h1')));
    });

    test('matches h1 with specific text', () {
      expect('<h1>Hello</h1>', hasElement('h1', withText: 'Hello'));
    });

    test('does not match h1 with different text', () {
      expect('<h1>Goodbye</h1>', isNot(hasElement('h1', withText: 'Hello')));
    });

    test('matches exact count', () {
      expect(fullHtml, hasElement('.item', count: 3));
    });

    test('fails when count differs', () {
      expect(fullHtml, isNot(hasElement('.item', count: 2)));
    });

    test('count: 0 matches when no elements found', () {
      expect('<p>No items</p>', hasElement('.item', count: 0));
    });

    test('attribute selector in CSS selector string', () {
      expect('<a href="/about">About</a>', hasElement('a[href="/about"]'));
    });

    test('matches element with attribute present', () {
      expect('<input required />', hasElement('input', withAttribute: 'required'));
    });

    test('matches attribute with specific value', () {
      expect('<input type="email" />', hasElement('input', withAttribute: 'type', attributeValue: 'email'));
    });

    test('does not match when attribute value differs', () {
      expect('<input type="text" />', isNot(hasElement('input', withAttribute: 'type', attributeValue: 'email')));
    });

    test('works with full HTML documents', () {
      expect(fullHtml, hasElement('h1', withText: 'Hello'));
    });

    test('works with partial fragments', () {
      expect(fragmentHtml, hasElement('li', count: 2));
    });

    test('describe produces readable message', () {
      final matcher = hasElement('h1', withText: 'Hello');
      final description = matcher.describe(StringDescription()).toString();
      expect(description, contains('h1'));
      expect(description, contains('Hello'));
    });

    test('describeMismatch reports element count', () {
      final matchState = <Object?, Object?>{};
      final matcher = hasElement('h1');
      matcher.matches('<p>No heading</p>', matchState);
      final desc = matcher.describeMismatch('<p>No heading</p>', StringDescription(), matchState, false).toString();
      expect(desc, contains('0'));
      expect(desc, contains('h1'));
    });

    test('describeMismatch reports text found when text filter fails', () {
      final matchState = <Object?, Object?>{};
      final matcher = hasElement('h1', withText: 'Expected');
      matcher.matches('<h1>Actual</h1>', matchState);
      final desc = matcher.describeMismatch('<h1>Actual</h1>', StringDescription(), matchState, false).toString();
      expect(desc, contains('Actual'));
    });
  });
}
