import 'dart:io';

import 'src/pipeline.dart';
import 'src/parity.dart';

Future<void> main(List<String> args) async {
  final root = Directory.fromUri(Platform.script.resolve('../'));
  final pipeline = Pipeline(root);
  if (args.length != 1) throw ArgumentError('usage: dart run tool/port.dart fetch|generate|build|check|parity');
  switch (args.single) {
    case 'fetch':
      await pipeline.fetch();
    case 'generate':
      await pipeline.generator.generate();
    case 'build':
      await pipeline.build();
    case 'check':
      await pipeline.check();
    case 'parity':
      final result = checkParity(root);
      result.lines.forEach(stdout.writeln);
      if (result.failures != 0) exitCode = 1;
    default:
      throw ArgumentError('Unknown pipeline command: ${args.single}');
  }
}
