import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'code_highlighter.dart';
import 'feed_generator.dart';
import 'search_index_generator.dart';
import 'theme_config.dart';
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

  /// The normalized URL path-prefix (sub-path) the site is served under.
  ///
  /// Orthogonal to [baseUrl]: [baseUrl] is the canonical absolute origin used
  /// by the sitemap/feeds, while [pathPrefix] is the sub-path every internal
  /// root-absolute URL resolves under (e.g. GitHub project pages served at
  /// `/trellis/`).
  ///
  /// Normalized to the canonical `/x/` form (leading slash, single trailing
  /// slash) when set, or the empty string when the site is served at the root.
  /// See [normalizePathPrefix].
  final String pathPrefix;

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

  /// Feed configuration. `null` when no `feeds:` section is present in config.
  final FeedConfig? feeds;

  /// Search index configuration. Default: disabled.
  final SearchConfig searchConfig;

  /// Build-time syntax-highlighting configuration. Default: enabled.
  final HighlightConfig highlightConfig;

  /// Theme configuration. `null` when no `theme:` is set in config.
  final ThemeConfig? themeConfig;

  const SiteConfig._({
    required this.siteDir,
    required this.title,
    required this.baseUrl,
    required this.pathPrefix,
    required this.description,
    required this.contentDir,
    required this.layoutsDir,
    required this.staticDir,
    required this.outputDir,
    required this.dataDir,
    required this.taxonomies,
    required this.paginate,
    required this.params,
    this.feeds,
    this.searchConfig = const SearchConfig(),
    this.highlightConfig = const HighlightConfig(),
    this.themeConfig,
  });

  /// Creates a [SiteConfig] with the given values.
  ///
  /// Directory paths may be relative (resolved against [siteDir]) or absolute.
  factory SiteConfig({
    required String siteDir,
    String title = '',
    String baseUrl = '',
    String pathPrefix = '',
    String description = '',
    String? contentDir,
    String? layoutsDir,
    String? staticDir,
    String? outputDir,
    String? dataDir,
    List<String> taxonomies = const [],
    int? paginate,
    Map<String, dynamic> params = const {},
    FeedConfig? feeds,
    SearchConfig searchConfig = const SearchConfig(),
    HighlightConfig highlightConfig = const HighlightConfig(),
    ThemeConfig? themeConfig,
  }) {
    String resolve(String? rel, String defaultName) {
      if (rel == null) return p.join(siteDir, defaultName);
      return p.isAbsolute(rel) ? rel : p.join(siteDir, rel);
    }

    return SiteConfig._(
      siteDir: siteDir,
      title: title,
      baseUrl: baseUrl,
      pathPrefix: normalizePathPrefix(pathPrefix),
      description: description,
      contentDir: resolve(contentDir, 'content'),
      layoutsDir: resolve(layoutsDir, 'layouts'),
      staticDir: resolve(staticDir, 'static'),
      outputDir: resolve(outputDir, 'output'),
      dataDir: resolve(dataDir, 'data'),
      taxonomies: taxonomies,
      paginate: paginate,
      params: params,
      feeds: feeds,
      searchConfig: searchConfig,
      highlightConfig: highlightConfig,
      themeConfig: themeConfig,
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

    final rawSearch = map['search'];
    final searchConfig = rawSearch is YamlMap ? SearchConfig.fromYaml(convertYamlMap(rawSearch)) : const SearchConfig();

    final rawHighlight = map['highlight'];
    final highlightConfig = rawHighlight is YamlMap
        ? HighlightConfig.fromYaml(convertYamlMap(rawHighlight))
        : const HighlightConfig();

    final themeConfig = ThemeConfig.fromYaml(map);

    final rawPathPrefix = map['pathPrefix'];
    final String pathPrefix;
    try {
      pathPrefix = normalizePathPrefix(rawPathPrefix);
    } on SiteConfigException catch (e) {
      throw SiteConfigException(e.message, configPath: resolvedPath);
    }

    return SiteConfig(
      siteDir: siteDir,
      title: (map['title'] as String?) ?? '',
      baseUrl: (map['baseUrl'] as String?) ?? '',
      pathPrefix: pathPrefix,
      description: (map['description'] as String?) ?? '',
      contentDir: map['contentDir'] as String?,
      layoutsDir: map['layoutsDir'] as String?,
      staticDir: map['staticDir'] as String?,
      outputDir: map['outputDir'] as String?,
      dataDir: map['dataDir'] as String?,
      taxonomies: taxonomies,
      paginate: paginate,
      params: params,
      feeds: FeedConfig.fromYaml(map['feeds']),
      searchConfig: searchConfig,
      highlightConfig: highlightConfig,
      themeConfig: themeConfig,
    );
  }

  /// Normalizes a raw `pathPrefix` config value to its canonical form.
  ///
  /// Accepts a `String` (or `null`, treated as no prefix) and returns:
  /// - the empty string for the root-equivalent values `''`, `/`, and `null`
  ///   (the no-prefix state — output is byte-for-byte unchanged); or
  /// - the canonical `/x/` form (leading slash, exactly one trailing slash) for
  ///   any non-empty sub-path, so `trellis`, `/trellis`, `trellis/`, and
  ///   `/trellis/` all normalize to `/trellis/`.
  ///
  /// Throws [SiteConfigException] naming `pathPrefix` and the offending value
  /// when [value] is not a `String`, or is a `String` that cannot be a
  /// root-absolute sub-path: a scheme-bearing/absolute URL such as
  /// `http://example.com`, a protocol-relative `//host`, a value containing
  /// whitespace or a `:` character, a `.`/`..` path segment, or an empty
  /// interior segment (e.g. `a//b`). A malformed prefix is rejected rather
  /// than silently half-applied.
  static String normalizePathPrefix(Object? value) {
    if (value == null) return '';
    if (value is! String) {
      throw SiteConfigException(
        'pathPrefix must be a string sub-path (e.g. /trellis/), got ${value.runtimeType}: $value',
      );
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';

    // Reject scheme-bearing (http://x) and protocol-relative (//host) values —
    // pathPrefix is a root-absolute sub-path, not an absolute/external URL.
    if (trimmed.contains('://') || trimmed.startsWith('//')) {
      throw SiteConfigException(
        'pathPrefix must be a root-absolute sub-path (e.g. /trellis/), '
        'not an absolute or scheme-bearing URL: $value',
      );
    }

    // Reject internal whitespace and ':' — never valid in a URL sub-path.
    if (trimmed.contains(RegExp(r'\s')) || trimmed.contains(':')) {
      throw SiteConfigException('pathPrefix must not contain whitespace or a colon: $value');
    }

    // Reject dot segments ('.', '..') and empty interior segments ('a//b') —
    // both would silently corrupt the resolved sub-path. Strip a single
    // leading/trailing empty segment first (from a leading/trailing '/'),
    // since that's the well-formed case; what's left must all be non-empty,
    // non-dot segments.
    final allSegments = trimmed.split('/');
    final coreSegments = allSegments.sublist(
      allSegments.isNotEmpty && allSegments.first.isEmpty ? 1 : 0,
      allSegments.isNotEmpty && allSegments.last.isEmpty ? allSegments.length - 1 : allSegments.length,
    );
    for (final segment in coreSegments) {
      if (segment == '.' || segment == '..') {
        throw SiteConfigException('pathPrefix must not contain "." or ".." path segments: $value');
      }
      if (segment.isEmpty) {
        throw SiteConfigException('pathPrefix must not contain an empty interior segment ("//"): $value');
      }
    }

    final withLeading = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    final withTrailing = withLeading.endsWith('/') ? withLeading : '$withLeading/';
    return withTrailing;
  }

  @override
  String toString() => 'SiteConfig(title: $title, siteDir: $siteDir, outputDir: $outputDir)';
}
