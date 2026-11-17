---
title: Switch
description: Toggle a binary setting with a switch role.
layout: ui_component
component: switch
tokens: [--input, --primary, --background, --ring]
---

A switch presents a native checkbox as an on/off control. Pass the normal
checkbox attributes to set its state and form value.

## Example

<!-- tl:ui_switch -->

```html
<input tl:replace="~{trellis-ui/switch :: switch}" id="reference-sync" name="sync" checked>
<label for="reference-sync">Sync automatically</label>
```

## Keyboard interaction

Tab focuses the switch. Space toggles it.

## Accessibility notes

Keep the label stable while the switch changes state. The underlying
checkbox provides checked and disabled semantics and submits its form value.
