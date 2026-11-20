---
title: Dropdown menu
description: Group commands behind a menu button.
layout: ui_component
component: dropdown-menu
tokens: [--popover, --popover-foreground, --accent, --accent-foreground, --destructive, --border, --radius]
---

Use a dropdown menu for a short list of commands. The checkbox item toggles
its state and keeps the menu open.

## Example

<!-- tl:ui_dropdown_menu -->

```html
<div tl:replace="~{trellis-ui/dropdown-menu :: dropdownMenu('reference-menu')}">
  <span tl:slot="trigger">Account actions</span>
  <button tl:replace="~{trellis-ui/dropdown-menu :: menuItem}">Edit profile</button>
  <button tl:replace="~{trellis-ui/dropdown-menu :: menuItem}" disabled>Manage team</button>
  <div tl:replace="~{trellis-ui/dropdown-menu :: menuSeparator}"></div>
  <button tl:replace="~{trellis-ui/dropdown-menu :: menuCheckboxItem(false)}">Show status</button>
</div>
```

## Keyboard interaction

Enter, Space, ArrowDown or ArrowUp opens the menu. Arrow keys move through
enabled items and wrap. Home and End jump to the first or last enabled item.
Typing a letter finds a matching item. Enter or Space selects, Escape dismisses
and returns focus to the trigger, and Tab moves on.

## Accessibility notes

Give the trigger a short accessible label. Use native `disabled` on commands
the reader cannot run. Normal items close on selection. The bubbling
`tl-select` event exposes the selected element as `detail.item`.
