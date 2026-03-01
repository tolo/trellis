/// Fluent builder for constructing template context maps.
class TrellisContext {
  final Map<String, dynamic> _data = {};

  /// Set a single key-value pair. Returns `this` for chaining.
  TrellisContext set(String key, dynamic value) {
    _data[key] = value;
    return this;
  }

  /// Merge all entries from [map]. Returns `this` for chaining.
  TrellisContext setAll(Map<String, dynamic> map) {
    _data.addAll(map);
    return this;
  }

  /// Build an unmodifiable context map from the current state.
  ///
  /// Can be called multiple times; each call returns a fresh
  /// unmodifiable snapshot. Subsequent [set]/[setAll] calls do NOT
  /// affect previously built maps.
  Map<String, dynamic> build() {
    return Map.unmodifiable(Map.of(_data));
  }
}
