import 'package:test/test.dart';
import 'package:trellis/testing.dart';

void main() {
  group('hasAttribute', () {
    test('matches attribute with exact string value', () {
      expect('<a href="/home">Home</a>', hasAttribute('a', 'href', '/home'));
    });

    test('matches attribute with Matcher value', () {
      expect('<a href="/home/page">Home</a>', hasAttribute('a', 'href', contains('/home')));
    });

    test('does not match when element not found', () {
      expect('<p>No link</p>', isNot(hasAttribute('a', 'href', '/home')));
    });

    test('does not match when attribute not found on element', () {
      expect('<a>No href</a>', isNot(hasAttribute('a', 'href', '/home')));
    });

    test('does not match when attribute value differs', () {
      expect('<a href="/other">Other</a>', isNot(hasAttribute('a', 'href', '/home')));
    });

    test('matches boolean attribute', () {
      expect('<input disabled />', hasAttribute('input', 'disabled', ''));
    });

    test('matches class attribute', () {
      expect('<div class="card active">Content</div>', hasAttribute('div', 'class', 'card active'));
    });

    test('describe produces readable message', () {
      final description = hasAttribute('a', 'href', '/home').describe(StringDescription()).toString();
      expect(description, contains('a'));
      expect(description, contains('href'));
      expect(description, contains('/home'));
    });

    test('describeMismatch reports element not found', () {
      final matchState = <Object?, Object?>{};
      final matcher = hasAttribute('a', 'href', '/home');
      matcher.matches('<p>No link</p>', matchState);
      final desc = matcher.describeMismatch('<p>No link</p>', StringDescription(), matchState, false).toString();
      expect(desc, contains('a'));
    });

    test('describeMismatch reports actual attribute value', () {
      final matchState = <Object?, Object?>{};
      final matcher = hasAttribute('a', 'href', '/home');
      matcher.matches('<a href="/other">Other</a>', matchState);
      final desc = matcher
          .describeMismatch('<a href="/other">Other</a>', StringDescription(), matchState, false)
          .toString();
      expect(desc, contains('/other'));
    });

    test('describeMismatch reports missing attribute', () {
      final matchState = <Object?, Object?>{};
      final matcher = hasAttribute('a', 'href', '/home');
      matcher.matches('<a>No href</a>', matchState);
      final desc = matcher.describeMismatch('<a>No href</a>', StringDescription(), matchState, false).toString();
      expect(desc, contains('href'));
    });
  });
}
