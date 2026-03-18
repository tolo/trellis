import 'package:test/test.dart';
import 'package:trellis/testing.dart';

void main() {
  group('hasNoElement', () {
    test('matches when element is absent', () {
      expect('<p>Hello</p>', hasNoElement('.error'));
    });

    test('does not match when element is present', () {
      expect('<p class="error">Oops</p>', isNot(hasNoElement('.error')));
    });

    test('matches when no elements of type exist', () {
      expect('<p>Hello</p>', hasNoElement('div'));
    });

    test('does not match with multiple matching elements', () {
      expect('<div class="warning">A</div><div class="warning">B</div>', isNot(hasNoElement('div.warning')));
    });

    test('describe produces readable message', () {
      final description = hasNoElement('.error').describe(StringDescription()).toString();
      expect(description, contains('.error'));
      expect(description, contains('not'));
    });

    test('describeMismatch includes count of found elements', () {
      final matchState = <Object?, Object?>{};
      final matcher = hasNoElement('.error');
      matcher.matches('<p class="error">E1</p><p class="error">E2</p>', matchState);
      final desc = matcher
          .describeMismatch('<p class="error">E1</p><p class="error">E2</p>', StringDescription(), matchState, false)
          .toString();
      expect(desc, contains('2'));
      expect(desc, contains('.error'));
    });
  });
}
