---
title: Cluster
description: Arrange items inline and allow them to wrap.
layout: ui_component
component: cluster
tokens: [--spacing]
---

Use a cluster for inline groups whose items can wrap. Choose a gap from
`none`, `xs`, `sm`, `md`, `lg`, or `xl`.

## Example

<!-- tl:ui_cluster -->

```html
<div tl:replace="~{trellis-ui/cluster :: cluster('sm')}">
  <span tl:replace="~{trellis-ui/badge :: badge('secondary')}">Design</span>
  <span tl:replace="~{trellis-ui/badge :: badge('secondary')}">Development</span>
  <span tl:replace="~{trellis-ui/badge :: badge('secondary')}">Documentation</span>
  <span tl:replace="~{trellis-ui/badge :: badge('secondary')}">Review</span>
</div>
```

## Keyboard interaction

Tab passes through the cluster and stops only at interactive children.

## Accessibility notes

Keep DOM order meaningful when the cluster wraps. Use suitable semantics
on the content inside it.
