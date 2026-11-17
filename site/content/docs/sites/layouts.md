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

Home pages resolve a front-matter `layout`, then `home.html`, then
`index.html`, then `_default/list.html`. Taxonomy pages have their own chain;
see [Taxonomies](#taxonomies). A site-owned layout wins over a theme layout at
the same path.

## Template context and data cascade

Values enter the template context from lowest to highest priority:

1. Site configuration and `${site.params.*}`.
2. Global files under `data/`, exposed as `${data.filename.*}`.
3. The current section's `_index.md` front matter.
4. The current page's front matter.

Layouts also receive:

- `${page.*}` – URL, rendered content, summary, TOC, section,
  `sectionPath`, ancestors, breadcrumbs, kind, and previous/next neighbors.
- `${pages}` – the ordered child pages of a home, section, or taxonomy term
  list; on a paginated list, only the current page's slice.
- `${site.menu}` – the generated navigation tree available on every page.
- `${pagination.*}` – page number, totals, and page links on paginated lists.
- `${taxonomy.*}` and `${feeds.*}` – taxonomy or feed data when configured.

## Breadcrumbs

`${page.breadcrumbs}` lists the page's ancestor sections from shallow to deep.
Each node has `url` and `title`; the title uses the same `menu_title`, title,
humanized-folder fallback as the menu. A folder without `_index.md` has an empty
`url`. Root pages get an empty list.

```html
<nav tl:if="${page.breadcrumbs}" aria-label="Breadcrumb">
  <a tl:each="crumb : ${page.breadcrumbs}" tl:href="${crumb.url}" tl:text="${crumb.title}">Section</a>
</nav>
```

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
per term at `/{taxonomy}/{slug}/`. Terms are lowercased and slugified, so
`Dart Web` becomes `/tags/dart-web/`.

- `${taxonomy.tags}` – on every page, the term list: each term has `name`,
  `slug`, `url`, `count`, and `pages`.
- `${page.termLinks.tags}` – on a content page, its own terms as `name`, `slug`,
  `url`, and `count`. Link terms through this `url` rather than building
  `/tags/{term}/` by hand.
- `${page.terms}` – on the `/{taxonomy}/` listing, the term list.
- `${pages}` and `${page.term}` – on a term page, the matching pages and the
  term itself.

The first matching layout renders each generated page:

| Page | Layout candidates, in order |
|---|---|
| `/{taxonomy}/` listing | `{taxonomy}/list.html`, `_default/taxonomy.html`, `_default/list.html` |
| `/{taxonomy}/{slug}/` term | `{taxonomy}/term.html`, `{taxonomy}/single.html`, `_default/taxonomy.html`, `_default/single.html` |

## Pagination

Set a page size in `trellis_site.yaml`:

```yaml
paginate: 10
```

Home, section, and taxonomy-term lists are split into pages. The first keeps
its base URL and later pages use `/page/{n}/`. `${pages}` holds the current
page's slice. Read `${pagination.page}`, `${pagination.totalPages}`,
`${pagination.totalItems}`, `${pagination.hasPrev}`, `${pagination.hasNext}`,
`${pagination.prevUrl}`, and `${pagination.nextUrl}` in the layout;
`${pagination.pages}` lists the URL of every page, for page-number links.

`${pagination}` is only set when a list spans more than one page, so guard it
with `tl:if="${pagination}"`. Without `paginate`, a theme's `posts_per_page`
param sets the page size.
