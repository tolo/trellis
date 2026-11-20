---
title: Sheet
description: Open page links or task controls in a modal at a viewport edge.
layout: ui_component
component: sheet
tokens: [--popover, --popover-foreground, --border, --ring]
---

Use a Sheet to show navigation or other modal content from a viewport edge.
Give it a unique ID and a visible title. Put a native button in the `trigger`
slot and the links or controls in the `content` slot.

## Example

<!-- tl:ui_sheet -->

```html
<div tl:replace="~{trellis-ui/sheet :: sheet('reference-sheet', 'right', 'Related guides')}">
  <tl:block tl:slot="trigger">
    <button id="reference-sheet-trigger" tl:replace="~{trellis-ui/button :: button}">Open related guides</button>
  </tl:block>
  <tl:block tl:slot="content">
    <ul>
      <li><a href="../../guide/">Using Trellis UI</a></li>
      <li><a href="../dialog/">Dialog reference</a></li>
    </ul>
  </tl:block>
</div>
```

The signature is `sheet(id, side, title, inlineAbove)`. Use `top`, `right`,
`bottom` or `left` for `side`. It defaults to `right`. Optional attributes
pass through to the panel.

## Inline layout

Omit `inlineAbove` to use a modal at every width. Set it to a number in
CSS pixels to show the same content inline at wider viewports. With
`inlineAbove=700`, the trigger opens a modal at 700 px. At 701 px the
modal and backdrop close, the content remains visible, and the trigger
and Close control disappear. Narrowing again restores a closed Sheet
and an operable trigger. If the suite script is unavailable, the
server-rendered links stay in normal page flow.

## Keyboard interaction

Focus moves inside the modal on open. Tab and Shift+Tab wrap inside it.
Escape, Close and a click on the backdrop return focus to the trigger.
An ordinary link activation closes the Sheet and lets the destination
receive focus.

An HTMX swap inside an open Sheet keeps the surrounding modal. If the
focused control is removed, focus moves to a usable control in the panel.

## Accessibility notes

A same-page destination can use a heading with `tabindex="-1"` so the
browser can focus it. Reduced motion removes the opening slide.
