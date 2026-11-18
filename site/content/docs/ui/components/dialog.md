---
title: Dialog
description: Open a native modal for a task that needs the reader’s attention.
layout: ui_component
component: dialog
tokens: [--popover, --popover-foreground, --muted-foreground, --border, --ring, --radius]
---

Use a dialog when a task needs a modal surface. The trigger opens the example and the footer button closes it.

## Example

<!-- tl:ui_dialog -->

```html
<div tl:replace="~{trellis-ui/dialog :: dialog('reference-dialog', 'Edit profile', 'Choose the display name shown on your profile.', false)}">
  <tl:block tl:slot="trigger">
    <button tl:replace="~{trellis-ui/button :: button}">Edit profile</button>
  </tl:block>
  <div tl:replace="~{trellis-ui/field :: field('reference-profile-name', 'Display name')}"
    autocomplete="nickname" autofocus></div>
  <tl:block tl:slot="footer">
    <button tl:replace="~{trellis-ui/button :: button('outline')}" data-dialog-close>Done</button>
  </tl:block>
</div>
```

## Keyboard interaction

Tab and Shift+Tab move through the modal. Escape closes it. A button marked
`data-dialog-close` closes it and focus returns to the opener.

## Accessibility notes

Give each dialog a unique ID, visible title, and useful description. The
fragment uses native modal focus management and derives title and description
IDs from that ID. For a server-rendered open dialog, set `data-return-focus` to
the stable opener ID and put `autofocus` on the first invalid field after validation.
