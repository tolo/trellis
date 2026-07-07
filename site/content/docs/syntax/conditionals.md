---
title: Conditionals
description: Show or hide content with tl:if and tl:unless, and branch on a value with tl:switch and tl:case.
weight: 30
---

Trellis has two conditional mechanisms: `tl:if` / `tl:unless` for a single
boolean test, and `tl:switch` / `tl:case` for multi-branch selection.

## `tl:if` – render when truthy

`tl:if` keeps the element (and its children) only when the expression is truthy:

```html
<div tl:if="${user}">Welcome back!</div>
```

## `tl:unless` – render when falsy

`tl:unless` is the inverse: it keeps the element only when the expression is
falsy:

```html
<div tl:unless="${loggedIn}">Please log in.</div>
```

### Truthiness rules

A value is **truthy** when it is non-null, not `false`, non-zero, and not the
strings `"false"`, `"off"`, or `"no"`. Note that empty strings and empty lists
are truthy.

## `tl:switch` / `tl:case` – multi-branch

`tl:switch` sets a value on the container; each child `tl:case` renders only if
its value matches. The wildcard `tl:case="*"` is the default branch:

```html
<div tl:switch="${role}">
  <p tl:case="admin">Admin view</p>
  <p tl:case="user">User view</p>
  <p tl:case="*">Guest view</p>
</div>
```

With `{'role': 'user'}` only the `User view` paragraph is emitted; with an
unmatched role, the `*` branch renders `Guest view`.
