---
title: Container
description: Constrain content width and compose a responsive sidebar.
layout: ui_component
component: container
tokens: [--spacing]
---

A container centres a readable width. The `sidebar` fragment gives its
first child the sidebar track and its second child the main track. Narrow
widths stack the tracks in document order.

## Example

<!-- tl:ui_container -->

```html
<div tl:replace="~{trellis-ui/container :: container('md')}">
  <div tl:replace="~{trellis-ui/container :: sidebar('md')}">
    <div><strong>Project</strong><p>Summary</p></div>
    <div><strong>Recent activity</strong><p>Three tasks are ready to review.</p></div>
  </div>
</div>
```

## Keyboard interaction

Tab passes through both layouts. Focusable descendants follow document
order after wrapping.

## Accessibility notes

Keep the sidebar and main content in an order that makes sense in a
single column. Use landmarks only when the content warrants them.
