/// Snapshot of template cache statistics.
final class CacheStats {
  final int size;
  final int hits;
  final int misses;
  final int expressionCacheSize;

  const CacheStats({required this.size, required this.hits, required this.misses, this.expressionCacheSize = 0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheStats &&
          other.size == size &&
          other.hits == hits &&
          other.misses == misses &&
          other.expressionCacheSize == expressionCacheSize;

  @override
  int get hashCode => Object.hash(size, hits, misses, expressionCacheSize);

  @override
  String toString() =>
      'CacheStats(size: $size, hits: $hits, misses: $misses, expressionCacheSize: $expressionCacheSize)';
}
