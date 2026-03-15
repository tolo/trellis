import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('CacheStats', () {
    test('equality', () {
      expect(
        CacheStats(size: 1, hits: 2, misses: 3, expressionCacheSize: 4),
        CacheStats(size: 1, hits: 2, misses: 3, expressionCacheSize: 4),
      );
    });

    test('inequality', () {
      expect(
        CacheStats(size: 1, hits: 2, misses: 3, expressionCacheSize: 4),
        isNot(CacheStats(size: 0, hits: 2, misses: 3, expressionCacheSize: 4)),
      );
    });

    test('toString', () {
      expect(
        CacheStats(size: 1, hits: 2, misses: 3, expressionCacheSize: 4).toString(),
        'CacheStats(size: 1, hits: 2, misses: 3, expressionCacheSize: 4)',
      );
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

  group('devMode cache invalidation', () {
    late Directory tempDir;
    late Trellis engine;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_cache_test_');
    });

    tearDown(() async {
      await engine.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('file change invalidates cache', () async {
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Hello</p>');
      engine = Trellis(loader: FileSystemLoader(tempDir.path, devMode: true), devMode: true);

      // First render — cache miss
      var result = await engine.renderFile('page', {});
      expect(result, contains('<p>Hello</p>'));
      expect(engine.cacheStats.misses, 1);
      expect(engine.cacheStats.hits, 0);

      // Second render — cache hit
      result = await engine.renderFile('page', {});
      expect(result, contains('<p>Hello</p>'));
      expect(engine.cacheStats.misses, 1);
      expect(engine.cacheStats.hits, 1);

      // Overwrite file and wait for change event
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Updated</p>');
      await (engine.loader as FileSystemLoader).changes!.first.timeout(const Duration(seconds: 2));

      // Cache was cleared by the change event — stats reset
      expect(engine.cacheStats.size, 0);
      expect(engine.cacheStats.hits, 0);
      expect(engine.cacheStats.misses, 0);

      // Render again — cache miss with updated content
      result = await engine.renderFile('page', {});
      expect(result, contains('<p>Updated</p>'));
      expect(engine.cacheStats.misses, 1);
      expect(engine.cacheStats.hits, 0);
    });

    test('devMode: false — file changes do not affect cache', () async {
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Original</p>');
      engine = Trellis(loader: FileSystemLoader(tempDir.path), devMode: false);

      // First render — cache miss
      await engine.renderFile('page', {});
      expect(engine.cacheStats.misses, 1);

      // Second render — cache hit
      await engine.renderFile('page', {});
      expect(engine.cacheStats.hits, 1);

      // Overwrite file with different content
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Changed</p>');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Without devMode, no cache invalidation occurs — stale entry remains,
      // but the new content is a different cache key so it's a new miss.
      // Stats are NOT reset (no clearCache was triggered).
      final result = await engine.renderFile('page', {});
      expect(result, contains('<p>Changed</p>'));
      expect(engine.cacheStats.misses, 2);
      expect(engine.cacheStats.hits, 1);
      // Old cached entry still occupies space
      expect(engine.cacheStats.size, 2);
    });

    test('close() stops cache invalidation', () async {
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Before</p>');
      engine = Trellis(loader: FileSystemLoader(tempDir.path, devMode: true), devMode: true);

      // First render — cache miss
      await engine.renderFile('page', {});
      expect(engine.cacheStats.misses, 1);

      // Second render — cache hit
      await engine.renderFile('page', {});
      expect(engine.cacheStats.hits, 1);

      // Close engine to stop watching
      await engine.close();

      // Overwrite file — no clearCache triggered since watcher is stopped
      File('${tempDir.path}/page.html').writeAsStringSync('<p>After</p>');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Stats are NOT reset (no clearCache was triggered).
      // New content is a different cache key — miss, stale entry remains.
      final result = await engine.renderFile('page', {});
      expect(result, contains('<p>After</p>'));
      expect(engine.cacheStats.misses, 2);
      expect(engine.cacheStats.hits, 1);
      // Old cached entry still occupies space
      expect(engine.cacheStats.size, 2);
    });
  });
}
