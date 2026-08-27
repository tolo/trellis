import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'yaml_utils.dart';

/// Thrown when loading or validating a theme manifest fails.
class ThemeManifestException implements Exception {
  /// A human-readable description of the error.
  final String message;

  /// The theme directory that caused the error, if available.
  final String? themeDir;

  const ThemeManifestException(this.message, {this.themeDir});

  @override
  String toString() {
    if (themeDir != null) return 'ThemeManifestException: $message\n  theme: $themeDir';
    return 'ThemeManifestException: $message';
  }
}

/// A single configurable theme parameter from `theme.yaml`.
class ThemeParam {
  /// The param name (e.g., 'primary_color').
  final String name;

  /// The type hint (e.g., 'string', 'color', 'boolean', 'int', 'list', 'enum').
  ///
  /// Advisory only — not validated at runtime.
  final String type;

  /// The default value for this param.
  final dynamic defaultValue;

  /// Human-readable description.
  final String? description;

  /// For enum-type params, the list of valid values.
  final List<String>? enumValues;

  const ThemeParam({
    required this.name,
    required this.type,
    required this.defaultValue,
    this.description,
    this.enumValues,
  });

  /// Parses a [ThemeParam] from a YAML value.
  ///
  /// If [yaml] is a map, extracts `type`, `default`, `description`, and
  /// `values` (for enum type). If [yaml] is a plain scalar, treats it as
  /// a string-typed param with the scalar as the default value.
  factory ThemeParam.fromYaml(String name, dynamic yaml) {
    if (yaml is Map) {
      final type = (yaml['type'] as String?) ?? 'string';
      final defaultValue = convertYaml(yaml['default']);
      final description = yaml['description'] as String?;
      List<String>? enumValues;
      if (type == 'enum') {
        final rawValues = yaml['values'];
        if (rawValues is YamlList) {
          enumValues = rawValues.map((v) => v.toString()).toList();
        } else if (rawValues is List) {
          enumValues = rawValues.map((v) => v.toString()).toList();
        }
      }
      return ThemeParam(
        name: name,
        type: type,
        defaultValue: defaultValue,
        description: description,
        enumValues: enumValues,
      );
    }
    // Plain scalar — treat as string param with scalar as default
    return ThemeParam(name: name, type: 'string', defaultValue: yaml);
  }
}

/// A parsed `theme.yaml` manifest describing a theme's metadata and params.
class ThemeManifest {
  /// Theme name (required). Must match the theme directory name.
  final String name;

  /// Theme version string (required).
  final String version;

  /// Theme author (optional).
  final String? author;

  /// Theme description (optional).
  final String? description;

  /// Minimum trellis_site version required (advisory, optional).
  final String? minTrellisVersion;

  /// Screenshot paths relative to theme directory (optional).
  final List<String> screenshots;

  /// Declared feature tags (optional).
  final List<String> features;

  /// Configurable parameters with defaults, types, and descriptions.
  final Map<String, ThemeParam> params;

  /// The directory containing this theme (set by [load]).
  final String themeDir;

  const ThemeManifest._({
    required this.name,
    required this.version,
    this.author,
    this.description,
    this.minTrellisVersion,
    this.screenshots = const [],
    this.features = const [],
    this.params = const {},
    required this.themeDir,
  });

  /// Loads and validates a theme manifest from [themeDir].
  ///
  /// Reads `theme.yaml` from the given directory. Throws
  /// [ThemeManifestException] if the directory is missing, the file is
  /// missing, the YAML is malformed, or required fields (`name`, `version`)
  /// are absent.
  static ThemeManifest load(String themeDir) {
    final canonicalDir = p.canonicalize(themeDir);

    if (!Directory(canonicalDir).existsSync()) {
      final themeName = p.basename(canonicalDir);
      // Almost always a `theme:` set without installing the theme, so name the
      // command that fixes it rather than only the directory that is missing.
      throw ThemeManifestException(
        "Theme '$themeName' not found in themes/ — install it first, e.g. "
        "'trellis theme add <url-or-path> --theme $themeName'",
        themeDir: canonicalDir,
      );
    }

    final manifestFile = File(p.join(canonicalDir, 'theme.yaml'));
    if (!manifestFile.existsSync()) {
      throw ThemeManifestException(
        'Theme manifest not found: ${p.join(canonicalDir, 'theme.yaml')}',
        themeDir: canonicalDir,
      );
    }

    final String source;
    try {
      source = manifestFile.readAsStringSync();
    } on FileSystemException catch (e) {
      throw ThemeManifestException('Could not read theme manifest: ${e.message}', themeDir: canonicalDir);
    }

    final dynamic yaml;
    try {
      yaml = loadYaml(source);
    } on YamlException catch (e) {
      throw ThemeManifestException('Invalid YAML in theme manifest: ${e.message}', themeDir: canonicalDir);
    }

    if (yaml == null || yaml is! YamlMap) {
      throw ThemeManifestException('Theme manifest must contain a YAML mapping', themeDir: canonicalDir);
    }

    final name = yaml['name'];
    if (name == null || name is! String || name.isEmpty) {
      throw ThemeManifestException('Theme manifest missing required field: name', themeDir: canonicalDir);
    }

    final version = yaml['version'];
    if (version == null) {
      throw ThemeManifestException('Theme manifest missing required field: version', themeDir: canonicalDir);
    }

    final rawScreenshots = yaml['screenshots'];
    final screenshots = rawScreenshots is YamlList ? rawScreenshots.map((e) => e.toString()).toList() : <String>[];

    final rawFeatures = yaml['features'];
    final features = rawFeatures is YamlList ? rawFeatures.map((e) => e.toString()).toList() : <String>[];

    final rawParams = yaml['params'];
    final Map<String, ThemeParam> params;
    if (rawParams is YamlMap) {
      params = {
        for (final entry in rawParams.entries)
          entry.key.toString(): ThemeParam.fromYaml(entry.key.toString(), entry.value),
      };
    } else {
      params = {};
    }

    return ThemeManifest._(
      name: name,
      version: version.toString(),
      author: yaml['author'] as String?,
      description: yaml['description'] as String?,
      minTrellisVersion: yaml['min_trellis_version'] as String?,
      screenshots: screenshots,
      features: features,
      params: params,
      themeDir: canonicalDir,
    );
  }

  /// Returns the default values for all declared params.
  ///
  /// Maps param names to their default values. Used as the base
  /// layer in deep merge with site `theme_params:`.
  Map<String, dynamic> get defaultParams => {for (final entry in params.entries) entry.key: entry.value.defaultValue};
}
