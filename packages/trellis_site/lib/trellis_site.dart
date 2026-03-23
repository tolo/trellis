/// Static site generator for Trellis.
///
/// Provides content discovery, page modelling, and build orchestration for
/// Markdown-based static sites with Hugo-inspired conventions.
library;

export 'src/content_discovery.dart';
export 'src/feed_generator.dart';
export 'src/front_matter_parser.dart';
export 'src/markdown_renderer.dart';
export 'src/page.dart';
export 'src/page_generator.dart';
export 'src/paginator.dart';
export 'src/shortcode_processor.dart';
export 'src/search_index_generator.dart';
export 'src/site_config.dart';
export 'src/sitemap_generator.dart';
export 'src/taxonomy.dart';
export 'src/theme_aware_loader.dart';
export 'src/theme_config.dart';
export 'src/theme_manifest.dart';
export 'src/theme_param_merger.dart';
export 'src/theme_sass_generator.dart';
export 'src/trellis_site_builder.dart';
export 'src/version.dart';
