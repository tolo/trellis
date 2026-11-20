---
title: Tooltip
description: Show a short hint on an existing control.
layout: ui_component
component: tooltip
tokens: [--foreground, --background, --radius]
---

Use a Tooltip for supplementary text. Give its hint a unique `id` and supply
one native focusable control inside the `trigger` slot. The control keeps its
accessible name and action. The suite appends the hint ID to its
`aria-describedby`, preserving any existing description IDs.

## Example

<!-- tl:ui_tooltip -->

```html
<div tl:replace="~{trellis-ui/tooltip :: tooltip('reference-mode-hint', 'Find light and dark themes.')}">
  <tl:block tl:slot="trigger">
    <a id="reference-mode" href="../../guide/#apply-a-shadcn-theme-block">Colour mode</a>
  </tl:block>
</div>
```

Use your app’s destination for the link. The signature is `tooltip(id, text, side, openDelay, closeDelay)`. Supply
plain text. The default side is `top`. The other sides are `right`, `bottom`
and `left`. The open and close delays default to 300 ms and 150 ms.
Pass `0` for either delay to make that transition immediate.

## Keyboard interaction

Tab onto the control to see the hint immediately. Tab away or press Escape to
dismiss it. Escape leaves focus on its current control. A pointer user can
move from the control onto the hint to keep it visible.

## Accessibility notes

Give icon-only controls their own accessible name. Put essential instructions
and actions in visible page content so readers can use them with touch or
without the suite script. For a panel with links or controls, use a
[Popover](../popover/) so users can move focus inside it.
