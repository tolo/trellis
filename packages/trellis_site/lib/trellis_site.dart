/// Static site generator for Trellis.
///
/// Provides content discovery, page modelling, and build orchestration for
/// Markdown-based static sites with Hugo-inspired conventions.
library;

export 'src/code_highlighter.dart';
export 'src/content_discovery.dart';
export 'src/feed_generator.dart';
export 'src/front_matter_date.dart';
export 'src/front_matter_parser.dart' hide parseFrontMatterWithTrustedUrls;
export 'src/markdown_renderer.dart';
export 'src/navigation_builder.dart';
export 'src/page.dart' hide renderFrontMatter, setTrustedPageUrls;
export 'src/page_generator.dart' hide generatePagesWithTrustedUrls;
export 'src/paginator.dart';
export 'src/shortcode_processor.dart';
export 'src/search_index_generator.dart';
export 'src/site_config.dart';
export 'src/site_source.dart';
export 'src/sitemap_generator.dart';
export 'src/taxonomy.dart';
export 'src/theme_aware_loader.dart';
export 'src/theme_config.dart';
export 'src/theme_layout_shadowing.dart';
export 'src/theme_manifest.dart';
export 'src/theme_param_merger.dart';
export 'src/theme_sass_compiler.dart'
    show PaletteDefaultMismatch, ThemeEntryCompilation, compileThemeEntry, paletteDefaultMismatches;
export 'src/theme_sass_generator.dart' show SkinMode, ThemeBuildConfig, ThemeSassGenerator, sassVariableName;
export 'src/trellis_site_builder.dart';
export 'src/version.dart';
