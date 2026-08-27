# Verdant — Trellis Blog Theme

A minimal, accessible blog theme for the [Trellis](https://pub.dev/packages/trellis) SDK.
Verdant is content-first: a hero, a recent-posts grid, post pages with optional
date/author/reading-time/tag metadata, and tag index and term pages. It ships
`light`, `dark`, and OS-aware `auto` skins, semantic landmarks with a
skip-to-content link, and full keyboard navigation — no CDN and no JavaScript
required.

Verdant is a sibling of the `arbor` docs theme and the `bloom` landing theme and
shares their conventions (manifest shape, the SASS param bridge,
`tl:extends`/`tl:define` layout inheritance, the 18 standard params). It differs
in intent: the content tree *is* the site, so the layouts read `${pages}` and
front matter rather than composing a page out of front-matter blocks.

## Features

- **Home hero + recent posts** — `hero_title`/`hero_description` params with the
  site title and description as fallbacks, then a card grid over `${pages}`.
- **Post metadata, each independently switchable** — publication date
  (`date_format`), author, estimated reading time, and tag pills.
- **Tag pages** — `/tags/` lists every term, `/tags/<slug>/` lists its posts.
  Requires `taxonomies: [tags]` in `trellis_site.yaml`; without it the pills link
  to pages that were never built.
- **Auto-generated excerpts** — `excerpt_length` caps summaries generated from a
  post body; an explicit `summary:` in front matter always wins.
- **Optional table of contents** — `show_toc` renders in-page headings on posts.
- **Feed discovery** — `show_rss_link` surfaces the site's feeds when the SSG
  generated any.
- **Three skins** — `light`, `dark`, and `auto` (follows
  `prefers-color-scheme`), both concrete skins passing WCAG 2.1 AA body-text
  contrast.
- **No highlighter shipped** — code renders clean but uncolored rather than
  pulling a highlighter from a CDN; build-time highlighting is configured
  site-side (see [ADR-010](../../dev/adrs/ADR-010-syntax-highlighting.md)).

## Using the theme

Install it out of the Trellis repository and set it in `trellis_site.yaml`:

```bash
trellis theme add https://github.com/tolo/trellis --theme verdant
```

```yaml
theme: verdant          # a real themes/verdant/ directory

taxonomies:
  - tags                # required for the tag pages the post pills link to
paginate: 5

theme_params:
  skin: auto            # light | dark | auto
  show_reading_time: true
  show_date: true
  show_author: true
  show_tags: true
  hero_title: "Field Notes"
  nav_links:
    - { label: Home,  url: / }
    - { label: Posts, url: /posts/ }
    - { label: About, url: /about/ }
```

Posts are ordinary Markdown under `content/posts/`; nothing about the theme has
to be edited to change colors, fonts, navigation, or which metadata appears.

## Layouts

- **`base.html`** — the HTML shell. Defines the `head-extra`, `site-header`,
  `content`, and `site-footer` blocks that a site overrides via `tl:extends`.
- **`home.html`** — hero plus the recent-posts grid.
- **`_default/single.html`** — a post or page: title, metadata row, optional
  table of contents, rendered Markdown, tag pills.
- **`_default/list.html`** — a section listing (title + summary per child page).
- **`tags/list.html`** — every taxonomy term.
- **`tags/term.html`** — the posts carrying one term.

## Theme-specific params

| Param | Type | Default | Description |
|---|---|---|---|
| `show_reading_time` | boolean | `true` | Estimated reading time on posts |
| `show_date` | boolean | `true` | Publication date on posts |
| `show_author` | boolean | `true` | Author name on posts |
| `show_tags` | boolean | `true` | Tag links on posts |
| `show_toc` | boolean | `false` | Table of contents on posts |
| `hero_title` | string | `null` | Home hero title (null = site title) |
| `hero_description` | string | `null` | Home hero subtitle (null = site description) |
| `date_format` | string | `MMM d, yyyy` | Date display format |
| `excerpt_length` | int | `160` | Character cap for auto-generated summaries |
| `posts_per_page` | int | `null` | Listing page size, used when the site sets no `paginate:` |

Plus all 18 [standard params](../../docs/reference/standard-params.md).

## Preview

```bash
cd example
trellis build && trellis serve
```

The example site (`Verdant Blog`) exercises the home hero, four posts, an about
page, and the tag pages. `themes/verdant/screenshots/{light,dark}.png` are
captured from it at 1280×800 and are what the
[themes gallery](https://tolo.github.io/trellis/docs/themes/gallery/) shows.
