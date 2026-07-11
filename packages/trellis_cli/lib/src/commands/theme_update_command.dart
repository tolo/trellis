import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';

import '../process_runner.dart';

/// The `trellis theme update [<name>]` subcommand.
///
/// Updates an installed theme via `git pull` (for unpinned themes) or
/// `git fetch` + `git checkout <ref>` (for pinned themes). If no name is
/// given, updates the active theme from `trellis_site.yaml`.
class ThemeUpdateCommand extends Command<int> {
  /// Base directory the site and its `themes/` are resolved from. Defaults to
  /// the process current directory.
  final String? workingDirectory;

  ThemeUpdateCommand({this.workingDirectory, ProcessRunner processRunner = runProcess})
      : _processRunner = processRunner;

  final ProcessRunner _processRunner;

  @override
  String get name => 'update';

  @override
  String get description => 'Update an installed theme.';

  @override
  String get invocation => 'trellis theme update [<name>]';

  @override
  Future<int> run() async {
    final baseDir = workingDirectory ?? Directory.current.path;
    final configPath = p.join(baseDir, 'trellis_site.yaml');
    if (!File(configPath).existsSync()) {
      stderr.writeln('Error: trellis_site.yaml not found in $baseDir');
      return 1;
    }

    final config = SiteConfig.load(configPath);
    final themeName = argResults!.rest.isEmpty ? config.themeConfig?.name : argResults!.rest.first;

    if (themeName == null) {
      stderr.writeln('Error: No theme specified and no active theme in config.');
      return 1;
    }

    final themeDir = p.join(baseDir, 'themes', themeName);
    if (!Directory(themeDir).existsSync()) {
      stderr.writeln("Error: Theme '$themeName' not found in themes/");
      return 1;
    }

    // Check if it's a git repo
    if (!Directory(p.join(themeDir, '.git')).existsSync()) {
      stderr.writeln("Warning: Theme '$themeName' is not a git repository — cannot update.");
      return 1;
    }

    // Determine ref from config
    final ref = config.themeConfig?.ref;

    try {
      if (ref != null) {
        // Fetch and checkout pinned ref
        var result = await _processRunner('git', ['-C', themeDir, 'fetch', 'origin']);
        if (result.exitCode != 0) {
          stderr.writeln('Error: git fetch failed: ${result.stderr}');
          return 1;
        }
        result = await _processRunner('git', ['-C', themeDir, 'checkout', ref]);
        if (result.exitCode != 0) {
          stderr.writeln('Error: git checkout $ref failed: ${result.stderr}');
          return 1;
        }
      } else {
        // Pull latest
        final result = await _processRunner('git', ['-C', themeDir, 'pull']);
        if (result.exitCode != 0) {
          stderr.writeln('Error: git pull failed: ${result.stderr}');
          return 1;
        }
      }
    } on ProcessException catch (e) {
      // errorCode 2 == ENOENT (git missing from PATH); anything else is a genuine
      // spawn failure and must not be misdiagnosed as missing git.
      if (e.errorCode == 2) {
        stderr.writeln('Error: git is required for theme commands but was not found on PATH - install git and retry.');
        return 1;
      }
      rethrow;
    }

    // Reload manifest and check min_trellis_version against installed version
    try {
      final manifest = ThemeManifest.load(themeDir);
      if (manifest.minTrellisVersion != null) {
        if (_isVersionLessThan(siteVersion, manifest.minTrellisVersion!)) {
          stderr.writeln(
            'Warning: Theme requires trellis_site >=${manifest.minTrellisVersion} '
            'but installed version is $siteVersion. '
            'Some features may not work correctly.',
          );
        }
      }
    } on ThemeManifestException catch (e) {
      stderr.writeln('Warning: Updated theme has invalid manifest — $e');
    }

    stdout.writeln('Updated theme "$themeName".');
    return 0;
  }

  /// Returns `true` if [a] is less than [b] using simple semver comparison.
  static bool _isVersionLessThan(String a, String b) {
    final aParts = a.split('.').map(int.tryParse).toList();
    final bParts = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final av = i < aParts.length ? (aParts[i] ?? 0) : 0;
      final bv = i < bParts.length ? (bParts[i] ?? 0) : 0;
      if (av < bv) return true;
      if (av > bv) return false;
    }
    return false;
  }
}
