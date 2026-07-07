---
title: Local Variables & Selection
description: Bind local variables with tl:with and set a selection context with tl:object.
weight: 80
---

Two attributes shape the data available to an element and its children:
`tl:with` binds named local variables, and `tl:object` sets a selection context
for `*{...}` expressions.

## `tl:with` – bind local variables

`tl:with` defines one or more local variables, scoped to the element and its
descendants. Each binding is `name=${expression}`; separate multiple bindings
with commas:

```html
<div tl:with="fullName=${first} + ' ' + ${last}">
  <span tl:text="${fullName}">Name</span>
</div>
```

The variable `fullName` is available anywhere inside the `<div>`.

## `tl:object` – set the selection context

`tl:object` binds an object as the *selection context* for the element's
subtree. Inside it, [selection expressions](/docs/syntax/expressions/) `*{...}`
read fields of that object directly, without repeating its name:

```html
<div tl:object="${user}">
  <span tl:text="*{name}">Name</span>
  <span tl:text="*{email}">Email</span>
</div>
```

The object is read via `toMap()` or `toJson()` if present, otherwise as a
`Map<String, dynamic>`.
