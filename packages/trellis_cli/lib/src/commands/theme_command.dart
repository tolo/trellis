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
  ThemeCommand() {
    addSubcommand(ThemeAddCommand());
    addSubcommand(ThemeUpdateCommand());
    addSubcommand(ThemeListCommand());
    addSubcommand(ThemeInfoCommand());
    addSubcommand(ThemeRemoveCommand());
  }

  @override
  String get name => 'theme';

  @override
  String get description => 'Manage themes for your Trellis site.';

  @override
  String get invocation => 'trellis theme <subcommand>';
}
