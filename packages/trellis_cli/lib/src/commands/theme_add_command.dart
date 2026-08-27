import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';

import '../process_runner.dart';
import '../theme_config_updater.dart';
import '../validators.dart';

/// The `trellis theme add <url-or-path>` subcommand.
///
/// Installs a theme from a git URL (shallow clone) or local path (directory
/// copy). Reads the theme's `theme.yaml`, then sets `theme:` in
/// `trellis_site.yaml`.
///
/// `--theme <name>` installs a single theme out of a multi-theme repository
/// (the layout the Trellis themes themselves use: `themes/<name>/` inside one
/// repo). The source is materialized in a temporary directory and only
/// `themes/<name>/` is copied into the site, so the site's `themes/` mirrors
/// the whole-repo case.
class ThemeAddCommand extends Command<int> {
  /// Base directory the site and its `themes/` are resolved from. Defaults to
  /// the process current directory.
  final String? workingDirectory;

  ThemeAddCommand({this.workingDirectory, ProcessRunner processRunner = runProcess}) : _processRunner = processRunner {
    argParser
      ..addOption('ref', help: 'Git tag, branch, or commit to checkout.', valueHelp: 'tag')
      ..addOption(
        'theme',
        help: "Install one theme from a multi-theme source's themes/<name>/ directory.",
        valueHelp: 'name',
      );
  }

  final ProcessRunner _processRunner;

  @override
  String get name => 'add';

  @override
  String get description => 'Install a theme from a git URL or local path.';

  @override
  String get invocation => 'trellis theme add <url-or-path> [--theme <name>] [--ref <tag>]';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('No URL or path specified.\nUsage: trellis theme add <url-or-path>');
    }
    if (argResults!.rest.length > 1) {
      usageException('Too many arguments. Usage: trellis theme add <url-or-path>');
    }

    final source = argResults!.rest.first;
    final ref = argResults!['ref'] as String?;
    final subdirectoryTheme = argResults!['theme'] as String?;

    if (subdirectoryTheme != null) {
      final invalid = validateThemeName(subdirectoryTheme);
      if (invalid != null) {
        stderr.writeln('Error: $invalid');
        return 1;
      }
    }

    final baseDir = workingDirectory ?? Directory.current.path;

    // Verify trellis_site.yaml exists
    final configPath = p.join(baseDir, 'trellis_site.yaml');
    if (!File(configPath).existsSync()) {
      stderr.writeln('Error: trellis_site.yaml not found in $baseDir');
      return 1;
    }

    // Create themes/ directory if needed
    final themesDir = p.join(baseDir, 'themes');
    Directory(themesDir).createSync(recursive: true);

    // Determine if source is a local path or git URL
    final isLocal = _isLocalPath(source);

    final String themeName;
    try {
      if (isLocal) {
        themeName = await _addFromLocalPath(source, themesDir, subdirectoryTheme);
      } else if (subdirectoryTheme != null) {
        themeName = await _addFromGitSubdirectory(source, themesDir, ref, subdirectoryTheme);
      } else {
        themeName = await _addFromGit(source, themesDir, ref);
      }
    } on _ThemeAddException {
      return 1;
    }

    // Verify theme.yaml is valid
    final themeDir = p.join(themesDir, themeName);
    try {
      ThemeManifest.load(themeDir);
    } on ThemeManifestException catch (e) {
      stderr.writeln('Error: Invalid theme — $e');
      // Clean up the cloned/copied directory
      Directory(themeDir).deleteSync(recursive: true);
      return 1;
    }

    // Update trellis_site.yaml
    final updater = ThemeConfigUpdater(configPath);
    updater.setTheme(themeName, ref: ref);

    stdout.writeln('Installed theme "$themeName".');
    if (ref != null) stdout.writeln('  Pinned to ref: $ref');
    stdout.writeln('  Theme directory: themes/$themeName/');
    stdout.writeln('');
    stdout.writeln('Customize via theme_params: in trellis_site.yaml.');

    return 0;
  }

  bool _isLocalPath(String source) {
    return source.startsWith('./') ||
        source.startsWith('/') ||
        source.startsWith('../') ||
        Directory(source).existsSync();
  }

  Future<String> _addFromLocalPath(String source, String themesDir, String? subdirectoryTheme) async {
    if (!Directory(source).existsSync()) {
      stderr.writeln('Error: Local path does not exist: $source');
      throw _ThemeAddException();
    }

    final themeName = subdirectoryTheme ?? p.basename(p.canonicalize(source));
    final sourceDir = subdirectoryTheme == null
        ? Directory(source)
        : Directory(_resolveThemeSubdirectory(source, subdirectoryTheme, source));
    _requireNotInstalled(themesDir, themeName);

    // Copy directory recursively, excluding .git/
    _copyDirectory(sourceDir, Directory(p.join(themesDir, themeName)));
    return themeName;
  }

  Future<String> _addFromGit(String url, String themesDir, String? ref) async {
    // Derive theme name from git URL
    final themeName = themeNameFromUrl(url);
    final destDir = p.join(themesDir, themeName);
    _requireNotInstalled(themesDir, themeName);

    // Shallow clone. Unlike the local-path copy, symlinks are kept as git
    // materializes them: git's own checkout is safe and non-recursing, so the
    // skip in _copyDirectory (which only guards our own recursive copy) does
    // not apply here.
    await _clone(url, destDir, ref);
    return themeName;
  }

  /// Installs `themes/<themeName>/` out of the repository at [url].
  ///
  /// The repository is cloned to a temporary directory and discarded once the
  /// subdirectory has been copied — the installed theme carries no `.git`, so
  /// it is re-installed rather than `trellis theme update`d.
  Future<String> _addFromGitSubdirectory(String url, String themesDir, String? ref, String themeName) async {
    _requireNotInstalled(themesDir, themeName);

    final tempRoot = Directory.systemTemp.createTempSync('trellis_theme_add_');
    try {
      final clonePath = p.join(tempRoot.path, 'repo');
      await _clone(url, clonePath, ref);
      final sourcePath = _resolveThemeSubdirectory(clonePath, themeName, url, ref: ref);
      _copyDirectory(Directory(sourcePath), Directory(p.join(themesDir, themeName)));
    } finally {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    }
    return themeName;
  }

  /// Resolves `<root>/themes/<themeName>` and verifies it holds a manifest.
  ///
  /// [sourceLabel] names the source in the error message (a URL or a local
  /// path). The lexical half of the containment check is belt-and-braces over
  /// the charset validation in [validateThemeName]: a name that reached here
  /// cannot traverse, and a future relaxation of the charset cannot silently
  /// start writing outside the copy root either. The canonical half is what
  /// stops a source whose own `themes/<name>` is a symlink out of the tree.
  String _resolveThemeSubdirectory(String root, String themeName, String sourceLabel, {String? ref}) {
    final resolved = p.normalize(p.join(root, 'themes', themeName));
    if (!p.isWithin(p.normalize(root), resolved) || !_resolvesWithin(root, resolved)) {
      stderr.writeln("Error: Theme path 'themes/$themeName' escapes $sourceLabel.");
      throw _ThemeAddException();
    }
    if (!File(p.join(resolved, 'theme.yaml')).existsSync()) {
      stderr.writeln(
        "Error: Theme '$themeName' not found in $sourceLabel${ref == null ? '' : ' at ref $ref'} — "
        'expected a manifest at themes/$themeName/theme.yaml.',
      );
      throw _ThemeAddException();
    }
    return resolved;
  }

  void _requireNotInstalled(String themesDir, String themeName) {
    if (Directory(p.join(themesDir, themeName)).existsSync()) {
      stderr.writeln("Error: Theme '$themeName' already installed. Use 'trellis theme update $themeName'.");
      throw _ThemeAddException();
    }
  }

  /// Shallow-clones [url] into [destination], optionally pinned to [ref].
  Future<void> _clone(String url, String destination, String? ref) async {
    final cloneArgs = ['clone', '--depth', '1'];
    if (ref != null) cloneArgs.addAll(['--branch', ref]);
    cloneArgs.addAll([url, destination]);

    final ProcessResult result;
    try {
      result = await _processRunner('git', cloneArgs);
    } on ProcessException catch (e) {
      if (e.errorCode == fileNotFoundErrorCode) {
        stderr.writeln('Error: git is required for theme commands but was not found on PATH – install git and retry.');
      } else {
        // Any other spawn failure (e.g. EACCES) is genuine but not missing git:
        // report it gracefully rather than letting it escape as a raw stack trace.
        stderr.writeln('Error: git command failed: ${e.message}');
      }
      throw _ThemeAddException();
    }
    if (result.exitCode != 0) {
      stderr.writeln('Error: Failed to clone theme: ${result.stderr}');
      throw _ThemeAddException();
    }
  }
}

/// Whether [resolved] is still inside [root] once every symlink on both paths
/// has been followed, mirroring the containment check in
/// `tool/generate_theme_gallery.dart`.
///
/// A lexical [p.isWithin] compares normalized strings, so a source whose own
/// `themes/<name>` is a symlink pointing out of the tree passes it. The copy
/// that follows then materializes files from outside the source as real files
/// under the site's `themes/<name>/`, and `trellis build` publishes whatever
/// `themes/<name>/static/` resolved to. A symlink that stays inside [root] is
/// legitimate and allowed — containment is the rule, not "no symlinks".
///
/// A [resolved] that does not exist is not an escape: the missing-manifest
/// error names that failure far better, so it is left to run.
bool _resolvesWithin(String root, String resolved) {
  if (!Directory(resolved).existsSync()) return true;
  return p.isWithin(Directory(root).resolveSymbolicLinksSync(), Directory(resolved).resolveSymbolicLinksSync());
}

/// Recursively copies [source] to [destination], excluding `.git/` directories
/// and symlinks. [sourceRoot] is the top-level copy root, used to render
/// skipped-symlink notices as paths relative to it (defaults to [source]).
void _copyDirectory(Directory source, Directory destination, [Directory? sourceRoot]) {
  final root = sourceRoot ?? source;
  destination.createSync(recursive: true);
  // followLinks: false + skipping Links: symlinks are skipped conservatively to
  // avoid cycles from theme example scaffolding (e.g. example/themes/<name> →
  // ../.. self-references that would otherwise recurse unboundedly). The per-link
  // notice keeps the skip visible to users with legitimately symlinked assets.
  for (final entity in source.listSync(recursive: false, followLinks: false)) {
    final basename = p.basename(entity.path);
    // Skip .git directory
    if (basename == '.git') continue;
    if (entity is Link) {
      final rel = p.relative(entity.path, from: root.path);
      stdout.writeln('Skipped symlink: $rel (symlinks are not copied)');
      continue;
    }

    final newPath = p.join(destination.path, basename);
    if (entity is File) {
      entity.copySync(newPath);
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory(newPath), root);
    }
  }
}

/// Sentinel exception used to signal early exit with exit code 1.
class _ThemeAddException implements Exception {}
