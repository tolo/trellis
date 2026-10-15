---
title: Attributes
description: Set HTML attributes with tl:attr, the shorthands tl:href / tl:src / tl:value / tl:class / tl:id, append with tl:classappend / tl:styleappend, and spread a map with tl:attrs.
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

## `tl:attrs` – spread a map of attributes

`tl:attrs` takes a single expression that evaluates to a `Map` and writes each
entry as an attribute. It is how a [component](/docs/syntax/composition/) places
the attributes it receives through a `...rest` parameter.

```html render=attrs-merge
<a href="/a" class="btn" style="color:red" tl:attrs="${attrs}" tl:href="@{/z}">go</a>
```

```json context=attrs-merge
{"attrs": {"href": "/m", "class": "wide", "style": "top:0", "data-n": 1}}
```

```html output=attrs-merge
<a href="/z" class="btn wide" style="color:red; top:0" data-n="1">go</a>
```

The merge rules:

- **Spread runs first** in the attribute group, so the element's own `tl:attr`,
  shorthands, `tl:classappend` and `tl:styleappend` override spread entries. Above,
  `tl:href` beat the map's `href`.
- Against literal attributes an entry **overwrites**, except `class` and `style`,
  which **append**. `tl:class` remains the explicit full replace.
- Values behave as in `tl:attr`: `null` removes the attribute, `true` renders a
  boolean attribute valueless and `false` removes it.
- A `null` map is a no-op.

```html render=attrs-values
<input title="old" tl:attrs="${attrs}">
```

```json context=attrs-values
{"attrs": {"title": null, "disabled": true, "required": false, "value": "v"}}
```

```html output=attrs-values
<input disabled="" value="v">
```

Attribute **names** come from the map at runtime, which no other directive does,
so they are validated. A name must match `^[A-Za-z][A-Za-z0-9_:.-]*$`, a non-`Map`
value throws, and a key starting with the configured attribute prefix (`tl:` by
default, compared case-insensitively) throws, so a spread map can carry data but
never a directive:

```html render=attrs-prefix
<div tl:attrs="${attrs}"></div>
```

```json context=attrs-prefix
{"attrs": {"tl:remove": "all"}}
```

```text throws=attrs-prefix
starts with the directive prefix
```

```html render=attrs-not-a-map
<div tl:attrs="${attrs}"></div>
```

```json context=attrs-not-a-map
{"attrs": "class=x"}
```

```text throws=attrs-not-a-map
tl:attrs expects a Map but got String
```

```html render=attrs-bad-name
<div tl:attrs="${attrs}"></div>
```

```json context=attrs-bad-name
{"attrs": {"1st": "x"}}
```

```text throws=attrs-bad-name
illegal attribute name "1st"
```

Keys are **case-sensitive; write them lowercase**. `class` appends, but `Class`
passes the name check and writes a second attribute:

```html render=attrs-case
<p class="a" tl:attrs="${attrs}"></p>
```

```json context=attrs-case
{"attrs": {"Class": "b"}}
```

```html output=attrs-case
<p class="a" Class="b"></p>
```

An element carries at most one `tl:attrs` (the HTML5 parser drops duplicates, as
with `tl:attr`).
