import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

import '../version.dart';

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
    } on _SassBuildFailure catch (failure) {
      stderr.write(_describeSassFailure(failure, siteDir: config.siteDir));
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
/// Throws [_SassBuildFailure] on compilation failure.
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

        // Fatal for themes only: an @import-era theme would compile with a
        // warning, but no skin file is injected any more, so `skin: dark` would
        // silently build light (ADR-013). A site's own stylesheets keep @import
        // until Dart Sass 3.0.
        final String css;
        try {
          css = TrellisCss.compileSass(
            wrapperPath,
            outputStyle: OutputStyle.compressed,
            loadPaths: loadPaths,
            fatalImportDeprecation: true,
          );
        } on SassCompilationException catch (e) {
          throw _SassBuildFailure(e, themeName: config.themeConfig!.name);
        }
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

      final String css;
      try {
        css = TrellisCss.compileSass(file.path, outputStyle: OutputStyle.compressed, loadPaths: loadPaths);
      } on SassCompilationException catch (e) {
        throw _SassBuildFailure(e);
      }
      File(outPath).writeAsStringSync(css);

      if (verbose) stdout.writeln('  Compiled ${file.path} → $outPath');
      count++;
    }
  }

  return count;
}

/// A SASS compilation failure, with the theme it came from when it happened in a
/// theme entry (as opposed to the site's own stylesheets).
class _SassBuildFailure implements Exception {
  _SassBuildFailure(this.error, {this.themeName});

  final SassCompilationException error;
  final String? themeName;
}

const _authoringGuideUrl = 'https://tolo.github.io/trellis/docs/themes/authoring/';

/// Renders [failure] for the terminal: the Trellis explanation first, the raw
/// Sass text beneath it as detail.
///
/// An `@import` in a theme gets its own message because Sass's wording ("Remove
/// this setting") points at a compiler option the user cannot change. Matching
/// on the message is the only handle: `trellis_css` does not expose the
/// deprecation id, and an unmatched message just falls through to the generic
/// rendering, which still carries the location.
String _describeSassFailure(_SassBuildFailure failure, {required String siteDir}) {
  final error = failure.error;
  final themeName = failure.themeName;
  final location = _sassLocation(error, siteDir);
  final buffer = StringBuffer();

  if (themeName != null && error.message.contains('@import rules are deprecated')) {
    buffer
      ..writeln('Build failed: theme "$themeName" uses @import${location == null ? '' : ' at $location'}.')
      ..writeln('Theme SASS is compiled with @use/@forward, so an @import theme cannot be built. To fix it, either:')
      ..writeln('  - if it is a built-in Trellis theme, re-add it at this release:')
      ..writeln('      trellis theme remove $themeName')
      ..writeln('      trellis theme add https://github.com/tolo/trellis --theme $themeName --ref v$cliVersion')
      ..writeln('  - otherwise migrate its SASS to @use: $_authoringGuideUrl')
      ..writeln()
      ..writeln('Sass reported:')
      ..writeln(_indent(error.message));
    return buffer.toString();
  }

  buffer.writeln('SASS compilation failed${themeName == null ? '' : ' in theme "$themeName"'}: ${error.message}');
  if (location != null) buffer.writeln('  at $location');
  return buffer.toString();
}

/// `path:line:column` of [error], with the path relative to [siteDir] when it is
/// inside it. Null when the exception carries no span.
String? _sassLocation(SassCompilationException error, String siteDir) {
  final path = error.path;
  if (path == null) return null;
  // The theme wrapper imports its entry by canonicalized (absolute, normalized)
  // path, so normalize both sides before testing containment.
  final canonicalSite = p.canonicalize(siteDir);
  final canonicalPath = p.canonicalize(path);
  final shown = p.isWithin(canonicalSite, canonicalPath) ? p.relative(canonicalPath, from: canonicalSite) : path;
  final line = error.line;
  if (line == null) return shown;
  return error.column == null ? '$shown:$line' : '$shown:$line:${error.column}';
}

String _indent(String text) => text.trimRight().split('\n').map((line) => line.isEmpty ? line : '  $line').join('\n');
