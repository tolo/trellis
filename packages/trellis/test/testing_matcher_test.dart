import 'package:test/test.dart';
import 'package:trellis/testing.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('isValidTemplate', () {
    test('matches valid templates', () {
      expect('<p tl:text="\${name}">x</p>', isValidTemplate());
    });

    test('describes mismatches', () {
      final matcher = isValidTemplate();
      final matchState = <Object?, Object?>{};
      final description = StringDescription();

      final matches = matcher.matches('<p tl:text=""></p>', matchState);
      matcher.describeMismatch('<p tl:text=""></p>', description, matchState, false);

      expect(matches, isFalse);
      expect(description.toString(), contains('Expression value cannot be empty'));
      expect(description.toString(), contains('tl:text'));
    });

    test('supports custom validator configuration', () {
      expect('<p data-tl-text="\${name}">x</p>', isValidTemplate(validator: TemplateValidator(prefix: 'data-tl')));
    });
  });
}
