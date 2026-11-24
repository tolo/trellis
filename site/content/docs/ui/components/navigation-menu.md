---
title: Navigation menu
description: Group site links in disclosure panels that remain usable before enhancement.
layout: ui_component
component: navigation-menu
tokens: [--popover, --popover-foreground, --foreground, --muted, --border, --radius]
---

Use `navigationMenu(label, ...attrs)` for the navigation landmark and link list. Put direct
links in list items and add grouped links with `navigationMenuGroup(id, title, side, align, offset)`.
Use a unique group ID for each panel. Placement defaults to bottom, start, and an offset of 4 px.

`navigationMenuLink(href, currentUrl, ...attrs)` marks an exact match with `aria-current="page"`.
Supply the current URL in the same form as the destination. In a header on the GitHub Pages edition
of this page, passing `/trellis/docs/ui/components/navigation-menu/` as both arguments marks this link
as current. The example uses `./` for the same match with page-relative links.

## Example

<!-- tl:ui_navigation_menu -->

```html
<nav tl:replace="~{trellis-ui/navigation-menu :: navigationMenu('Trellis UI docs')}">
  <li>
    <a tl:replace="~{trellis-ui/navigation-menu :: navigationMenuLink('../', './')}">Components</a>
  </li>
  <li tl:replace="~{trellis-ui/navigation-menu :: navigationMenuGroup('reference-guides', 'Guides')}">
    <ul role="list">
      <li>
        <a tl:replace="~{trellis-ui/navigation-menu :: navigationMenuLink('../../guide/', './')}">Using Trellis UI</a>
      </li>
    </ul>
  </li>
  <li tl:replace="~{trellis-ui/navigation-menu :: navigationMenuGroup('reference-patterns', 'Patterns', 'bottom', 'end')}">
    <ul role="list">
      <li>
        <a tl:replace="~{trellis-ui/navigation-menu :: navigationMenuLink('./', './')}">Navigation menu</a>
      </li>
      <li>
        <a tl:replace="~{trellis-ui/navigation-menu :: navigationMenuLink('../accordion/', './')}">Accordion</a>
      </li>
    </ul>
  </li>
</nav>
```

## Keyboard interaction

Enter or Space opens a group. Arrow Down opens it and moves to the first link.
Tab follows the normal document order. While a group is open, focusing another
group trigger opens its panel. Escape closes the panel and returns focus to its
trigger. With a mouse, a brief hover opens the panel and keeps it available when
the pointer moves from the trigger to its links.

## Accessibility notes

Give the landmark a name and each group a title that describes its destinations.
The server renders native disclosures and anchors. When suite assets are unavailable,
readers open the groups with their native controls and follow the same links.
