---
title: Toast
description: Show a dismissible notification after an action.
layout: ui_component
component: toast
tokens: [--popover, --popover-foreground, --muted-foreground, --border, --destructive, --radius]
---

Use a toast for the outcome of an action. A duration of `0` keeps this
notification available until you dismiss it.

## Example

<!-- tl:ui_toast -->

```html
<div tl:replace="~{trellis-ui/toast :: toast('success', 'Changes saved', 'Your profile has been updated.', 0, false)}"></div>
```

Toasts stack in the existing notification region. A rightward touch swipe
dismisses the touched toast. Vertical scrolling and leftward or short swipes
leave it in place.

## Keyboard interaction

Tab reaches the dismiss button. Enter or Space dismisses the notification.
Finite timers pause while the toast is hovered or contains focus.

## Accessibility notes

Use the polite viewport for routine updates. Error toasts use `role="alert"`.
Keep fields and actions needed to recover from an error with the relevant form.

## Server responses

Render a single viewport in the page before returning an out-of-band response.
With the default ID, `outOfBand: true` appends the toast under `#toaster`.

```html
<div tl:replace="~{trellis-ui/toast :: toastViewport}"></div>
```

```dart
final html = engine.renderFileFragment('trellis-ui/toast', fragment: 'toast', context: {
  'type': 'success',
  'title': 'Changes saved',
  'description': 'Your profile has been updated.',
  'duration': 0,
  'outOfBand': true,
});
```
