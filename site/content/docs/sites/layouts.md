---
title: Layouts
description: Render site content with Trellis layouts, context data, navigation, taxonomies, and pagination.
weight: 30
---

Layouts turn discovered content into HTML using the Trellis template engine.

## Layout resolution

For a single or list page, Trellis selects the first matching layout:

1. Front-matter `layout` such as `layout: custom` → `custom.html`.
2. Type-specific layout → `{type}/{single|list}.html`.
3. Section-specific layout → `{section}/{single|list}.html`.
4. Default layout → `_default/{single|list}.html`.

Home pages resolve `home.html`, then `index.html`, then
`_default/list.html`. A site-owned layout wins over a theme layout at the same
path.

## Template context and data cascade

Values enter the template context from lowest to highest priority:

1. Site configuration and `${site.params.*}`.
2. Global files under `data/`, exposed as `${data.filename.*}`.
3. The current section's `_index.md` front matter.
4. The current page's front matter.

Layouts also receive:

- `${page.*}` – URL, rendered content, summary, TOC, section,
  `sectionPath`, ancestors, kind, and previous/next neighbors.
- `${pages}` – the ordered child pages of a home, section, or taxonomy list.
- `${site.menu}` – the generated navigation tree available on every page.
- `${pagination.*}` – page number, totals, links, and the current slice.
- `${taxonomy.*}` and `${feeds.*}` – taxonomy or feed data when configured.

## Navigation menu

`${site.menu}` mirrors the content hierarchy. Each node contains `title`,
`url`, and `children`. It follows the same weight-aware ordering as section
pages, omits drafts and `menu_exclude: true` pages, and uses `menu_title` before
the page title or a humanized slug.

```html
<nav>
  <ul>
    <li tl:each="item : ${site.menu}">
      <a tl:href="${item.url}" tl:text="${item.title}">Page</a>
    </li>
  </ul>
</nav>
```

## Previous and next

Single pages receive `${page.prev}` and `${page.next}` for their immediate
neighbors at the same `sectionPath`. Each value has `url` and `title`. The first
and last page omit the missing neighbor; home, section, and taxonomy list pages
do not receive these links.

## Taxonomies

Declare collections such as tags and categories:

```yaml
taxonomies: [tags, categories]
```

Matching front matter generates a taxonomy listing at `/{taxonomy}/` and a page
per term at `/{taxonomy}/{slug}/`. Layouts read the generated terms and matching
pages through `${taxonomy.*}`.

## Pagination

Set a page size in `trellis_site.yaml`:

```yaml
paginate: 10
```

Home, section, and taxonomy-term lists are split into pages. The first keeps
its base URL and later pages use `/page/{n}/`. Read
`${pagination.page}`, `${pagination.totalPages}`, `${pagination.hasNext}`,
`${pagination.prevUrl}`, `${pagination.nextUrl}`, and `${pagination.pages}` in
the layout.
