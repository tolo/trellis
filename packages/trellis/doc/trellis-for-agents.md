# Trellis — Guide for AI Agents

Concise rules for writing **Trellis** templates correctly and safely. Trellis is a
Thymeleaf-inspired HTML template engine for Dart: templates are valid HTML annotated with
`tl:*` attributes, rendered server-side, fragment-first for HTMX.

> **Using this guide:** reference it from your project's `CLAUDE.md` / `AGENTS.md` so agents read
> it before writing templates — either link this file's URL directly, or vendor a copy into your
> repo (e.g. under `dev/guidelines/`) and link that. A typical index entry:
> `Trellis templates | <path-or-url> | Before writing templates`. Keep project-specific rules in
> your `CLAUDE.md`, not in this file, so it stays a clean, swappable copy.
>
> This is policy, not a full reference — for exact syntax see the
> [README](https://github.com/tolo/trellis/blob/main/packages/trellis/README.md). Verify behavior
> against the `trellis` version your project pins.


## Core principles

- **Escape by default.** Untrusted/user-controlled values go through `tl:text` (or `tl:attr`).
- **Keep templates dumb.** Compute view data in Dart; templates only place prepared values.
- **Trust boundary lives in code.** The code building the context decides what is safe to emit
  as raw HTML — the template cannot.


## Security — the rules that matter most

| Directive | Output | Use for |
|---|---|---|
| `tl:text` | HTML-escaped | **Default** for all text, especially user input |
| `tl:attr` + shorthands (`tl:href`, `tl:src`, `tl:value`, `tl:class`, `tl:id`) | attribute-escaped | All dynamic attribute values |
| `tl:utext` | **raw, unescaped** | **Only** pre-rendered, trusted HTML |
| `tl:attrs` (map spread) | names validated, values HTML-escaped only | Developer-built maps; never untrusted keys, and values under `href`/`src`/`srcdoc`/`on*`/`style` need the same validation as `tl:attr` |

```html
<span tl:text="${title}">Title</span>            <!-- safe default -->
<div  tl:utext="${trustedBodyHtml}">body</div>    <!-- only if already trusted -->
```

If a value *could* contain unsafe HTML, never pass it to `tl:utext`. There is no sanitizer in
the engine — sanitize in Dart before marking something trusted. The inserted HTML is output only:
`tl:*` attributes in it are emitted as-is, never evaluated, so build dynamic markup in the template
or a fragment, not in the value.


## Keep templates dumb

Do these in Dart, not in template expressions:

- format dates and numbers, build labels and messages
- choose CSS classes (`'status-${status.name}'`)
- filter, sort, and shape lists into render-ready view models
- decide which template or fragment to render
- map "absent" to `null` so the template can omit it

```dart
// Good: render-ready context — strings, render-ready lists, null for "omit"
{
  'title': title,
  'statusClass': 'status-${status.name}',
  'subtitle': subtitle.isEmpty ? null : subtitle,
  'items': items.map((i) => {'label': i.label, 'href': i.url}).toList(),
}

// Bad: makes the template finish the job
{
  'rawUserHtml': userInput,                        // unsanitized → XSS if sent to tl:utext
  'items': allItems.where(complexFilter).toList(), // business logic at render time
}
```

Template expressions should stay trivial (a field access, a simple ternary). Push everything
else upstream.


## Core directives

```html
<p   tl:text="${message}">placeholder</p>             <!-- escaped text -->
<div tl:if="${user}">…</div>                          <!-- show if truthy -->
<div tl:unless="${readOnly}">…</div>                  <!-- show if falsy -->
<li  tl:each="item : ${items}" tl:text="${item.label}">…</li>
<div tl:fragment="badge">…</div>                      <!-- reusable partial -->
<div tl:with="full=${first} + ' ' + ${last}">…</div>  <!-- local var -->

<a   tl:href="${url}">link</a>                        <!-- attribute shorthands -->
<input tl:value="${title}">
<div tl:class="${statusClass}">
<div class="card" tl:classappend="${active} ? 'active' : ''">  <!-- append, not replace -->
<input tl:attr="value=${title},data-id=${id}">        <!-- generic / multiple attrs -->
```

Truthiness: non-null, non-false, non-zero, not `"false"`/`"off"`/`"no"`. **Empty strings and
empty lists are truthy** — guard with `null` (or an explicit length check), not `""`/`[]`.

Prefer the dedicated shorthands for common attributes; use `tl:attr` for anything else.


## Components

A fragment is a component when it takes content slots, spread attributes or both
(syntax: [composition guide](https://tolo.github.io/trellis/docs/syntax/composition/)):

```html
<!-- ui/field.html: define -->
<label tl:fragment="field(label, name, ...attrs)" class="field">
  <span tl:text="${label}">Label</span>
  <input type="text" tl:attr="name=${name}" tl:attrs="${attrs}">
  <small tl:slot="hint"></small>
</label>

<!-- use: host attributes go to ...attrs, direct children fill slots -->
<div tl:replace="~{ui/field.html :: field('Email', 'email')}" type="email" required>
  <span tl:slot="hint">We never share your email.</span>
</div>
```

- **Invoke with `tl:replace`.** The host disappears, so `...attrs` is the only way its attributes survive.
- **A marker must be a direct child of the host**; the marker element is discarded and its children move in.
  Use `<tl:block tl:slot="x">` for several siblings, but not inside a `<table>`.
- **Defaults live as literal attributes** (`type="text"`) that `tl:attrs` overwrites; do not probe the map
  (`${attrs.type} ?: 'text'` throws in strict mode).
- **A filled region drops its own `tl:text`/`tl:utext`/`tl:insert`/`tl:replace`**; unfilled, they are the default.
- **`<tr tl:slot>` under a `<table>` host is lost** (implicit `<tbody>`); mark `<tbody tl:slot>` or host on a `<tbody>`.
- **`renderFragment()` takes the bare name** even for `toast(type, title)`; parameters come from same-named
  context keys and `...attrs` is an empty map. In-template `tl:replace="toast"` leaves parameters null.
- **No literal `id` in a parameterised component**: it repeats per use. Set it with `tl:id`.


## Footguns (these fail silently — the engine warns, it does not fix)

- **One `tl:attr` per element.** HTML forbids duplicate attribute names, so two `tl:attr` on the
  same element → the parser keeps the first and drops the rest *before Trellis runs*. Put every
  dynamic attribute in a single comma-separated `tl:attr` (or use shorthands).
- **Don't wrap `<tr>`/`<option>` in `<tl:block>`.** Inside `<table>`/`<select>` the HTML5 parser
  foster-parents unknown tags out of the element, detaching the loop scope (symptom: right row
  count, empty cells). Put `tl:each` directly on the `<tr>`/`<option>`.
- A `null` attribute value **removes** the attribute; boolean attrs render valueless on `true`,
  vanish on `false`.


## Integration (HTMX)

- Render full pages and fragments from the same templates; return fragments via
  `renderFragment()` / `renderFragments()` for HTMX swaps.
- Reuse a preloaded/cached template source when rendering the same fragment repeatedly.
- Keep dynamic URLs in the context (`tl:href` / `tl:attr`); keep static HTMX attributes
  (`hx-get`, `hx-target`, …) hardcoded in the markup.
- Keep template structure stable so CSS, HTMX, and tests can target it reliably.


## Validate

Treat templates as code under test:

```dart
import 'package:trellis/testing.dart';
expect(myTemplateSource, isValidTemplate());   // in `dart test`
```

```bash
dart run trellis:validate --strict             # CI gate; --strict makes warnings fail
```

`--strict` is required in CI: the silent-mutation issues above are reported as *warnings*, so a
plain run still exits `0`.


## Checklist

- [ ] `tl:text` is the default for text; `tl:utext` only for trusted, pre-rendered HTML
- [ ] Dynamic attributes use a shorthand or a single `tl:attr`
- [ ] Conditions and loop bodies are trivial; data is shaped in Dart
- [ ] Fragments used for independently rendered (HTMX) partials
- [ ] `null` (not `""`/`[]`) signals "omit"
- [ ] Templates validate clean under `trellis:validate --strict`


## Full reference

- Engine README & syntax: <https://github.com/tolo/trellis/blob/main/packages/trellis/README.md>
- Framework integration (Shelf, Dart Frog, Relic, HTMX): <https://github.com/tolo/trellis/blob/main/docs/guides/framework-integration.md>
- API docs: <https://pub.dev/documentation/trellis/latest/>
- Doc index for agents (`llms.txt`): <https://github.com/tolo/trellis/blob/main/llms.txt>
