---
title: trellis_site
description: The Trellis static site generator API and configuration reference.
weight: 50
---

`trellis_site` turns Markdown content and Trellis HTML layouts into a complete
static site. This page is the package reference. For the guided workflow, start
with [Sites Getting Started](/docs/sites/getting-started/).

## Installation

```yaml
dependencies:
  trellis_site: ^0.13.0
```

## Quick start

Create `trellis_site.yaml`:

```yaml
title: My Site
baseUrl: https://example.com
taxonomies: [tags]
paginate: 10
```

Build programmatically:

```dart
import 'package:trellis_site/trellis_site.dart';

final config = SiteConfig.load('trellis_site.yaml');
final site = TrellisSite(config);
final result = await site.build();
print('Built ${result.pageCount} pages in ${result.elapsed.inMilliseconds}ms');
```

Or use [trellis_cli](/docs/packages/trellis_cli/):

```bash
trellis build
trellis serve
```

### SASS and theme CSS

`TrellisSite.build()` renders pages and copies static files, but compiles no
SASS: it skips `.scss` and `.sass` files in `static/` and does not compile a
theme's `sass/` entries. `trellis build` runs `TrellisSite.build()` and then
compiles both, writing `static/<path>.scss` to `<path>.css` and a theme's
`sass/<entry>.scss` to `css/<entry>.css` (partials starting with `_` are
skipped). A programmatic build of a themed site therefore needs its own compile
step, such as `compileThemeEntry` for theme entries and
`TrellisCss.compileSass` from `trellis_css` for site files.

## Project structure

```text
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
    main.scss             # Compiled to main.css by `trellis build`
  data/
    authors.yaml          # Global data (available as ${data.authors})
  output/                 # Generated site
```

## Configuration keys

`trellis_site.yaml` accepts:

- `title`, `baseUrl`, and `description` for site identity;
- `pathPrefix` for a site served below the domain root;
- `contentDir`, `layoutsDir`, `staticDir`, `dataDir`, and `outputDir` for
  filesystem locations;
- `theme`, `theme_params`, and `theme_ref` (the git ref that
  `trellis theme add --ref` pins) for an installed theme;
- `taxonomies` and `paginate` for generated collections;
- `params` for arbitrary values exposed as `${site.params.*}`;
- `feeds`, `search`, and `highlight` for generated discovery artifacts and
  build-time code highlighting.

Paths can be relative to the site root or absolute.

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
  author: Site Author
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

Content organization, ordering, bundles, drafts, dates, and shortcodes are
covered in [Sites: Content](/docs/sites/content/).

Taxonomies, pagination, menus, and previous/next navigation are covered in
[Sites: Layouts](/docs/sites/layouts/).

Sitemaps, Atom/RSS feeds, section feeds, and search indexes are covered in
[Sites: Search and feeds](/docs/sites/search-and-feeds/).

Theme installation and customization are covered in
[Sites: Themes](/docs/sites/themes/). On Windows, a site whose theme lives on a
UNC network path (`\\server\share\…`) is untested and may fail to resolve the
theme entry; use a mapped drive letter.

Fenced code blocks are highlighted at build time; see
[Syntax highlighting](#syntax-highlighting).

## Path prefix

`pathPrefix` mounts the generated site below the domain root, such as GitHub
Project Pages at `https://user.github.io/my-site/`. Values like `my-site`,
`/my-site`, and `/my-site/` normalize to `/my-site/`; `''` and `/` mean the
domain root.

The prefix changes emitted URLs, not disk paths. A page at
`output/posts/intro/index.html` can therefore render a URL such as
`/my-site/posts/intro/`. `baseUrl` remains the absolute origin and composes with
the prefix in the sitemap and feeds.

A value that cannot be normalized (a scheme-bearing or protocol-relative URL
such as `http://x` or `//host`, or a non-string) aborts the build with a
`SiteConfigException` and writes no output. With no `pathPrefix`, output is
byte-for-byte identical to a root-served build.

Deploy by publishing the whole `output/` directory as the site root; the host
mounts it under the prefix (GitHub Project Pages serves the artifact root at
`/<repo>/`). Nesting the output under the prefix would apply it twice.

Root-absolute internal `href` and `src` values in rendered HTML are rewritten
with the prefix: a Markdown link such as `[guide](/docs/guide/)`, a theme
literal such as `<link href="/css/main.css">`, or a vendored
`<script src="/js/app.js">`. Relative links, anchors, external URLs, and
already-prefixed engine URLs are unchanged. Escaped code examples (a fenced
`html` block showing `href="/x"`) are not rewritten. Only `href` and `src` are
rewritten, not `srcset` or CSS `url(...)`, so use relative or prefix-aware paths
there. `${site.pathPrefix}` exposes the normalized prefix
to layouts for references that need an explicit join:

```html
<link rel="stylesheet" tl:href="${site.pathPrefix} + 'css/main.css'">
<script tl:src="${site.pathPrefix} + 'js/app.js'"></script>
```

With `pathPrefix: /my-site/` these emit `/my-site/css/main.css` and
`/my-site/js/app.js`; with no prefix they stay `css/main.css` and `js/app.js`.
`${site.pathPrefix}` is the empty string when no prefix is set. Engine-derived
URLs such as `${page.url}` already carry the prefix and need no concatenation.

For host configuration and link-integrity checks, see
[Sites: Deploy](/docs/sites/deploy/).

## Syntax highlighting

Fenced Markdown code blocks are highlighted at build time
([ADR-010](https://github.com/tolo/trellis/blob/main/dev/adrs/ADR-010-syntax-highlighting.md)):
the generated HTML carries highlight.js-style `.hljs-*` token spans and ships no
client-side highlighter JavaScript. Highlighting is on by default; set
`enabled: false` to emit plain `<pre><code>` instead:

```yaml
highlight:
  enabled: true   # default; set false to disable
```

Only an explicit `enabled: false` turns it off; any other value leaves it on.
`highlight:` must be a map. A bare scalar such as `highlight: false` is ignored
and highlighting stays on, so disable it with `highlight:` plus `enabled: false`.
Unknown or unspecified code-block languages stay unhighlighted. Token colors
come from the active theme's `.hljs-*` CSS.

The old per-theme `syntax_highlighting` param is retired and ignored;
highlighting is controlled here, not per theme.

## Front matter fields

YAML front matter begins at the first line of a Markdown file:

```markdown
---
title: Hello World
date: 2026-03-15T09:30:00Z
draft: false
summary: A custom listing summary.
layout: custom
type: article
weight: 10
tags: [dart, web]
menu_title: Hello
menu_exclude: false
sitemap: true
feed: true
search: true
---
```

Recognized fields include `title`, `date`, `draft`, `summary`, `layout`,
`type`, `weight`, `sitemap`, `feed`, `search`, `menu_title`, and
`menu_exclude`. Taxonomy fields come from the configured taxonomy names. Other
fields remain available as `${page.fieldName}`.

## Template context

Layouts receive a cascade in this order, with later sources taking precedence:

1. Site configuration and `${site.params.*}`.
2. Global `data/*.yaml` values under `${data.*}`.
3. Section front matter.
4. Page front matter.

Additional values include:

- `${page.*}` – metadata including `url`, `content`, `summary`, `toc`,
  `section`, `sectionPath`, `ancestors`, `breadcrumbs`, `kind`, `prev`, and
  `next`, plus `termLinks` when taxonomies are configured;
- `${pages}` – ordered children for list pages; on a paginated list, the
  current page's slice;
- `${site.menu}` – the generated hierarchical navigation tree;
- `${pagination.*}` – page number, totals, and page URLs, set only when a list
  spans more than one page;
- `${taxonomy.*}` – each configured taxonomy's term list; and
- `${feeds.*}` – generated site-wide feed URLs.

Three `${page.*}` values describe where a page sits:

- `${page.section}` is the top-level folder (`docs`), unchanged for nested
  pages.
- `${page.sectionPath}` is the full nested lineage (`docs/guides`); empty for
  root pages.
- `${page.ancestors}` is the cumulative lineage list
  (`['docs', 'docs/guides']`); empty for root pages.

See [Sites: Layouts](/docs/sites/layouts/) for worked navigation, taxonomy, and
pagination examples.

## Page ordering

Within a section, pages with an integer `weight` sort first, ascending; ties and
unweighted pages fall back to date descending, then URL ascending. A section
where no page declares `weight` keeps exactly the date-then-URL order. A
malformed `weight` (a quoted string, say) is ignored with a build warning naming
the page, and the page is treated as unweighted; the build never aborts.

One engine function, `orderedSectionPages(sectionPath, allPages)`, returns a
section's own-level content pages in this order. `${pages}`, pagination,
`${site.menu}`, and `${page.prev}`/`${page.next}` all route through it, so every
derived ordering matches the `${pages}` listing. See
[Sites: Content](/docs/sites/content/#page-ordering).

## Navigation data

[Sites: Layouts](/docs/sites/layouts/) covers the menu, breadcrumbs, and
previous/next links. These are the exact shapes and edge cases.

### `${site.menu}`

Available on every page render: single pages, section listings, the home page,
and taxonomy virtual pages. Each node is a map with exactly three keys:

```text
{ title: String, url: String, children: List<node> }
```

- A section folder with no `_index.md` still yields a node, titled from its
  humanized folder name (`getting-started` becomes `Getting Started`).
- A section page that sets `menu_exclude: true` drops its own node and hoists
  its surviving children to the parent. Empty or fully excluded content yields
  an empty list, never null.
- The tree is built once and shared across renders, so nodes carry no active
  flag. A theme marks the current page and its ancestor trail by comparing each
  `node.url` against `${page.url}`:

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

### `${page.prev}` and `${page.next}`

Each is a `{url, title}` map for the page's immediate neighbor within its own
`${page.sectionPath}` level, in the `${pages}` order, so a section with weights
reads in `weight` order, not date order. Sibling sub-sections are not chained,
and there is no cross-section or site-wide "next article". Only single pages
receive them; list pages sequence through `${pagination.*}`. A missing neighbor
is simply not attached (the key is falsy), so guard each side with `tl:if`:

```html
<nav tl:if="${page.prev} or ${page.next}" aria-label="Page navigation">
  <a tl:if="${page.prev}" tl:href="${page.prev.url}" tl:text="${page.prev.title}">Previous</a>
  <a tl:if="${page.next}" tl:href="${page.next.url}" tl:text="${page.next.title}">Next</a>
</nav>
```

### `${page.breadcrumbs}`

One `{url, title}` node per ancestor section, shallow to deep, mirroring
`${page.ancestors}`: for `docs/guides`, `[{docs}, {docs/guides}]`. Each `url` is
the section's own path-prefix-aware URL, the same as the `${site.menu}` section
node. `${page.ancestors}` is unchanged; `${page.breadcrumbs}` is its labelled,
linkable companion.

## Layout resolution

Single and list pages resolve the first available layout in this order:

1. Front-matter `layout`, such as `layout: custom` → `custom.html`.
2. Type-specific `{type}/{single|list}.html`.
3. Section-specific `{section}/{single|list}.html`.
4. `_default/{single|list}.html`.

Home pages resolve a front-matter `layout`, then `home.html`, then
`index.html`, then `_default/list.html`. Taxonomy listing and term pages have
their own chain, covered in [Sites: Layouts](/docs/sites/layouts/#taxonomies).
Site-owned layouts take precedence over theme layouts at the same path.

For the full authoring workflow, return to the [Sites guide](/docs/sites/).
