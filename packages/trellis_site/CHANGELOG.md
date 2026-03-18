# Changelog

## 0.1.0

- Initial release.
- `ContentDiscovery` — recursive `.md` scanning with Hugo-style URL derivation, `PageKind` detection (home, section, single), and page bundle support.
- `FrontMatterParser` — YAML front matter extraction with draft detection.
- `MarkdownRenderer` — GitHub-flavored Markdown to HTML via `package:markdown`, with summary extraction and table of contents generation.
- `PageGenerator` — layout resolution (front matter > type > section > `_default`), data cascade (site params, global data, section FM, page FM), and HTML output.
- `TrellisSite` — full build orchestration: clean, discover, parse, render, generate, copy static assets.
- `BuildResult` — build outcome with page count, static file count, elapsed time, and warnings.
- `SiteConfig` — `trellis_site.yaml` configuration loading with `title`, `baseUrl`, `description`, directory paths, `taxonomies`, `paginate`, and `params`.
- `TaxonomyCollector` — automatic taxonomy collection from front matter, with virtual listing and term page generation.
- `Paginator` — list page pagination with `PaginationContext` for template injection (`page`, `totalPages`, `hasNext`, `prevUrl`, `nextUrl`).
- `SitemapGenerator` — `sitemap.xml` generation with `<lastmod>` from front matter date or file mtime.
- `ShortcodeProcessor` — pre-Markdown (`{{% name %}}`) and post-Markdown (`<!-- tl:name -->`) shortcode processing, with content shortcode support and template rendering via Trellis fragments.
- Global data files (`data/*.yaml`) available as `${data.*}` in templates.
- Page bundle asset copying to output directory.
- Draft filtering (excluded by default, includable via `includeDrafts` flag).
