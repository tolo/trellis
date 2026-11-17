import '../templates/analysis_options_template.dart';
import '../templates/dart_frog/dart_frog_about_page_template.dart';
import '../templates/dart_frog/dart_frog_about_route_template.dart';
import '../templates/dart_frog/dart_frog_base_layout_template.dart';
import '../templates/dart_frog/dart_frog_config_template.dart';
import '../templates/dart_frog/dart_frog_counter_route_templates.dart';
import '../templates/dart_frog/dart_frog_counter_state_template.dart';
import '../templates/dart_frog/dart_frog_index_page_template.dart';
import '../templates/dart_frog/dart_frog_index_route_template.dart';
import '../templates/dart_frog/dart_frog_middleware_template.dart';
import '../templates/dart_frog/dart_frog_nav_partial_template.dart';
import '../templates/dart_frog/dart_frog_pubspec_template.dart';
import '../templates/dart_frog/dart_frog_styles_template.dart';
import '../templates/dart_frog/dart_frog_ui_route_template.dart';
import '../templates/htmx_asset.dart';
import '../templates/ui_scaffold_template.dart';
import 'file_writer.dart';

/// Generates a complete Dart Frog + Trellis + HTMX project scaffold.
///
/// Produces a runnable server project demonstrating file-based routing,
/// `trellis_dart_frog` provider/middleware, template inheritance, HTMX SPA
/// navigation, and counter fragment interactions.
class DartFrogProjectGenerator {
  /// Creates a generator for a Dart Frog project with [projectName], writing
  /// files via [writer].
  DartFrogProjectGenerator({required this.projectName, required this.writer, this.htmxCdn = false, this.ui = false});

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
    await writer.writeFile('pubspec.yaml', dartFrogPubspecTemplate(projectName, ui: ui));
    await writer.writeFile('dart_frog.yaml', dartFrogConfigTemplate(projectName));
    await writer.writeFile('.gitignore', dartFrogGitignoreTemplate() + (ui ? '/$publicUiPreview/\n' : ''));
    await writer.writeFile('analysis_options.yaml', analysisOptionsTemplate());
    if (ui) {
      await writer.writeFile(
        'templates/pages/ui.html',
        uiPageTemplate(layout: 'layouts/base.html', previewPath: '../../$publicUiPreview'),
      );
      await writer.writeFile('routes/ui.dart', dartFrogUiRouteTemplate(projectName));
      await writer.writeFile('main.dart', dartFrogUiEntrypointTemplate(htmxCdn: htmxCdn));
    }

    // Routes
    await writer.writeFile(
      'routes/_middleware.dart',
      dartFrogMiddlewareTemplate(projectName, htmxCdn: htmxCdn, ui: ui),
    );
    await writer.writeFile('routes/index.dart', dartFrogIndexRouteTemplate(projectName));
    await writer.writeFile('routes/about.dart', dartFrogAboutRouteTemplate(projectName));
    await writer.writeFile('routes/counter/increment.dart', dartFrogIncrementRouteTemplate(projectName));
    await writer.writeFile('routes/counter/decrement.dart', dartFrogDecrementRouteTemplate(projectName));
    await writer.writeFile('routes/counter/reset.dart', dartFrogResetRouteTemplate(projectName));
    await writer.writeFile('lib/counter_state.dart', dartFrogCounterStateTemplate(projectName));

    // Templates
    await writer.writeFile(
      'templates/layouts/base.html',
      dartFrogBaseLayoutTemplate(projectName, htmxCdn: htmxCdn, ui: ui),
    );
    await writer.writeFile('templates/pages/index.html', dartFrogIndexPageTemplate());
    await writer.writeFile('templates/pages/about.html', dartFrogAboutPageTemplate());
    await writer.writeFile('templates/partials/nav.html', dartFrogNavPartialTemplate(ui: ui));

    // Static assets (Dart Frog serves from public/ by default)
    await writer.writeFile('public/styles.css', scaffoldStyles(dartFrogStylesTemplate() + htmxIndicatorCss, ui: ui));
    if (!htmxCdn) {
      await writer.writeFile('public/js/htmx.min.js', htmxSource);
    }
    await writer.writeFile('public/js/csrf.js', csrfScript);
  }
}
