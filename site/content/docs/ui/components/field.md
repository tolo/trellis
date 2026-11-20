---
title: Field
description: A labelled input with help and validation messages.
layout: ui_component
component: field
tokens: [--foreground, --muted-foreground, --destructive, --input, --ring]
---

The field fragment owns its text input. It forwards attributes to that input.
Use the standalone label and fieldset fragments to compose other controls.

## Example

<!-- tl:ui_field -->

```html
<div tl:replace="~{trellis-ui/field :: field('reference-username', 'Username', 'Use lowercase letters.', 'That name is taken.')}"
  name="username" value="garden" autocomplete="username"></div>
```

## Keyboard interaction

Tab focuses the input. The label also focuses its associated input when
clicked. Native text-editing keys work in the input.

## Accessibility notes

Use a distinct control ID per field. The hint and error IDs derive from it.
A field with an error sets `aria-invalid`, links the messages with
`aria-describedby`, and exposes the error as an alert.
