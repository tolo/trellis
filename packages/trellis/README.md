<p align="center">
  <img src="https://raw.githubusercontent.com/tolo/trellis/main/assets/logo-with-text.png" alt="Trellis" width="400">
</p>

<p align="center">
  <a href="https://pub.dev/packages/trellis"><img src="https://img.shields.io/pub/v/trellis.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/trellis/publisher"><img src="https://img.shields.io/pub/publisher/trellis.svg" alt="package publisher"></a>
</p>

A natural HTML template engine for Dart: templates are valid HTML that browsers render as prototypes without a
server. Fragment-first design built for hypermedia-driven web frameworks like [HTMX](https://htmx.org/). Inspired by
[Thymeleaf](https://www.thymeleaf.org/).

`trellis` is the template engine at the heart of the [Trellis SDK](https://github.com/tolo/trellis), a pure-Dart
toolkit for server-rendered web apps and static sites (server integrations, SSG, CSS, hot reload, and a scaffolding
CLI). This page covers the engine; see the [project README](https://github.com/tolo/trellis#readme) for the full
package map.

> **Full guide: <https://tolo.github.io/trellis/docs/packages/trellis/>**
>
> Configuration, loaders, validation, testing, custom processors, and the public API. The template language itself is in
> the [Syntax Reference](https://tolo.github.io/trellis/docs/syntax/). Generated API docs:
> [pub.dev/documentation/trellis](https://pub.dev/documentation/trellis/latest/).

## Installation

Requires Dart SDK `^3.10.0`.

```
dart pub add trellis
```

## Quick Start

```dart
import 'package:trellis/trellis.dart';

final engine = Trellis(loader: MapLoader({}));

final html = engine.render(
  r'<h1 tl:text="${title}">Default Title</h1>',
  {'title': 'Hello, Trellis!'},
);
// <html><head></head><body><h1>Hello, Trellis!</h1></body></html>
```

`render()` returns a full HTML document; `renderFragment()` returns just the named fragment. Write templates in Dart as
raw strings (`r'...'`) so Dart does not interpolate `${...}`. Without a `loader:`, the engine reads from
`FileSystemLoader('templates/')`, which throws if that directory does not exist.

## Features

- Natural templates: valid HTML that renders as a prototype without a server
- Fragment-first: `tl:fragment` plus `renderFragment()` returns HTMX partial responses
- Layout inheritance with `tl:extends` / `tl:define`, and components with `tl:slot`, `tl:attrs`, and `...rest`
- Expression language with filters, i18n message lookup (`#{key}`), and `${#strings.*}`, `${#numbers.*}`,
  `${#dates.*}`, `${#lists.*}` utility objects
- Template validation: `TemplateValidator`, the `isValidTemplate()` matcher, and `dart run trellis:validate` for CI
- Testing helpers in `package:trellis/testing.dart`: `testEngine`, `hasElement`, snapshot goldens
- Custom processors, filters, and dialects
- Synchronous `render()`, LRU DOM cache, optional strict mode, dev-mode file watching
- `tl:text` always HTML-escapes; a dynamic `javascript:`, `vbscript:` or non-image `data:` URL in `href`, `src` and
  other URL attributes is replaced (opt out per value with `TrustedUrl`); `FileSystemLoader` rejects path traversal
  and symlink escapes
- AOT-compatible: the context is a `Map<String, dynamic>`, no reflection

## License

MIT
