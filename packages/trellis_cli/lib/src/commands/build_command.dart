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
  BuildCommand() {
    argParser
      ..addOption('output', abbr: 'o', help: 'Output directory.', defaultsTo: 'output')
      ..addOption('base-url', help: 'Override the base URL from trellis_site.yaml.')
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

    // Locate trellis_site.yaml in cwd
    final configPath = p.join(Directory.current.path, 'trellis_site.yaml');
    if (!File(configPath).existsSync()) {
      stderr.writeln('Error: trellis_site.yaml not found in ${Directory.current.path}');
      return 1;
    }

    // Load config
    final SiteConfig config;
    try {
      final rawConfig = SiteConfig.load(configPath);
      final outputExplicit = argResults!.wasParsed('output');
      final outputDir = outputExplicit
          ? (p.isAbsolute(outputOption) ? outputOption : p.join(Directory.current.path, outputOption))
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
        themeConfig: rawConfig.themeConfig,
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

  // Compile site static SASS files
  final staticDir = Directory(config.staticDir);
  if (staticDir.existsSync()) {
    for (final file in staticDir.listSync(recursive: true).whereType<File>()) {
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

  // Compile theme SASS files from theme's sass/ directory.
  // When a theme bridge is active, generate a wrapper entry file that imports
  // _theme_params.scss before the theme's SCSS file. This ensures merged params
  // (theme defaults + site theme_params:) override the theme's !default values.
  if (themeBuildConfig != null && config.themeConfig != null) {
    final themeDir = p.join(config.siteDir, 'themes', config.themeConfig!.name);
    final themeSassDir = Directory(p.join(themeDir, 'sass'));
    if (themeSassDir.existsSync()) {
      for (final file in themeSassDir.listSync(recursive: true).whereType<File>()) {
        final ext = p.extension(file.path).toLowerCase();
        if (ext != '.scss' && ext != '.sass') continue;
        if (p.basename(file.path).startsWith('_')) continue; // skip partials

        final relative = p.relative(file.path, from: themeSassDir.path);
        final outPath = p.join(config.outputDir, 'css', p.setExtension(relative, '.css'));
        Directory(p.dirname(outPath)).createSync(recursive: true);

        // Generate a bridge wrapper that imports _theme_params.scss first.
        // The wrapper lives in .trellis/build/ so its @import "theme_params"
        // resolves to the adjacent _theme_params.scss. The theme's actual SCSS
        // file is imported via absolute path so its own relative @imports
        // resolve correctly from its original directory.
        final wrapperBaseName = p.basenameWithoutExtension(file.path);
        final wrapperPath = p.join(themeBuildConfig.buildDir, 'bridge_$wrapperBaseName.scss');
        final themeFileAbsolute = p.canonicalize(file.path);
        File(wrapperPath).writeAsStringSync(
          '// Auto-generated bridge wrapper — do not edit\n'
          '@import "theme_params";\n'
          '@import "$themeFileAbsolute";\n',
        );

        final css = TrellisCss.compileSass(
          wrapperPath,
          outputStyle: OutputStyle.compressed,
          loadPaths: loadPaths,
        );
        File(outPath).writeAsStringSync(css);

        if (verbose) stdout.writeln('  Compiled ${file.path} → $outPath');
        count++;
      }
    }
  }

  return count;
}
