---
title: Text
description: Set element text with tl:text (escaped) and tl:utext (unescaped HTML).
weight: 20
---

Two attributes replace an element's body with a value: `tl:text` escapes the
result, and `tl:utext` inserts it as raw HTML.

## `tl:text` – escaped text

`tl:text` replaces the element's content with the value of an expression,
HTML-escaping it. This is the safe default and guards against XSS:

```html
<p tl:text="${message}">placeholder</p>
```

Rendering with `{'message': 'Hello & welcome'}` produces:

```html
<p>Hello &amp; welcome</p>
```

The placeholder (`placeholder`) is only shown when the raw template is opened in
a browser without rendering; `tl:text` replaces it at render time.

## `tl:utext` – unescaped HTML

`tl:utext` inserts the value as raw, unescaped HTML into the element body. Use it
only with content you trust, since it does **not** protect against XSS:

```html
<div tl:utext="${richContent}">placeholder</div>
```

With `{'richContent': '<strong>Bold</strong>'}` this renders:

```html
<div><strong>Bold</strong></div>
```

> **Security:** `tl:text` always escapes and is safe for user-supplied data.
> Reserve `tl:utext` for trusted, pre-sanitized HTML.
