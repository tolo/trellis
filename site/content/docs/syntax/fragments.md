---
title: Fragments
description: Define reusable pieces with tl:fragment and include them with tl:insert or tl:replace, including cross-file and CSS-selector targeting.
weight: 60
---

Fragments are named, reusable pieces of a template. They are the foundation of
Trellis's HTMX-first design: the same fragment renders inside a full page and,
via `renderFragment()`, as a standalone partial response.

## `tl:fragment` – define a fragment

`tl:fragment` names an element as a reusable fragment. Fragments can take
parameters, listed in parentheses:

```html
<div tl:fragment="card(title, body)">
  <h2 tl:text="${title}">Title</h2>
  <p tl:text="${body}">Body</p>
</div>
```

## `tl:insert` – include, keeping the host element

`tl:insert` renders a fragment *inside* the host element, which is preserved.
Arguments are passed positionally to a parameterized fragment:

```html
<div tl:insert="card('Hello', 'World')">replaced by fragment</div>
```

## `tl:replace` – include, replacing the host element

`tl:replace` renders the fragment *in place of* the host element, which is
discarded:

```html
<div tl:replace="userCard">replaced entirely</div>
```

## Cross-file inclusion

Reference a fragment in another template file with the `~{file :: fragment}`
syntax:

```html
<div tl:insert="~{components :: header}">loads header from components.html</div>
```

## CSS-selector targeting

Instead of a fragment name, target an element in another file by `#id` or
`.class`:

```html
<div tl:insert="~{components :: #main-nav}">loads by id</div>
```

Circular fragment inclusions are detected and reported with the full cycle path.

## Rendering a fragment directly

From Dart, render just a named fragment – this is what an HTMX partial response
returns:

```dart
final fragment = engine.renderFragment(
  pageTemplate,
  fragment: 'itemList',
  context: {'items': items},
);
```
