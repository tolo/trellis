import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'yaml_utils.dart';

/// Thrown when [SiteConfig.load()] encounters a configuration error.
class SiteConfigException implements Exception {
  /// A human-readable description of the error.
  final String message;

  /// The config file path that caused the error, if available.
  final String? configPath;

  const SiteConfigException(this.message, {this.configPath});

  @override
  String toString() {
    if (configPath != null) return 'SiteConfigException: $message\n  config: $configPath';
    return 'SiteConfigException: $message';
  }
}

/// Configuration loaded from `trellis_site.yaml`.
///
/// All directory paths are stored as absolute paths.
class SiteConfig {
  /// The site title.
  final String title;

  /// The canonical base URL (e.g. `https://example.com`).
  final String baseUrl;

  /// The site description.
  final String description;

  /// The site root directory (the directory containing `trellis_site.yaml`).
  final String siteDir;

  /// Absolute path to the content directory. Defaults to `siteDir/content`.
  final String contentDir;

  /// Absolute path to the layouts directory. Defaults to `siteDir/layouts`.
  final String layoutsDir;

  /// Absolute path to the static assets directory. Defaults to `siteDir/static`.
  final String staticDir;

  /// Absolute path to the output directory. Defaults to `siteDir/output`.
  final String outputDir;

  /// Absolute path to the global data directory. Defaults to `siteDir/data`.
  final String dataDir;

  /// Declared taxonomy names (e.g. `['tags', 'categories']`).
  final List<String> taxonomies;

  /// Items per page for list pages. `null` means no pagination.
  final int? paginate;

  /// Site-level parameters available in templates as `${site.params.*}`.
  final Map<String, dynamic> params;

  const SiteConfig._({
    required this.siteDir,
    required this.title,
    required this.baseUrl,
    required this.description,
    required this.contentDir,
    required this.layoutsDir,
    required this.staticDir,
    required this.outputDir,
    required this.dataDir,
    required this.taxonomies,
    required this.paginate,
    required this.params,
  });

  /// Creates a [SiteConfig] with the given values.
  ///
  /// Directory paths may be relative (resolved against [siteDir]) or absolute.
  factory SiteConfig({
    required String siteDir,
    String title = '',
    String baseUrl = '',
    String description = '',
    String? contentDir,
    String? layoutsDir,
    String? staticDir,
    String? outputDir,
    String? dataDir,
    List<String> taxonomies = const [],
    int? paginate,
    Map<String, dynamic> params = const {},
  }) {
    String resolve(String? rel, String defaultName) {
      if (rel == null) return p.join(siteDir, defaultName);
      return p.isAbsolute(rel) ? rel : p.join(siteDir, rel);
    }

    return SiteConfig._(
      siteDir: siteDir,
      title: title,
      baseUrl: baseUrl,
      description: description,
      contentDir: resolve(contentDir, 'content'),
      layoutsDir: resolve(layoutsDir, 'layouts'),
      staticDir: resolve(staticDir, 'static'),
      outputDir: resolve(outputDir, 'output'),
      dataDir: resolve(dataDir, 'data'),
      taxonomies: taxonomies,
      paginate: paginate,
      params: params,
    );
  }

  /// Loads and validates a [SiteConfig] from [configPath].
  ///
  /// [configPath] is the path to `trellis_site.yaml`.
  ///
  /// Throws [SiteConfigException] if the file is missing, unreadable, or
  /// contains invalid YAML.
  static SiteConfig load(String configPath) {
    final resolvedPath = p.canonicalize(configPath);
    final configFile = File(resolvedPath);

    if (!configFile.existsSync()) {
      throw SiteConfigException('Config file not found: $resolvedPath', configPath: resolvedPath);
    }

    final String source;
    try {
      source = configFile.readAsStringSync();
    } on FileSystemException catch (e) {
      throw SiteConfigException('Could not read config file: ${e.message}', configPath: resolvedPath);
    }

    final dynamic yaml;
    try {
      yaml = loadYaml(source);
    } on YamlException catch (e) {
      throw SiteConfigException('Invalid YAML in config file: ${e.message}', configPath: resolvedPath);
    }

    if (yaml != null && yaml is! YamlMap) {
      throw SiteConfigException(
        'Config file must contain a YAML mapping, got ${yaml.runtimeType}',
        configPath: resolvedPath,
      );
    }

    final map = (yaml as YamlMap?) ?? YamlMap();
    final siteDir = p.dirname(resolvedPath);

    final rawParams = map['params'];
    final params = rawParams is YamlMap ? convertYamlMap(rawParams) : <String, dynamic>{};

    final rawTaxonomies = map['taxonomies'];
    final taxonomies = rawTaxonomies is YamlList ? rawTaxonomies.map((e) => e.toString()).toList() : <String>[];

    final rawPaginate = map['paginate'];
    final paginate = rawPaginate is int ? rawPaginate : null;

    return SiteConfig(
      siteDir: siteDir,
      title: (map['title'] as String?) ?? '',
      baseUrl: (map['baseUrl'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      contentDir: map['contentDir'] as String?,
      layoutsDir: map['layoutsDir'] as String?,
      staticDir: map['staticDir'] as String?,
      outputDir: map['outputDir'] as String?,
      dataDir: map['dataDir'] as String?,
      taxonomies: taxonomies,
      paginate: paginate,
      params: params,
    );
  }

  @override
  String toString() => 'SiteConfig(title: $title, siteDir: $siteDir, outputDir: $outputDir)';
}
