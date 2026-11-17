---
title: Badge
description: Mark a status or category inline.
layout: ui_component
component: badge
tokens: [--primary, --primary-foreground, --secondary, --secondary-foreground, --border, --destructive]
---

Use text to identify the status. The variant changes its emphasis.

## Example

<!-- tl:ui_badge -->

```html
<span tl:replace="~{trellis-ui/badge :: badge}">Active</span>
<span tl:replace="~{trellis-ui/badge :: badge('secondary')}">Draft</span>
<span tl:replace="~{trellis-ui/badge :: badge('outline')}">Archived</span>
```

## Keyboard interaction

Tab passes through a badge. Put interactions on an actual link or button.

## Accessibility notes

Use text to convey the status without depending on its colour. A badge
is inline content with no implicit live announcement.
