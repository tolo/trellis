import 'file_writer.dart';
import '../templates/analysis_options_template.dart';
import '../templates/base_layout_template.dart';
import '../templates/gitignore_template.dart';
import '../templates/handlers_template.dart';
import '../templates/htmx_fragments_template.dart';
import '../templates/index_page_template.dart';
import '../templates/nav_partial_template.dart';
import '../templates/pubspec_template.dart';
import '../templates/server_template.dart';
import '../templates/styles_template.dart';

/// Generates a complete Trellis project scaffold.
class ProjectGenerator {
  /// Creates a generator for a project with [projectName], writing files
  /// via [writer].
  ProjectGenerator({required this.projectName, required this.writer});

  /// The Dart-valid project name.
  final String projectName;

  /// The file writer used to create project files.
  final FileWriter writer;

  /// Generates all project files.
  ///
  /// Creates 10 files: pubspec.yaml, bin/server.dart, lib/handlers.dart,
  /// 4 templates (layouts/base.html, pages/index.html, partials/nav.html,
  /// partials/htmx.html), static/styles.css, .gitignore, and
  /// analysis_options.yaml.
  Future<void> generate() async {
    await writer.writeFile('pubspec.yaml', pubspecTemplate(projectName));
    await writer.writeFile('bin/server.dart', serverTemplate(projectName));
    await writer.writeFile('lib/handlers.dart', handlersTemplate(projectName));
    await writer.writeFile('templates/layouts/base.html', baseLayoutTemplate(projectName));
    await writer.writeFile('templates/pages/index.html', indexPageTemplate());
    await writer.writeFile('templates/partials/nav.html', navPartialTemplate());
    await writer.writeFile('templates/partials/htmx.html', htmxFragmentsTemplate());
    await writer.writeFile('static/styles.css', stylesTemplate());
    await writer.writeFile('.gitignore', gitignoreTemplate());
    await writer.writeFile('analysis_options.yaml', analysisOptionsTemplate());
  }
}
