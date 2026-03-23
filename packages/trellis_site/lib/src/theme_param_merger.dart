/// The result of merging theme params.
class ThemeParamMergeResult {
  /// The merged param values (theme defaults + site overrides).
  final Map<String, dynamic> params;

  /// Warnings about unknown params (in site overrides but not in theme manifest).
  final List<String> warnings;

  const ThemeParamMergeResult({required this.params, this.warnings = const []});
}

/// Merges theme param defaults with site `theme_params:` overrides.
///
/// Deep merge semantics:
/// - Maps: merged recursively (site keys override theme keys)
/// - Scalars/lists: site value replaces theme value entirely
///
/// Also detects unknown params (params in site overrides that don't exist
/// in the theme manifest) and returns them as warnings.
class ThemeParamMerger {
  const ThemeParamMerger();

  /// Merges [themeDefaults] with [siteOverrides].
  ///
  /// Returns a [ThemeParamMergeResult] containing the merged params
  /// and any warnings about unknown params.
  ThemeParamMergeResult merge(Map<String, dynamic> themeDefaults, Map<String, dynamic> siteOverrides) {
    final warnings = <String>[];
    for (final key in siteOverrides.keys) {
      if (!themeDefaults.containsKey(key)) {
        warnings.add("Unknown theme param '$key' — ignored");
      }
    }
    final merged = deepMerge(themeDefaults, siteOverrides);
    return ThemeParamMergeResult(params: merged, warnings: warnings);
  }

  /// Deep-merges two maps.
  ///
  /// For each key in [overrides]:
  /// - If both base and override values are maps, recurse.
  /// - Otherwise, the override value replaces the base value.
  ///
  /// Keys in [base] not present in [overrides] are preserved.
  static Map<String, dynamic> deepMerge(Map<String, dynamic> base, Map<String, dynamic> overrides) {
    final result = Map<String, dynamic>.from(base);
    for (final entry in overrides.entries) {
      final baseValue = result[entry.key];
      if (baseValue is Map<String, dynamic> && entry.value is Map<String, dynamic>) {
        result[entry.key] = deepMerge(baseValue, entry.value as Map<String, dynamic>);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }
}
