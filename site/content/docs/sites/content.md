---
title: Content
description: Organize Markdown content, front matter, page bundles, drafts, and shortcodes.
weight: 20
---

Trellis discovers Markdown under `content/` and derives pages from its directory structure.

## Content conventions

| File | URL | Kind | `section` | `sectionPath` |
|---|---|---|---|---|
| `content/_index.md` | `/` | home | `` | `` |
| `content/about.md` | `/about/` | single | `` | `` |
| `content/posts/_index.md` | `/posts/` | section | `posts` | `posts` |
| `content/posts/hello.md` | `/posts/hello/` | single | `posts` | `posts` |
| `content/docs/guides/_index.md` | `/docs/guides/` | section | `docs` | `docs/guides` |

An `_index.md` file defines the home page or a section listing. Other Markdown
files become single pages. A nested section lists pages at its own level rather
than flattening sibling sections into one list.

## Front matter

Start a file with YAML between `---` delimiters:

```markdown
---
title: Hello World
date: 2026-03-15T09:30:00Z
tags: [dart, web]
draft: false
layout: custom
summary: A custom summary for listings.
weight: 20
---

# Hello World

Content here.
```

Standard fields include `title`, `date`, `draft`, `summary`, `layout`, `type`,
`weight`, `sitemap`, `feed`, `search`, `menu_title`, and `menu_exclude`. Custom
fields are available to layouts as `${page.fieldName}`.

`menu_title` changes a page's label in the generated menu without changing its
page title. `menu_exclude: true` removes it from the menu.

### Dates and time zones

A date without a zone is interpreted as UTC calendar fields, so feeds and the
sitemap stay identical across build machines. Add `Z` or a numeric offset when
the timestamp represents a specific instant:

```yaml
date: 2026-03-15
date: 2026-03-15T09:30:00Z
date: 2026-03-15T09:30:00+02:00
```

## Page ordering

Within a section, pages with an integer `weight` come first in ascending order.
Equal-weight and unweighted pages fall back to date descending, then URL
ascending. The same order drives section listings, pagination, menus, and
previous/next links. A malformed weight produces a warning and is treated as
unweighted.

## Page bundles

A directory containing `index.md` is a page bundle:

```text
content/posts/my-trip/
|-- index.md
`-- photo.jpg
```

The page renders at `/posts/my-trip/`; co-located assets are copied beside the
generated page. Use bundles when content and its images belong together.

## Drafts

Pages with `draft: true` are excluded from normal builds. Include them in a
local preview when needed:

```bash
trellis build --drafts
```

## Shortcodes

Reusable content snippets live under `layouts/shortcodes/`. The pre-Markdown
form can emit Markdown before parsing:

```markdown
{{% callout kind="note" %}}
```

The post-Markdown form transforms rendered HTML:

```html
<!-- tl:figure src="diagram.svg" alt="Build flow" -->
```

Shortcode arguments are exposed to the matching Trellis fragment template.
Keep document structure in Markdown and use shortcodes for repeated,
parameterized content.
