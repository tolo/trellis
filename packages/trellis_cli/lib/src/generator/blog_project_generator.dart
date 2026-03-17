import 'file_writer.dart';
import '../templates/analysis_options_template.dart';
import '../templates/blog/blog_base_layout_template.dart';
import '../templates/blog/blog_content_templates.dart';
import '../templates/blog/blog_home_layout_template.dart';
import '../templates/blog/blog_list_layout_template.dart';
import '../templates/blog/blog_post_layout_template.dart';
import '../templates/blog/blog_pubspec_template.dart';
import '../templates/blog/blog_single_layout_template.dart';
import '../templates/blog/blog_site_config_template.dart';
import '../templates/blog/blog_styles_template.dart';

/// Generates a complete Trellis SSG blog project scaffold.
///
/// Produces a static-site project (no Dart server) that can be built with
/// `trellis build` and previewed with `trellis serve`.
class BlogProjectGenerator {
  /// Creates a generator for a blog project with [projectName], writing files
  /// via [writer].
  BlogProjectGenerator({required this.projectName, required this.writer});

  /// The Dart-valid project name.
  final String projectName;

  /// The file writer used to create project files.
  final FileWriter writer;

  /// Generates all project files.
  ///
  /// Creates 15 files: pubspec.yaml, trellis_site.yaml, 5 layouts, 5 content
  /// files, styles.css, .gitignore, and analysis_options.yaml.
  Future<void> generate() async {
    // Config files
    await writer.writeFile('pubspec.yaml', blogPubspecTemplate(projectName));
    await writer.writeFile('trellis_site.yaml', blogSiteConfigTemplate(projectName));
    await writer.writeFile('.gitignore', blogGitignoreTemplate());
    await writer.writeFile('analysis_options.yaml', analysisOptionsTemplate());

    // Content
    await writer.writeFile('content/_index.md', blogHomeContentTemplate(projectName));
    await writer.writeFile('content/about.md', blogAboutContentTemplate(projectName));
    await writer.writeFile('content/posts/_index.md', blogPostsIndexTemplate());
    await writer.writeFile('content/posts/welcome.md', blogWelcomePostTemplate());
    await writer.writeFile('content/posts/getting-started.md', blogGettingStartedPostTemplate());

    // Layouts
    await writer.writeFile('layouts/base.html', blogBaseLayoutTemplate(projectName));
    await writer.writeFile('layouts/home.html', blogHomeLayoutTemplate());
    await writer.writeFile('layouts/_default/single.html', blogSingleLayoutTemplate());
    await writer.writeFile('layouts/_default/list.html', blogListLayoutTemplate());
    await writer.writeFile('layouts/posts/single.html', blogPostLayoutTemplate());

    // Static assets
    await writer.writeFile('static/styles.css', blogStylesTemplate());
  }
}
