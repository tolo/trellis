import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('CacheStats', () {
    test('equality', () {
      expect(CacheStats(size: 1, hits: 2, misses: 3), CacheStats(size: 1, hits: 2, misses: 3));
    });

    test('inequality', () {
      expect(CacheStats(size: 1, hits: 2, misses: 3), isNot(CacheStats(size: 0, hits: 2, misses: 3)));
    });

    test('toString', () {
      expect(CacheStats(size: 1, hits: 2, misses: 3).toString(), 'CacheStats(size: 1, hits: 2, misses: 3)');
    });
  });

  group('LRU cache', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), maxCacheSize: 3);
    });

    test('cache hit tracking', () {
      engine.render('<p>a</p>', {});
      engine.render('<p>a</p>', {});
      expect(engine.cacheStats.hits, 1);
      expect(engine.cacheStats.misses, 1);
    });

    test('cache miss tracking', () {
      engine.render('<p>a</p>', {});
      engine.render('<p>b</p>', {});
      engine.render('<p>c</p>', {});
      expect(engine.cacheStats.misses, 3);
      expect(engine.cacheStats.hits, 0);
    });

    test('size tracking', () {
      engine.render('<p>a</p>', {});
      engine.render('<p>b</p>', {});
      expect(engine.cacheStats.size, 2);
    });

    test('LRU eviction', () {
      engine.render('<p>a</p>', {});
      engine.render('<p>b</p>', {});
      engine.render('<p>c</p>', {});
      // Cache full at 3
      engine.render('<p>d</p>', {}); // Evicts 'a'
      expect(engine.cacheStats.size, 3);
    });

    test('LRU promotion — recently accessed not evicted', () {
      engine.render('<p>a</p>', {}); // miss
      engine.render('<p>b</p>', {}); // miss
      engine.render('<p>c</p>', {}); // miss
      engine.render('<p>a</p>', {}); // hit — promotes 'a'
      engine.render('<p>d</p>', {}); // miss — evicts 'b' (LRU)

      // 'a' should still be cached (was promoted)
      engine.render('<p>a</p>', {}); // hit
      expect(engine.cacheStats.hits, 2);

      // 'b' was evicted — renders as miss
      engine.render('<p>b</p>', {}); // miss
      expect(engine.cacheStats.misses, 5);
    });

    test('clearCache resets cache and stats', () {
      engine.render('<p>a</p>', {});
      engine.render('<p>a</p>', {});
      expect(engine.cacheStats.size, 1);
      expect(engine.cacheStats.hits, 1);

      engine.clearCache();
      expect(engine.cacheStats, CacheStats(size: 0, hits: 0, misses: 0));

      // After clear, same template is a miss again
      engine.render('<p>a</p>', {});
      expect(engine.cacheStats.misses, 1);
      expect(engine.cacheStats.hits, 0);
    });

    test('cache disabled returns zeroes', () {
      final noCache = Trellis(loader: MapLoader({}), cache: false);
      noCache.render('<p>a</p>', {});
      noCache.render('<p>a</p>', {});
      expect(noCache.cacheStats, CacheStats(size: 0, hits: 0, misses: 0));
    });
  });
}
