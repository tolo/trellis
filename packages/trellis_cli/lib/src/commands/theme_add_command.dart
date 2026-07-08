import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';

import '../theme_config_updater.dart';
import '../validators.dart';

/// The `trellis theme add <url-or-path>` subcommand.
///
/// Installs a theme from a git URL (shallow clone) or local path (directory
/// copy). Reads the theme's `theme.yaml`, then sets `theme:` in
/// `trellis_site.yaml`.
class ThemeAddCommand extends Command<int> {
  /// Base directory the site and its `themes/` are resolved from. Defaults to
  /// the process current directory.
  final String? workingDirectory;

  ThemeAddCommand({this.workingDirectory}) {
    argParser.addOption('ref', help: 'Git tag, branch, or commit to checkout.', valueHelp: 'tag');
  }

  @override
  String get name => 'add';

  @override
  String get description => 'Install a theme from a git URL or local path.';

  @override
  String get invocation => 'trellis theme add <url-or-path> [--ref <tag>]';

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
        themeName = await _addFromLocalPath(source, themesDir);
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

  Future<String> _addFromLocalPath(String source, String themesDir) async {
    final sourceDir = Directory(source);
    if (!sourceDir.existsSync()) {
      stderr.writeln('Error: Local path does not exist: $source');
      throw _ThemeAddException();
    }

    final themeName = p.basename(p.canonicalize(source));
    final destDir = p.join(themesDir, themeName);

    if (Directory(destDir).existsSync()) {
      stderr.writeln("Error: Theme '$themeName' already installed. Use 'trellis theme update $themeName'.");
      throw _ThemeAddException();
    }

    // Copy directory recursively, excluding .git/
    _copyDirectory(sourceDir, Directory(destDir));
    return themeName;
  }

  Future<String> _addFromGit(String url, String themesDir, String? ref) async {
    // Derive theme name from git URL
    final themeName = themeNameFromUrl(url);
    final destDir = p.join(themesDir, themeName);

    if (Directory(destDir).existsSync()) {
      stderr.writeln("Error: Theme '$themeName' already installed. Use 'trellis theme update $themeName'.");
      throw _ThemeAddException();
    }

    // Shallow clone
    final cloneArgs = ['clone', '--depth', '1'];
    if (ref != null) cloneArgs.addAll(['--branch', ref]);
    cloneArgs.addAll([url, destDir]);

    final ProcessResult result;
    try {
      result = await Process.run('git', cloneArgs);
    } on ProcessException {
      stderr.writeln('Error: git is required for theme commands but was not found on PATH — install git and retry.');
      throw _ThemeAddException();
    }
    if (result.exitCode != 0) {
      stderr.writeln('Error: Failed to clone theme: ${result.stderr}');
      throw _ThemeAddException();
    }

    return themeName;
  }
}

/// Recursively copies [source] to [destination], excluding `.git/` directories.
void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync(recursive: false)) {
    final basename = p.basename(entity.path);
    // Skip .git directory
    if (basename == '.git') continue;

    final newPath = p.join(destination.path, basename);
    if (entity is File) {
      entity.copySync(newPath);
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory(newPath));
    }
  }
}

/// Sentinel exception used to signal early exit with exit code 1.
class _ThemeAddException implements Exception {}
