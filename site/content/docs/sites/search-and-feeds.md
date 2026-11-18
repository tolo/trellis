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
  excludeSections: [internal]
  stripHtml: true
  maxContentLength: 5000
```

| Key | Default | Meaning |
|---|---|---|
| `enabled` | `false` | Write the index and shared search client when pages qualify. |
| `output` | `search-index.json` | File name under the output directory. |
| `fields` | `[title, summary, content, tags]` | Entry fields; also `date` and `section`. |
| `excludeSections` | `[]` | Top-level sections to leave out. |
| `stripHtml` | `true` | Strip tags from `summary` and `content`. |
| `maxContentLength` | none | Truncate `content` to this many characters; omit for no limit. |

Every entry includes its built URL plus the configured fields. Only single
pages are indexed: the home page and section listings are not. Drafts are left
out, and `search: false` in a page's front matter omits it.

Trellis writes `trellis-search.js` beside the index. Arbor, Folio, and Lattice
load it for the docs sidebar when `theme_params.show_search` is on. The combobox
appears after the same-origin index loads. It lists up to 20 page titles that
match every search term across title, summary, content, and tags, ignoring case.
Use the arrow keys and Enter or click a result to open its page. The indexed URL
already carries the configured path prefix.

The bundled themes use the default index location. If you change `search.output`,
adjust your layout's script URL and its `data-search-index` attribute to point
to the new directory and index. The name `trellis-search.js` is reserved for
the shared client. Keep that path free of site assets in the index directory.

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
  fullContent: false
```

A `feeds:` section turns feeds on. `atom` defaults to `true`, `rss` to `false`,
and `limit` to `20` items per feed. `fullContent: true` puts each page's
rendered HTML in the feed instead of its summary. Feeds list single pages
newest first.

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

Each named section receives its own `/{section}/feed.xml` and
`/{section}/rss.xml` containing pages from that section. Listing sections also
narrows the site-wide `feed.xml` and `rss.xml` to pages from those sections, so
pages outside them, such as a root `about.md`, appear in no feed. A name that
matches no section produces a build warning.
