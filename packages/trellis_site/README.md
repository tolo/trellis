# trellis_site

Static site generator for [Trellis](https://pub.dev/packages/trellis) -- Markdown content, Trellis templates, Hugo-inspired conventions.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Features

- **Content discovery** -- recursive `.md` scanning with Hugo-style URL derivation and page bundles
- **Front matter** -- YAML metadata (`title`, `date`, `draft`, `tags`, custom fields)
- **Markdown rendering** -- GitHub-flavored Markdown via `package:markdown` (tables, task lists, footnotes, alerts, emoji)
- **Template lookup** -- priority-ordered layout resolution (front matter `layout` > type > section > `_default`)
- **Build orchestration** -- `TrellisSite.build()` runs the full pipeline and returns a `BuildResult`
- **Taxonomies** -- configurable taxonomy collection (`tags`, `categories`, etc.) with virtual listing and term pages
- **Pagination** -- automatic page splitting for section, home, and taxonomy term pages
- **Sitemap** -- `sitemap.xml` generation with `<lastmod>` from front matter or file mtime
- **Feeds** -- Atom `feed.xml`, optional RSS `rss.xml`, and per-section feeds
- **Search index** -- configurable JSON output for client-side search tools
- **Shortcodes** -- reusable content snippets via `{{% name %}}` (pre-Markdown) and `<!-- tl:name -->` (post-Markdown)
- **Data cascade** -- site params, global data files (`data/*.yaml`), section front matter, page front matter
- **Configurable directories** -- override content, layouts, static, data, and output paths
- **Page bundles** -- `index.md` directories with co-located assets copied to output
- **Draft filtering** -- `draft: true` pages excluded by default, includable via flag

## Theme System

Trellis sites can use pre-built themes for complete, customizable designs with zero boilerplate.

Install a theme with the CLI:

```bash
trellis theme add https://github.com/tolo/trellis --theme verdant --ref v0.11.0
```

Then configure in `trellis_site.yaml`:

```yaml
theme: verdant
theme_params:
  skin: dark
  primary_color: "#e11d48"
  nav_links:
    - label: Home
      url: /
    - label: Blog
      url: /posts/
```

All 18 standard params (colors, fonts, layout, nav, social links, feature toggles) are configurable without forking or editing the theme. Sites can also override individual layouts or `tl:define` blocks for deeper customization.

See the [Theme Usage Guide](../../docs/guides/theme-usage.md) and [Standard Params Contract](../../docs/reference/standard-params.md) for full documentation.

## Installation

```yaml
dependencies:
  trellis_site: ^0.1.0
```

## Quick Start

Create a `trellis_site.yaml` in your project root:

```yaml
title: My Site
baseUrl: https://example.com
taxonomies:
  - tags
paginate: 10
```

Build the site programmatically:

```dart
import 'package:trellis_site/trellis_site.dart';

final config = SiteConfig.load('trellis_site.yaml');
final site = TrellisSite(config);
final result = await site.build();
print('Built ${result.pageCount} pages in ${result.elapsed.inMilliseconds}ms');
```

Or use the CLI:

```bash
trellis build
trellis serve
```

## Configuration

`trellis_site.yaml` supports a small set of top-level keys for common setup:

- `title`, `baseUrl`, `description`
- `pathPrefix` for serving the site under a sub-path (see [Path prefix](#path-prefix))
- `contentDir`, `layoutsDir`, `staticDir`, `dataDir`, `outputDir`
- `taxonomies`, `paginate`
- `params` for arbitrary site-level values exposed as `${site.params.*}`
- `feeds` and `search` for generated output artifacts

Paths may be relative to the site root or absolute.

```yaml
title: My Site
baseUrl: https://example.com
pathPrefix: /my-site/
description: Notes about Dart and server-rendered HTML
contentDir: content
layoutsDir: layouts
staticDir: static
dataDir: data
outputDir: output
taxonomies: [tags, categories]
paginate: 10
params:
  author: Tobias
  showReadingTime: true
feeds:
  atom: true
  rss: true
  sections: [posts]
  limit: 20
search:
  enabled: true
  output: search-index.json
  fields: [title, summary, content, tags]
highlight:
  enabled: true
```

### Path prefix

`pathPrefix` serves a site under a sub-path (e.g. GitHub project pages at
`https://user.github.io/my-site/`) instead of a domain root. When set, every
engine-derived internal URL resolves under the prefix -- page links
(`${page.url}`), the section/menu tree, prev/next links, and the search-index
`url` fields -- and `sitemap.xml`/feeds compose `baseUrl` with the prefixed URL
so the prefix appears exactly once (`https://example.com/my-site/posts/intro/`).

The value is normalized: `my-site`, `/my-site`, `my-site/`, and `/my-site/` all
canonicalize to `/my-site/` (leading slash, single trailing slash). `''` and
`/` mean "served at root" -- with no `pathPrefix` (the default), output is
byte-for-byte identical to a root-served build. An un-normalizable value (a
scheme-bearing or protocol-relative URL such as `http://x` or `//host`, or a
non-string) aborts the build with a `SiteConfigException` and writes no output.

`baseUrl` (the canonical absolute origin used by `sitemap.xml`/feeds) and
`pathPrefix` (the sub-path) are orthogonal and compose.

The prefix lives in the emitted **URLs**, not in the on-disk output layout:
files are written at their unprefixed paths (`output/posts/intro/index.html`,
not `output/my-site/posts/intro/index.html`). Deploy by publishing the whole
`output/` directory as the site root — the host mounts it under the prefix
(GitHub Project Pages serves the artifact root at `/<repo>/`), so a `/my-site/`
link resolves to the corresponding unprefixed file. Nesting the output under the
prefix would double-apply it.

**Hand-written links and assets get the prefix automatically** (expected SSG
behavior, like Hugo's `baseURL`): any **root-absolute internal** `href`/`src` in
the emitted HTML — a Markdown link like `[guide](/docs/guide/)`, a theme literal
like `<link href="/css/main.css">`, or a vendored `<script src="/js/app.js">` —
is rewritten to carry the prefix. **Relative links** (`../guide/`) and in-page
anchors (`#section`) are left untouched, so they keep working as-is; absolute/
external URLs and already-prefixed engine URLs are never touched (no double
prefix). Escaped code examples (a `` ```html `` block showing `href="/x"`) are
not rewritten. With no `pathPrefix`, this pass is a no-op. Only `href`/`src` are
rewritten — `srcset` and CSS `url(...)` are not, so use relative or prefix-aware
paths there. You can still use `${site.pathPrefix}` explicitly if you prefer.

`${site.pathPrefix}` in templates and theme layouts holds the normalized prefix
(`/my-site/` when set, empty string when not) so theme authors can prefix
hand-written literal asset and link references the engine cannot rewrite
automatically. Concatenate it onto the literal path in a `tl:href`/`tl:src`
expression:

```html
<link rel="stylesheet" tl:href="${site.pathPrefix} + 'css/main.css'">
<script tl:src="${site.pathPrefix} + 'js/app.js'"></script>
```

With `pathPrefix: /my-site/` these emit `/my-site/css/main.css` and
`/my-site/js/app.js`; with no prefix they stay `css/main.css` and `js/app.js`.
Engine-derived URLs such as `${page.url}` already carry the prefix and need no
concatenation.

## Project Structure

```
my_site/
  trellis_site.yaml       # Site configuration
  content/
    _index.md             # Home page
    about.md              # Single page
    posts/
      _index.md           # Section listing
      hello-world.md      # Post
      my-trip/
        index.md          # Page bundle
        photo.jpg          # Bundle asset (copied alongside page)
  layouts/
    base.html             # Base layout (tl:extends target)
    home.html             # Home page layout
    _default/
      single.html         # Default single page layout
      list.html           # Default list page layout
    posts/
      single.html         # Section-specific single layout
    shortcodes/
      youtube.html        # Shortcode template
  static/
    styles.css            # Copied to output as-is
    main.scss             # Compiled to CSS by trellis_css
  data/
    authors.yaml          # Global data (available as ${data.authors})
  output/                 # Generated site
```

## Content Conventions

| File | URL | Kind | `section` | `sectionPath` |
|------|-----|------|-----------|---------------|
| `content/_index.md` | `/` | home | `` | `` |
| `content/about.md` | `/about/` | single | `` | `` |
| `content/posts/_index.md` | `/posts/` | section | `posts` | `posts` |
| `content/posts/hello.md` | `/posts/hello/` | single | `posts` | `posts` |
| `content/posts/trip/index.md` | `/posts/trip/` | single (bundle) | `posts` | `posts` |
| `content/docs/guides/_index.md` | `/docs/guides/` | section | `docs` | `docs/guides` |
| `content/docs/guides/a.md` | `/docs/guides/a/` | single | `docs` | `docs/guides` |

A nested `_index.md` is a section page for its own level. Its `${pages}` listing contains exactly that level's own pages (e.g. `docs/guides/_index.md` lists `docs/guides/*` and excludes sibling `docs/tutorials/*`).

## Front Matter

YAML front matter is delimited by `---` at the start of a file:

```markdown
---
title: Hello World
date: 2026-03-15
tags: [dart, web]
draft: false
layout: custom
summary: A custom summary for listings.
---

# Hello World

Content here.
```

Standard fields: `title`, `date`, `draft`, `summary`, `layout`, `type`, `weight`, `sitemap`, `feed`, `search`, `menu_title`, `menu_exclude`. Custom fields are available in templates as `${page.fieldName}`.

`menu_title` (string) overrides a page's title in the `${site.menu}` navigation tree; `menu_exclude: true` removes a page from that tree. See [Navigation Menu](#navigation-menu).

## Page Ordering

Within a section, pages are ordered by an integer `weight` front-matter field, then by the default date order:

- **Weighted pages first**, ascending by `weight` (lower `weight` sorts earlier).
- **Ties among equal weights**, and **all unweighted pages**, fall through to the default order: date descending, then URL ascending.
- When **no page in a section declares `weight`**, the order is exactly the default date-descending-then-URL order -- no new tiebreak is introduced (existing blog behavior is byte-for-byte unchanged).

A non-integer or otherwise malformed `weight` (e.g. a quoted string) is **ignored with a build warning** naming the page and the page is treated as unweighted; the build never aborts.

This one ordering rule is applied by a single reusable engine function, `orderedSectionPages(sectionPath, allPages)`, which returns a section's own-level content pages in canonical order. The `${pages}` list, pagination, and every downstream ordering consumer (menu tree, prev/next) route through this same function, so all derived orderings match the `${pages}` listing exactly.

## Navigation Menu

`${site.menu}` is a nested navigation tree mirroring the content section hierarchy, available on **every** page render -- single pages, section listings, the home page, and taxonomy virtual pages alike (not only list pages). Each node is a map with exactly three keys:

```
{ title: String, url: String, children: List<node> }
```

- **Order** -- each section's own-level pages appear in the same canonical (weight-aware) order as `${pages}`; sections nest by `${page.sectionPath}` lineage.
- **Title** follows a 3-tier precedence: `menu_title` front matter → `title` front matter → humanized URL slug (`getting-started` → `Getting Started`). A section folder with no `_index.md` still yields a node titled from its humanized folder name.
- **Exclusion** -- draft pages and pages with `menu_exclude: true` are absent. A section page that opts out drops its own node but hoists its surviving children to the parent. Empty or fully-excluded content yields an empty list (never null).
- **Active trail** -- the tree is built once and shared across renders, so it carries **no** per-node active flag. A theme marks the current page and its ancestor trail by comparing each `node.url` against `${page.url}` at render time.

```html
<nav>
  <ul>
    <li tl:each="item : ${site.menu}">
      <a tl:href="${item.url}" tl:class="${item.url == page.url} ? 'active' : ''" tl:text="${item.title}">Item</a>
      <ul tl:if="${item.children}">
        <li tl:each="child : ${item.children}">
          <a tl:href="${child.url}" tl:text="${child.title}">Child</a>
        </li>
      </ul>
    </li>
  </ul>
</nav>
```

## In-Section Prev/Next

Every **single doc page** exposes `${page.prev}` and `${page.next}` -- references to its immediate neighbors within the page's own section, so a doc can be read straight through in its authored order. Each is a `{url, title}` map:

```
{ url: String, title: String }
```

- **Order** -- neighbors come from the section's own-level pages in the same canonical (weight-aware) order as `${pages}` and `${site.menu}` (via `orderedSectionPages`); there is **no** separate prev/next sort. Weighted sections read in `weight` order, not date order.
- **Own section only** -- neighbors are drawn from the page's own `${page.sectionPath}` level; sibling sub-sections are not chained, and there is no cross-section or whole-site "next article".
- **Boundaries by absence** -- the first page has no `prev`, the last has no `next`, and a single-page section has neither. Absent neighbors are simply not attached (the key is falsy), so a template guards each side with `tl:if` and renders only the links that exist -- never an error or an empty placeholder.
- **Single doc pages only** -- section listings, the home page, and taxonomy pages do **not** receive `${page.prev}`/`${page.next}`; list-page sequencing stays with `${pagination.*}`.

```html
<nav tl:if="${page.prev} or ${page.next}" aria-label="Page navigation">
  <a tl:if="${page.prev}" tl:href="${page.prev.url}" tl:text="${page.prev.title}">Previous</a>
  <a tl:if="${page.next}" tl:href="${page.next.url}" tl:text="${page.next.title}">Next</a>
</nav>
```

## Breadcrumbs

Every page exposes `${page.breadcrumbs}` -- a structured trail of its ancestor sections, one node per lineage level in shallow-to-deep order, ready to render as a labelled breadcrumb. Each node is a `{url, title}` map:

```
{ url: String, title: String }
```

- **Titles** -- each node's `title` uses the same 3-tier fallback as `${site.menu}`: the section `_index.md`'s `menu_title`, then its `title`, then the humanized folder segment (e.g. `Guides`, never the raw `docs/guides` path).
- **URLs** -- `url` is the section's own (path-prefix-aware) URL, matching the shape of `${site.menu}` section nodes. A folder with no `_index.md` yields an empty `url` (nothing to link to) while still contributing a humanized title.
- **Ordering** -- nodes mirror `${page.ancestors}`: for `docs/guides`, `[{docs}, {docs/guides}]`. Root pages have an empty list.
- **Additive** -- `${page.ancestors}` (the cumulative *path* list) is unchanged; `${page.breadcrumbs}` is the labelled, linkable companion.

```html
<nav tl:if="${page.breadcrumbs}" aria-label="Breadcrumb">
  <a href="/">Home</a>
  <a tl:each="crumb : ${page.breadcrumbs}" tl:href="${crumb.url}" tl:text="${crumb.title}">Section</a>
</nav>
```

## Template Context

Templates receive a data cascade (lowest to highest priority):

1. **Site params** -- `${site.title}`, `${site.baseUrl}`, `${site.pathPrefix}`, `${site.params.*}`
2. **Global data** -- `${data.filename.*}` from `data/*.yaml`
3. **Section front matter** -- from the section's `_index.md`
4. **Page front matter** -- from the page's own front matter

Additional context variables:

- `${page.*}` -- page metadata (`url`, `content`, `summary`, `toc`, `section`, `sectionPath`, `ancestors`, `kind`)
  - `${page.section}` is the **top-level** folder (e.g. `docs`) -- unchanged for nested pages.
  - `${page.sectionPath}` is the **full nested lineage** (e.g. `docs/guides`); empty for root pages.
  - `${page.ancestors}` is the cumulative lineage list (e.g. `['docs', 'docs/guides']`); empty for root pages.
  - `${page.breadcrumbs}` is the structured breadcrumb trail (`{url, title}` nodes, one per ancestor section); empty for root pages. See [Breadcrumbs](#breadcrumbs).
  - `${page.prev}` / `${page.next}` -- immediate in-section neighbors (`{url, title}`) for single doc pages; absent at section boundaries. See [In-Section Prev/Next](#in-section-prevnext).
- `${pages}` -- child pages for list pages (section, home, taxonomy term)
- `${site.menu}` -- nested navigation tree (`{title, url, children}` nodes) available on every page render; see [Navigation Menu](#navigation-menu)
- `${pagination.*}` -- pagination metadata (`page`, `totalPages`, `hasNext`, `prevUrl`, `nextUrl`, `pages`)
- `${taxonomy.*}` -- taxonomy term lists (when taxonomies are configured)
- `${feeds.*}` -- generated site-wide feed URLs (`atom`, `rss`) when feeds are enabled

## Layout Resolution

Templates are resolved in priority order:

1. Front matter `layout` field (e.g. `layout: custom` resolves `custom.html`)
2. Type-specific: `{type}/{single|list}.html`
3. Section-specific: `{section}/{single|list}.html`
4. Default: `_default/{single|list}.html`

Home pages: `home.html` > `index.html` > `_default/list.html`

## Taxonomies

Declare taxonomies in `trellis_site.yaml`:

```yaml
taxonomies:
  - tags
  - categories
```

Pages with matching front matter fields (e.g. `tags: [dart, web]`) are automatically collected. Virtual pages are generated:

- `/{taxonomy}/` -- listing page with all terms (uses `list.html` layout)
- `/{taxonomy}/{slug}/` -- term page with matching pages (uses `single.html` layout)

## Pagination

Enable pagination in `trellis_site.yaml`:

```yaml
paginate: 10
```

List pages (section, home, taxonomy term) are split into chunks. Page 1 uses the base URL; subsequent pages use `/page/{n}/`. Templates access `${pagination.page}`, `${pagination.totalPages}`, `${pagination.hasNext}`, `${pagination.prevUrl}`, `${pagination.nextUrl}`.

## Shortcodes

Reusable content snippets rendered via Trellis fragment templates in `layouts/shortcodes/`.

Pre-Markdown syntax (processed before Markdown rendering):

```markdown
{{% youtube id="dQw4w9WgXcQ" %}}
```

Content shortcodes (with inner content rendered as Markdown):

```markdown
{{% note title="Important" %}}
This is rendered as **Markdown** inside the shortcode.
{{% /note %}}
```

Post-Markdown syntax (processed after Markdown rendering):

```html
<!-- tl:youtube id="dQw4w9WgXcQ" -->
```

## Sitemap

When `baseUrl` is set, `sitemap.xml` is generated automatically. Pages with `sitemap: false` in front matter are excluded. `<lastmod>` uses the `date` front matter field, falling back to file modification time.

## Feeds

Enable feeds in `trellis_site.yaml`:

```yaml
feeds:
  atom: true
  rss: true
  sections: [posts]
  limit: 20
  fullContent: false
```

Generated outputs:

- `feed.xml` -- site-wide Atom feed
- `rss.xml` -- site-wide RSS 2.0 feed when `rss: true`
- `/{section}/feed.xml` and `/{section}/rss.xml` -- per-section feeds when `sections` are configured

Templates can link to site-wide feeds via `${feeds.atom}` and `${feeds.rss}` when available. Pages with `feed: false` in front matter are excluded.

## Syntax Highlighting

Fenced Markdown code blocks are highlighted at **build time** (ADR-010): the
generated HTML carries highlight.js-style `.hljs-*` token spans and ships **no**
client-side highlighter JavaScript. Highlighting is **on by default**; set
`enabled: false` to emit plain `<pre><code>` instead:

```yaml
highlight:
  enabled: true   # default -- set false to disable
```

Only an explicit `enabled: false` turns it off; any other value leaves it on.
`highlight:` must be a map -- a bare scalar such as `highlight: false` is
ignored (highlighting stays on); disable it with `highlight:` plus
`enabled: false`.
Unknown or unspecified code-block languages are left unhighlighted (plain
`<pre><code>`). Token colors come from the active theme's `.hljs-*` CSS.

Migration: the old per-theme `syntax_highlighting` param is retired and is now
ignored -- highlighting is controlled here via `highlight:`, not per theme.

## Search Index

Generate a JSON search index for client-side search:

```yaml
search:
  enabled: true
  output: search-index.json
  fields: [title, summary, content, tags]
  excludeSections: [drafts, internal]
  stripHtml: true
  maxContentLength: 5000
```

This writes a JSON array to the output directory, suitable for tools such as
Fuse.js or Lunr.js. Draft pages and pages with `search: false` in front matter
are excluded.

## API Documentation

- https://pub.dev/documentation/trellis_site/latest/

## License

See the [Trellis repository](https://github.com/tolo/trellis) for license information.
