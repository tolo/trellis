import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('expression cache', () {
    test('reuses parsed expressions across renders', () {
      final engine = Trellis(loader: MapLoader({}), cache: true);
      const template = '<div><p tl:text="\${user.name}">x</p><span tl:text="\${user.name}">y</span></div>';

      final first = engine.render(template, {
        'user': {'name': 'Alice'},
      });
      final second = engine.render(template, {
        'user': {'name': 'Bob'},
      });

      expect(first, contains('<p>Alice</p>'));
      expect(second, contains('<span>Bob</span>'));
      expect(engine.cacheStats.expressionCacheSize, 1);
    });

    test('looped expressions are parsed once and reused', () {
      final engine = Trellis(loader: MapLoader({}), cache: true);
      const template = '<li tl:each="item : \${items}" tl:text="\${item}">x</li>';

      final result = engine.render(template, {
        'items': ['a', 'b', 'c'],
      });

      expect(result, contains('<li>a</li>'));
      expect(result, contains('<li>b</li>'));
      expect(result, contains('<li>c</li>'));
      expect(engine.cacheStats.expressionCacheSize, 2);
    });

    test('clearCache resets DOM and expression caches', () {
      final engine = Trellis(loader: MapLoader({}), cache: true);

      engine.render('<p tl:text="\${name}">x</p>', {'name': 'Alice'});
      expect(engine.cacheStats.size, 1);
      expect(engine.cacheStats.expressionCacheSize, 1);

      engine.clearCache();

      expect(engine.cacheStats, CacheStats(size: 0, hits: 0, misses: 0, expressionCacheSize: 0));
    });

    test('cache disabled leaves expression cache empty', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);

      engine.render('<p tl:text="\${name}">x</p>', {'name': 'Alice'});
      engine.render('<p tl:text="\${name}">x</p>', {'name': 'Bob'});

      expect(engine.cacheStats.expressionCacheSize, 0);
    });

    test('parse failures are not cached', () {
      final engine = Trellis(loader: MapLoader({}), cache: true);

      expect(() => engine.render('<p tl:text="\${name">x</p>', {'name': 'Alice'}), throwsA(isA<ExpressionException>()));
      expect(() => engine.render('<p tl:text="\${name">x</p>', {'name': 'Alice'}), throwsA(isA<ExpressionException>()));

      expect(engine.cacheStats.expressionCacheSize, 0);
    });
  });
}
