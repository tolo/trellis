# Changelog

## 0.11.0

### Added

- **Lattice theme and Lattice-powered Trellis site** – a reusable garden-inspired documentation theme now powers the
  redesigned project site, including its content-driven landing page and complete documentation navigation.
- **Generated themes gallery** – the site inventory is generated deterministically from every installed theme manifest,
  with prefix-relative metadata and site-owned copies of each available declared light and dark screenshot.
- **Folio theme** – a bookish documentation and reference theme with semantic figures, captions, and sidenotes.
- **Meadow theme** – a product-landing theme with content-driven marketing sections and resilient card/copy layouts.

### Changed

- **Date-only front matter is resolved as UTC midnight** (TD-014). `date: 2026-01-01` previously parsed as *local*
  midnight, so `feed.xml` `<updated>` and `rss.xml` `<pubDate>` depended on the build machine's timezone – the same
  content emitted `2025-12-31T23:00:00Z` on a CET laptop and `2026-01-01T00:00:00Z` on a UTC runner. Feed timestamps
  are now identical on every machine. Values that carry a time are unchanged: an explicit offset is honoured, a
  zone-less time is still read as local. Sites that relied on the local-time reading see their feed timestamps shift by
  their UTC offset; write a zone-explicit `date:` to pin an exact instant. `sitemap.xml` `<lastmod>` is a calendar date
  and is unchanged.

### Documentation

- Theme authoring now documents theme `data/*.yaml` fallback, site whole-file precedence by filename stem,
  `${data.<stem>.*}` access, and optional theme-specific `excerpt_length` without changing the 18 standard params.

## 0.10.2

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.10.1

### Fixed

- Build time no longer grows quadratically with the number of pages in a single section. `${page.prev}`/`${page.next}` resolution re-sorted the whole section for every page it rendered, so a flat blog with thousands of posts in one section slowed sharply (a 4000-post section spent ~8 s on neighbour resolution alone; 2000 posts ~1.9 s). The section ordering is now computed once per build pass. A full build of a 2000-post flat blog now spends ~350 ms in total page generation. Sites with pages spread across many sections were barely affected and see no change.

### Added

- `benchmark/site_scale_benchmark.dart` – a scale benchmark for the page-generation hot paths, run by hand when touching `orderedSectionPages`, prev/next resolution, or `NavigationBuilder`. Reports growth ratios across site sizes so superlinear behaviour is visible, includes the flat single-section worst case, and times a full `generateAll` on that worst case so the memoized path is measured where it lives.

## 0.10.0

### Added

- **Per-page taxonomy term links (`${page.termLinks.<taxonomy>}`)**: every content page now exposes its *own* front-matter terms, per declared taxonomy, as a list of `{name, slug, url, count}` maps whose `url` is the canonical slugified term-page path (`/tags/hello-world/`) resolved from the same index that generates the term pages. Themes link tags via `${tag.url}` instead of string-building `/{taxonomy}/{rawTerm}/`. The key is present only when the taxonomy is declared and the page has terms, so templates not reading it are byte-for-byte unchanged; `${taxonomy.<name>}` remains the site-global term list.
- **Build-time syntax highlighting (ADR-010)**: fenced Markdown code blocks are highlighted at build time by a new `CodeHighlighter` (backed by `package:highlight`), which emits highlight.js-style `.hljs-*` token spans directly into the built HTML — no client-side highlighter JS is shipped or fetched. Controlled by a new top-level `highlight:` key in `trellis_site.yaml`, **on by default**; set `enabled: false` under it to fall back to plain `<pre><code>`. Unknown or unspecified languages are left unhighlighted.

### Changed

- **Syntax-highlighting token CSS migrated from Prism `.token.*` to `.hljs-*`** (ADR-010) across the official themes, to match the new build-time output. The per-theme **`syntax_highlighting` param is retired** — highlighting is now controlled site-side via the `highlight:` config key, not per theme. Migration: replace `theme_params: { syntax_highlighting: false }` with `highlight: { enabled: false }` in `trellis_site.yaml`; the old param is now ignored with an `Unknown theme param` warning.

### Fixed

- **Theme SASS bridge hardening** (follow-up review of the 0.9.1 fix): string params are now emitted via SASS interpolation (`#{"..."}`) instead of the deprecated global `unquote()` (removed in Dart Sass 3.0.0), eliminating the `global-builtin` deprecation warnings 0.9.1 introduced. A SASS interpolation marker (`#{...}`) in a param value is neutralized to literal text — never evaluated — across **every** emit path: string values, the hex-color fast-path (now gated on a real hex pattern rather than string length, so an interpolation-shaped value like `#{9}` can no longer slip through raw and be evaluated), `color`-typed values, and map keys. Multiline (newline-containing) param values no longer abort the SASS compile (escaped as CSS `\a`). (Structural characters `;{}` in a value remain a separate, tracked robustness limitation — see TD-011.)
- **Verdant `_default/single.html` tag pills broke the build for any tagged post.** The pills built each tag URL as `@{/tags/{tag}/}` — invalid Trellis URL-expression syntax (`@{...}` supports query params, not `{path}` templating) — so rendering a post with `show_tags` on threw an `ExpressionException` and aborted the build. Even had it parsed, interpolating the raw tag produced `/tags/Hello World/` while the term page lives at the slugified `/tags/hello-world/` — a 404 for any tag with uppercase, spaces, or punctuation. Pills now iterate `${page.termLinks.tags}` and link via each term's canonical `url`, matching the generated term page exactly. The bundled `example/` site now declares `taxonomies: [tags]` so its term pages are generated and the pills resolve.
- **Verdant `example/` site was not buildable standalone.** Two problems, both now fixed to match the working `arbor` example: (1) `theme: ..` never resolved — theme resolution joins `<siteDir>/themes/<value>`, so `..` pointed at the example dir, not the theme; the example now ships a git-tracked `themes/verdant → ../..` symlink and sets `theme: verdant`. (2) The example's `home.html` override wrapped an already-complete page URL in a `@{...}` URL expression (`@{${p.url}}`), a parse error; it now links via `${p.url}` like the theme's own layout. `trellis build` on `themes/verdant/example` is green (8 pages, 0 broken links).

## 0.9.1

### Fixed

- **Theme SASS bridge: string params compiled into invalid quoted CSS values.** String-typed theme params (`font_family`, `max_width`, ...) were written to the generated `_theme_params.scss` as quoted SASS strings; the bridge loads before the theme's `_variables.scss`, so the quoted value won and compiled into invalid CSS (`font-family: "system-ui, ..."` — ignored by browsers, falling back to serif; `max-width: "1200px"` — dropped, unconstraining the layout). Affected every theme built with a params bridge (arbor and verdant alike). The generator now emits values via `unquote()` with escaping for embedded quotes/backslashes.

## 0.9.0

### Added

- **URL path-prefix (`pathPrefix`)**: serve a site under a sub-path (e.g. GitHub project pages at `/my-site/`) via a new `pathPrefix` config key. When set, every engine-derived internal URL -- page links (`${page.url}`), the section/menu tree, prev/next, and search-index `url` fields -- resolves under the prefix, and `sitemap.xml`/feeds compose `baseUrl` with the prefixed URL so the prefix appears exactly once. The value normalizes leading/trailing slashes to a canonical `/x/` form (`my-site`, `/my-site`, `my-site/`, `/my-site/` all → `/my-site/`); `''` and `/` mean root-served. Absolute/external URLs are left untouched. An un-normalizable value (scheme-bearing/protocol-relative URL, non-string, whitespace or `:` anywhere, a `.`/`..` path segment, or an empty interior segment such as `a//b`) aborts the build with a `SiteConfigException` and writes no output. With no `pathPrefix` (the default) output is byte-for-byte unchanged. The normalized prefix is exposed to templates as `${site.pathPrefix}` so theme authors can prefix hand-written literal asset references, e.g. `tl:href="${site.pathPrefix} + 'css/main.css'"`. The prefix lives in emitted URLs only, not in the on-disk output layout — files are written at their unprefixed paths so the whole `output/` tree can be published as the site root and mounted under the prefix by the host (e.g. GitHub Project Pages). Hand-written root-absolute internal links and asset references in the emitted HTML (Markdown content links, theme literals, `<script src>`/`<link href>`) are automatically rewritten to carry the prefix (expected SSG behavior); relative links, in-page anchors, external URLs, escaped code examples, and already-prefixed engine URLs are left untouched.
- **Weighted page ordering**: pages may declare an integer `weight` front-matter field; within a section, weighted pages sort first by ascending `weight`, then ties and all unweighted pages fall through to the existing date-descending-then-URL order. Sections with no `weight` are byte-for-byte unchanged. A malformed `weight` (non-integer) is ignored with a build warning naming the page and treated as unweighted; the build never aborts.
- **Nested-section lineage**: new additive `Page.sectionPath` field exposes a page's full nested section lineage (e.g. `docs/guides`), available in templates as `${page.sectionPath}` (string) and `${page.ancestors}` (cumulative list). `${page.section}` is unchanged and remains the top-level folder.
- A nested `_index.md` section listing now contains exactly its own-level pages and excludes sibling sub-sections' pages.
- `orderedSectionPages(sectionPath, allPages)` -- a reusable engine function returning a section's own-level content pages in canonical (weight-aware) order. The `${pages}` listing, pagination, and downstream ordering consumers route through this single function.
- **Hierarchical navigation menu (`${site.menu}`)**: a nested navigation tree mirroring the content section hierarchy, available to **every** page render (single, section, home, and taxonomy virtual pages -- not only list pages). Each node is a `{title, url, children}` map; own-level pages within a section are ordered via `orderedSectionPages` (same canonical weight-aware order as `${pages}`), and sections nest by `Page.sectionPath` lineage. The tree carries **no** per-page active flag -- it is built once and shared across renders, so a theme marks the active page and its ancestor trail at render time by comparing each `node.url` against `${page.url}`. A node's `title` follows a 3-tier precedence: `menu_title` front matter → `title` front matter → humanized URL slug (`getting-started` → `Getting Started`). Sibling **section** nodes are ordered by their section page's (`_index.md`) `weight` (ascending, weighted before unweighted), then lexically — so a docs IA can order its sections deliberately; with no section weights the order is the previous pure-lexical order (backward-compatible). Draft pages and pages with `menu_exclude: true` are excluded (a section that opts out drops its own node but hoists surviving children to its parent; a folder with no `_index.md` still yields a synthesized node titled from the humanized folder name). Empty or fully-excluded content yields an empty list (never null). Sites whose templates do not reference `${site.menu}` are byte-for-byte unchanged.
- **Front-matter keys `menu_title` (string) and `menu_exclude` (bool)**: control a page's `${site.menu}` node title and inclusion.
- **In-section prev/next (`${page.prev}` / `${page.next}`)**: every single doc page exposes references to its immediate neighbors within its own section, each a `{url, title}` map, so a doc reads straight through in its authored order. Neighbors follow the section's canonical (weight-aware) order via `orderedSectionPages` -- the same ordering as `${pages}` and `${site.menu}`, with no separate prev/next sort (weighted sections read in `weight` order, not date order). Boundaries are handled by absence: the first page has no `prev`, the last has no `next`, and a single-page section has neither, so a `tl:if`-guarded region renders only the links that exist. Only single doc pages receive these keys; section, home, and taxonomy pages do not (list-page sequencing stays with `${pagination.*}`). Neighbor `title` uses the same 3-tier fallback as `${site.menu}` (`menu_title` → `title` → humanized URL segment), so a titleless neighbor still renders a readable label. Sites whose templates do not reference `${page.prev}`/`${page.next}` are byte-for-byte unchanged.
- **Structured breadcrumbs (`${page.breadcrumbs}`)**: every page exposes a structured breadcrumb trail -- one `{url, title}` node per ancestor section, shallow-to-deep (mirroring `${page.ancestors}`). Titles use the `${site.menu}` 3-tier fallback (`menu_title` → `title` → humanized folder segment) so labels read like the menu (`Guides`, not `docs/guides`); URLs are the section's own path-prefix-aware URL (empty for a folder with no `_index.md`). Additive to the unchanged `${page.ancestors}` cumulative-path list.

### Fixed

- **Relative `theme:` paths now resolve.** A `theme:` value that escapes the site directory (e.g. `theme: ../../themes/arbor`, used when a site references a repo-root theme) is now normalized so both the manifest loader and the template `FileSystemLoader` resolve a real path. Previously the un-collapsed `..` segments (through a non-existent `<siteDir>/themes` directory) made the template loader throw "base path does not exist". Bare theme names (`theme: verdant`) are unaffected.

## 0.8.2

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

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
