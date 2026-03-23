import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';

/// The `trellis theme info <name>` subcommand.
///
/// Displays theme manifest metadata and all params with current (site-configured)
/// and default values.
class ThemeInfoCommand extends Command<int> {
  @override
  String get name => 'info';

  @override
  String get description => 'Show theme details and parameters.';

  @override
  String get invocation => 'trellis theme info <name>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('No theme name specified.\nUsage: trellis theme info <name>');
    }

    final themeName = argResults!.rest.first;
    final themeDir = p.join(Directory.current.path, 'themes', themeName);

    if (!Directory(themeDir).existsSync()) {
      stderr.writeln("Error: Theme '$themeName' not found in themes/");
      return 1;
    }

    final ThemeManifest manifest;
    try {
      manifest = ThemeManifest.load(themeDir);
    } on ThemeManifestException catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    }

    // Load site config for current param values (only when this is the active theme)
    var currentParams = <String, dynamic>{};
    final configPath = p.join(Directory.current.path, 'trellis_site.yaml');
    if (File(configPath).existsSync()) {
      try {
        final config = SiteConfig.load(configPath);
        if (config.themeConfig?.name == themeName) {
          currentParams = config.themeConfig!.params;
        }
      } on SiteConfigException {
        // Ignore — just show defaults
      }
    }

    // Display manifest metadata
    stdout.writeln('Theme: ${manifest.name}');
    stdout.writeln('Version: ${manifest.version}');
    if (manifest.author != null) stdout.writeln('Author: ${manifest.author}');
    if (manifest.description != null) stdout.writeln('Description: ${manifest.description}');
    if (manifest.minTrellisVersion != null) {
      stdout.writeln('Requires: trellis_site >=${manifest.minTrellisVersion}');
    }
    if (manifest.features.isNotEmpty) {
      stdout.writeln('Features: ${manifest.features.join(', ')}');
    }

    // Display params
    if (manifest.params.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln('Parameters:');
      for (final param in manifest.params.values) {
        final current = currentParams[param.name];
        final defaultVal = param.defaultValue;
        final typeStr = param.type;
        final enumStr = param.enumValues != null ? ' [${param.enumValues!.join(', ')}]' : '';

        if (current != null) {
          stdout.writeln('  ${param.name} ($typeStr$enumStr)');
          stdout.writeln('    Current: $current');
          stdout.writeln('    Default: $defaultVal');
        } else {
          stdout.writeln('  ${param.name} ($typeStr$enumStr) = $defaultVal');
        }
        if (param.description != null) {
          stdout.writeln('    ${param.description}');
        }
      }
    }

    return 0;
  }
}
