---
title: Accordion
description: Reveal FAQ or navigation sections with native disclosure controls.
layout: ui_component
component: accordion
tokens: [--foreground, --muted-foreground, --border, --ring, --radius]
---

Use `accordion(...attrs)` to group `accordionItem(name, title, open, ...attrs)` fragments.
Put the panel content inside each item. The `title` supplies the summary text.
Pass `true` for an initially open item. Omitted `open` starts the item closed.

## Examples

<!-- tl:ui_accordion -->

```html
<h3>Multiple open</h3>
<div tl:replace="~{trellis-ui/accordion :: accordion}">
  <div tl:replace="~{trellis-ui/accordion :: accordionItem(null, 'Delivery', true)}">
    <p>Orders ship within two working days.</p>
  </div>
  <div tl:replace="~{trellis-ui/accordion :: accordionItem(null, 'Returns')}">
    <p>Return unused items within 30 days.</p>
  </div>
</div>
<h3>Single open</h3>
<div tl:replace="~{trellis-ui/accordion :: accordion}">
  <div tl:replace="~{trellis-ui/accordion :: accordionItem('reference-account', 'Profile', true)}">
    <p>Change your name and contact details.</p>
  </div>
  <div tl:replace="~{trellis-ui/accordion :: accordionItem('reference-account', 'Security')}">
    <p>Update your sign-in details.</p>
  </div>
</div>
```

## Group names

Pass `null` for independently open items. For a single-open group, give all its
items the same nonempty `name`. Use a different name for every group in the
document, including copies hidden at a breakpoint.

When an HTMX response replaces a group, use a fresh name for that response.
HTMX can insert the replacement before removing the old group. Distinct names
let the replacement keep its server-rendered open item during that overlap.
A static group can use a fixed name.

## Keyboard interaction

Tab moves among the summaries and the controls in open panels. Enter or Space
on a summary toggles its panel. The browser provides this behavior with suite
scripts disabled.

## Accessibility notes

Give every summary a meaningful title. Place destination links inside the panel
or beside the disclosure, where each has its own focus target. The browser
announces expanded and collapsed state from the native summary. Browser
find-in-page can reveal text in a closed panel where the browser supports it.
