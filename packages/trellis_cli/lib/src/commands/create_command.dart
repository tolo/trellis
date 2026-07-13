import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../generator/blog_project_generator.dart';
import '../generator/dart_frog_project_generator.dart';
import '../generator/file_writer.dart';
import '../generator/project_generator.dart';
import '../generator/relic_project_generator.dart';
import '../generator/theme_project_generator.dart';
import '../validators.dart';

/// The `trellis create <project-name>` command.
///
/// Generates a Trellis project scaffold. Use `--template` to choose between
/// the HTMX server-rendered app template (default), the blog SSG template,
/// the Dart Frog + Trellis + HTMX template, the Relic + Trellis + HTMX
/// template, or the theme scaffold template.
class CreateCommand extends Command<int> {
  /// Base directory the project is scaffolded into. Defaults to the process
  /// current directory. Injected by tests so scaffolding never depends on (or
  /// mutates) the process-global working directory.
  final String? workingDirectory;

  CreateCommand({this.workingDirectory}) {
    argParser.addOption(
      'template',
      abbr: 't',
      help: 'Project template to use.',
      defaultsTo: 'htmx',
      allowed: ['htmx', 'blog', 'dart_frog', 'relic', 'theme'],
      allowedHelp: {
        'htmx': 'Shelf + HTMX server-rendered app (default)',
        'blog': 'Static blog site with Markdown content and Trellis SSG',
        'dart_frog': 'Dart Frog + Trellis + HTMX server app',
        'relic': 'Relic + Trellis + HTMX server app',
        'theme': 'Trellis theme with standard params, skins, and layouts',
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

    final baseDir = workingDirectory ?? Directory.current.path;
    final dir = Directory(p.join(baseDir, projectName));
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
    } else if (template == 'theme') {
      final generator = ThemeProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();

      stdout.writeln('Created theme "$projectName".');
      stdout.writeln('');
      stdout.writeln('Next steps:');
      stdout.writeln('  cd $projectName');
      stdout.writeln('  Edit theme.yaml and customize params');
      stdout.writeln('  Preview: cd example && trellis build && trellis serve');
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
