import 'package:args/command_runner.dart';

import 'theme_add_command.dart';
import 'theme_info_command.dart';
import 'theme_list_command.dart';
import 'theme_remove_command.dart';
import 'theme_update_command.dart';

/// The `trellis theme` command group.
///
/// Manages theme installation, updates, inspection, and removal.
class ThemeCommand extends Command<int> {
  /// Base directory the site and its `themes/` are resolved from. Defaults to
  /// the process current directory. Injected by tests and forwarded to every
  /// subcommand so theme operations never depend on (or mutate) the
  /// process-global working directory.
  final String? workingDirectory;

  ThemeCommand({this.workingDirectory}) {
    addSubcommand(ThemeAddCommand(workingDirectory: workingDirectory));
    addSubcommand(ThemeUpdateCommand(workingDirectory: workingDirectory));
    addSubcommand(ThemeListCommand(workingDirectory: workingDirectory));
    addSubcommand(ThemeInfoCommand(workingDirectory: workingDirectory));
    addSubcommand(ThemeRemoveCommand(workingDirectory: workingDirectory));
  }

  @override
  String get name => 'theme';

  @override
  String get description => 'Manage themes for your Trellis site.';

  @override
  String get invocation => 'trellis theme <subcommand>';
}
