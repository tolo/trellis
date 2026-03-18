import 'dart:io';

import 'package:args/command_runner.dart';

import '../generator/blog_project_generator.dart';
import '../generator/dart_frog_project_generator.dart';
import '../generator/file_writer.dart';
import '../generator/project_generator.dart';
import '../generator/relic_project_generator.dart';
import '../validators.dart';

/// The `trellis create <project-name>` command.
///
/// Generates a Trellis project scaffold. Use `--template` to choose between
/// the HTMX server-rendered app template (default), the blog SSG template,
/// the Dart Frog + Trellis + HTMX template, or the Relic + Trellis + HTMX
/// template.
class CreateCommand extends Command<int> {
  CreateCommand() {
    argParser.addOption(
      'template',
      abbr: 't',
      help: 'Project template to use.',
      defaultsTo: 'htmx',
      allowed: ['htmx', 'blog', 'dart_frog', 'relic'],
      allowedHelp: {
        'htmx': 'Shelf + HTMX server-rendered app (default)',
        'blog': 'Static blog site with Markdown content and Trellis SSG',
        'dart_frog': 'Dart Frog + Trellis + HTMX server app',
        'relic': 'Relic + Trellis + HTMX server app',
      },
    );
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

    final template = argResults!['template'] as String;
    final writer = DiskFileWriter(dir.path);

    if (template == 'blog') {
      final generator = BlogProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();

      stdout.writeln('Created blog project "$projectName".');
      stdout.writeln('');
      stdout.writeln('Next steps:');
      stdout.writeln('  cd $projectName');
      stdout.writeln('  dart pub get');
      stdout.writeln('  trellis build');
      stdout.writeln('  trellis serve');
    } else if (template == 'dart_frog') {
      final generator = DartFrogProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();

      stdout.writeln('Created Dart Frog project "$projectName".');
      stdout.writeln('');
      stdout.writeln('Next steps:');
      stdout.writeln('  cd $projectName');
      stdout.writeln('  dart pub get');
      stdout.writeln('  dart_frog dev');
    } else if (template == 'relic') {
      final generator = RelicProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();

      stdout.writeln('Created Relic project "$projectName".');
      stdout.writeln('');
      stdout.writeln('Next steps:');
      stdout.writeln('  cd $projectName');
      stdout.writeln('  dart pub get');
      stdout.writeln('  dart run bin/server.dart');
    } else {
      final generator = ProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();

      stdout.writeln('Created project "$projectName".');
      stdout.writeln('');
      stdout.writeln('Next steps:');
      stdout.writeln('  cd $projectName');
      stdout.writeln('  dart pub get');
      stdout.writeln('  dart run bin/server.dart');
    }

    return 0;
  }
}
