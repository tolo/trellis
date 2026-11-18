---
title: Card
description: Group related content into a titled surface.
layout: ui_component
component: card
tokens: [--card, --card-foreground, --muted-foreground, --radius]
---

Use the title, description, content and footer slots to group related
information. The card’s title is an `h2`.

## Example

<!-- tl:ui_card -->

```html
<section tl:replace="~{trellis-ui/card :: card}">
  <span tl:slot="title">Garden project</span>
  <span tl:slot="description">Updated this morning</span>
  <p>Three tasks are ready to review.</p>
  <tl:block tl:slot="footer">
    <button tl:replace="~{trellis-ui/button :: button('outline')}">Review tasks</button>
  </tl:block>
</section>
```

## Keyboard interaction

Tab passes through the card and stops at its interactive children in
document order.

## Accessibility notes

Keep the card title descriptive and leave the surface out of the tab order.
Use a native link or button for a card action.
