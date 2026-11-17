---
title: Breadcrumb
description: Show the current page’s place in a hierarchy.
layout: ui_component
component: breadcrumb
tokens: [--foreground, --muted-foreground]
items:
  - {label: Documentation, href: /docs/}
  - {label: Trellis UI, href: /docs/ui/}
  - {label: Breadcrumb, current: true}
---

Pass a list of linked ancestors followed by the current page.

## Example

<!-- tl:ui_breadcrumb -->

```html
<nav tl:replace="~{trellis-ui/breadcrumb :: breadcrumb(items)}" aria-label="Example breadcrumb"></nav>
```

Supply the example data as YAML front matter on a site using the source,
or as a context map in an application.

```yaml
items:
  - {label: Documentation, href: /docs/}
  - {label: Trellis UI, href: /docs/ui/}
  - {label: Breadcrumb, current: true}
```

## Keyboard interaction

Tab moves between ancestor links and Enter follows the focused link. Tab
passes through the current page text.

## Accessibility notes

Name the breadcrumb navigation. The current item uses
`aria-current="page"` and separators are hidden from assistive technology.
