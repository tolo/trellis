---
title: Output Control
description: Strip elements from output with tl:remove, and render children without a wrapper using the <tl:block> virtual element.
weight: 100
---

These two features control what actually reaches the output HTML: `tl:remove`
strips elements or their tags, and `<tl:block>` groups content without emitting a
wrapper element.

## `tl:remove` – strip from output

`tl:remove` removes an element, its children, or just its tag, depending on the
mode:

```html
<div tl:remove="all">removed entirely from output</div>
<div tl:remove="body">tag kept, children removed</div>
<div tl:remove="tag">children kept, tag removed</div>
<ul tl:remove="all-but-first"><li>kept</li><li tl:remove="all">removed</li></ul>
<div tl:remove="none">kept as-is (prototype marker)</div>
```

The modes are:

- `all` – remove the element and its children entirely.
- `body` – keep the tag, remove its children.
- `tag` – keep the children, remove the surrounding tag.
- `all-but-first` – keep only the first child of this element (handy to trim a
  prototype list down to one row).
- `none` – keep everything as-is; useful as an explicit prototype marker.

A common use is stripping placeholder rows that exist only so the raw template
previews nicely in a browser.

## `<tl:block>` – the virtual element

`<tl:block>` is not an attribute – it is a *virtual element*. It renders only its
children; the `<tl:block>` tag itself is never emitted. This lets you attach a
`tl:*` attribute (such as `tl:each`) to a group of siblings without introducing a
wrapper element in the output:

```html
<tl:block tl:each="item : ${items}">
  <dt tl:text="${item.key}">key</dt>
  <dd tl:text="${item.value}">value</dd>
</tl:block>
```

The output contains the repeated `<dt>`/`<dd>` pairs with no wrapping element.
The self-closing form is also supported:

```html
<tl:block tl:utext="${bodyHtml}"/>
```

> **Do not wrap `<table>` or `<select>` rows in a `<tl:block>`.** Inside those
> elements the HTML5 parser foster-parents unknown tags (like `<tl:block>`) out
> of the table *before* Trellis runs, detaching the loop scope – the symptom is
> the right number of rows but empty cells. Put `tl:each` directly on the `<tr>`
> or `<option>` instead. `TemplateValidator` warns when this happens.
