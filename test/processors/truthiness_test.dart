import 'package:test/test.dart';
import 'package:trellis/src/truthiness.dart';

void main() {
  group('isTruthy', () {
    group('falsy values', () {
      test('null', () => expect(isTruthy(null), false));
      test('false', () => expect(isTruthy(false), false));
      test('0 (int)', () => expect(isTruthy(0), false));
      test('0.0 (double)', () => expect(isTruthy(0.0), false));
      test('"false"', () => expect(isTruthy('false'), false));
      test('"off"', () => expect(isTruthy('off'), false));
      test('"no"', () => expect(isTruthy('no'), false));
    });

    group('truthy values', () {
      test('true', () => expect(isTruthy(true), true));
      test('"" (empty string)', () => expect(isTruthy(''), true));
      test('"hello"', () => expect(isTruthy('hello'), true));
      test('1', () => expect(isTruthy(1), true));
      test('-1', () => expect(isTruthy(-1), true));
      test('3.14', () => expect(isTruthy(3.14), true));
      test('[] (empty list)', () => expect(isTruthy([]), true));
      test('{} (empty map)', () => expect(isTruthy({}), true));
      test('[1]', () => expect(isTruthy([1]), true));
      test("{'a': 1}", () => expect(isTruthy({'a': 1}), true));
    });

    group('case sensitivity', () {
      test('"False" is truthy', () => expect(isTruthy('False'), true));
      test('"FALSE" is truthy', () => expect(isTruthy('FALSE'), true));
      test('"OFF" is truthy', () => expect(isTruthy('OFF'), true));
      test('"NO" is truthy', () => expect(isTruthy('NO'), true));
      test('"No" is truthy', () => expect(isTruthy('No'), true));
    });
  });
}
