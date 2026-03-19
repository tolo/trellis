import 'file_writer.dart';
import '../templates/analysis_options_template.dart';
import '../templates/gitignore_template.dart';
import '../templates/relic/relic_about_page_template.dart';
import '../templates/relic/relic_base_layout_template.dart';
import '../templates/relic/relic_handlers_template.dart';
import '../templates/relic/relic_index_page_template.dart';
import '../templates/relic/relic_pubspec_template.dart';
import '../templates/relic/relic_server_template.dart';
import '../templates/relic/relic_styles_template.dart';

/// Generates a complete Relic + Trellis + HTMX project scaffold.
///
/// Produces a runnable server project demonstrating Relic's explicit
/// engine-passing pattern (no DI), `trellis_relic` response helpers,
/// template inheritance, security headers, and HTMX fragment interactions
/// (counter example with increment, decrement, and reset).
class RelicProjectGenerator {
  /// Creates a generator for a Relic project with [projectName], writing
  /// files via [writer].
  RelicProjectGenerator({required this.projectName, required this.writer});

  /// The Dart-valid project name.
  final String projectName;

  /// The file writer used to create project files.
  final FileWriter writer;

  /// Generates all project files.
  ///
  /// Creates 9 files: pubspec.yaml, bin/server.dart, lib/handlers.dart,
  /// 3 HTML templates (base.html, index.html, about.html),
  /// static/styles.css, .gitignore, and analysis_options.yaml.
  Future<void> generate() async {
    // Config files
    await writer.writeFile('pubspec.yaml', relicPubspecTemplate(projectName));
    await writer.writeFile('.gitignore', gitignoreTemplate());
    await writer.writeFile('analysis_options.yaml', analysisOptionsTemplate());

    // Dart source
    await writer.writeFile('bin/server.dart', relicServerTemplate(projectName));
    await writer.writeFile('lib/handlers.dart', relicHandlersTemplate(projectName));

    // Templates
    await writer.writeFile('templates/base.html', relicBaseLayoutTemplate(projectName));
    await writer.writeFile('templates/index.html', relicIndexPageTemplate());
    await writer.writeFile('templates/about.html', relicAboutPageTemplate());

    // Static assets
    await writer.writeFile('static/styles.css', relicStylesTemplate());
  }
}
