---
title: Search and feeds
description: Generate a search index, sitemap, and Atom or RSS feeds for a Trellis site.
weight: 50
---

Trellis can emit discovery artifacts alongside the rendered HTML.

## Search index

Enable a JSON index for a client-side search UI:

```yaml
search:
  enabled: true
  output: search-index.json
  fields: [title, summary, content, tags]
```

Every entry includes its built URL plus the configured fields. Set
`search: false` in a page's front matter to omit it. A theme can fetch the
same-origin `search-index.json`, filter it in the browser, and use each entry's
URL verbatim; URLs already include the configured `pathPrefix`.

## Sitemap

Builds write `sitemap.xml` when `baseUrl` is non-empty and at least one page is
included. Its `<loc>` values combine `baseUrl`,
`pathPrefix`, and the page URL. `<lastmod>` comes from front matter when a date
is present and otherwise from the content file's modified time.

Set `sitemap: false` in a page's front matter to exclude it:

```yaml
sitemap: false
```

## Atom and RSS

Configure site-wide feeds in `trellis_site.yaml`:

```yaml
feeds:
  atom: true
  rss: true
  limit: 20
```

Atom is written to `feed.xml`; RSS is written to `rss.xml`. Feed URLs and item
links combine `baseUrl` with the normalized path prefix. Set `feed: false` in
front matter to exclude an individual page.

## Per-section feeds

List the sections that need their own feeds:

```yaml
feeds:
  atom: true
  rss: true
  sections: [posts, releases]
  limit: 20
```

Each named section receives its own feed artifacts containing pages from that
section. This keeps a focused subscription separate from the site-wide stream.
