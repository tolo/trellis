/// Static site generator for Trellis.
///
/// Provides content discovery, page modelling, and build orchestration for
/// Markdown-based static sites with Hugo-inspired conventions.
library;

export 'src/content_discovery.dart';
export 'src/front_matter_parser.dart';
export 'src/markdown_renderer.dart';
export 'src/page.dart';
export 'src/page_generator.dart';
export 'src/paginator.dart';
export 'src/shortcode_processor.dart';
export 'src/site_config.dart';
export 'src/sitemap_generator.dart';
export 'src/taxonomy.dart';
export 'src/trellis_site_builder.dart';
