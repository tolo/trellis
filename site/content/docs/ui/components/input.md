---
title: Input
description: A native single-line form control.
layout: ui_component
component: input
tokens: [--background, --foreground, --input, --ring, --radius]
---

Use an input with a visible label. Pass standard attributes such as `type`,
`name`, and `autocomplete` to the native control.

## Example

<!-- tl:ui_input -->

```html
<label for="reference-email">Work email</label>
<input tl:replace="~{trellis-ui/input :: input}" id="reference-email"
  type="email" name="email" autocomplete="email">
```

## Keyboard interaction

Tab focuses the input. Arrow keys move the caret and ordinary typing edits
the value. Enter can submit the containing form.

## Accessibility notes

Match the label’s `for` to the input’s ID. Link help and validation messages
with `aria-describedby` and set `aria-invalid` for an invalid value.
