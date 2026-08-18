import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

void main() {
  group('ThemeParamMerger.deepMerge()', () {
    test('basic scalar override', () {
      final result = ThemeParamMerger.deepMerge({'a': 1}, {'a': 2});
      expect(result, equals({'a': 2}));
    });

    test('map value in base, not overridden — preserved', () {
      final result = ThemeParamMerger.deepMerge({
        'a': {'b': 1},
      }, {});
      expect(
        result,
        equals({
          'a': {'b': 1},
        }),
      );
    });

    test('recursive map merge', () {
      final result = ThemeParamMerger.deepMerge(
        {
          'a': {'b': 1, 'c': 2},
        },
        {
          'a': {'b': 3},
        },
      );
      expect(
        result,
        equals({
          'a': {'b': 3, 'c': 2},
        }),
      );
    });

    test('list replaces entirely — not merged', () {
      final result = ThemeParamMerger.deepMerge(
        {
          'a': [1, 2],
        },
        {
          'a': [3],
        },
      );
      expect(
        result,
        equals({
          'a': [3],
        }),
      );
    });

    test('scalar replaces map', () {
      final result = ThemeParamMerger.deepMerge(
        {
          'a': {'b': 1},
        },
        {'a': 'flat'},
      );
      expect(result, equals({'a': 'flat'}));
    });

    test('map replaces scalar', () {
      final result = ThemeParamMerger.deepMerge(
        {'a': 'flat'},
        {
          'a': {'b': 1},
        },
      );
      expect(
        result,
        equals({
          'a': {'b': 1},
        }),
      );
    });

    test('override adds new keys not in base', () {
      final result = ThemeParamMerger.deepMerge({'a': 1}, {'b': 2});
      expect(result, equals({'a': 1, 'b': 2}));
    });

    test('empty overrides returns copy of base', () {
      final base = {'a': 1, 'b': 'hello'};
      final result = ThemeParamMerger.deepMerge(base, {});
      expect(result, equals(base));
      // Verify it's a copy, not the same instance
      expect(result, isNot(same(base)));
    });

    test('empty base returns copy of overrides', () {
      final overrides = {'a': 1, 'b': 'hello'};
      final result = ThemeParamMerger.deepMerge({}, overrides);
      expect(result, equals(overrides));
    });
  });

  group('ThemeParamMerger.merge()', () {
    const merger = ThemeParamMerger();

    test('known params produce no warnings and correct merged values', () {
      final defaults = {'skin': 'auto', 'color': '#2563eb'};
      final overrides = {'skin': 'dark'};
      final result = merger.merge(defaults, overrides);

      expect(result.warnings, isEmpty);
      expect(result.params['skin'], equals('dark'));
      expect(result.params['color'], equals('#2563eb'));
    });

    test('unknown param emits a warning with the param name', () {
      final defaults = {'skin': 'auto'};
      final overrides = {'unknown_key': 'value'};
      final result = merger.merge(defaults, overrides);

      expect(result.warnings, hasLength(1));
      expect(result.warnings.first, contains('unknown_key'));
    });

    test('multiple unknown params emit multiple warnings', () {
      final defaults = {'skin': 'auto'};
      final overrides = {'foo': 1, 'bar': 2};
      final result = merger.merge(defaults, overrides);

      expect(result.warnings, hasLength(2));
      expect(result.warnings.any((w) => w.contains('foo')), isTrue);
      expect(result.warnings.any((w) => w.contains('bar')), isTrue);
    });

    test('all params unknown — all warned, still present in merged map', () {
      final defaults = <String, dynamic>{};
      final overrides = {'foo': 'x', 'bar': 'y'};
      final result = merger.merge(defaults, overrides);

      expect(result.warnings, hasLength(2));
      expect(result.params['foo'], equals('x'));
      expect(result.params['bar'], equals('y'));
    });

    test('empty site overrides — defaults unchanged, no warnings', () {
      final defaults = {'skin': 'auto', 'color': '#2563eb'};
      final result = merger.merge(defaults, {});

      expect(result.warnings, isEmpty);
      expect(result.params, equals(defaults));
    });

    test('merge result params are a new map, not shared with inputs', () {
      final defaults = {'a': 1};
      final overrides = {'b': 2};
      final result = merger.merge(defaults, overrides);

      expect(result.params, isNot(same(defaults)));
      expect(result.params, isNot(same(overrides)));
    });
  });

  group('ThemeParamMergeResult', () {
    test('warnings defaults to empty list', () {
      const result = ThemeParamMergeResult(params: {});
      expect(result.warnings, isEmpty);
    });

    test('stores params and warnings', () {
      const result = ThemeParamMergeResult(params: {'a': 1}, warnings: ["Unknown theme param 'x' — ignored"]);
      expect(result.params['a'], equals(1));
      expect(result.warnings, hasLength(1));
    });
  });
}
