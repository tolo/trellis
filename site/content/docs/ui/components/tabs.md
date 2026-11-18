---
title: Tabs
description: Switch between related views without leaving the page.
layout: ui_component
component: tabs
tokens: [--background, --foreground, --muted, --muted-foreground, --ring, --radius]
---

The example uses horizontal tabs with one panel visible at a time. Use a
matching value on each trigger and its panel.

## Example

<!-- tl:ui_tabs -->

```html
<div tl:replace="~{trellis-ui/tabs :: tabs('reference-tabs', 'account', false)}">
  <div tl:replace="~{trellis-ui/tabs :: tabList}" aria-label="Account details">
    <button tl:replace="~{trellis-ui/tabs :: tabTrigger('account')}">Account</button>
    <button tl:replace="~{trellis-ui/tabs :: tabTrigger('billing')}">Billing</button>
  </div>
  <div tl:replace="~{trellis-ui/tabs :: tabPanel('account')}">Update your account settings.</div>
  <div tl:replace="~{trellis-ui/tabs :: tabPanel('billing')}">Review your invoices.</div>
</div>
```

## Keyboard interaction

Tab enters at the selected tab. Left and Right move focus in a horizontal
list. Up and Down do the same in a vertical list. Home and End move to the
first and last enabled tab. Enter or Space shows the focused tab’s panel.

## Accessibility notes

Name the tab list, give each tabs instance a unique ID, and choose an enabled
initial tab. Native `disabled` on a trigger skips it during arrow navigation.
The component associates each tab with its panel and hides inactive panels.
