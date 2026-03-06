import 'package:test/test.dart';
import 'package:trellis/src/message_source.dart';

void main() {
  group('MapMessageSource', () {
    test('resolves key with exact locale', () {
      final source = MapMessageSource(messages: {
        'en': {'greeting': 'Hello'},
        'fr': {'greeting': 'Bonjour'},
      });
      expect(source.resolve('greeting', locale: 'en'), 'Hello');
      expect(source.resolve('greeting', locale: 'fr'), 'Bonjour');
    });

    test('locale fallback — requested locale not found, uses first available', () {
      final source = MapMessageSource(messages: {
        'en': {'greeting': 'Hello'},
      });
      expect(source.resolve('greeting', locale: 'de'), 'Hello');
    });

    test('no locale specified — uses first available', () {
      final source = MapMessageSource(messages: {
        'en': {'greeting': 'Hello'},
      });
      expect(source.resolve('greeting'), 'Hello');
    });

    test('key not found returns null', () {
      final source = MapMessageSource(messages: {
        'en': {'greeting': 'Hello'},
      });
      expect(source.resolve('missing'), isNull);
    });

    test('positional arg replacement {0}, {1}', () {
      final source = MapMessageSource(messages: {
        'en': {'greeting': 'Hello, {0}! You have {1} messages.'},
      });
      expect(
        source.resolve('greeting', locale: 'en', args: ['Alice', 5]),
        'Hello, Alice! You have 5 messages.',
      );
    });

    test('null arg replaced with empty string', () {
      final source = MapMessageSource(messages: {
        'en': {'greeting': 'Hello, {0}!'},
      });
      expect(source.resolve('greeting', locale: 'en', args: [null]), 'Hello, !');
    });

    test('missing positional arg — placeholder left as-is', () {
      final source = MapMessageSource(messages: {
        'en': {'greeting': 'Hello, {0} and {1}!'},
      });
      expect(
        source.resolve('greeting', locale: 'en', args: ['Alice']),
        'Hello, Alice and {1}!',
      );
    });

    test('empty messages map returns null', () {
      final source = MapMessageSource(messages: {});
      expect(source.resolve('anything'), isNull);
    });

    test('flat key with dots', () {
      final source = MapMessageSource(messages: {
        'en': {'greeting.formal': 'Good day'},
      });
      expect(source.resolve('greeting.formal', locale: 'en'), 'Good day');
    });

    test('empty args list — no replacement', () {
      final source = MapMessageSource(messages: {
        'en': {'greeting': 'Hello, {0}!'},
      });
      expect(source.resolve('greeting', locale: 'en', args: []), 'Hello, {0}!');
    });
  });
}
