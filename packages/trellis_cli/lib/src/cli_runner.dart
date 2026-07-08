import 'dart:async';

import 'package:args/command_runner.dart';

import 'commands/build_command.dart';
import 'commands/create_command.dart';
import 'commands/serve_command.dart';
import 'commands/theme_command.dart';
import 'version.dart';

/// The top-level command runner for the Trellis CLI.
class TrellisCli extends CommandRunner<int> {
  /// Creates a [TrellisCli] with all commands registered.
  ///
  /// [serveStopSignal] is forwarded to [ServeCommand] to override the default
  /// SIGINT-based shutdown. Tests may inject a [Completer.future] here to
  /// stop the server without sending a process signal.
  ///
  /// [workingDirectory] is forwarded to every command as the base directory for
  /// resolving scaffolds, sites, and themes. It defaults to the process current
  /// directory (zero user-facing change); tests inject a temp directory so the
  /// suite never mutates the process-global working directory.
  TrellisCli({Future<void>? serveStopSignal, String? workingDirectory})
    : super('trellis', 'Trellis SDK — build and serve static sites.') {
    argParser.addFlag('version', negatable: false, help: 'Print the CLI version.');
    addCommand(CreateCommand(workingDirectory: workingDirectory));
    addCommand(BuildCommand(workingDirectory: workingDirectory));
    addCommand(ServeCommand(stopSignal: serveStopSignal, workingDirectory: workingDirectory));
    addCommand(ThemeCommand(workingDirectory: workingDirectory));
  }

  @override
  Future<int> run(Iterable<String> args) async {
    final results = parse(args);
    if (results['version'] as bool) {
      print('trellis_cli $cliVersion');
      return 0;
    }
    return await (runCommand(results) as Future<int?>?) ?? 0;
  }
}
