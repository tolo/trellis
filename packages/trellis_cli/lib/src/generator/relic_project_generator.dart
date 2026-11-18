import '../templates/analysis_options_template.dart';
import '../templates/gitignore_template.dart';
import '../templates/htmx_asset.dart';
import '../templates/relic/relic_about_page_template.dart';
import '../templates/relic/relic_base_layout_template.dart';
import '../templates/relic/relic_handlers_template.dart';
import '../templates/relic/relic_index_page_template.dart';
import '../templates/relic/relic_pubspec_template.dart';
import '../templates/relic/relic_server_template.dart';
import '../templates/relic/relic_styles_template.dart';
import '../templates/ui_scaffold_template.dart';
import 'file_writer.dart';

/// Generates a complete Relic + Trellis + HTMX project scaffold.
///
/// Produces a runnable server project demonstrating Relic's explicit
/// engine-passing pattern (no DI), `trellis_relic` response helpers,
/// template inheritance, security headers, CSRF protection, and HTMX fragment interactions
/// (counter example with increment, decrement, and reset).
class RelicProjectGenerator {
  /// Creates a generator for a Relic project with [projectName], writing
  /// files via [writer].
  RelicProjectGenerator({required this.projectName, required this.writer, this.htmxCdn = false, this.ui = false});

  /// The Dart-valid project name.
  final String projectName;

  /// The file writer used to create project files.
  final FileWriter writer;

  /// Load the SRI-pinned CDN build instead of writing the embedded HTMX file.
  final bool htmxCdn;

  /// Include the Trellis UI example and asset wiring.
  final bool ui;

  /// Generates all project files.
  Future<void> generate() async {
    // Config files
    await writer.writeFile('pubspec.yaml', relicPubspecTemplate(projectName, ui: ui));
    await writer.writeFile('.gitignore', gitignoreTemplate() + (ui ? '/$staticUiPreview/\n' : ''));
    await writer.writeFile('analysis_options.yaml', analysisOptionsTemplate());
    if (ui) {
      await writer.writeFile(
        'templates/ui.html',
        uiPageTemplate(layout: 'base.html', previewPath: '../$staticUiPreview'),
      );
    }

    // Dart source
    await writer.writeFile('bin/server.dart', relicServerTemplate(projectName, htmxCdn: htmxCdn, ui: ui));
    await writer.writeFile('lib/handlers.dart', relicHandlersTemplate(projectName, ui: ui));

    // Templates
    await writer.writeFile('templates/base.html', relicBaseLayoutTemplate(projectName, htmxCdn: htmxCdn, ui: ui));
    await writer.writeFile('templates/index.html', relicIndexPageTemplate());
    await writer.writeFile('templates/about.html', relicAboutPageTemplate());

    // Static assets
    await writer.writeFile('static/js/csrf.js', csrfScript);
    await writer.writeFile('static/styles.css', scaffoldStyles(relicStylesTemplate() + htmxIndicatorCss, ui: ui));
    if (!htmxCdn) {
      await writer.writeFile('static/js/htmx.min.js', htmxSource);
    }
  }
}
