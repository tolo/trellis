---
title: Separator
description: A horizontal or vertical divider between related items.
layout: ui_component
component: separator
tokens: [--border]
---

The default separator is a horizontal rule. Set the orientation to
`vertical` when the items sit side by side.

## Example

<!-- tl:ui_separator -->

```html
<p>Account details</p>
<hr tl:replace="~{trellis-ui/separator :: separator}">
<p>Notification preferences</p>
```

## Keyboard interaction

Tab passes through the separator.

## Accessibility notes

Use a separator when the boundary adds context. The vertical form carries
`role="separator"` and `aria-orientation="vertical"`.
