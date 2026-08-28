import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis/trellis.dart' hide TemplateNotFoundException;

import 'code_highlighter.dart';
import 'content_discovery.dart';
import 'feed_generator.dart';
import 'front_matter_parser.dart';
import 'markdown_renderer.dart';
import 'navigation_builder.dart';
import 'page.dart';
import 'page_generator.dart';
import 'shortcode_processor.dart';
import 'search_index_generator.dart';
import 'site_config.dart';
import 'sitemap_generator.dart';
import 'taxonomy.dart';
import 'theme_aware_loader.dart';
import 'theme_layout_shadowing.dart';
import 'theme_manifest.dart';
import 'theme_param_merger.dart';
import 'theme_sass_generator.dart';

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

  /// Theme SASS build configuration, if a theme with SASS is active.
  ///
  /// Used by the CLI to configure SASS compilation with correct load paths.
  /// `null` when no theme is configured.
  final ThemeBuildConfig? themeBuildConfig;

  /// Site layouts that shadow theme layouts, as paths relative to the site root.
  ///
  /// Populated only when the active theme turned out inert: its stylesheets and
  /// scripts were published to the output and no emitted page links any of them,
  /// so the site ships unstyled while carrying the theme's CSS.
  ///
  /// Empty whenever an emitted page still links one of those assets — a site
  /// `base.html` copied from the theme keeps its stylesheet link, and a
  /// site layout rendering inside the theme's shell inherits it. Overriding
  /// `base.html` with a shell of your own is reported, because nothing links the
  /// theme after that.
  final List<String> themeShadowedLayouts;

  const BuildResult({
    required this.pageCount,
    required this.staticFileCount,
    required this.elapsed,
    this.warnings = const [],
    this.themeBuildConfig,
    this.themeShadowedLayouts = const [],
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
  /// Matches an `href`/`src` attribute value, the only places a page can link an
  /// asset. Used by [_anyPageLinks].
  static final RegExp _linkAttribute = RegExp(r'''(?:href|src)\s*=\s*["']([^"']*)["']''', caseSensitive: false);

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
  /// 8.5. Generate feeds (when `feeds:` config section exists)
  /// 9. Generate search index (when `search.enabled: true`)
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
    // 1.5. Load theme manifest, merge params, and generate SASS bridge
    Map<String, dynamic>? mergedThemeParams;
    ThemeBuildConfig? themeBuildConfig;
    if (config.themeConfig != null) {
      // Normalize so a relative `theme:` value (e.g. `../../themes/arbor`, used
      // when a site references a theme outside its own dir) collapses its `..`
      // segments to a real path both the manifest loader and the template
      // FileSystemLoader can resolve — the loader does not canonicalize.
      final themeDir = p.normalize(p.join(config.siteDir, 'themes', config.themeConfig!.name));
      final ThemeManifest manifest;
      try {
        manifest = ThemeManifest.load(themeDir);
      } on ThemeManifestException catch (e) {
        throw SiteConfigException(e.message, configPath: p.join(config.siteDir, 'trellis_site.yaml'));
      }

      const merger = ThemeParamMerger();
      final mergeResult = merger.merge(manifest.defaultParams, config.themeConfig!.params);
      mergedThemeParams = mergeResult.params;

      for (final warning in mergeResult.warnings) {
        buildWarnings.add(BuildWarning(warning));
      }

      // Generate SASS bridge files (_theme_params.scss, _theme_custom_props.css)
      final paramTypes = <String, String>{for (final entry in manifest.params.entries) entry.key: entry.value.type};
      try {
        const generator = ThemeSassGenerator();
        themeBuildConfig = generator.generate(
          mergedParams: mergedThemeParams,
          paramTypes: paramTypes,
          siteDir: config.siteDir,
          themeDir: themeDir,
        );
      } on ArgumentError catch (e) {
        throw SiteConfigException(e.message.toString(), configPath: p.join(config.siteDir, 'trellis_site.yaml'));
      }
    }

    // 2. Discover pages — pathPrefix flows through deriveUrl into every page.url
    final discovery = ContentDiscovery(config.contentDir, pathPrefix: config.pathPrefix);
    final pages = await discovery.discover();

    // 3. Parse front matter
    final fmParser = const FrontMatterParser();
    for (final page in pages) {
      fmParser.parse(page, config.contentDir);
    }

    // Build-time syntax highlighter (ADR-010) — shared by the page Markdown pass
    // and the shortcode-body Markdown pass. `null` when highlighting is disabled,
    // which makes both passes emit plain `<pre><code>` (highlight runs at step 4,
    // before the step-6 path-prefix pass that already skips <pre>/<code>).
    final codeHighlighter = config.highlightConfig.enabled ? const CodeHighlighter() : null;

    // 3.5. Process pre-Markdown shortcodes
    final shortcodeProcessor = ShortcodeProcessor(siteDir: config.siteDir, highlighter: codeHighlighter);
    for (final page in pages) {
      shortcodeProcessor.processPreMarkdown(page);
    }

    // 4. Render Markdown
    final excerptLength = mergedThemeParams?['excerpt_length'] as int?;
    final mdRenderer = MarkdownRenderer(maxSummaryLength: excerptLength, highlighter: codeHighlighter);
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
    final siteContext = _buildSiteContext(pages);
    var siteParams = <String, dynamic>{'site': siteContext, 'theme': ?mergedThemeParams};
    if (config.taxonomies.isNotEmpty) {
      final collector = const TaxonomyCollector();
      final nonDraftPages = pages.where((pg) => !pg.isDraft).toList();
      final taxIndex = collector.collect(config.taxonomies, nonDraftPages);

      // Expose ${taxonomy.<name>} as a list of term maps on every page
      final taxContext = <String, dynamic>{
        for (final entry in taxIndex.entries) entry.key: entry.value.toTermMapList(),
      };
      siteParams = <String, dynamic>{'site': siteContext, 'taxonomy': taxContext, 'theme': ?mergedThemeParams};

      // Enrich each content page with its OWN terms as pre-slugified link maps,
      // resolved from the same index that generates the term pages. Templates
      // link tags via `${page.termLinks.<taxonomy>}[].url` — the canonical term
      // URL — instead of string-building `/{taxonomy}/{rawTerm}/`, which 404s
      // for any term that slugifies (uppercase, spaces, punctuation).
      for (final page in nonDraftPages) {
        final termLinks = collector.termLinksForPage(page, taxIndex);
        if (termLinks.isNotEmpty) page.frontMatter['termLinks'] = termLinks;
      }

      // Inject virtual taxonomy listing and term pages into the pipeline
      final virtualPages = collector.buildVirtualPages(taxIndex, nonDraftPages);
      pages.addAll(virtualPages);
    }

    // 6. Generate HTML pages — with theme-aware loader and layout/data search paths
    final themeDir = config.themeConfig != null
        ? p.normalize(p.join(config.siteDir, 'themes', config.themeConfig!.name))
        : null;
    final TemplateLoader loader;
    if (themeDir != null) {
      loader = ThemeAwareLoader.forTheme(siteDir: config.siteDir, themeDir: themeDir);
    } else {
      loader = ThemeAwareLoader.noTheme(siteDir: config.siteDir);
    }
    final generator = PageGenerator(
      siteDir: config.siteDir,
      outputDir: config.outputDir,
      layoutsDir: config.layoutsDir,
      dataDir: config.dataDir,
      siteParams: siteParams,
      paginate: config.paginate ?? (mergedThemeParams?['posts_per_page'] as int?),
      loader: loader,
      layoutSearchPaths: themeDir != null ? [p.join(themeDir, 'layouts')] : null,
      themeDataDir: themeDir != null ? p.join(themeDir, 'data') : null,
      pathPrefix: config.pathPrefix,
    );
    // pageCount reflects actual output files, including paginated pages
    final pageCount = await generator.generateAll(pages);
    buildWarnings.addAll(generator.warnings);

    // 7. Copy static assets — theme first so site files overwrite on conflict
    final themeAssets = <String>{};
    var themeStaticCount = 0;
    if (themeDir != null) {
      final themeStatic = _copyThemeStaticAssets(themeDir);
      themeStaticCount = themeStatic.fileCount;
      themeAssets.addAll(themeStatic.stylesheetsAndScripts);
      themeAssets.addAll(_themeStylesheetOutputs(themeDir));
    }
    var staticCount = themeStaticCount + _copyStaticAssets() + _copyBundleAssets(pages);
    if (themeBuildConfig != null) {
      final props = _copyThemeCustomProps(themeBuildConfig);
      themeAssets.addAll(props);
      staticCount += props.length;
    }

    final themeShadowedLayouts = themeDir == null
        ? const <String>[]
        : _detectInertTheme(themeDir, generator.emittedPages, themeAssets);

    // 8. Generate sitemap
    final sitemapGenerator = SitemapGenerator(baseUrl: config.baseUrl, contentDir: config.contentDir);
    if (sitemapGenerator.writeToOutput(pages, config.outputDir)) staticCount++;

    // 8.5. Generate feeds
    if (config.feeds != null) {
      final feedGenerator = FeedGenerator(
        config: config.feeds!,
        baseUrl: config.baseUrl,
        siteTitle: config.title,
        siteDescription: config.description,
        contentDir: config.contentDir,
        siteAuthor: config.params['author'] as String?,
      );

      // Validate configured sections against known sections
      final knownSections = pages.where((pg) => pg.section.isNotEmpty).map((pg) => pg.section).toSet();
      for (final section in config.feeds!.sections) {
        if (!knownSections.contains(section)) {
          buildWarnings.add(
            BuildWarning(
              "feeds.sections references unknown section '$section'. "
              'Available: ${knownSections.join(', ')}',
            ),
          );
        }
      }

      final feedResult = feedGenerator.writeToOutput(pages, config.outputDir);
      staticCount += feedResult.fileCount;
      for (final warning in feedResult.warnings) {
        buildWarnings.add(BuildWarning(warning));
      }
    }

    // 9. Generate search index
    if (config.searchConfig.enabled) {
      final searchGenerator = SearchIndexGenerator(config.searchConfig);
      if (searchGenerator.writeToOutput(pages, config.outputDir)) staticCount++;
    }

    stopwatch.stop();

    return BuildResult(
      pageCount: pageCount,
      staticFileCount: staticCount,
      elapsed: stopwatch.elapsed,
      warnings: buildWarnings,
      themeBuildConfig: themeBuildConfig,
      themeShadowedLayouts: themeShadowedLayouts,
    );
  }

  /// Builds the `site` context map available as `${site.*}` in templates.
  ///
  /// [pages] is the discovered content set (drafts already resolved via
  /// `includeDrafts`); it is used to build the `${site.menu}` navigation tree so
  /// that tree rides the shared site params on every page render — single,
  /// section, home, and taxonomy virtual pages alike. Taxonomy virtual pages are
  /// injected into the pipeline after this call, so they never appear as menu
  /// nodes but still receive the tree.
  Map<String, dynamic> _buildSiteContext(List<Page> pages) {
    final context = <String, dynamic>{
      'title': config.title,
      'baseUrl': config.baseUrl,
      // Normalized path-prefix for theme authors to prefix hand-written literal
      // asset/link references the engine cannot auto-rewrite, e.g.
      // `href="${site.pathPrefix}css/main.css"`. Canonical `/x/` (trailing
      // slash) when configured, empty string when the site is served at root.
      'pathPrefix': config.pathPrefix,
      'description': config.description,
      'params': config.params,
      // Hierarchical navigation tree (nested {title, url, children} nodes),
      // built once and shared across every render. Active-trail state is resolved
      // at render time by comparing node.url to ${page.url} (no per-node flag).
      'menu': const NavigationBuilder().build(pages),
    };

    if (config.feeds != null) {
      final feedUrls = <String, dynamic>{};
      if (config.feeds!.atom) feedUrls['atom'] = '/feed.xml';
      if (config.feeds!.rss) feedUrls['rss'] = '/rss.xml';
      context['feeds'] = feedUrls;
    }

    return context;
  }

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

  /// Returns the site layouts to report when the active theme turned out inert,
  /// or an empty list when the theme is doing its job.
  ///
  /// A theme is inert when its stylesheets and scripts were published —
  /// [themeAssets] — and not one page in [emittedPages] links any of them. That
  /// is the symptom exactly: the theme's CSS sits in the output while every page
  /// renders from the site's own layouts, so the site ships unstyled.
  ///
  /// The result is empty whenever an emitted page still links one of those
  /// assets. That is what keeps a site layout that keeps the theme's stylesheet
  /// link — a `base.html` copied from the theme, or a leaf layout rendering
  /// inside the theme's shell — out of the report. It is *not* a
  /// "partial override" exemption: replacing only `base.html` with a shell of
  /// your own does warn, because then nothing links the theme any more.
  ///
  /// Gated on a layout actually being shadowed — that is the list the warning
  /// names, and it keeps the page scan off every build that does not override
  /// theme layouts at all.
  List<String> _detectInertTheme(String themeDir, List<String> emittedPages, Set<String> themeAssets) {
    if (emittedPages.isEmpty || themeAssets.isEmpty) return const [];
    final shadowed = shadowedThemeLayouts(
      siteDir: config.siteDir,
      siteLayoutsDir: config.layoutsDir,
      themeDir: themeDir,
    );
    if (shadowed.isEmpty || _anyPageLinks(emittedPages, themeAssets)) return const [];
    return shadowed;
  }

  /// Whether any page in [emittedPages] links one of [assetPaths].
  ///
  /// Only `href`/`src` attribute values count, so an asset name occurring in body
  /// text is not mistaken for a reference. A value matches when its path equals
  /// the output-relative [assetPaths] entry or ends with it, which covers the
  /// root-absolute form, the `pathPrefix`-rewritten form and a relative one
  /// alike.
  ///
  /// Only files this build rendered are read, and they are read with malformed
  /// input allowed: a diagnostic must never be the thing that fails a build.
  bool _anyPageLinks(List<String> emittedPages, Set<String> assetPaths) {
    for (final path in emittedPages) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final html = file.readAsStringSync(encoding: const Utf8Codec(allowMalformed: true));
      for (final match in _linkAttribute.allMatches(html)) {
        final link = match.group(1)!.split('?').first.split('#').first;
        if (assetPaths.any((asset) => link == asset || link.endsWith('/$asset'))) return true;
      }
    }
    return false;
  }

  /// Returns the output-relative CSS paths the SASS step compiles out of
  /// `<theme>/sass/`, without compiling anything.
  ///
  /// Theme SASS is compiled after [build] returns, by the CSS pipeline the CLI
  /// drives, so `css/main.css` — the stylesheet a themed page actually links — is
  /// not among the files [_copyThemeStaticAssets] copied. Mirrors that step's
  /// mapping: `sass/<rel>.scss` becomes `css/<rel>.css`, partials (`_` prefix)
  /// excluded. Predicted, not verified: a page linking the theme's stylesheet is
  /// using the theme whether or not that build also ran the compile.
  List<String> _themeStylesheetOutputs(String themeDir) {
    final sassDir = Directory(p.join(themeDir, 'sass'));
    if (!sassDir.existsSync()) return const [];

    final outputs = <String>[];
    for (final file in sassDir.listSync(recursive: true, followLinks: false).whereType<File>()) {
      final ext = p.extension(file.path).toLowerCase();
      if (ext != '.scss' && ext != '.sass') continue;
      if (p.basename(file.path).startsWith('_')) continue; // partial
      final relative = p.setExtension(p.relative(file.path, from: sassDir.path), '.css');
      outputs.add('css/${p.split(relative).join('/')}');
    }
    return outputs;
  }

  /// Copies the generated `_theme_custom_props.css` to `css/theme-props.css` in the output.
  ///
  /// Returns the output-relative path it wrote, or an empty list if the source
  /// file didn't exist. That path is a theme stylesheet, so it counts towards the
  /// inert-theme check.
  List<String> _copyThemeCustomProps(ThemeBuildConfig themeBuildConfig) {
    final srcFile = File(p.join(themeBuildConfig.buildDir, '_theme_custom_props.css'));
    if (!srcFile.existsSync()) return const [];
    final dest = p.join(config.outputDir, 'css', 'theme-props.css');
    Directory(p.dirname(dest)).createSync(recursive: true);
    srcFile.copySync(dest);
    return const ['css/theme-props.css'];
  }

  /// Copies theme static files from `themeDir/static/` to the output directory.
  ///
  /// Called before [_copyStaticAssets] so that site files overwrite theme files
  /// on conflict. Skips `.scss` and `.sass` files (compiled by the CSS pipeline).
  ///
  /// Returns how many files were copied, and — separately — the output-relative
  /// URL paths of the `.css` and `.js` among them. Only those two indicate a page
  /// is being *styled* by the theme, so only those feed [_detectInertTheme]: an
  /// unstyled page can still carry the theme's `favicon.svg` or a font it never
  /// applies, and counting those would silence the warning.
  ({int fileCount, List<String> stylesheetsAndScripts}) _copyThemeStaticAssets(String themeDir) {
    final themeStaticDir = Directory(p.join(themeDir, 'static'));
    if (!themeStaticDir.existsSync()) return (fileCount: 0, stylesheetsAndScripts: const []);

    var fileCount = 0;
    final stylesheetsAndScripts = <String>[];
    // followLinks: false - a symlink under static/ escapes the source tree and
    // publishes whatever it points at. An installed theme is third-party code, so
    // a committed `static/secrets -> ~/.ssh` would land in output/. Symlinks list
    // as Link, not File, so whereType<File> then drops them.
    for (final entity in themeStaticDir.listSync(recursive: true, followLinks: false).whereType<File>()) {
      final ext = p.extension(entity.path).toLowerCase();
      if (ext == '.scss' || ext == '.sass') continue;

      final relative = p.relative(entity.path, from: themeStaticDir.path);
      final dest = p.join(config.outputDir, relative);
      Directory(p.dirname(dest)).createSync(recursive: true);
      entity.copySync(dest);
      fileCount++;
      if (ext == '.css' || ext == '.js') stylesheetsAndScripts.add(p.split(relative).join('/'));
    }
    return (fileCount: fileCount, stylesheetsAndScripts: stylesheetsAndScripts);
  }

  /// Copies static files from [SiteConfig.staticDir] to the output directory.
  ///
  /// Skips `.scss` and `.sass` files (compiled by the CSS pipeline).
  /// Returns the number of files copied.
  int _copyStaticAssets() {
    final staticDir = Directory(config.staticDir);
    if (!staticDir.existsSync()) return 0;

    var count = 0;
    // followLinks: false - a symlink under static/ escapes the source tree and
    // publishes whatever it points at. An installed theme is third-party code, so
    // a committed `static/secrets -> ~/.ssh` would land in output/. Symlinks list
    // as Link, not File, so whereType<File> then drops them.
    for (final entity in staticDir.listSync(recursive: true, followLinks: false).whereType<File>()) {
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
        // Strip the path-prefix so bundle assets land beside their unprefixed
        // page output (the emitted page.url keeps the prefix; see stripPathPrefix).
        final urlPath = stripPathPrefix(page.url, config.pathPrefix).replaceAll(RegExp(r'^/|/$'), '');
        final dest = urlPath.isEmpty ? p.join(config.outputDir, filename) : p.join(config.outputDir, urlPath, filename);

        Directory(p.dirname(dest)).createSync(recursive: true);
        sourceFile.copySync(dest);
        count++;
      }
    }
    return count;
  }
}
