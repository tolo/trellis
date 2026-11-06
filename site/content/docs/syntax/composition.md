---
title: Composition
description: Build reusable components from plain fragments with content slots (tl:slot), attribute spreading (tl:attrs) and the ...rest fragment parameter.
weight: 65
---

A component in Trellis is a [fragment](/docs/syntax/fragments/) that accepts
parameters, content and extra attributes from its caller. Three primitives
provide that, with no new elements and no new expression syntax:

- **`tl:slot`** – the caller hands markup to named regions of the fragment.
- **`tl:attrs="${map}"`** – spread a map onto an element as attributes
  ([reference](/docs/syntax/attributes/)).
- **`...rest` parameter** – a trailing fragment parameter that receives the
  attributes written on the invoking element.

Both the component file and the template that uses it stay valid HTML, so each
opens in a browser as a prototype.

> The examples on this page are executed by the Trellis test suite. Each
> `file=` fence is a template in the page's loader, each `render=` fence is
> rendered with the `context=` JSON beside it, and the result is checked
> against the `output=` fence. Output whitespace is collapsed for display.

## A component and its use

The component file declares parameters, a rest parameter and two slots:

```html file=ui/field.html
<label tl:fragment="field(label, name, ...attrs)" class="field">
  <span class="field-label" tl:text="${label}">Label</span>
  <input class="field-input" type="text" tl:attr="name=${name}" tl:attrs="${attrs}">
  <span class="field-hint" tl:slot="hint"></span>
</label>
```

```html file=ui/dialog.html
<dialog tl:fragment="dialog(id, title, ...attrs)" class="dialog" tl:id="${id}" tl:attrs="${attrs}">
  <header><h2 tl:text="${title}">Title</h2></header>
  <div class="dialog-body" tl:slot>Body</div>
  <footer tl:slot="footer"><button>Close</button></footer>
</dialog>
```

The page invokes them with `tl:replace`:

```html render=field-dialog
<div tl:replace="~{ui/field.html :: field('Email', 'email')}"
     type="email" required hx-post="/validate" hx-trigger="blur">
  <span tl:slot="hint">We never share your email.</span>
</div>

<div tl:replace="~{ui/dialog.html :: dialog('confirm', 'Delete item?')}">
  <p>This action cannot be undone.</p>
  <tl:block tl:slot="footer">
    <button tl:attr="hx-delete=@{/items(id=${item.id})}">Delete</button>
    <button>Cancel</button>
  </tl:block>
</div>
```

```json context=field-dialog
{"item": {"id": 7}}
```

```html output=field-dialog
<label class="field">
  <span class="field-label">Email</span>
  <input class="field-input" type="email" required="" hx-post="/validate" hx-trigger="blur" name="email">
  <span class="field-hint">We never share your email.</span>
</label>
<dialog class="dialog" id="confirm">
  <header><h2>Delete item?</h2></header>
  <div class="dialog-body"><p>This action cannot be undone.</p></div>
  <footer>
    <button hx-delete="/items?id=7">Delete</button>
    <button>Cancel</button>
  </footer>
</dialog>
```

The `type`, `required` and `hx-*` attributes written on the host landed on the
`<input>` inside the component, and the caller's text replaced the hint's empty
fallback.

## Content slots – `tl:slot`

### Defining slots

Inside a fragment, any element may carry `tl:slot="name"`. Its children are the
**fallback content**. A bare `tl:slot` marks the single anonymous (default)
slot. Each slot name may be declared once per fragment, and the fragment's own
root element cannot be a slot: declare the region on an inner element.

A region may carry its own directives. When the caller fills the region, its
`tl:text`, `tl:utext`, `tl:insert` and `tl:replace` are dropped so the caller's
content shows. Unfilled, they render as the default, which suits a slot that
falls back to a parameter. `tl:if`, `tl:each` and `tl:attr` apply either way.

```html file=ui/popover.html
<div tl:fragment="popover(label)" class="popover">
  <button tl:slot="trigger" tl:text="${label}">Open</button>
  <div class="popover-body" tl:slot>Details</div>
</div>
```

```html render=slot-default-text
<div tl:replace="~{ui/popover.html :: popover('Menu')}"></div>

<div tl:replace="~{ui/popover.html :: popover('Menu')}">
  <i tl:slot="trigger">Custom</i>
</div>
```

```html output=slot-default-text
<div class="popover"><button>Menu</button><div class="popover-body">Details</div></div>
<div class="popover"><button>Custom</button><div class="popover-body">Details</div></div>
```

### Filling slots

The **direct children** of the element carrying `tl:insert` or `tl:replace`
provide the content:

- A direct child with `tl:slot="name"` fills the slot of that name. Several
  markers for the same slot concatenate in document order.
- Unmarked children fill the anonymous slot, **if the fragment declares one**.
  Otherwise they are discarded, as invocation placeholders always have been.
- Whitespace-only text never counts as unmarked content (ASCII whitespace only:
  a child holding just `&nbsp;` is content), and neither do HTML comments, so a
  pretty-printed call that fills only named slots keeps the anonymous slot's
  fallback.
- A slot with no marker keeps its fallback. A marker with no children clears it.

```html file=ui/card.html
<article tl:fragment="card(title)" class="card">
  <h3 tl:text="${title}">Title</h3>
  <div class="card-body" tl:slot>Default body</div>
  <footer tl:slot="footer">Default footer</footer>
</article>
```

```html render=card-slots
<div tl:replace="~{ui/card.html :: card('A')}"></div>

<div tl:replace="~{ui/card.html :: card('B')}"><p>Body text</p></div>

<div tl:replace="~{ui/card.html :: card('C')}">
  <b tl:slot="footer">Only the footer</b>
</div>

<div tl:replace="~{ui/card.html :: card('D')}">
  <i tl:slot="footer">one</i>
  <i tl:slot="footer">two</i>
</div>
```

```html output=card-slots
<article class="card"><h3>A</h3><div class="card-body">Default body</div><footer>Default footer</footer></article>
<article class="card"><h3>B</h3><div class="card-body"><p>Body text</p></div><footer>Default footer</footer></article>
<article class="card"><h3>C</h3><div class="card-body">Default body</div><footer>Only the footer</footer></article>
<article class="card"><h3>D</h3><div class="card-body">Default body</div><footer>onetwo</footer></article>
```

### The merge model: the marker is discarded

A slot fills like a `tl:define` block override
([inheritance](/docs/syntax/inheritance/)): the region element in the fragment
is **kept** and only its children are replaced. The caller's marker element is
**discarded** and its children move in. In case C above the `<b>` is gone and
`<footer>` holds its text.

This differs from the web-component `<slot>` you may know, where the filler
element itself is projected into the slot. To contribute several elements with
no wrapper, use `<tl:block tl:slot="name">` (not inside a table, see below).

### Scope: slot content sees the fragment's variables

Slot content is grafted into the fragment before it is processed, so it sees the
fragment's variables: the caller's context plus the fragment's parameters and
locals. A fragment parameter **shadows** a same-named caller variable inside slot
content:

```html render=card-scope
<div tl:replace="~{ui/card.html :: card('Fragment title')}">
  <p><span tl:text="${title}">x</span></p>
</div>
```

```json context=card-scope
{"title": "Caller title"}
```

```html output=card-scope
<article class="card"><h3>Fragment title</h3><div class="card-body"><p><span>Fragment title</span></p></div><footer>Default footer</footer></article>
```

The same rule makes a **scoped slot** work: a `tl:slot` region inside the
fragment's own `tl:each` is cloned per iteration, and the caller's markup sees
the loop variable.

```html file=ui/table.html
<table>
  <tbody tl:fragment="table(rows)">
    <tr tl:each="row : ${rows}" tl:slot="row"><td tl:text="${row.name}">Name</td></tr>
  </tbody>
</table>
```

```html render=table-rows
<table>
  <tbody tl:replace="~{ui/table.html :: table(${people})}">
    <tr tl:slot="row"><td tl:text="${row.name}">Name</td><td>!</td></tr>
  </tbody>
</table>
```

```json context=table-rows
{"people": [{"name": "Ada"}, {"name": "Grace"}]}
```

```html output=table-rows
<table>
  <tbody>
    <tr><td>Ada</td><td>!</td></tr>
    <tr><td>Grace</td><td>!</td></tr>
  </tbody>
</table>
```

### Which element can be a marker

The HTML5 parser reshapes a document before Trellis sees it, so a marker must be
an element the parser accepts as a child of the host: `<tr>` and `<td>` only
when the host sits inside a real `<table>` (as above), `<option>` when the host
is a `<select>`, and `<span>`, `<tl:block>` and most other elements everywhere
else. This is an authoring rule, not a runtime check. To fill a `<select>` from a
non-`select` host, mark an `<optgroup tl:slot>` holding real `<option>` elements.
Definition-side regions can be `<tr>` or `<option>` freely, because they already
sit in table or select context.

The parser also wraps `<tr>` children of a `<table>` in an implicit `<tbody>`. A
`<tr tl:slot>` written directly under a `<table>` host is therefore not a direct
child, and its fill is lost. `<thead>`, `<tbody>`, `<tfoot>`, `<caption>` and
`<colgroup>` markers need a `<table>` host: under a `<div>` host the parser drops
them. So a table component that takes a header and rows in one call declares a
region per section, and the caller marks whole sections:

```html file=ui/data-table.html
<table tl:fragment="data-table(rows)" class="data-table">
  <thead tl:slot="head"><tr><th>Name</th></tr></thead>
  <tbody tl:slot="body"><tr tl:each="row : ${rows}"><td tl:text="${row.name}">Name</td></tr></tbody>
</table>
```

```html render=table-sections
<table tl:replace="~{ui/data-table.html :: data-table(${people})}">
  <thead tl:slot="head"><tr><th>Person</th></tr></thead>
</table>

<table tl:replace="~{ui/data-table.html :: data-table(${people})}">
  <tbody tl:slot="body"><tr><td>Fixed</td></tr></tbody>
</table>
```

```json context=table-sections
{"people": [{"name": "Ada"}, {"name": "Grace"}]}
```

```html output=table-sections
<table class="data-table">
  <thead><tr><th>Person</th></tr></thead>
  <tbody><tr><td>Ada</td></tr><tr><td>Grace</td></tr></tbody>
</table>
<table class="data-table">
  <thead><tr><th>Name</th></tr></thead>
  <tbody><tr><td>Fixed</td></tr></tbody>
</table>
```

To repeat a caller row per item, as in the scoped-slot example above, make the
host a `<tbody>` inside the page's own `<table>` and mark `<tr>` children.

### Nested regions

A `tl:slot` inside another region's fallback is part of that fallback, not a
second declaration. A caller marker can therefore not name the inner slot, and
filling the outer slot removes the inner one with the rest of the fallback.

### Gating a marker with `tl:if` / `tl:unless`

`tl:if` and `tl:unless` on a caller-side marker decide whether it contributes. A
falsy gate contributes nothing, and the slot keeps its fallback if no other
marker fills it.

```html render=gate-off
<div tl:replace="~{ui/card.html :: card('G')}">
  <b tl:slot="footer" tl:if="${showFooter}">Shown</b>
</div>
```

```json context=gate-off
{"showFooter": false}
```

```html output=gate-off
<article class="card"><h3>G</h3><div class="card-body">Default body</div><footer>Default footer</footer></article>
```

The gate is evaluated when the content is grafted, **before** the fragment
processes its own `tl:each`, so a loop variable of the fragment does not exist
yet. Gating a marker on one throws in strict mode:

```html render=gate-timing
<table>
  <tbody tl:replace="~{ui/table.html :: table(${people})}">
    <tr tl:slot="row" tl:if="${row.name == 'Ada'}"><td>Ada only</td></tr>
  </tbody>
</table>
```

```json context=gate-timing
{"people": [{"name": "Ada"}]}
```

```text throws=gate-timing
Undefined variable: "row"
```

Gate on caller-side data, or put the condition inside the slot content.

### Errors

These throw `TemplateException`, and a marker is checked before its `tl:if` or
`tl:unless` runs, so a mistake fails regardless of the data:

```html render=unknown-slot
<div tl:replace="~{ui/card.html :: card('H')}"><b tl:slot="sidebar">x</b></div>
```

```text throws=unknown-slot
targets a slot fragment "card" does not declare
```

```html render=bare-marker
<div tl:replace="~{ui/field.html :: field('Name', 'name')}"><b tl:slot>x</b></div>
```

```text throws=bare-marker
targets the anonymous slot, which fragment "field" does not declare
```

Unmarked children draw no error when there is no anonymous slot, but a bare
`tl:slot` marker does, because a marker states an intent to fill. Any other
`tl:*` attribute on a marker throws, so a replicated contribution via `tl:each`
is not available:

```html render=marker-each
<div tl:replace="~{ui/card.html :: card('I')}">
  <b tl:slot="footer" tl:each="x : ${xs}">x</b>
</div>
```

```json context=marker-each
{"xs": [1, 2]}
```

```text throws=marker-each
only tl:if and tl:unless may accompany tl:slot
```

A duplicate slot name in one fragment, `tl:slot` on the `tl:fragment` element
itself, and a `tl:slot` in the unmarked content of an inner host inside a
definition ([below](#composing-slotted-fragments)) also throw when the fragment
is invoked.

Slots, like the rest parameter, work through **name-based** invocation only.
`~{file :: #id}` and tag-name targets never bound parameters, and a marker on
such an invocation throws the unknown-slot error. A `tl:slot` outside any
fragment is inert: the attribute is dropped and the content stays.

### A marker must be a direct child of the host

Only literal direct children count. On a page, a marker nested deeper, or inside
a `<tl:block>` wrapper, is not looked through: it is inert and its container
becomes unmarked content. Inside a fragment definition the same shape is an
error, see [Composing slotted fragments](#composing-slotted-fragments).

```html render=nested-marker
<div tl:replace="~{ui/dialog.html :: dialog('d', 'Title')}">
  <div><span tl:slot="footer">Never bound</span></div>
</div>
```

```html output=nested-marker
<dialog class="dialog" id="d">
  <header><h2>Title</h2></header>
  <div class="dialog-body"><div><span>Never bound</span></div></div>
  <footer><button>Close</button></footer>
</dialog>
```

`TemplateValidator` warns about this mistake, see [Validation](#validation).

### Composing slotted fragments

A fragment can invoke another from inside its own definition. A marker binds to
its **nearest** enclosing host, so the direct-child markers of the inner host are
that invocation's contribution, not slots of the outer fragment. To pass a slot
through, **re-mark** it: put a `tl:slot` region inside the contribution. The
outer fragment then declares it, and its caller fills it as usual. A bare
`<tl:block tl:slot>` contribution forwards its content into the inner fragment's
anonymous slot the same way:

```html file=ui/confirm.html
<section tl:fragment="confirm(title)" class="confirm">
  <div tl:replace="~{ui/dialog.html :: dialog('confirm', ${title})}">
    <tl:block tl:slot>
      <p tl:slot="message">Are you sure?</p>
    </tl:block>
    <tl:block tl:slot="footer">
      <span tl:slot="actions"><button>OK</button></span>
    </tl:block>
  </div>
</section>
```

```html render=confirm-forward
<div tl:replace="~{ui/confirm.html :: confirm('Delete item?')}">
  <p tl:slot="message">This cannot be undone.</p>
  <tl:block tl:slot="actions"><button>Delete</button><button>Cancel</button></tl:block>
</div>

<div tl:replace="~{ui/confirm.html :: confirm('Archive item?')}"></div>
```

```html output=confirm-forward
<section class="confirm">
  <dialog class="dialog" id="confirm">
    <header><h2>Delete item?</h2></header>
    <div class="dialog-body"><p>This cannot be undone.</p></div>
    <footer><span><button>Delete</button><button>Cancel</button></span></footer>
  </dialog>
</section>
<section class="confirm">
  <dialog class="dialog" id="confirm">
    <header><h2>Archive item?</h2></header>
    <div class="dialog-body"><p>Are you sure?</p></div>
    <footer><span><button>OK</button></span></footer>
  </dialog>
</section>
```

A `tl:slot` that sits in the **unmarked** content of the inner host, wrapped in
some other element, is neither: it is not a direct child, so it cannot fill the
inner slot, and nothing says it should declare a slot of the outer fragment.
Rather than guess, the engine throws when the outer fragment is invoked, filled
or not, and even when the inner invocation is gated off by `tl:if`. The message
names the marker, the host directive and the fragment, and points at the two
fixes: make the marker a direct child of the host, or re-mark it inside a
direct-child marker.

```html render=wrapped-marker
<section tl:fragment="confirm">
  <div tl:replace="~{ui/dialog.html :: dialog('c', 'Title')}">
    <p><i tl:slot="footer">OK</i></p>
  </div>
</section>
<div tl:replace="confirm"></div>
```

```text throws=wrapped-marker
is inside the unmarked content of a tl:replace host
```

A host nested in that unmarked content starts over for its own children, and a
nested `tl:fragment` owns its own slots. On a page there is no enclosing
fragment to declare anything, so a wrapped marker stays inert and only draws a
validator warning.

## Attribute spreading – `tl:attrs`

`tl:attrs="${map}"` writes every entry of a map as an attribute, with the merge
rules documented in the [attributes reference](/docs/syntax/attributes/). It is
how a component places the attributes it receives.

## Pass-through – the `...rest` parameter

A fragment opts in to receiving the invoking element's attributes by declaring a
rest parameter, at most one and always last:

```html file=ui/chip.html
<span tl:fragment="chip(label, ...attrs)" class="chip" tl:attrs="${attrs}" tl:text="${label}">Label</span>
```

At invocation the engine binds it to a map of the host's **effective attribute
set**: its literal attributes plus the results of its own attribute directives
(`tl:attr`, the shorthands, `tl:classappend` and `tl:styleappend`, and
`tl:attrs`), evaluated once in the caller's scope, minus every `tl:*` control
attribute. The fragment decides where the map goes. Valueless booleans arrive as
empty strings and render valueless again. Values are opaque strings, so `hx-*` and
`data-*` attributes pass through without the core knowing about them.

```html render=chip-replace
<a tl:replace="~{ui/chip.html :: chip('New')}" class="big" data-id="1"
   tl:classappend="${tone}" tl:attrs="${extra}"></a>
```

```json context=chip-replace
{"tone": "hot", "extra": {"hx-get": "/new"}}
```

```html output=chip-replace
<span class="chip big hot" data-id="1" hx-get="/new">New</span>
```

### Prefer `tl:replace` for components

With `tl:replace` the host element disappears, so forwarding its attributes is
the only way they survive. With `tl:insert` the host stays, applying its own
attribute directives, and the same map is also bound, so spreading it **repeats**
the attributes on the surviving host. `tl:insert` also keeps only the fragment
root's **children**, so a `tl:attrs` spread or `...rest` on the fragment root is
not visible under `tl:insert`. Spread on an inner element instead:

```html file=ui/link.html
<div tl:fragment="link(href, ...attrs)"><a tl:href="${href}" tl:attrs="${attrs}">Open</a></div>
```

```html render=link-insert
<section tl:insert="~{ui/link.html :: link('/x')}" class="host"></section>
```

```html output=link-insert
<section class="host"><a class="host" href="/x">Open</a></section>
```

### Rules

- A rest parameter that is repeated, not last, unnamed or named like a
  positional parameter throws when the fragment definition is collected.
  Whitespace after `...` is ignored, so `... attrs` declares `attrs`.
- An invocation with more positional arguments than the declared non-rest
  parameters throws. Fragments without a rest parameter keep ignoring extras.
- `renderFragment()` binds the rest parameter to an empty map, see
  [rendering a fragment as a response](/docs/syntax/fragments/#rendering-a-parameterised-fragment-as-a-response).

```html render=extra-arg
<div tl:replace="~{ui/field.html :: field('Email', 'email', 'extra')}"></div>
```

```text throws=extra-arg
takes 2 positional argument(s) before its rest parameter
```

### Spread the map, do not probe it

In strict mode, reading a key the map lacks throws before an elvis or ternary can
apply a default, and filters take one argument. A component therefore spreads the
whole map and keeps its defaults as literal attributes that the spread
overwrites, as `field` does with `type="text"`.

```html file=ui/probe.html
<span tl:fragment="probe(...attrs)" tl:text="${attrs.type} ?: 'text'">x</span>
```

```html render=probe-key
<div tl:replace="~{ui/probe.html :: probe}"></div>
```

```text throws=probe-key
Undefined member: "type"
```

## Traps and conventions

| Trap | What happens | Do this |
|---|---|---|
| Slot content shadowing | A fragment parameter hides a same-named caller variable inside slot content | Name parameters distinctly, or pass the value as an argument |
| Self-nesting | A component inside its own slot content trips the name-keyed fragment cycle error | Restructure, or invoke a differently named fragment |
| `<tl:block tl:slot>` in a table | The HTML5 parser foster-parents `<tl:block>` out of `<table>`, detaching its `tl:*` attributes | Mark a real element: `<tr>` or `<td>` |
| Directive on a filled region | A region's own `tl:text`, `tl:utext`, `tl:insert` and `tl:replace` are dropped when the caller fills it | Expect the caller's content to win; put a default there only to show when unfilled |
| `<tr tl:slot>` under a `<table>` host | The parser wraps the rows in an implicit `<tbody>`, so they are not direct children and the fill is lost | Mark `<tbody tl:slot>`, or host on a `<tbody>` |
| Marker timing | `tl:if` on a marker runs before the fragment's `tl:each` | Gate on caller data |
| Dynamic attribute names | `tl:attrs` is the first place a name, not only a value, is decided at runtime | Names are validated and `tl:`-prefixed keys throw, but never build the map from untrusted keys |
| Mixed-case keys | `Class` or `ID` replaces the existing `class` or `id` instead of appending | Write spread keys lowercase; only the exact keys `class` and `style` append |
| `data-*` camel case | HTML parsers lowercase attribute names, so `data-myFoo` never reaches `dataset.myFoo` | Use lowercase names |
| Custom dialects | `slot` and `attrs` are now built-in `tl:*` names; a dialect processor registered under either name runs alongside the built-in slot or spread handling, silently | Rename the custom attribute |

The self-nesting case, for reference:

```html render=self-nesting
<div tl:replace="~{ui/card.html :: card('Outer')}">
  <div tl:replace="~{ui/card.html :: card('Inner')}">inner</div>
</div>
```

```text throws=self-nesting
Fragment cycle detected
```

## Validation

`TemplateValidator` (and `dart run trellis:validate`) reports these composition
mistakes:

- A `tl:slot` marker under a visible `tl:insert`/`tl:replace` host that is not
  the host's literal direct child. On a page it can never bind, so this is a
  **warning**. Inside a fragment definition it is an **error** with the engine's
  message, see [Composing slotted fragments](#composing-slotted-fragments); a
  marker inside one of the host's direct-child markers re-marks a region and is
  clean. A marker with no host in the same document is assumed to be a
  definition-side region and is not reported. The error is reported for a
  wrapped marker inside any fragment definition, because invoking it by name
  throws, even where the definition is only rendered inline, by
  `renderFragment` or by selector, which leave the marker inert.
- A literal `id` on or inside a parameterized fragment (a **warning**). The fragment may render
  several times on one page, repeating the id. Set it per use with `tl:id` or
  `tl:attrs`. Parameterless fragments are the usual HTMX swap-target pattern
  (`tl:fragment="todo-list"` around `<div id="todo-list">`) and never warn; a
  literal `id` that `tl:id` or a `tl:attr` `id` binding overrides is a prototype
  placeholder and does not warn either.

The id check does not model which markup the render discards, so two shapes warn
although the `id` never repeats: a parameterized swap target with a literal root
`id`, and a literal `id` on prototype content that is replaced at render time (an
element carrying `tl:replace`, or a child of a `tl:text` element). Move the `id`
to `tl:id`, make the fragment parameterless, or drop the prototype `id`.
`isValidTemplate()` treats warnings as failures, and `dart run trellis:validate --strict`
exits non-zero on them.
