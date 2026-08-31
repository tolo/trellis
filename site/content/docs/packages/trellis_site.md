---
title: trellis_site
description: The Trellis static site generator – Markdown content, layouts, taxonomies, pagination, feeds, navigation, and search index.
weight: 50
---

`trellis_site` is the static site generator built on the
[Trellis engine](/docs/packages/trellis/): Markdown content, Trellis HTML
layouts, and Hugo-inspired conventions. It scans your content, renders each page
through a layout, and writes a complete static site.

This guide is a tour of the SSG's features. For a gentle introduction to
templates themselves, read [Getting Started](/docs/getting-started/) and the
[Syntax Reference](/docs/syntax/) first. To build and preview a site from the
command line, use [trellis_cli](/docs/packages/trellis_cli/); to apply a
pre-built design, see [Theme Authoring](/docs/themes/authoring/).

## Features

- **Content discovery** – recursive `.md` scanning with Hugo-style URL
  derivation and page bundles.
- **Front matter** – YAML metadata (`title`, `date`, `draft`, `tags`, and custom
  fields).
- **Markdown rendering** – GitHub-flavored Markdown via `package:markdown`
  (tables, task lists, footnotes, alerts, emoji).
- **Template lookup** – priority-ordered layout resolution (front-matter
  `layout` > type > section > `_default`).
- **Taxonomies** – configurable collections (`tags`, `categories`, etc.) with
  virtual listing and term pages.
- **Pagination** – automatic page splitting for section, home, and taxonomy
  term pages.
- **Sitemap** – `sitemap.xml` with `<lastmod>` from front matter or file mtime.
- **Feeds** – Atom `feed.xml`, optional RSS `rss.xml`, and per-section feeds.
- **Search index** – configurable JSON output for client-side search tools.
- **Shortcodes** – reusable content snippets via `{{% name %}}` (pre-Markdown)
  and `<!-- tl:name -->` (post-Markdown).
- **Data cascade** – site params, global data files, section front matter, and
  page front matter.
- **Page bundles** – `index.md` directories with co-located assets copied to
  output.
- **Draft filtering** – `draft: true` pages excluded by default, includable via
  a flag.

## Installation

```yaml
dependencies:
  trellis_site: ^0.1.0
```

## Quick start

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

Or use the [trellis_cli](/docs/packages/trellis_cli/):

```bash
trellis build
trellis serve
```

## Configuration

`trellis_site.yaml` supports a small set of top-level keys:

- `title`, `baseUrl`, `description`
- `pathPrefix` for serving under a sub-path (see [Path prefix](#path-prefix))
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
engine-derived internal URL resolves under the prefix – page links
(`${page.url}`), the section/menu tree, prev/next links, and the search-index
`url` fields – and `sitemap.xml`/feeds compose `baseUrl` with the prefixed URL
so the prefix appears exactly once
(`https://example.com/my-site/posts/intro/`).

The value is normalized: `my-site`, `/my-site`, `my-site/`, and `/my-site/` all
canonicalize to `/my-site/` (leading slash, single trailing slash). `''` and
`/` mean "served at root". `baseUrl` (the canonical absolute origin used by
`sitemap.xml`/feeds) and `pathPrefix` (the sub-path) are orthogonal and compose.

The prefix lives in the emitted **URLs**, not in the on-disk layout: files are
written at their unprefixed paths (`output/posts/intro/index.html`). Deploy by
publishing the whole `output/` directory as the site root; the host mounts it
under the prefix.

**Hand-written links and assets get the prefix automatically.** Any
root-absolute internal `href`/`src` in the emitted HTML – a Markdown link like
`[guide](/my-page/)`, a theme literal like `<link href="/css/main.css">`, or
a `<script src="/js/app.js">` – is rewritten to carry the prefix. Relative links
(`../guide/`) and in-page anchors (`#section`) are left untouched; absolute or
external URLs and already-prefixed engine URLs are never touched. Escaped code
examples are not rewritten. Only `href`/`src` are rewritten – `srcset` and CSS
`url(...)` are not, so use relative or prefix-aware paths there.

`${site.pathPrefix}` in templates holds the normalized prefix (`/my-site/` when
set, empty string when not) so theme authors can prefix literal references the
engine cannot rewrite:

```html
<link rel="stylesheet" tl:href="${site.pathPrefix} + 'css/main.css'">
<script tl:src="${site.pathPrefix} + 'js/app.js'"></script>
```

## Project structure

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
        photo.jpg         # Bundle asset (copied alongside page)
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

## Content conventions

| File | URL | Kind | `section` | `sectionPath` |
|------|-----|------|-----------|---------------|
| `content/_index.md` | `/` | home | `` | `` |
| `content/about.md` | `/about/` | single | `` | `` |
| `content/posts/_index.md` | `/posts/` | section | `posts` | `posts` |
| `content/posts/hello.md` | `/posts/hello/` | single | `posts` | `posts` |
| `content/posts/trip/index.md` | `/posts/trip/` | single (bundle) | `posts` | `posts` |
| `content/docs/guides/_index.md` | `/docs/guides/` | section | `docs` | `docs/guides` |
| `content/docs/guides/a.md` | `/docs/guides/a/` | single | `docs` | `docs/guides` |

A nested `_index.md` is a section page for its own level. Its `${pages}` listing
contains exactly that level's own pages (e.g. `docs/guides/_index.md` lists
`docs/guides/*` and excludes sibling `docs/tutorials/*`).

## Front matter

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

Standard fields: `title`, `date`, `draft`, `summary`, `layout`, `type`,
`weight`, `sitemap`, `feed`, `search`, `menu_title`, `menu_exclude`. Custom
fields are available in templates as `${page.fieldName}`.

`menu_title` (string) overrides a page's title in the `${site.menu}` navigation
tree; `menu_exclude: true` removes a page from that tree.

### Dates and time zones

A date-only `date:` (`2026-03-15`) names a calendar day, not an instant, so
`feed.xml` and `rss.xml` anchor it at **UTC midnight**. A zone-less date-time
(`2026-03-15T09:30:00`) likewise names UTC calendar fields. That keeps feeds and
`sitemap.xml` `<lastmod>` identical no matter which machine runs the build.

A `date:` with `Z` or a numeric offset is read as that exact instant. Use one when
the timestamp is authored in a timezone other than UTC:

```yaml
date: 2026-03-15T09:30:00Z        # explicit UTC
date: 2026-03-15T09:30:00+02:00   # explicit offset
date: 2026-03-15T09:30:00         # no zone - treated as UTC calendar fields
```

## Page ordering

Within a section, pages are ordered by an integer `weight` front-matter field,
then by the default date order:

- **Weighted pages first**, ascending by `weight` (lower `weight` sorts earlier).
- **Ties among equal weights**, and **all unweighted pages**, fall through to the
  default order: date descending, then URL ascending.
- When **no page in a section declares `weight`**, the order is exactly the
  default date-descending-then-URL order.

A malformed `weight` (e.g. a quoted string) is ignored with a build warning and
the page is treated as unweighted; the build never aborts.

One reusable engine function, `orderedSectionPages(sectionPath, allPages)`,
applies this rule. The `${pages}` list, pagination, and every downstream
ordering consumer (menu tree, prev/next) route through it, so all derived
orderings match the `${pages}` listing exactly.

## Navigation menu

`${site.menu}` is a nested navigation tree mirroring the content section
hierarchy, available on **every** page render. Each node is a map with exactly
three keys:

```
{ title: String, url: String, children: List<node> }
```

- **Order** – each section's own-level pages appear in the same canonical
  (weight-aware) order as `${pages}`; sections nest by `${page.sectionPath}`
  lineage.
- **Title** follows a 3-tier precedence: `menu_title` front matter → `title`
  front matter → humanized URL slug (`getting-started` → `Getting Started`).
- **Exclusion** – draft pages and pages with `menu_exclude: true` are absent. A
  section page that opts out drops its own node but hoists its surviving children
  to the parent.
- **Active trail** – the tree is built once and shared across renders, so it
  carries no per-node active flag. A theme marks the current page by comparing
  each `node.url` against `${page.url}` at render time.

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

## In-section prev/next

Every single doc page exposes `${page.prev}` and `${page.next}` – references to
its immediate neighbors within the page's own section, so a doc can be read
straight through in its authored order. Each is a `{url, title}` map.

- **Order** – neighbors come from the section's own-level pages in the same
  canonical order as `${pages}` and `${site.menu}`. Weighted sections read in
  `weight` order, not date order.
- **Own section only** – neighbors are drawn from the page's own
  `${page.sectionPath}` level; sibling sub-sections are not chained.
- **Boundaries by absence** – the first page has no `prev`, the last has no
  `next`, and a single-page section has neither.
- **Single doc pages only** – section listings, the home page, and taxonomy
  pages do not receive prev/next; list-page sequencing stays with
  `${pagination.*}`.

```html
<nav tl:if="${page.prev} or ${page.next}" aria-label="Page navigation">
  <a tl:if="${page.prev}" tl:href="${page.prev.url}" tl:text="${page.prev.title}">Previous</a>
  <a tl:if="${page.next}" tl:href="${page.next.url}" tl:text="${page.next.title}">Next</a>
</nav>
```

## Template context

Templates receive a data cascade (lowest to highest priority):

1. **Site params** – `${site.title}`, `${site.baseUrl}`, `${site.pathPrefix}`,
   `${site.params.*}`
2. **Global data** – `${data.filename.*}` from `data/*.yaml`
3. **Section front matter** – from the section's `_index.md`
4. **Page front matter** – from the page's own front matter

Additional context variables:

- `${page.*}` – page metadata (`url`, `content`, `summary`, `toc`, `section`,
  `sectionPath`, `ancestors`, `kind`, and `prev`/`next` for single doc pages).
  `${page.section}` is the top-level folder (e.g. `docs`); `${page.sectionPath}`
  is the full nested lineage (e.g. `docs/guides`); `${page.ancestors}` is the
  cumulative lineage list.
- `${pages}` – child pages for list pages (section, home, taxonomy term).
- `${site.menu}` – the nested navigation tree.
- `${pagination.*}` – pagination metadata (`page`, `totalPages`, `hasNext`,
  `prevUrl`, `nextUrl`, `pages`).
- `${taxonomy.*}` – taxonomy term lists (when taxonomies are configured).
- `${feeds.*}` – generated site-wide feed URLs (`atom`, `rss`) when enabled.

## Layout resolution

Templates are resolved in priority order:

1. Front-matter `layout` field (e.g. `layout: custom` resolves `custom.html`).
2. Type-specific: `{type}/{single|list}.html`.
3. Section-specific: `{section}/{single|list}.html`.
4. Default: `_default/{single|list}.html`.

Home pages: `home.html` > `index.html` > `_default/list.html`.

## Taxonomies

Declare taxonomies in `trellis_site.yaml`:

```yaml
taxonomies:
  - tags
  - categories
```

Pages with matching front-matter fields (e.g. `tags: [dart, web]`) are collected
automatically. Virtual pages are generated:

- `/{taxonomy}/` – a listing page with all terms (uses `list.html`).
- `/{taxonomy}/{slug}/` – a term page with matching pages (uses `single.html`).

## Pagination

```yaml
paginate: 10
```

List pages (section, home, taxonomy term) are split into chunks. Page 1 uses the
base URL; subsequent pages use `/page/{n}/`. Templates access
`${pagination.page}`, `${pagination.totalPages}`, `${pagination.hasNext}`,
`${pagination.prevUrl}`, `${pagination.nextUrl}`.

## Shortcodes

Reusable content snippets rendered via Trellis fragment templates in
`layouts/shortcodes/`.

Pre-Markdown syntax (processed before Markdown rendering):

```markdown
{{% youtube id="dQw4w9WgXcQ" %}}
```

Content shortcodes (inner content rendered as Markdown):

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

When `baseUrl` is set, `sitemap.xml` is generated automatically. Pages with
`sitemap: false` in front matter are excluded. `<lastmod>` uses the `date` front
matter field, falling back to file modification time.

## Feeds

```yaml
feeds:
  atom: true
  rss: true
  sections: [posts]
  limit: 20
  fullContent: false
```

Generated outputs:

- `feed.xml` – site-wide Atom feed.
- `rss.xml` – site-wide RSS 2.0 feed when `rss: true`.
- `/{section}/feed.xml` and `/{section}/rss.xml` – per-section feeds when
  `sections` are configured.

Templates can link to site-wide feeds via `${feeds.atom}` and `${feeds.rss}`.
Pages with `feed: false` in front matter are excluded.

## Syntax highlighting

Fenced Markdown code blocks are highlighted at **build time** (ADR-010): the
generated HTML carries highlight.js-style `.hljs-*` token spans and ships **no**
client-side highlighter JavaScript. Highlighting is **on by default**; set
`enabled: false` to emit plain `<pre><code>` instead:

```yaml
highlight:
  enabled: true   # default – set false to disable
```

Only an explicit `enabled: false` turns it off; any other value leaves it on.
`highlight:` must be a map – a bare scalar such as `highlight: false` is
ignored (highlighting stays on); disable it with `highlight:` plus
`enabled: false`.
Unknown or unspecified code-block languages are left unhighlighted (plain
`<pre><code>`). Token colors come from the active theme's `.hljs-*` CSS.

Migration: the old per-theme `syntax_highlighting` param is retired and is now
ignored – highlighting is controlled here via `highlight:`, not per theme.

## Search index

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

## Themes

Trellis sites can use pre-built themes for complete, customizable designs with
zero boilerplate. Install a theme with the CLI:

```bash
trellis theme add https://github.com/tolo/trellis --theme verdant --ref v0.11.0
```

Then configure it in `trellis_site.yaml`:

```yaml
theme: verdant
theme_params:
  skin: dark
  primary_color: "#e11d48"
```

All standard params (colors, fonts, layout, nav, social links, feature toggles)
are configurable without forking the theme. To build your own theme, see the
[Theme Authoring](/docs/themes/authoring/) guide.
