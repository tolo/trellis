# Changelog

## 0.1.0

### Added

- `ContentDiscovery` for recursive Markdown scanning, page-bundle support, and Hugo-style URL derivation.
- `FrontMatterParser` for YAML front matter extraction and validation.
- `MarkdownRenderer` for GitHub-flavored Markdown, summary extraction, and table-of-contents generation.
- `PageGenerator` for layout resolution, data cascade assembly, and page rendering.
- `TrellisSite` for full build orchestration across content, layouts, data, static assets, and output.
- `BuildResult` and `BuildWarning` for build reporting.
- `SiteConfig` for `trellis_site.yaml` loading with configurable content, layouts, static, data, and output directories.
- `TaxonomyCollector` and `Paginator` for section, taxonomy, and list-page generation.
- `ShortcodeProcessor` for pre-Markdown and post-Markdown shortcodes rendered through Trellis templates.

### Generated Output

- `SitemapGenerator` for `sitemap.xml`.
- `FeedGenerator`, `FeedConfig`, and `FeedResult` for Atom, RSS, and per-section feeds.
- `SearchIndexGenerator` and `SearchConfig` for JSON search indexes compatible with client-side search tools.

### Content Features

- Global data file loading from `data/*.yaml`.
- Draft filtering, page bundle asset copying, and site-level params exposed to templates.
