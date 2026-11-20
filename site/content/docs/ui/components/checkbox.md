---
title: Checkbox
description: Turn an option on or off independently.
layout: ui_component
component: checkbox
tokens: [--input, --primary, --primary-foreground, --ring, --radius]
---

Use a checkbox for a choice that can be on or off. Pass `checked` on the host
to set its initial state.

## Example

<!-- tl:ui_checkbox -->

```html
<input tl:replace="~{trellis-ui/checkbox :: checkbox}" id="reference-reminders" name="reminders" checked>
<label for="reference-reminders">Send reminders</label>
```

## Keyboard interaction

Tab reaches the checkbox. Space toggles it. A disabled checkbox is skipped.

## Accessibility notes

Use a visible label connected to the checkbox ID. The native control exposes
checked and disabled states. Use a fieldset and legend for related choices.
