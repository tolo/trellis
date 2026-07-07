---
title: Trellis
description: A pure-Dart SDK for building server-rendered web applications and static sites – without Node.js, JavaScript frameworks, or a build toolchain.
layout: home
---

## Modern web apps in pure Dart

Trellis is a pure-Dart SDK for building server-rendered web applications and
static sites – without Node.js, JavaScript frameworks, or a build toolchain. It
starts with a [Thymeleaf](https://www.thymeleaf.org/)-inspired template engine
whose templates are *valid HTML* – browsers render them as prototypes without a
server – and grows into a composable set of packages for server integration,
static site generation, CSS, and hot reload. Use just the engine, or the whole
SDK. One language, one toolchain, one binary.

## Why Trellis

- **Natural HTML templates** – templates are valid HTML with `tl:*` attributes;
  designers and browsers can open them directly, no server required.
- **HTMX-first fragments** – `tl:fragment` + `renderFragment()` map directly to
  HTMX partial responses and out-of-band swaps, so the same templates serve full
  pages and dynamic fragments with no duplication.
- **Pure-Dart toolchain** – HTML, Markdown, and SASS are all Dart packages. No
  Node.js, no webpack, no external binaries – one language across templates,
  server, styles, and tooling.
- **Single-binary deploy** – `dart compile exe` produces one file with instant
  startup and tiny containers, so shipping is a single artifact.

## See it

Templates are just HTML you can open in a browser. Add `tl:*` attributes to bind
data, loop, and swap content:

```html
<article tl:each="post : ${posts}">
  <h2 tl:text="${post.title}">Title</h2>
  <p tl:text="${post.summary}">Summary</p>
  <a tl:href="@{/posts(id=${post.id})}">Read more</a>
</article>
```

Render from Dart – sync, AOT-safe, no reflection:

```dart
import 'package:trellis/trellis.dart';

final engine = Trellis();

final html = engine.render(
  '<h1 tl:text="${title}">Default Title</h1>',
  {'title': 'Hello, Trellis!'},
);
// <h1>Hello, Trellis!</h1>
```

## Get started

- [**Get Started**](/docs/) – read the docs and build your first Trellis site.
- [**GitHub**](https://github.com/tolo/trellis) – source, issues, and releases.
- [**pub.dev**](https://pub.dev/packages/trellis) – the published `trellis` package.
