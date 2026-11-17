---
title: Grid
description: Lay out tiles with a responsive minimum column size.
layout: ui_component
component: grid
tokens: [--spacing]
---

Choose a minimum track size of `sm` (10rem), `md` (15rem), or `lg`
(20rem). The grid collapses to available width on narrow screens.

## Example

<!-- tl:ui_grid -->

```html
<div tl:replace="~{trellis-ui/grid :: grid('sm', 'sm')}">
  <button tl:replace="~{trellis-ui/button :: button('outline')}">Overview</button>
  <button tl:replace="~{trellis-ui/button :: button('outline')}">Tasks</button>
  <button tl:replace="~{trellis-ui/button :: button('outline')}">Activity</button>
</div>
```

## Keyboard interaction

Tab passes through the grid and visits focusable children in DOM order.

## Accessibility notes

This grid is a layout. Give the children their own semantics and keep
the source order aligned with the reading order.
