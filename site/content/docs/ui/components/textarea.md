---
title: Textarea
description: A multiline native text control.
layout: ui_component
component: textarea
tokens: [--background, --foreground, --input, --ring, --radius]
---

Use a natural textarea host. Its text becomes the initial value through the
anonymous slot.

## Example

<!-- tl:ui_textarea -->

```html
<label for="reference-summary">Project summary</label>
<textarea tl:replace="~{trellis-ui/textarea :: textarea}" id="reference-summary"
  name="summary" rows="3">A short project update.</textarea>
```

## Keyboard interaction

Tab focuses the textarea. Enter inserts a new line. Tab moves to the
next control.

## Accessibility notes

Use a visible label and a unique control ID. Connect help or error
text with `aria-describedby`.
