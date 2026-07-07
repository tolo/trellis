---
title: Attributes
description: Set HTML attributes with tl:attr, the shorthands tl:href / tl:src / tl:value / tl:class / tl:id, and append with tl:classappend / tl:styleappend.
weight: 50
---

Trellis can set any HTML attribute from an expression. There is one generic
attribute, `tl:attr`, plus convenient shorthands for the most common cases.

## `tl:attr` – set any attributes

`tl:attr` sets one or more attributes from a comma-separated list of
`name=${value}` pairs:

```html
<div tl:attr="data-id=${item.id},title=${item.name}">content</div>
```

> **Set multiple attributes with one `tl:attr`.** HTML forbids duplicate
> attribute names, so the HTML5 parser keeps only the first `tl:attr` on an
> element and silently drops the rest – *before* Trellis runs. Always combine
> them into a single comma-separated `tl:attr`. `TemplateValidator` warns when a
> duplicate is detected.

A `null` value removes the attribute. Boolean HTML attributes (`disabled`,
`checked`, and so on) render valueless when `true` and are removed when `false`.

## Shorthand attributes

These shorthands set a single named attribute directly, and read more naturally
than the generic form:

```html
<a tl:href="${url}">link</a>
<img tl:src="${imageUrl}">
<input tl:value="${val}">
<div tl:class="${className}">styled</div>
<div tl:id="${elementId}">identified</div>
```

- `tl:href` sets `href` – pairs naturally with a [URL expression](/docs/syntax/expressions/) `@{...}`.
- `tl:src` sets `src`.
- `tl:value` sets `value`.
- `tl:class` sets `class` – it **replaces** the existing class, it does not append.
- `tl:id` sets `id`.

## `tl:classappend` / `tl:styleappend` – append

Where `tl:class` replaces, these two append to an existing `class` or `style`
attribute, leaving what is already there in place:

```html
<div class="card" tl:classappend="${active} ? 'active' : ''">content</div>
<div style="color:red" tl:styleappend="font-weight:bold">content</div>
```

The first renders `class="card active"` when `active` is truthy.
