# Changelog

## 0.8.0

### Changed

- Version aligned to the unified Trellis SDK lockstep versioning scheme — all SDK packages now share a single version number and are released together. No functional changes since 0.2.0.

## 0.2.0

### Added

- **Theme system**: `ThemeManifest`, `ThemeConfig`, and `ThemeParamMerger` for parsing `theme.yaml` manifests and deep-merging theme params with site overrides.
- `ThemeAwareLoader` for site-first, theme-fallback layout resolution with `theme:` prefix support for cross-boundary `tl:extends`.
- `ThemeSassGenerator` for auto-generating `_theme_params.scss` (SASS variables) and `_theme_custom_props.css` (CSS custom properties) from merged theme params.
- `ThemeBuildConfig` and `SkinMode` for SASS bridge configuration and skin file resolution (light, dark, auto).
- Theme static asset merging (theme `static/` copied to output, site `static/` wins on conflict).
- Theme data file merging (theme `data/` as fallback, site `data/` wins per-file).
- `${theme.*}` template context namespace for accessing merged theme params.
- Build warnings for unknown `theme_params:` keys.
- `siteVersion` constant for runtime version identification.

### Changed

- `SiteConfig` extended with `themeConfig` field (parsed from `theme:`, `theme_ref:`, `theme_params:` in `trellis_site.yaml`).
- `BuildResult` extended with optional `ThemeBuildConfig` for CLI SASS compilation.
- `PageGenerator` accepts external `TemplateLoader`, `layoutSearchPaths`, and `themeDataDir` for theme-aware builds.
- SASS load path order: `.trellis/build/` (bridge) → `site/sass/` → `theme/sass/`.

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
