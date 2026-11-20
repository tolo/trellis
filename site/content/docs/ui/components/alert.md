---
title: Alert
description: Draw attention to a notice or an error.
layout: ui_component
component: alert
tokens: [--card, --card-foreground, --muted-foreground, --destructive, --border, --radius]
---

Use the title slot and body to explain what happened and what the reader
can do next.

## Example

<!-- tl:ui_alert -->

```html
<div tl:replace="~{trellis-ui/alert :: alert('destructive')}">
  <span tl:slot="title">Upload failed</span>
  Check the file size and try again.
</div>
```

## Keyboard interaction

Tab passes through an alert and stops at any links or buttons it contains.

## Accessibility notes

Alerts have no implicit live role. For dynamically announced updates, set
`role="status"` or `role="alert"` through the caller and put the live region
in the document before inserting the message.
