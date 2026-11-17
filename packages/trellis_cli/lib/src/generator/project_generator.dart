import 'file_writer.dart';
import '../templates/htmx_asset.dart';
import '../templates/analysis_options_template.dart';
import '../templates/about_page_template.dart';
import '../templates/base_layout_template.dart';
import '../templates/gitignore_template.dart';
import '../templates/handlers_template.dart';
import '../templates/index_page_template.dart';
import '../templates/nav_partial_template.dart';
import '../templates/pubspec_template.dart';
import '../templates/server_template.dart';
import '../templates/styles_template.dart';

/// Generates a complete Trellis project scaffold.
class ProjectGenerator {
  /// Creates a generator for a project with [projectName], writing files
  /// via [writer].
  ProjectGenerator({required this.projectName, required this.writer, this.htmxCdn = false});

  /// The Dart-valid project name.
  final String projectName;

  /// The file writer used to create project files.
  final FileWriter writer;

  /// Load the SRI-pinned CDN build instead of writing the embedded HTMX file.
  final bool htmxCdn;

  /// Generates all project files.
  ///
  Future<void> generate() async {
    await writer.writeFile('pubspec.yaml', pubspecTemplate(projectName));
    await writer.writeFile('bin/server.dart', serverTemplate(projectName, htmxCdn: htmxCdn));
    await writer.writeFile('lib/handlers.dart', handlersTemplate(projectName));
    await writer.writeFile('templates/layouts/base.html', baseLayoutTemplate(projectName, htmxCdn: htmxCdn));
    await writer.writeFile('templates/pages/index.html', indexPageTemplate());
    await writer.writeFile('templates/pages/about.html', aboutPageTemplate());
    await writer.writeFile('templates/partials/nav.html', navPartialTemplate());
    await writer.writeFile('static/styles.css', stylesTemplate() + htmxIndicatorCss);
    if (!htmxCdn) await writer.writeFile('static/js/htmx.min.js', htmxSource);
    await writer.writeFile('static/js/csrf.js', csrfScript);
    await writer.writeFile('.gitignore', gitignoreTemplate());
    await writer.writeFile('analysis_options.yaml', analysisOptionsTemplate());
  }
}
