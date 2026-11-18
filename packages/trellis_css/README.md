# trellis_css

CSS utilities for the [Trellis](https://pub.dev/packages/trellis) template engine: Dart-native SASS compilation and
fragment-scoped CSS via `tl:scope`.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Installation

```yaml
dependencies:
  trellis_css: ^0.13.0
```

## Quick start

```dart
import 'package:trellis_css/trellis_css.dart';

final css = TrellisCss.compileSass('styles/main.scss');
```

## Features

- SASS compilation via `package:sass`, the canonical Dart SASS implementation. No npm, no Node.js.
- Compile from a file or a string, `.scss` or indented `.sass`, with `compressed` output and `loadPaths` for
  `@use`/`@import`.
- `fatalImportDeprecation: true` fails the compile on any `@import` rule.
- `tl:scope` processor (`CssDialect`): fragment-scoped CSS using CSS `@scope`. Scoped styles travel with HTMX
  fragments.

## Documentation

**[Full guide: tolo.github.io/trellis/docs/packages/trellis_css/](https://tolo.github.io/trellis/docs/packages/trellis_css/)**
covers every compile option, error handling, and `tl:scope` with rendered output.

API reference: <https://pub.dev/documentation/trellis_css/latest/>

## License

See the [Trellis repository](https://github.com/tolo/trellis) for license information.
