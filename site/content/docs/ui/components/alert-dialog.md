---
title: Alert dialog
description: Ask for explicit confirmation before a consequential action.
layout: ui_component
component: alert-dialog
tokens: [--popover, --popover-foreground, --destructive, --border, --ring, --radius]
---

Use an alert dialog to confirm a consequential action. The live example
dismisses after either button and leaves the project in place.

## Example

<!-- tl:ui_alert_dialog -->

```html
<div tl:replace="~{trellis-ui/alert-dialog :: alertDialog('reference-delete', 'Delete project?', 'The project and its settings will be removed.', false)}">
  <tl:block tl:slot="trigger">
    <button tl:replace="~{trellis-ui/button :: button('destructive')}">Delete project</button>
  </tl:block>
  <tl:block tl:slot="action">
    <button tl:replace="~{trellis-ui/button :: button('destructive')}">Confirm deletion</button>
  </tl:block>
</div>
```

## Keyboard interaction

Opening focuses Cancel. Tab and Shift+Tab stay within the modal. Escape and
Cancel dismiss it. Enter or Space activates the focused button.

The panel fades briefly on dismissal while focus moves immediately. Readers who
prefer reduced motion skip the fade.

## Accessibility notes

Describe the consequence in the title and description. Keep a safe default
action and give each alert dialog its own ID so its accessible name and
description resolve to the matching elements.
