---
title: Native select
description: Choose one value using a native select and options.
layout: ui_component
component: native-select
tokens: [--input, --background, --foreground, --muted-foreground, --ring, --radius]
---

Invoke this fragment on a natural select host so option and optgroup
markup reaches the anonymous slot.

## Example

<!-- tl:ui_native_select -->

```html
<label for="reference-priority">Priority</label>
<select tl:replace="~{trellis-ui/native-select :: native-select}" id="reference-priority" name="priority">
  <option value="normal">Normal</option>
  <option value="high">High</option>
</select>
```

## Keyboard interaction

Tab focuses the select. The browser and OS handle opening the list, moving
through options and confirming a selection.

## Accessibility notes

Label the select and use distinct option text. The decorative chevron is
hidden from assistive technology. Use the native `disabled` attribute
when the selection is unavailable.
