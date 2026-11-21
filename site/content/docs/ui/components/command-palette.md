---
title: Command palette
description: Open a modal picker and filter choices from the keyboard.
layout: ui_component
component: command-palette
tokens: [--input, --popover, --popover-foreground, --accent, --accent-foreground, --ring, --radius]
options:
  - {value: apple, label: Apple}
  - {value: apricot, label: Apricot}
  - {value: banana, label: Banana}
---

The palette opens a labelled Dialog with a Combobox ready for typing. A local
query matches every term in an option label, ignoring case.

## Example

<!-- tl:ui_command_palette -->

```html
<div tl:replace="~{trellis-ui/command-palette :: commandPalette('pick-fruit', 'Choose a fruit', 'Search fruit…', options)}">
  <tl:block tl:slot="trigger">
    <button tl:replace="~{trellis-ui/button :: button}" type="button">Search fruit</button>
  </tl:block>
</div>
```

## Accessibility notes

Supply options as `{value, label}` maps and use a distinct base ID per palette.
Give the trigger an accessible name and keep it reachable when other overlays
are closed.

## Keyboard interaction

Pass a key letter to enable the Control or Command shortcut when the key reaches
the page. The example omits `shortcut` for trigger-only activation. Editable controls
and handlers that already consumed the key keep their shortcuts.

ArrowDown and ArrowUp move through the matches. Enter or a pointer selects the
option and dispatches one bubbling `tl-select` event with `detail.value`.
Escape closes the whole palette and returns focus to the opener. Reopening
starts with an empty query.

## Indexed search

Lattice can use the same picker for build-generated site search. The docs site
opens it with Search or the platform shortcut. It shows **No results** for an
unmatched query and **Search unavailable** when the index fails to load.
[Enable indexed search in Lattice](/docs/sites/search-and-feeds/#search-index).
