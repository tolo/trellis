import 'dart:io';

import 'src/parity.dart';
import 'src/pipeline.dart';
import 'src/sync.dart';
import 'src/sync_report.dart';

const _usage = 'usage: dart run tool/port.dart fetch|generate|build|check|parity|sync <tag>|sync --check-report <file>';

Future<void> main(List<String> args) async {
  final root = Directory.fromUri(Platform.script.resolve('../'));
  exitCode = await runPortCommand(args, Pipeline(root));
}

/// Runs the same pipeline command line against a supplied root and HTTP client.
Future<int> runPortCommand(List<String> args, Pipeline pipeline, {String? compilerPath, String? platform}) async {
  switch (args) {
    case ['--help' || '-h']:
      stdout.writeln(_usage);
    case ['fetch']:
      await pipeline.fetch();
    case ['generate']:
      await pipeline.generator.generate();
    case ['build']:
      await pipeline.build();
    case ['check']:
      await pipeline.check();
    case ['parity']:
      final result = checkParity(pipeline.root);
      result.lines.forEach(stdout.writeln);
      return result.failures == 0 ? 0 : 1;
    case ['sync', final tag]:
      final report = await syncPin(pipeline, tag, compilerPath: compilerPath, platform: platform);
      stdout.writeln('Sync report: ${report.path}');
    case ['sync', '--check-report', final path]:
      final issues = syncReportIssues(File(path).readAsStringSync());
      if (issues.isNotEmpty) {
        issues.forEach(stderr.writeln);
        return 1;
      }
      stdout.writeln('Sync report check: all changes and gate results triaged');
    default:
      throw ArgumentError(_usage);
  }
  return 0;
}
