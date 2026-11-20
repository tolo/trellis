---
title: Pagination
description: Navigate between pages of results.
layout: ui_component
component: pagination
tokens: [--background, --foreground, --accent, --accent-foreground, --border, --ring, --radius]
pages:
  - {label: '1', href: '#example', current: true}
  - {label: '2', href: '#keyboard-interaction'}
  - {label: '3', href: '#accessibility-notes'}
---

Pass each page’s URL and mark the current page. Previous and next accept
`null` at the boundaries.

## Example

<!-- tl:ui_pagination -->

```html
<nav tl:replace="~{trellis-ui/pagination :: pagination(pages, null, '#keyboard-interaction')}"
  aria-label="Example pagination"></nav>
```

Supply the example data as YAML front matter on a site using the source,
or as a context map in an application.

```yaml
pages:
  - {label: '1', href: '#example', current: true}
  - {label: '2', href: '#keyboard-interaction'}
  - {label: '3', href: '#accessibility-notes'}
```

## Keyboard interaction

Tab moves through the available links. Enter follows the focused link.
Unavailable previous and next controls do not enter the tab order.

## Accessibility notes

Give the navigation an accessible label. The active link is marked with
`aria-current="page"` and the fragment gives numbered links accessible names.
