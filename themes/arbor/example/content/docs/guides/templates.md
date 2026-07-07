---
title: Templates
description: Write natural HTML templates with tl:* attributes across every fenced language.
---

This page exercises every vendored highlighter grammar — Dart, HTML, CSS, YAML,
and Bash — plus the in-page table of contents.

## Dart

Trellis templates are compiled and rendered from Dart:

```dart
import 'package:trellis/trellis.dart';

void main() {
  final engine = Trellis(loader: FileSystemLoader('templates'));
  final html = engine.render('<h1 tl:text="\${title}">x</h1>', {'title': 'Hello'});
  print(html);
}
```

## HTML

Templates are valid HTML with `tl:*` attributes:

```html
<article tl:each="post : ${posts}">
  <h2 tl:text="${post.title}">Title</h2>
  <p tl:text="${post.summary}">Summary</p>
</article>
```

## CSS

Themes ship SASS that compiles to CSS custom properties:

```css
:root {
  --trellis-primary: #0f7a4d;
  --trellis-bg: #ffffff;
}
```

## YAML

Configure the theme in `trellis_site.yaml`:

```yaml
theme: arbor
theme_params:
  skin: dark
  primary_color: "#4ade80"
```

## Bash

Build and preview from the command line:

```bash
trellis build --drafts
python3 -m http.server --directory output 8080
```

## Plain block

A fenced block with no language is rendered as plain, readable text:

```
This block has no language identifier — it renders unhighlighted.
```
