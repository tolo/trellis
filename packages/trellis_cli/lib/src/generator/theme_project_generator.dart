import 'file_writer.dart';
import '../templates/theme/theme_base_layout_template.dart';
import '../templates/theme/theme_dark_skin_template.dart';
import '../templates/theme/theme_example_config_template.dart';
import '../templates/theme/theme_example_content_template.dart';
import '../templates/theme/theme_example_layout_template.dart';
import '../templates/theme/theme_gitignore_template.dart';
import '../templates/theme/theme_home_layout_template.dart';
import '../templates/theme/theme_light_skin_template.dart';
import '../templates/theme/theme_list_layout_template.dart';
import '../templates/theme/theme_main_scss_template.dart';
import '../templates/theme/theme_manifest_template.dart';
import '../templates/theme/theme_readme_template.dart';
import '../templates/theme/theme_single_layout_template.dart';
import '../templates/theme/theme_variables_template.dart';

/// Generates a Trellis theme project scaffold.
///
/// Produces a theme skeleton with theme.yaml, layouts with tl:define blocks,
/// SASS with !default variables and skin presets, and an example site for
/// previewing during development.
class ThemeProjectGenerator {
  /// Creates a generator for a theme project with [projectName], writing files
  /// via [writer].
  ThemeProjectGenerator({required this.projectName, required this.writer});

  /// The theme project name.
  final String projectName;

  /// The file writer used to create project files.
  final FileWriter writer;

  /// Generates all theme project files (15 total).
  ///
  /// Creates: theme.yaml, 4 layouts, 4 SASS files, static/.gitkeep,
  /// 3 example files, README.md, and .gitignore.
  Future<void> generate() async {
    // Theme manifest
    await writer.writeFile('theme.yaml', themeManifestTemplate(projectName));

    // Layouts
    await writer.writeFile('layouts/base.html', themeBaseLayoutTemplate(projectName));
    await writer.writeFile('layouts/_default/single.html', themeSingleLayoutTemplate());
    await writer.writeFile('layouts/_default/list.html', themeListLayoutTemplate());
    await writer.writeFile('layouts/home.html', themeHomeLayoutTemplate());

    // SASS
    await writer.writeFile('sass/_variables.scss', themeVariablesTemplate());
    await writer.writeFile('sass/_skins/_light.scss', themeLightSkinTemplate());
    await writer.writeFile('sass/_skins/_dark.scss', themeDarkSkinTemplate());
    await writer.writeFile('sass/main.scss', themeMainScssTemplate());

    // Static placeholder
    await writer.writeFile('static/.gitkeep', '');

    // Example site
    await writer.writeFile('example/trellis_site.yaml', themeExampleConfigTemplate(projectName));
    await writer.writeFile('example/content/_index.md', themeExampleContentTemplate());
    await writer.writeFile('example/layouts/home.html', themeExampleLayoutTemplate());

    // Project files
    await writer.writeFile('README.md', themeReadmeTemplate(projectName));
    await writer.writeFile('.gitignore', themeGitignoreTemplate());
  }
}
