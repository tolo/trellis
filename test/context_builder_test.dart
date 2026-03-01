import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('TrellisContext', () {
    test('set and build', () {
      final ctx = TrellisContext().set('name', 'Alice').build();
      expect(ctx, {'name': 'Alice'});
    });

    test('setAll and build', () {
      final ctx = TrellisContext().setAll({'a': 1, 'b': 2}).build();
      expect(ctx, {'a': 1, 'b': 2});
    });

    test('chaining set and setAll', () {
      final ctx = TrellisContext().set('a', 1).set('b', 2).setAll({'c': 3}).build();
      expect(ctx, {'a': 1, 'b': 2, 'c': 3});
    });

    test('build returns unmodifiable map', () {
      final ctx = TrellisContext().set('k', 'v').build();
      expect(() => ctx['x'] = 1, throwsA(isA<UnsupportedError>()));
    });

    test('overwrite key', () {
      final ctx = TrellisContext().set('k', 1).set('k', 2).build();
      expect(ctx, {'k': 2});
    });

    test('empty build', () {
      final ctx = TrellisContext().build();
      expect(ctx, isEmpty);
      expect(() => ctx['x'] = 1, throwsA(isA<UnsupportedError>()));
    });

    test('reusable — build twice returns independent maps', () {
      final builder = TrellisContext().set('a', 1);
      final first = builder.build();
      builder.set('b', 2);
      final second = builder.build();

      expect(first, {'a': 1});
      expect(second, {'a': 1, 'b': 2});
    });
  });
}
