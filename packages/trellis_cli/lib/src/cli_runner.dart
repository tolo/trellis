import 'package:args/command_runner.dart';

import 'commands/create_command.dart';
import 'version.dart';

/// The top-level command runner for the Trellis CLI.
class TrellisCli extends CommandRunner<int> {
  TrellisCli() : super('trellis', 'Trellis SDK — project scaffolding.') {
    argParser.addFlag('version', negatable: false, help: 'Print the CLI version.');
    addCommand(CreateCommand());
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
