import 'dart:io';

import 'package:path/path.dart' as p;

import 'content_discovery.dart';
import 'front_matter_parser.dart';
import 'markdown_renderer.dart';
import 'page.dart';
import 'page_generator.dart';
import 'shortcode_processor.dart';
import 'site_config.dart';
import 'sitemap_generator.dart';
import 'taxonomy.dart';

/// A non-fatal issue collected during a site build.
class BuildWarning {
  /// Human-readable description of the issue.
  final String message;

  /// The URL or file path that caused the warning, if available.
  final String? context;

  const BuildWarning(this.message, {this.context});

  @override
  String toString() {
    if (context != null) return 'BuildWarning: $message ($context)';
    return 'BuildWarning: $message';
  }
}

/// The outcome of a [TrellisSite.build()] call.
class BuildResult {
  /// The number of HTML pages written to the output directory.
  final int pageCount;

  /// The number of static asset files copied to the output directory.
  final int staticFileCount;

  /// Total time elapsed for the build.
  final Duration elapsed;

  /// Non-fatal issues encountered during the build.
  final List<BuildWarning> warnings;

  const BuildResult({
    required this.pageCount,
    required this.staticFileCount,
    required this.elapsed,
    this.warnings = const [],
  });

  /// Whether any warnings were collected.
  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() =>
      'BuildResult(pages: $pageCount, static: $staticFileCount, '
      'elapsed: ${elapsed.inMilliseconds}ms, warnings: ${warnings.length})';
}

/// Orchestrates a full static site build.
///
/// Wires all pipeline stages — content discovery, front matter parsing,
/// Markdown rendering, page generation, and static asset copying — and
/// returns a [BuildResult] describing what was built.
///
/// Example:
/// ```dart
/// final config = SiteConfig.load('my_site/trellis_site.yaml');
/// final site = TrellisSite(config);
/// final result = await site.build();
/// print('Built ${result.pageCount} pages in ${result.elapsed.inMilliseconds}ms');
/// ```
class TrellisSite {
  /// The site configuration.
  final SiteConfig config;

  /// When `true`, draft pages are included in the build output.
  final bool includeDrafts;

  const TrellisSite(this.config, {this.includeDrafts = false});

  /// Runs the full build pipeline and returns a [BuildResult].
  ///
  /// Pipeline stages:
  /// 1. Clean output directory
  /// 2. Discover pages (S01)
  /// 3. Parse front matter (S02)
  /// 3.5. Process pre-Markdown shortcodes (S09)
  /// 4. Render Markdown (S03)
  /// 4.5. Process post-Markdown shortcodes (S09)
  /// 5. Collect taxonomy terms and inject virtual pages (S06)
  /// 6. Generate HTML pages (S04)
  /// 7. Copy static assets
  /// 8. Generate sitemap
  ///
  /// Throws [SiteConfigException] if the output directory configuration is
  /// unsafe. Throws [TemplateNotFoundException] if a required layout is
  /// missing.
  Future<BuildResult> build() async {
    _validateOutputDir();
    final stopwatch = Stopwatch()..start();
    final buildWarnings = <BuildWarning>[];

    // 1. Clean output directory
    _cleanOutputDir();

    try {
      return await _runPipeline(stopwatch, buildWarnings);
    } catch (_) {
      // Ensure a partial output directory is never left behind on failure.
      final outDir = Directory(config.outputDir);
      if (outDir.existsSync()) outDir.deleteSync(recursive: true);
      rethrow;
    }
  }

  Future<BuildResult> _runPipeline(Stopwatch stopwatch, List<BuildWarning> buildWarnings) async {
    // 2. Discover pages
    final discovery = ContentDiscovery(config.contentDir);
    final pages = await discovery.discover();

    // 3. Parse front matter
    final fmParser = const FrontMatterParser();
    for (final page in pages) {
      fmParser.parse(page, config.contentDir);
    }

    // 3.5. Process pre-Markdown shortcodes
    final shortcodeProcessor = ShortcodeProcessor(siteDir: config.siteDir);
    for (final page in pages) {
      shortcodeProcessor.processPreMarkdown(page);
    }

    // 4. Render Markdown
    final mdRenderer = const MarkdownRenderer();
    for (final page in pages) {
      mdRenderer.render(page);
    }

    // 4.5. Process post-Markdown shortcodes
    for (final page in pages) {
      shortcodeProcessor.processPostMarkdown(page);
    }
    buildWarnings.addAll(shortcodeProcessor.warnings);

    // Apply includeDrafts: when true, treat all pages as non-draft
    if (includeDrafts) {
      for (final page in pages) {
        page.isDraft = false;
      }
    }

    // 5. Taxonomy: collect terms and inject virtual pages
    var siteParams = <String, dynamic>{'site': _buildSiteContext()};
    if (config.taxonomies.isNotEmpty) {
      final collector = const TaxonomyCollector();
      final nonDraftPages = pages.where((pg) => !pg.isDraft).toList();
      final taxIndex = collector.collect(config.taxonomies, nonDraftPages);

      // Expose ${taxonomy.<name>} as a list of term maps on every page
      final taxContext = <String, dynamic>{
        for (final entry in taxIndex.entries) entry.key: entry.value.toTermMapList(),
      };
      siteParams = <String, dynamic>{'site': _buildSiteContext(), 'taxonomy': taxContext};

      // Inject virtual taxonomy listing and term pages into the pipeline
      final virtualPages = collector.buildVirtualPages(taxIndex, nonDraftPages);
      pages.addAll(virtualPages);
    }

    // 6. Generate HTML pages
    final generator = PageGenerator(
      siteDir: config.siteDir,
      outputDir: config.outputDir,
      layoutsDir: config.layoutsDir,
      dataDir: config.dataDir,
      siteParams: siteParams,
      paginate: config.paginate,
    );
    // pageCount reflects actual output files, including paginated pages
    final pageCount = await generator.generateAll(pages);

    // 7. Copy static assets
    var staticCount = _copyStaticAssets() + _copyBundleAssets(pages);

    // 8. Generate sitemap
    final sitemapGenerator = SitemapGenerator(baseUrl: config.baseUrl, contentDir: config.contentDir);
    if (sitemapGenerator.writeToOutput(pages, config.outputDir)) staticCount++;

    stopwatch.stop();

    return BuildResult(
      pageCount: pageCount,
      staticFileCount: staticCount,
      elapsed: stopwatch.elapsed,
      warnings: buildWarnings,
    );
  }

  /// Builds the `site` context map available as `${site.*}` in templates.
  Map<String, dynamic> _buildSiteContext() => <String, dynamic>{
    'title': config.title,
    'baseUrl': config.baseUrl,
    'description': config.description,
    'params': config.params,
  };

  /// Validates that the output directory will not destroy source directories.
  ///
  /// Rejects any [SiteConfig.outputDir] that equals or is a parent of
  /// [siteDir], [contentDir], [layoutsDir], [staticDir], or [dataDir].
  void _validateOutputDir() {
    final outputDir = p.canonicalize(config.outputDir);
    final protectedDirs = {
      'siteDir': p.canonicalize(config.siteDir),
      'contentDir': p.canonicalize(config.contentDir),
      'layoutsDir': p.canonicalize(config.layoutsDir),
      'staticDir': p.canonicalize(config.staticDir),
      'dataDir': p.canonicalize(config.dataDir),
    };

    for (final entry in protectedDirs.entries) {
      final dir = entry.value;
      if (outputDir == dir) {
        throw SiteConfigException(
          'outputDir must not equal ${entry.key} — this would delete source files',
          configPath: p.join(config.siteDir, 'trellis_site.yaml'),
        );
      }
      // outputDir is a parent of a protected dir
      if (p.isWithin(outputDir, dir)) {
        throw SiteConfigException(
          'outputDir must not be a parent of ${entry.key} — this would delete source files',
          configPath: p.join(config.siteDir, 'trellis_site.yaml'),
        );
      }
    }
  }

  /// Deletes and recreates the output directory.
  void _cleanOutputDir() {
    final outDir = Directory(config.outputDir);
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
  }

  /// Copies static files from [SiteConfig.staticDir] to the output directory.
  ///
  /// Skips `.scss` and `.sass` files (compiled by the CSS pipeline).
  /// Returns the number of files copied.
  int _copyStaticAssets() {
    final staticDir = Directory(config.staticDir);
    if (!staticDir.existsSync()) return 0;

    var count = 0;
    for (final entity in staticDir.listSync(recursive: true).whereType<File>()) {
      final ext = p.extension(entity.path).toLowerCase();
      if (ext == '.scss' || ext == '.sass') continue;

      final relative = p.relative(entity.path, from: config.staticDir);
      final dest = p.join(config.outputDir, relative);
      Directory(p.dirname(dest)).createSync(recursive: true);
      entity.copySync(dest);
      count++;
    }
    return count;
  }

  /// Copies page bundle assets to the output directory alongside their pages.
  ///
  /// Returns the number of files copied.
  int _copyBundleAssets(List<Page> pages) {
    var count = 0;
    for (final page in pages.where((pg) => pg.isBundle && pg.bundleAssets.isNotEmpty && !pg.isDraft)) {
      for (final assetPath in page.bundleAssets) {
        final sourceFile = File(p.join(config.contentDir, assetPath));
        if (!sourceFile.existsSync()) continue;

        final filename = p.basename(assetPath);
        final urlPath = page.url.replaceAll(RegExp(r'^/|/$'), '');
        final dest = urlPath.isEmpty ? p.join(config.outputDir, filename) : p.join(config.outputDir, urlPath, filename);

        Directory(p.dirname(dest)).createSync(recursive: true);
        sourceFile.copySync(dest);
        count++;
      }
    }
    return count;
  }
}
