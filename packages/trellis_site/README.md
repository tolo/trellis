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
- `contentDir`, `layoutsDir`, `staticDir`, `dataDir`, `outputDir`
- `taxonomies`, `paginate`
- `params` for arbitrary site-level values exposed as `${site.params.*}`
- `feeds` and `search` for generated output artifacts

Paths may be relative to the site root or absolute.

```yaml
title: My Site
baseUrl: https://example.com
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
```

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

| File | URL | Kind |
|------|-----|------|
| `content/_index.md` | `/` | home |
| `content/about.md` | `/about/` | single |
| `content/posts/_index.md` | `/posts/` | section |
| `content/posts/hello.md` | `/posts/hello/` | single |
| `content/posts/trip/index.md` | `/posts/trip/` | single (bundle) |

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

Standard fields: `title`, `date`, `draft`, `summary`, `layout`, `type`, `sitemap`, `feed`, `search`. Custom fields are available in templates as `${page.fieldName}`.

## Template Context

Templates receive a data cascade (lowest to highest priority):

1. **Site params** -- `${site.title}`, `${site.baseUrl}`, `${site.params.*}`
2. **Global data** -- `${data.filename.*}` from `data/*.yaml`
3. **Section front matter** -- from the section's `_index.md`
4. **Page front matter** -- from the page's own front matter

Additional context variables:

- `${page.*}` -- page metadata (`url`, `content`, `summary`, `toc`, `section`, `kind`)
- `${pages}` -- child pages for list pages (section, home, taxonomy term)
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
