---
title: trellis_css
description: CSS utilities for Trellis – Dart-native SASS compilation and fragment-scoped CSS via tl:scope.
weight: 60
---

`trellis_css` adds CSS tooling to the [Trellis engine](/docs/packages/trellis/):
Dart-native SASS compilation and fragment-scoped CSS via the `tl:scope`
processor.

## Features

- **SASS compilation** via `package:sass` – the canonical Dart SASS
  implementation. No npm, no Node.js.
- **`tl:scope` processor** – fragment-scoped CSS using CSS `@scope`. Scoped
  styles travel with HTMX fragments.

## Installation

```yaml
dependencies:
  trellis_css: ^0.11.1
```

## SASS compilation

### Compile a file

```dart
import 'package:trellis_css/trellis_css.dart';

final css = TrellisCss.compileSass('styles/main.scss');
```

### Compile a string

```dart
final css = TrellisCss.compileSassString(r'''
  $primary: #3498db;
  .btn { color: $primary; }
''');
```

### Output styles

```dart
// Minified output
final minified = TrellisCss.compileSass(
  'styles/main.scss',
  outputStyle: OutputStyle.compressed,
);
```

### Indented syntax (`.sass`)

```dart
final css = TrellisCss.compileSassString(
  '.btn\n  color: blue\n',
  syntax: Syntax.sass,
);
```

### Load paths for `@use`/`@import`

```dart
final css = TrellisCss.compileSass(
  'styles/main.scss',
  loadPaths: ['styles/'],
);
```

### Error handling

```dart
try {
  final css = TrellisCss.compileSass('styles/main.scss');
} on SassCompilationException catch (e) {
  print('Error: ${e.message} at line ${e.line}');
}
```

## Fragment-scoped CSS (`tl:scope`)

Register `CssDialect` with your Trellis engine to enable the `tl:scope`
processor:

```dart
import 'package:trellis/trellis.dart';
import 'package:trellis_css/trellis_css.dart';

final engine = Trellis(dialects: [CssDialect()]);
```

In your template:

```html
<div tl:fragment="card">
  <style tl:scope>
    h2 { color: navy; }
  </style>
  <h2>Card Title</h2>
</div>
```

Renders as:

```html
<div class="tl-scope-card">
  <style>
    @scope (.tl-scope-card) {
      h2 { color: navy; }
    }
  </style>
  <h2>Card Title</h2>
</div>
```

Because the scoped styles are wrapped in `@scope`, they only apply within the
fragment – so when the fragment is swapped into a page by HTMX, its CSS travels
with it and does not leak into the rest of the document.

See [Fragments](/docs/syntax/fragments/) for the `tl:fragment` syntax, and
[trellis_site](/docs/packages/trellis_site/) for how the CLI compiles SASS
during a static-site build.
