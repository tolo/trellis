---
title: Stack
description: Lay out items vertically with a shared gap.
layout: ui_component
component: stack
tokens: [--spacing]
---

A stack keeps items in source order and applies spacing from the shared
gap scale: `none`, `xs`, `sm`, `md`, `lg`, or `xl`.

## Example

<!-- tl:ui_stack -->

```html
<div tl:replace="~{trellis-ui/stack :: stack('sm')}">
  <button tl:replace="~{trellis-ui/button :: button}">Save changes</button>
  <button tl:replace="~{trellis-ui/button :: button('outline')}">Cancel</button>
</div>
```

## Keyboard interaction

Tab passes through the stack and reaches its focusable children in document
order.

## Accessibility notes

Put the items in their reading order. Choose accessible names and semantics
on the children.
