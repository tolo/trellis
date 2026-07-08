import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';

/// The `trellis theme list` subcommand.
///
/// Lists all installed themes (subdirectories of `themes/`) with a `*` marker
/// on the active theme. Works even without a `trellis_site.yaml`.
class ThemeListCommand extends Command<int> {
  /// Base directory the site and its `themes/` are resolved from. Defaults to
  /// the process current directory.
  final String? workingDirectory;

  ThemeListCommand({this.workingDirectory});

  @override
  String get name => 'list';

  @override
  String get description => 'List installed themes.';

  @override
  String get invocation => 'trellis theme list';

  @override
  Future<int> run() async {
    final baseDir = workingDirectory ?? Directory.current.path;
    final configPath = p.join(baseDir, 'trellis_site.yaml');

    String? activeTheme;
    if (File(configPath).existsSync()) {
      try {
        final config = SiteConfig.load(configPath);
        activeTheme = config.themeConfig?.name;
      } on SiteConfigException {
        // Config unreadable — still list themes without active marker
      }
    }

    final themesDir = Directory(p.join(baseDir, 'themes'));
    if (!themesDir.existsSync()) {
      stdout.writeln('No themes installed.');
      return 0;
    }

    final themeDirs = themesDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    if (themeDirs.isEmpty) {
      stdout.writeln('No themes installed.');
      return 0;
    }

    for (final dir in themeDirs) {
      final name = p.basename(dir.path);
      final marker = name == activeTheme ? ' *' : '';
      final version = _getThemeVersion(dir.path);
      stdout.writeln('  $name$marker${version != null ? ' ($version)' : ''}');
    }

    if (activeTheme != null) {
      stdout.writeln('');
      stdout.writeln('* = active theme');
    }

    return 0;
  }

  String? _getThemeVersion(String themeDir) {
    try {
      final manifest = ThemeManifest.load(themeDir);
      return manifest.version;
    } catch (_) {
      return null;
    }
  }
}
