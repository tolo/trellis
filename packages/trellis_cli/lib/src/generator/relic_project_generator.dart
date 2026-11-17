import 'file_writer.dart';
import '../templates/htmx_asset.dart';
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
  RelicProjectGenerator({required this.projectName, required this.writer, this.htmxCdn = false});

  /// The Dart-valid project name.
  final String projectName;

  /// The file writer used to create project files.
  final FileWriter writer;

  /// Load the SRI-pinned CDN build instead of writing the embedded HTMX file.
  final bool htmxCdn;

  /// Generates all project files.
  ///
  Future<void> generate() async {
    // Config files
    await writer.writeFile('pubspec.yaml', relicPubspecTemplate(projectName));
    await writer.writeFile('.gitignore', gitignoreTemplate());
    await writer.writeFile('analysis_options.yaml', analysisOptionsTemplate());

    // Dart source
    await writer.writeFile('bin/server.dart', relicServerTemplate(projectName, htmxCdn: htmxCdn));
    await writer.writeFile('lib/handlers.dart', relicHandlersTemplate(projectName));

    // Templates
    await writer.writeFile('templates/base.html', relicBaseLayoutTemplate(projectName, htmxCdn: htmxCdn));
    await writer.writeFile('templates/index.html', relicIndexPageTemplate());
    await writer.writeFile('templates/about.html', relicAboutPageTemplate());

    // Static assets
    await writer.writeFile('static/styles.css', relicStylesTemplate() + htmxIndicatorCss);
    if (!htmxCdn) await writer.writeFile('static/js/htmx.min.js', htmxSource);
  }
}
