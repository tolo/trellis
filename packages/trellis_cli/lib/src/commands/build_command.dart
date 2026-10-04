import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

/// The `trellis build` command.
///
/// Loads `trellis_site.yaml` from the current directory, runs the full SSG
/// pipeline via [TrellisSite.build], compiles any SASS/SCSS files in the site's
/// static directory, and prints a build summary.
class BuildCommand extends Command<int> {
  /// Base directory the site is loaded from and built into. Defaults to the
  /// process current directory. Injected by tests so builds never depend on (or
  /// mutate) the process-global working directory.
  final String? workingDirectory;

  BuildCommand({this.workingDirectory}) {
    argParser
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'output')
      ..addOption('base-url', help: 'Override the base URL from trellis_site.yaml.')
      ..addOption('path-prefix', help: 'Override the URL path-prefix (sub-path) from trellis_site.yaml.')
      ..addFlag('drafts', help: 'Include draft content.', defaultsTo: false)
      ..addFlag('verbose', abbr: 'v', help: 'Show detailed build log.', defaultsTo: false);
  }

  @override
  String get name => 'build';

  @override
  String get description => 'Build a Trellis static site.';

  @override
  String get invocation => 'trellis build [options]';

  @override
  Future<int> run() async {
    final verbose = argResults!['verbose'] as bool;
    final includeDrafts = argResults!['drafts'] as bool;
    final outputOption = argResults!['output'] as String;
    final baseUrlOverride = argResults!['base-url'] as String?;
    final pathPrefixOverride = argResults!['path-prefix'] as String?;

    final baseDir = workingDirectory ?? Directory.current.path;

    // Locate trellis_site.yaml in the working directory
    final configPath = p.join(baseDir, 'trellis_site.yaml');
    if (!File(configPath).existsSync()) {
      stderr.writeln('Error: trellis_site.yaml not found in $baseDir');
      return 1;
    }

    // Load config
    final SiteConfig config;
    try {
      final rawConfig = SiteConfig.load(configPath);
      final outputExplicit = argResults!.wasParsed('output');
      final outputDir = outputExplicit
          ? (p.isAbsolute(outputOption) ? outputOption : p.join(baseDir, outputOption))
          : rawConfig.outputDir;
      final baseUrl = baseUrlOverride ?? rawConfig.baseUrl;

      config = SiteConfig(
        siteDir: rawConfig.siteDir,
        title: rawConfig.title,
        baseUrl: baseUrl,
        description: rawConfig.description,
        contentDir: rawConfig.contentDir,
        layoutsDir: rawConfig.layoutsDir,
        staticDir: rawConfig.staticDir,
        outputDir: outputDir,
        dataDir: rawConfig.dataDir,
        taxonomies: rawConfig.taxonomies,
        paginate: rawConfig.paginate,
        params: rawConfig.params,
        feeds: rawConfig.feeds,
        searchConfig: rawConfig.searchConfig,
        highlightConfig: rawConfig.highlightConfig,
        themeConfig: rawConfig.themeConfig,
        // pathPrefix from config (or --path-prefix override); the constructor
        // re-normalizes, so passing the already-normalized config value is safe.
        pathPrefix: pathPrefixOverride ?? rawConfig.pathPrefix,
      );
    } on SiteConfigException catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    }

    stdout.writeln('Building site...');

    // Run build pipeline
    final BuildResult result;
    try {
      final site = TrellisSite(config, includeDrafts: includeDrafts);
      result = await site.build();
    } on SiteConfigException catch (e) {
      stderr.writeln('Build failed: $e');
      return 1;
    } on TemplateNotFoundException catch (e) {
      stderr.writeln('Build failed: $e');
      return 1;
    } on FrontMatterException catch (e) {
      stderr.writeln('Build failed: $e');
      return 1;
    }

    // Compile SASS after build (build() cleans outputDir as step 1)
    final int sassCount;
    try {
      sassCount = await _compileSass(config, verbose, themeBuildConfig: result.themeBuildConfig);
    } on SassCompilationException catch (e) {
      stderr.writeln('SASS compilation failed: $e');
      return 1;
    }

    // Print summary
    if (result.hasWarnings) {
      if (verbose) {
        for (final w in result.warnings) {
          stdout.writeln('  Warning: ${w.message}${w.context != null ? ' (${w.context})' : ''}');
        }
      }
    }

    final totalStatic = result.staticFileCount + sassCount;
    final elapsed = result.elapsed.inMilliseconds;
    final warningStr = result.hasWarnings
        ? ' (${result.warnings.length} warning${result.warnings.length == 1 ? '' : 's'})'
        : '';
    stdout.writeln('Built ${result.pageCount} pages, $totalStatic static files in ${elapsed}ms$warningStr');

    return 0;
  }
}

/// Scans [config.staticDir] for `.scss`/`.sass` files (excluding partials that
/// start with `_`), compiles each with [TrellisCss.compileSass], and writes the
/// resulting `.css` files to [config.outputDir] mirroring the source structure.
///
/// When [themeBuildConfig] is provided, uses theme-aware SASS load paths and
/// also compiles SASS files from the theme's `sass/` directory.
///
/// Returns the number of SASS files compiled.
///
/// Throws [SassCompilationException] on compilation failure.
Future<int> _compileSass(SiteConfig config, bool verbose, {ThemeBuildConfig? themeBuildConfig}) async {
  final loadPaths = themeBuildConfig?.sassLoadPaths ?? [config.staticDir];
  var count = 0;

  // Compile theme SASS files from theme's sass/ directory.
  // When a theme bridge is active, each entry is compiled through a generated
  // wrapper (ThemeBuildConfig.bridgeWrapperSource) that `@use`s the entry with
  // the merged params (theme defaults + site theme_params:) configured onto it.
  if (themeBuildConfig != null && config.themeConfig != null) {
    // Normalize so a relative `theme:` value (e.g. `../../themes/arbor`) collapses
    // its `..` segments — matches the engine's theme resolution in
    // trellis_site_builder. Without this, the theme's sass/ dir is not found for a
    // site that references a theme outside its own directory, silently skipping
    // theme CSS compilation (the site builds but ships unstyled).
    final themeDir = p.normalize(p.join(config.siteDir, 'themes', config.themeConfig!.name));
    final themeSassDir = Directory(p.join(themeDir, 'sass'));
    if (themeSassDir.existsSync()) {
      for (final file in themeSassDir.listSync(recursive: true, followLinks: false).whereType<File>()) {
        final ext = p.extension(file.path).toLowerCase();
        if (ext != '.scss' && ext != '.sass') continue;
        if (p.basename(file.path).startsWith('_')) continue; // skip partials

        final relative = p.relative(file.path, from: themeSassDir.path);
        final outPath = p.join(config.outputDir, 'css', p.setExtension(relative, '.css'));
        Directory(p.dirname(outPath)).createSync(recursive: true);

        // The wrapper lives in .trellis/build/ so its `@use "theme_params"`
        // resolves to the adjacent _theme_params.scss. The theme's actual SCSS
        // file is `@use`d via absolute path so its own relative `@use`s resolve
        // from its original directory.
        final wrapperBaseName = p.basenameWithoutExtension(file.path);
        final wrapperPath = p.join(themeBuildConfig.buildDir, 'bridge_$wrapperBaseName.scss');
        File(wrapperPath).writeAsStringSync(themeBuildConfig.bridgeWrapperSource(p.canonicalize(file.path)));

        final css = TrellisCss.compileSass(wrapperPath, outputStyle: OutputStyle.compressed, loadPaths: loadPaths);
        File(outPath).writeAsStringSync(css);

        if (verbose) stdout.writeln('  Compiled ${file.path} → $outPath');
        count++;
      }
    }
  }

  // Compile site SASS last so site-first theme precedence also holds when a
  // site intentionally replaces the theme's css/main.css entry point.
  final staticDir = Directory(config.staticDir);
  if (staticDir.existsSync()) {
    for (final file in staticDir.listSync(recursive: true, followLinks: false).whereType<File>()) {
      final ext = p.extension(file.path).toLowerCase();
      if (ext != '.scss' && ext != '.sass') continue;
      if (p.basename(file.path).startsWith('_')) continue; // skip partials

      final relative = p.relative(file.path, from: config.staticDir);
      final outPath = p.join(config.outputDir, p.setExtension(relative, '.css'));
      Directory(p.dirname(outPath)).createSync(recursive: true);

      final css = TrellisCss.compileSass(file.path, outputStyle: OutputStyle.compressed, loadPaths: loadPaths);
      File(outPath).writeAsStringSync(css);

      if (verbose) stdout.writeln('  Compiled ${file.path} → $outPath');
      count++;
    }
  }

  return count;
}
