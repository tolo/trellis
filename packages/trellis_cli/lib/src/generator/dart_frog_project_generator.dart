import 'file_writer.dart';
import '../templates/analysis_options_template.dart';
import '../templates/dart_frog/dart_frog_base_layout_template.dart';
import '../templates/dart_frog/dart_frog_config_template.dart';
import '../templates/dart_frog/dart_frog_index_page_template.dart';
import '../templates/dart_frog/dart_frog_index_route_template.dart';
import '../templates/dart_frog/dart_frog_middleware_template.dart';
import '../templates/dart_frog/dart_frog_nav_partial_template.dart';
import '../templates/dart_frog/dart_frog_pubspec_template.dart';
import '../templates/dart_frog/dart_frog_styles_template.dart';
import '../templates/dart_frog/dart_frog_todo_partial_template.dart';
import '../templates/dart_frog/dart_frog_todo_route_template.dart';

/// Generates a complete Dart Frog + Trellis + HTMX project scaffold.
///
/// Produces a runnable server project demonstrating file-based routing,
/// `trellis_dart_frog` provider/middleware, template inheritance, and HTMX
/// fragment interactions (todo example with add, complete, and delete).
class DartFrogProjectGenerator {
  /// Creates a generator for a Dart Frog project with [projectName], writing
  /// files via [writer].
  DartFrogProjectGenerator({required this.projectName, required this.writer});

  /// The Dart-valid project name.
  final String projectName;

  /// The file writer used to create project files.
  final FileWriter writer;

  /// Generates all project files.
  ///
  /// Creates 12 files: pubspec.yaml, dart_frog.yaml, analysis_options.yaml,
  /// .gitignore, 2 route handlers, 3 HTML templates, 1 nav partial,
  /// 1 todo partial, and styles.css.
  Future<void> generate() async {
    // Config files
    await writer.writeFile('pubspec.yaml', dartFrogPubspecTemplate(projectName));
    await writer.writeFile('dart_frog.yaml', dartFrogConfigTemplate(projectName));
    await writer.writeFile('.gitignore', dartFrogGitignoreTemplate());
    await writer.writeFile('analysis_options.yaml', analysisOptionsTemplate());

    // Routes
    await writer.writeFile('routes/_middleware.dart', dartFrogMiddlewareTemplate(projectName));
    await writer.writeFile('routes/index.dart', dartFrogIndexRouteTemplate(projectName));
    await writer.writeFile('routes/todos/index.dart', dartFrogTodoRouteTemplate());

    // Templates
    await writer.writeFile('templates/layouts/base.html', dartFrogBaseLayoutTemplate(projectName));
    await writer.writeFile('templates/pages/index.html', dartFrogIndexPageTemplate());
    await writer.writeFile('templates/partials/nav.html', dartFrogNavPartialTemplate());
    await writer.writeFile('templates/partials/todo_list.html', dartFrogTodoPartialTemplate());

    // Static assets (Dart Frog serves from public/ by default)
    await writer.writeFile('public/styles.css', dartFrogStylesTemplate());
  }
}
