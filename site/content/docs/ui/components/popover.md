---
title: Popover
description: Open an interactive panel next to a button.
layout: ui_component
component: popover
tokens: [--popover, --popover-foreground, --muted-foreground, --foreground, --radius]
---

Use a Popover for controls that fit in a small panel. Supply a unique `id` and
fill the `trigger` and `content` slots. Position it on the `top`, `right`,
`bottom` or `left`, with `start`, `center` or `end` alignment across that side.
The defaults are `bottom`, `start` and a 4 px offset. The panel flips or
shrinks to stay inside the viewport.

## Example

<!-- tl:ui_popover -->

```html
<div tl:replace="~{trellis-ui/popover :: popover('reference-options', 'bottom', 'start', 8)}">
  <span tl:slot="trigger">Options</span>
  <div tl:slot="content">
    <div tl:replace="~{trellis-ui/popover :: popoverHeader}">
      <h2 tl:replace="~{trellis-ui/popover :: popoverTitle}">Display options</h2>
      <p tl:replace="~{trellis-ui/popover :: popoverDescription}">Set the number of rows per page.</p>
    </div>
    <label for="reference-page-size">Rows per page</label>
    <input tl:replace="~{trellis-ui/input :: input}" id="reference-page-size" type="number" value="10" min="1">
  </div>
</div>
```

## Keyboard interaction

Enter or Space opens the panel and moves focus inside. Tab reaches the controls
in document order. Tab or Shift+Tab beyond the panel closes it and leaves focus
on the next control. Escape or clicking outside closes the panel and returns
focus to the trigger.

## Accessibility notes

Give the trigger a short accessible label and label the controls inside the
panel. Without the suite script the button stays visible and the panel stays
closed. Put essential links or actions in the page as well, or use a native
disclosure when readers need access without JavaScript.
