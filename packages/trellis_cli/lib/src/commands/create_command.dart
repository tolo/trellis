import 'dart:io';

import 'package:args/command_runner.dart';

import '../generator/file_writer.dart';
import '../generator/project_generator.dart';
import '../validators.dart';

/// The `trellis create <project-name>` command.
///
/// Generates a complete Shelf + HTMX + Trellis project scaffold.
class CreateCommand extends Command<int> {
  CreateCommand() {
    argParser.addOption('template', abbr: 't', help: 'Project template to use.', defaultsTo: 'htmx', allowed: ['htmx']);
  }

  @override
  String get name => 'create';

  @override
  String get description => 'Create a new Trellis project.';

  @override
  String get invocation => 'trellis create <project-name>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('No project name specified.');
    }
    if (argResults!.rest.length > 1) {
      usageException('Too many arguments.');
    }

    final projectName = argResults!.rest.first;
    final error = validateProjectName(projectName);
    if (error != null) {
      usageException(error);
    }

    final dir = Directory(projectName);
    if (dir.existsSync()) {
      usageException('Directory "$projectName" already exists.');
    }

    await dir.create();

    final generator = ProjectGenerator(projectName: projectName, writer: DiskFileWriter(dir.path));
    await generator.generate();

    stdout.writeln('Created project "$projectName".');
    stdout.writeln('');
    stdout.writeln('Next steps:');
    stdout.writeln('  cd $projectName');
    stdout.writeln('  dart pub get');
    stdout.writeln('  dart run bin/server.dart');

    return 0;
  }
}
