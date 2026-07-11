# Arbor — Trellis Documentation Theme

A documentation theme for the [Trellis](https://pub.dev/packages/trellis) SDK.
Arbor renders the navigation a docs site needs: a hierarchical sidebar (from the
content tree), an in-page table of contents, prev/next links, build-time syntax
highlighting, and a search UI shell — all with semantic landmarks, a
skip-to-content link, WCAG 2.1 AA color contrast, and a responsive layout with a
JavaScript-free collapsible mobile sidebar.

Arbor is a sibling of the `verdant` blog theme and shares its conventions
(manifest shape, SASS bridge, `tl:extends`/`tl:define` layout inheritance). Code
is colored at build time (`.hljs-*` spans baked in by the SSG, ADR-010), so the
theme ships no highlighter JS; the client-side scripts it does ship — the search
UI and the code-block copy button — are **vendored, same-origin assets, never
CDN-loaded** (see [`VENDORED.md`](VENDORED.md)).

## Features

- **Hierarchical sidebar** from `${site.menu}` with active-page and
  ancestor-trail highlighting; up to three nesting levels.
- **In-page table of contents** from the flat `${page.toc}` list, indented by
  heading level.
- **Prev/next page navigation** from `${page.prev}`/`${page.next}` (renders when
  those neighbors are available).
- **Build-time syntax highlighting** — the SSG bakes `.hljs-*` spans into the
  built HTML (ADR-010); the theme styles them via `sass/_code.scss` and ships no
  highlighter JS. Code is colored with JavaScript disabled. No CDN, no npm.
- **Progressive enhancement** — the docs are fully readable with JavaScript
  disabled; search and the copy button never gate reading.
- **Light + dark skins** (and `auto`, following the OS preference), both passing
  WCAG 2.1 AA body-text contrast.
- **Accessible + responsive** — semantic `<header>`/`<nav>`/`<main>`/`<footer>`
  landmarks, skip-to-content link, focus-visible outlines, reduced-motion
  support, and a JS-free `<details>` disclosure that collapses the sidebar on
  mobile.

## Using the theme

In your site's `trellis_site.yaml`:

```yaml
theme: arbor
```

after adding it under your site's `themes/` directory (e.g. via
`trellis theme add <arbor-url>`), then customize with `theme_params:`:

```yaml
theme_params:
  skin: auto
  primary_color: "#0f7a4d"
  sidebar_title: "Guides"
  show_search: true
```

## Params

Arbor implements all 19 standard theme params (see
`docs/reference/standard-params.md`) plus documentation-specific params:

| Param | Type | Default | Purpose |
|---|---|---|---|
| `show_sidebar` | boolean | `true` | Show the `${site.menu}` navigation sidebar |
| `show_toc` | boolean | `true` | Show the in-page table of contents |
| `show_prev_next` | boolean | `true` | Show prev/next page links |
| `show_search` | boolean | `true` | Show the search UI shell |
| `toc_title` | string | `"On this page"` | Heading above the TOC |
| `sidebar_title` | string | `"Documentation"` | Sidebar label / heading |

See `theme.yaml` for the full param list and the standard-param defaults.

## Layouts

| Layout | Purpose |
|---|---|
| `layouts/base.html` | Root shell — landmarks, skip-link, vendored scripts, and the shared `sidebar` / `toc` fragments |
| `layouts/home.html` | Landing page — hero + `${pages}` cards (no sidebar) |
| `layouts/_default/single.html` | A documentation page — sidebar + article + TOC + prev/next |
| `layouts/_default/list.html` | A section index — sidebar + listing of `${pages}` |

Every content layout extends `base.html` via `tl:extends`. The shared sidebar and
TOC are defined once in `base.html` as `tl:fragment`s and pulled into each layout
with `tl:replace="~{layouts/base.html :: sidebar}"` (guarded at the call site so
absent navigation data renders an empty, non-erroring region).

## Preview

```bash
cd example
trellis build
```

The `example/` site exercises a nested content tree (sidebar levels), code fences
(highlighting), and headings (TOC). It builds with the current engine context
surface even where `${site.menu}`/`${page.toc}` producers have not yet landed —
the navigation regions simply render empty.

## Vendored assets

All JavaScript is committed under `static/` and served same-origin (no CDN, no
npm). See [`VENDORED.md`](VENDORED.md) for provenance — what is vendored and where
it came from.
