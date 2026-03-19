# trellis_css

CSS utilities for the Trellis template engine — Dart-native SASS compilation and fragment-scoped CSS via `tl:scope`.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Features

- **SASS compilation** via `package:sass` — the canonical Dart SASS implementation. No npm, no Node.js.
- **`tl:scope` processor** — fragment-scoped CSS using CSS `@scope`. Scoped styles travel with HTMX fragments.

## Installation

```yaml
dependencies:
  trellis_css: ^0.1.0
```

## SASS Compilation

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

## Fragment-Scoped CSS (`tl:scope`)

Register `CssDialect` with your Trellis engine to enable the `tl:scope` processor:

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

## API Documentation

- https://pub.dev/documentation/trellis_css/latest/

## License

See the [Trellis repository](https://github.com/tolo/trellis) for license information.
