import 'package:yaml/yaml.dart';

import 'site_config.dart';
import 'yaml_utils.dart';

/// Theme configuration parsed from the `theme:`, `theme_ref:`, and
/// `theme_params:` fields in `trellis_site.yaml`.
///
/// This is the site-side configuration, not the theme manifest itself.
class ThemeConfig {
  /// The active theme name (e.g., 'verdant'). Matches a directory under `themes/`.
  final String name;

  /// Optional git ref to pin the theme to (e.g., 'v1.0.0', 'main').
  final String? ref;

  /// User-provided param overrides that are deep-merged with theme defaults.
  final Map<String, dynamic> params;

  const ThemeConfig({required this.name, this.ref, this.params = const {}});

  /// Parses a [ThemeConfig] from the site YAML map.
  ///
  /// Returns `null` if the `theme:` key is absent (no theme active).
  /// Throws [SiteConfigException] if `theme:` is present but invalid.
  static ThemeConfig? fromYaml(Map<dynamic, dynamic> yaml) {
    final theme = yaml['theme'];
    if (theme == null) return null;
    if (theme is! String || theme.isEmpty) {
      throw SiteConfigException("'theme:' must be a non-empty string");
    }

    final rawRef = yaml['theme_ref'];
    if (rawRef != null && rawRef is! String) {
      throw SiteConfigException("'theme_ref:' must be a string, got ${rawRef.runtimeType}");
    }
    final ref = rawRef as String?;

    final rawParams = yaml['theme_params'];
    final params = rawParams is YamlMap ? convertYamlMap(rawParams) : <String, dynamic>{};

    return ThemeConfig(name: theme, ref: ref, params: params);
  }
}
