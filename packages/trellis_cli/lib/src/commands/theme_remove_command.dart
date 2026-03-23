import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';

import '../theme_config_updater.dart';

/// The `trellis theme remove <name>` subcommand.
///
/// Deletes the theme directory, clears `theme:` from `trellis_site.yaml` if
/// it was the active theme, and warns about any orphaned `theme_params:`.
class ThemeRemoveCommand extends Command<int> {
  @override
  String get name => 'remove';

  @override
  String get description => 'Remove an installed theme.';

  @override
  String get invocation => 'trellis theme remove <name>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('No theme name specified.\nUsage: trellis theme remove <name>');
    }

    final themeName = argResults!.rest.first;
    final themeDir = p.join(Directory.current.path, 'themes', themeName);

    if (!Directory(themeDir).existsSync()) {
      stderr.writeln("Error: Theme '$themeName' not found in themes/");
      return 1;
    }

    // Delete the theme directory
    Directory(themeDir).deleteSync(recursive: true);

    // Update config if this was the active theme
    final configPath = p.join(Directory.current.path, 'trellis_site.yaml');
    if (File(configPath).existsSync()) {
      try {
        final config = SiteConfig.load(configPath);
        if (config.themeConfig?.name == themeName) {
          final updater = ThemeConfigUpdater(configPath);
          updater.clearTheme();

          if (config.themeConfig!.params.isNotEmpty) {
            stdout.writeln(
              'Warning: theme_params: section still in trellis_site.yaml — '
              'remove manually if no longer needed.',
            );
          }
        }
      } on SiteConfigException {
        // Config unreadable — directory already removed, nothing more to do
      }
    }

    stdout.writeln('Removed theme "$themeName".');
    return 0;
  }
}
