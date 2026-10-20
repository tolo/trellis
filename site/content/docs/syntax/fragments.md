---
title: Fragments
description: Define reusable pieces with tl:fragment and include them with tl:insert or tl:replace, including cross-file and CSS-selector targeting, and render a fragment as a response.
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

## Components

Fragments can also take content and extra attributes from the caller, through
`tl:slot`, `tl:attrs` and a trailing `...rest` parameter. See
[Composition](/docs/syntax/composition/). Those work through name-based
invocation only (`tl:replace="~{file :: name(...)}"`), not CSS-selector targeting.

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

## Rendering a parameterised fragment as a response

`renderFragment`, `renderFragments`, `renderFileFragment` and `renderFileFragments`
(and the Shelf, dart_frog and Relic helpers and the testing helpers built on them)
address a fragment by its **bare name**, even when it declares parameters. A
fragment declared `toast(type, title)` is rendered with `fragment: 'toast'`, and
its parameters resolve from the same-named keys of the render context, like any
other variable:

```html render=toast-top fragment=toast
<div tl:fragment="toast(type, title)" class="toast" tl:classappend="${type}">
  <strong tl:text="${title}">Title</strong>
</div>
```

```json context=toast-top
{"type": "error", "title": "Saved"}
```

```html output=toast-top
<div class="toast error"><strong>Saved</strong></div>
```

An absent key is null, or throws in strict mode, as for any variable. A `...rest`
parameter is bound to an empty map, so a component that spreads it renders in
strict mode too. The result is fully processed.

### An out-of-band toast

htmx swaps out of band only an element that carries `hx-swap-oob`. Put that
attribute on a thin wrapper, not on the toast's own root: the root is also what
every in-page `tl:replace="toast(…)"` renders, and inside an htmx response an
in-page toast carrying `hx-swap-oob` would be pulled out of the main swap. Keep
each wrapper thin: it declares the toast's parameters, carries only `hx-swap-oob`
(and an id where the swap needs one), and invokes `toast` with them, so all toast
markup stays in the one definition.

A stacking swap such as `beforeend` needs the wrapper anyway, because htmx 2
inserts only the *children* of a non-`outerHTML` out-of-band element:

```html render=toast-oob fragment=toastStack
<div tl:fragment="toast(type, title)" class="toast" tl:classappend="${type}">
  <strong tl:text="${title}">Title</strong>
</div>
<div tl:fragment="toastStack(type, title)" hx-swap-oob="beforeend:#toasts">
  <div tl:replace="toast(${type}, ${title})"></div>
</div>
```

```json context=toast-oob
{"type": "error", "title": "Saved"}
```

```html output=toast-oob
<div hx-swap-oob="beforeend:#toasts"><div class="toast error"><strong>Saved</strong></div></div>
```

For an `outerHTML` swap by id, the wrapper takes the id of the element it
replaces as a parameter and sets it with `tl:id`, since a literal id repeats on
every render:

```html render=toast-oob-id fragment=toastById
<div tl:fragment="toast(type, title)" class="toast" tl:classappend="${type}">
  <strong tl:text="${title}">Title</strong>
</div>
<div tl:fragment="toastById(id, type, title)" tl:id="${id}" hx-swap-oob="true">
  <div tl:replace="toast(${type}, ${title})"></div>
</div>
```

```json context=toast-oob-id
{"id": "flash", "type": "error", "title": "Saved"}
```

```html output=toast-oob-id
<div hx-swap-oob="true" id="flash"><div class="toast error"><strong>Saved</strong></div></div>
```

In a handler, list the wrapper beside the main fragment, for example
`renderOobFragments(request, 'todos', ['todo-list', 'toastStack'], context)` with
the Shelf helper; in a page, `tl:replace="toast('error', ${msg})"` renders the same
toast in place.

A fragment name **with arguments** throws, naming the bare name to pass instead:

```html render=toast-args fragment=toast('error','Saved')
<div tl:fragment="toast(type, title)"><strong tl:text="${title}">Title</strong></div>
```

```text throws=toast-args
is addressed with arguments; pass the bare name "toast" instead
```

An empty `()` is read as the bare name.

### The one difference from in-template invocation

Invoked from another template, `tl:replace="toast"` without arguments leaves the
parameters **unpassed, and they stay null** – the context is not consulted. Only
`renderFragment` reads them from the context:

```html file=ui/toast.html
<div tl:fragment="toast(type, title)" class="toast" tl:classappend="${type}">
  <strong tl:text="${title}">Title</strong>
</div>
```

```html render=toast-bare
<div tl:replace="~{ui/toast.html :: toast}"></div>
<div tl:replace="~{ui/toast.html :: toast('warning', 'Careful')}"></div>
```

```json context=toast-bare
{"type": "error", "title": "Saved"}
```

```html output=toast-bare
<div class="toast"><strong></strong></div>
<div class="toast warning"><strong>Careful</strong></div>
```

Both forms of the in-template call are valid; pass arguments when you want values.

Two caveats:

- Two fragments sharing a name is an authoring error with no engine rule: a
  top-level render takes the first in document order, an in-template call the
  last.
- `renderFragments` renders several fragments against **one** context, so two
  fragments that both declare `title` read the same `title`.

Directives on the `tl:fragment` element itself act as they would in place when
the fragment is rendered as a response: a `tl:each` renders one element per item,
a removed root (`tl:if` false, `tl:unless` true, `tl:remove="all"`) renders
nothing and `renderFragments` concatenates the others, and a `tl:replace` renders
its target.
