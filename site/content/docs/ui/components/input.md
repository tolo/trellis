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

## Date fields

For a single date, use a native `<input type="date">`. The browser provides
the date control without JavaScript. Place the labelled field inside your form
and set its `name` so the form submits the date.

```html
<label for="appointment-date">Appointment date</label>
<input type="date" id="appointment-date" name="appointment_date">
```

## Keyboard interaction

Tab focuses the input. In text fields, arrow keys move the caret and typing
edits the value. Enter can submit the containing form.

## Accessibility notes

Match the label’s `for` to the input’s ID. Link help and validation messages
with `aria-describedby` and set `aria-invalid` for an invalid value.
