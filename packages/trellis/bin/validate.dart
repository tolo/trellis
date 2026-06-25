import 'dart:io';

import 'package:args/args.dart';
import 'package:trellis/trellis.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('dir', defaultsTo: 'templates', help: 'Directory to scan recursively for .html templates.')
    ..addOption('prefix', defaultsTo: 'tl', help: 'Template attribute prefix.')
    ..addFlag(
      'strict',
      aliases: ['fatal-warnings'],
      negatable: false,
      help: 'Treat warnings as failures (exit 1). Use this for CI gates.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(arguments);
  if (results['help'] as bool) {
    stdout.writeln('Usage: dart run trellis:validate [directory] [options]\n');
    stdout.write(parser.usage);
    return;
  }

  // A positional argument (e.g. `trellis:validate templates/`) takes precedence
  // over --dir so the natural invocation works as expected.
  final dirPath = results.rest.isNotEmpty ? results.rest.first : results['dir'] as String;
  final directory = Directory(dirPath);
  if (!directory.existsSync()) {
    stderr.writeln('Directory not found: ${directory.path}');
    exitCode = 1;
    return;
  }

  final strict = results['strict'] as bool;
  final validator = TemplateValidator(prefix: results['prefix'] as String);
  final files =
      directory.listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.html')).toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  var hasErrors = false;
  var hasWarnings = false;
  for (final file in files) {
    final source = await file.readAsString();
    final issues = validator.validate(source);
    for (final issue in issues) {
      stderr.writeln(
        '${file.path}:${issue.line ?? 0}: ${issue.severity.name}: ${issue.message}'
        '${issue.attribute != null ? ' (${issue.attribute})' : ''}',
      );
      switch (issue.severity) {
        case ValidationSeverity.error:
          hasErrors = true;
        case ValidationSeverity.warning:
          hasWarnings = true;
      }
    }
  }

  exitCode = hasErrors || (strict && hasWarnings) ? 1 : 0;
}
