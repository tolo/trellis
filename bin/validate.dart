import 'dart:io';

import 'package:args/args.dart';
import 'package:trellis/trellis.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('dir', defaultsTo: 'templates')
    ..addOption('prefix', defaultsTo: 'tl')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(arguments);
  if (results['help'] as bool) {
    stdout.write(parser.usage);
    return;
  }

  final directory = Directory(results['dir'] as String);
  if (!directory.existsSync()) {
    stderr.writeln('Directory not found: ${directory.path}');
    exitCode = 1;
    return;
  }

  final validator = TemplateValidator(prefix: results['prefix'] as String);
  final files =
      directory.listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.html')).toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  var hasErrors = false;
  for (final file in files) {
    final source = await file.readAsString();
    final issues = validator.validate(source);
    for (final issue in issues) {
      stderr.writeln(
        '${file.path}:${issue.line ?? 0}: ${issue.severity.name}: ${issue.message}'
        '${issue.attribute != null ? ' (${issue.attribute})' : ''}',
      );
      if (issue.severity == ValidationSeverity.error) {
        hasErrors = true;
      }
    }
  }

  exitCode = hasErrors ? 1 : 0;
}
