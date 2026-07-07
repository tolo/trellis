---
title: Getting Started
description: Install Trellis, render your first template, and learn the core principles behind natural HTML templates.
weight: 10
---

This page takes you from zero to a rendered template. You will install the
engine, render your first `tl:text` example, and learn the handful of principles
that make Trellis templates *natural HTML*.

## Requirements

- Dart SDK `^3.10.0`

## Installation

Add the engine to an existing Dart project:

```bash
dart pub add trellis
```

That single command installs the `trellis` package. Its only runtime dependency
is `package:html`, the Dart team's HTML5 parser.

## Your first template

A Trellis template is ordinary HTML. You bind data by adding `tl:*` attributes.
The `tl:text` attribute replaces an element's body with an escaped value:

```dart
import 'package:trellis/trellis.dart';

final engine = Trellis();

final html = engine.render(
  '<h1 tl:text="${title}">Default Title</h1>',
  {'title': 'Hello, Trellis!'},
);
```

The call above returns:

```html
<h1>Hello, Trellis!</h1>
```

Notice two things:

- The placeholder text (`Default Title`) is what a browser shows when it opens
  the raw template file directly – so a designer can preview the layout with no
  server. At render time `tl:text` **replaces** that placeholder with the value
  of `${title}`.
- The output is HTML-escaped. `tl:text` always escapes, so it is safe against
  XSS. (For trusted, pre-rendered HTML, use
  [`tl:utext`](/docs/syntax/text/) instead.)

## A slightly larger example

Real templates loop, bind attributes, and build URLs. Here a list of posts is
rendered with [`tl:each`](/docs/syntax/iteration/),
[`tl:text`](/docs/syntax/text/), and the URL expression `@{...}`:

```html
<article tl:each="post : ${posts}">
  <h2 tl:text="${post.title}">Title</h2>
  <p tl:text="${post.summary}">Summary</p>
  <a tl:href="@{/posts(id=${post.id})}">Read more</a>
</article>
```

Rendered from Dart – synchronous, AOT-safe, no reflection:

```dart
import 'package:trellis/trellis.dart';

final engine = Trellis();

final html = engine.render(pageTemplate, {
  'posts': [
    {'id': 1, 'title': 'First', 'summary': 'Intro post'},
    {'id': 2, 'title': 'Second', 'summary': 'More writing'},
  ],
});
```

## Core principles

A few ideas run through every part of Trellis:

- **Templates are valid HTML.** Every construct is expressed with `tl:*`
  attributes (or the `<tl:block>` virtual element), so the file parses and
  previews as HTML with no special tooling.
- **Fragment-first.** `tl:fragment` defines a reusable piece, and
  `renderFragment()` renders just that piece – which maps directly to an HTMX
  partial response. The same template serves full pages and dynamic fragments.
- **Sync-first API.** `render()` is synchronous. `renderFile()` is async only
  because it performs file I/O.
- **No reflection.** The rendering context is a plain `Map<String, dynamic>`,
  which keeps Trellis compatible with Dart AOT compilation (`dart compile exe`).
- **Escape by default.** `tl:text` always HTML-escapes. Unescaped output is
  opt-in via `tl:utext`, for trusted content only.

## HTML5-valid attribute names

If you need templates that pass strict HTML5 validation, configure a
hyphenated prefix and use `data-tl-*` attributes instead of `tl:*`:

```dart
final engine = Trellis(prefix: 'data-tl');
```

```html
<p data-tl-text="${message}">placeholder</p>
```

## Next steps

You can now install Trellis and render a template. Next, work through the
[Syntax Reference](/docs/syntax/) to learn every attribute and expression form –
start with [Expressions](/docs/syntax/expressions/), the language you write
inside every `tl:*` attribute.
