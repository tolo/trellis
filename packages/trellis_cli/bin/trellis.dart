import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:trellis_cli/trellis_cli.dart';

Future<void> main(List<String> args) async {
  try {
    final exitCode = await TrellisCli().run(args);
    exit(exitCode);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln('');
    stderr.writeln(e.usage);
    exit(64);
  }
}
