/// Result summary for [Trellis.warmUp] and [Trellis.warmUpAll].
final class WarmUpResult {
  /// Number of newly cached template entries loaded during warm-up.
  final int loaded;

  /// Template names that failed to load or parse during warm-up.
  final List<(String name, Object error)> failed;

  /// Number of cache entries evicted while warming templates.
  final int evicted;

  const WarmUpResult({required this.loaded, this.failed = const [], this.evicted = 0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarmUpResult && other.loaded == loaded && other.evicted == evicted && _listEquals(other.failed, failed);

  @override
  int get hashCode => Object.hash(loaded, evicted, Object.hashAll(failed));

  @override
  String toString() => 'WarmUpResult(loaded: $loaded, failed: $failed, evicted: $evicted)';
}

bool _listEquals(List<Object?> left, List<Object?> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
