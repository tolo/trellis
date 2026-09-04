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
  trellis_site: ^0.11.0
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

## Configuration keys

`trellis_site.yaml` accepts:

- `title`, `baseUrl`, and `description` for site identity;
- `pathPrefix` for a site served below the domain root;
- `contentDir`, `layoutsDir`, `staticDir`, `dataDir`, and `outputDir` for
  filesystem locations;
- `theme` and `theme_params` for an installed theme;
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
[Sites: Themes](/docs/sites/themes/).

## Path prefix

`pathPrefix` mounts the generated site below the domain root, such as GitHub
Project Pages at `https://user.github.io/my-site/`. Values like `my-site`,
`/my-site`, and `/my-site/` normalize to `/my-site/`; `''` and `/` mean the
domain root.

The prefix changes emitted URLs, not disk paths. A page at
`output/posts/intro/index.html` can therefore render a URL such as
`/my-site/posts/intro/`. `baseUrl` remains the absolute origin and composes with
the prefix in the sitemap and feeds.

Root-absolute internal `href` and `src` values in rendered HTML are rewritten
with the prefix. Relative links, anchors, external URLs, and already-prefixed
engine URLs are unchanged. `${site.pathPrefix}` exposes the normalized prefix
to layouts for references that need an explicit join:

```html
<link rel="stylesheet" tl:href="${site.pathPrefix} + 'css/main.css'">
```

For host configuration and link-integrity checks, see
[Sites: Deploy](/docs/sites/deploy/).

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
sitemap:
  exclude: false
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
  `section`, `sectionPath`, `ancestors`, `kind`, `prev`, and `next`;
- `${pages}` – ordered children for list pages;
- `${site.menu}` – the generated hierarchical navigation tree;
- `${pagination.*}` – pagination state and the current page slice;
- `${taxonomy.*}` – taxonomy data for generated collection pages; and
- `${feeds.*}` – generated site-wide feed URLs.

See [Sites: Layouts](/docs/sites/layouts/) for worked navigation, taxonomy, and
pagination examples.

## Layout resolution

Single and list pages resolve the first available layout in this order:

1. Front-matter `layout`, such as `layout: custom` → `custom.html`.
2. Type-specific `{type}/{single|list}.html`.
3. Section-specific `{section}/{single|list}.html`.
4. `_default/{single|list}.html`.

Home pages resolve `home.html`, then `index.html`, then
`_default/list.html`. Site-owned layouts take precedence over theme layouts at
the same path.

For the full authoring workflow, return to the [Sites guide](/docs/sites/).
