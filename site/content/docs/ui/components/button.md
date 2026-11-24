---
title: Button
description: A native button with appearance and size variants.
layout: ui_component
component: button
tokens: [--primary, --primary-foreground, --background, --border, --ring, --radius]
---

Use a button for an action. The fragment defaults to type `button`.
Set the type to `submit` for the control that submits a form.

## Example

<!-- tl:ui_button -->

```html
<button tl:replace="~{trellis-ui/button :: button}">Save changes</button>
<button tl:replace="~{trellis-ui/button :: button('outline', 'sm')}">Cancel</button>
```

## Keyboard interaction

Tab focuses an enabled button. Enter or Space activates it. A disabled button
is skipped.

## Accessibility notes

Use an action label. For an icon-only button, give the host an `aria-label`
and hide a decorative icon with `aria-hidden="true"`.

While a submission is pending, set `disabled` to prevent repeat activation and
`aria-busy="true"` to keep the progress label at full opacity. Use a label
such as “Saving…”. Restore the action label and clear both attributes when the
request finishes or fails.
