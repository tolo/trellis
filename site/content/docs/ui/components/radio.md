---
title: Radio
description: Select one choice from a native radio group.
layout: ui_component
component: radio
tokens: [--input, --primary, --ring]
---

Use one shared name and distinct IDs and values for mutually exclusive choices.
Each radio invocation outputs a fieldset with its own legend and control.

## Example

<!-- tl:ui_radio -->

```html
<input tl:replace="~{trellis-ui/radio :: radio('Weekly digest')}" id="reference-weekly" name="frequency"
  value="weekly" checked aria-label="Weekly">
<input tl:replace="~{trellis-ui/radio :: radio('Monthly digest')}" id="reference-monthly" name="frequency"
  value="monthly" aria-label="Monthly">
```

## Keyboard interaction

Tab enters the group on the checked radio. Arrow keys move selection among
radios with the same name. Space selects the focused radio.

## Accessibility notes

Give each input an accessible name. The legend labels its fieldset. Use the
same `name` to let the browser enforce one selection.
