---
title: trellis_dev
description: Developer tools for Trellis – SSE-based browser hot reload for template development.
weight: 70
---

`trellis_dev` provides live reload for
[Trellis](/docs/packages/trellis/) template development. When a template file
changes on disk, all connected browser tabs refresh automatically via
Server-Sent Events (SSE).

Three public APIs are provided:

- **`liveReloadHandler()`** – a Shelf `Handler` that serves SSE events.
- **`devMiddleware()`** – a Shelf `Middleware` combining the SSE endpoint with
  optional script injection.
- **`liveReloadScript()`** – the vanilla JS `EventSource` snippet.

## Installation

```yaml
dependencies:
  trellis_dev: ^0.13.0
```

`devMiddleware()` is imported from server code (`bin/` or Dart Frog `routes/`),
so list it under `dependencies`, as the examples do, and leave it out of the
production pipeline.

## Usage

### Quick start with `devMiddleware()`

The simplest approach – adds both the SSE endpoint and auto-injects the reload
script into HTML responses:

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:trellis/trellis.dart';
import 'package:trellis_dev/trellis_dev.dart';

void main() async {
  final loader = FileSystemLoader('templates', devMode: true);
  final engine = Trellis(loader: loader);

  final handler = const Pipeline()
      .addMiddleware(devMiddleware(loader))
      .addHandler(myAppHandler);

  await io.serve(handler, 'localhost', 8080);
  print('Listening on http://localhost:8080');
}
```

### Manual setup with `liveReloadHandler()`

For more control, use the handler and script separately:

```dart
final loader = FileSystemLoader('templates', devMode: true);

// Mount the SSE endpoint.
final sseHandler = liveReloadHandler(loader);

// Add the script to your HTML template manually.
final script = liveReloadScript();
// Insert `script` before </body> in your templates.
```

### Custom SSE path

Both `devMiddleware()` and `liveReloadScript()` accept a custom `ssePath`:

```dart
final middleware = devMiddleware(loader, ssePath: '/my/reload');
final script = liveReloadScript(ssePath: '/my/reload');
```

## Requirements

The `FileSystemLoader` **must** be created with `devMode: true` to enable file
watching. If `devMode` is `false`, a `StateError` is thrown.

## Lifecycle

File watching is owned by `FileSystemLoader`. Call `loader.close()` to stop
watching and clean up resources; the SSE connections then close automatically.

## API reference

### `liveReloadHandler(FileSystemLoader loader)`

Returns a Shelf `Handler` that serves SSE events. Each connected client receives
a `reload` event when any template file changes.

### `devMiddleware(FileSystemLoader loader, {String ssePath, bool injectScript, bool validate, TemplateValidator? validator, StringSink? validationSink})`

Returns a Shelf `Middleware` that:

- Routes `ssePath` (default `/_dev/reload`) to the SSE handler.
- When `injectScript` is `true` (default), injects the reload script before
  `</body>` in buffered HTML responses.
- When `validate` is `true` (default), validates every template at startup and
  again on each file change, writing issues to `validationSink` (default stderr)
  as `path:line: severity: message (attribute)`, the `dart run trellis:validate`
  format. An unchanged template is reported once. Pass `validate: false` to turn
  it off, or a configured `validator` to match a custom prefix or dialect set.

### `liveReloadScript({String ssePath})`

Returns a `<script>` block containing a self-contained IIFE that connects to the
SSE endpoint and reloads the page on `reload` events.

## Framework notes

`trellis_dev` works with any Shelf-based server, including
[trellis_shelf](/docs/packages/trellis_shelf/) apps. It also pairs with
[trellis_dart_frog](/docs/packages/trellis_dart_frog/): the SSE-based browser
refresh works independently of Dart Frog's own hot restart. Wrap the Shelf
middleware with `fromShelfMiddleware(devMiddleware(loader))`, passing the
engine's own loader; see the [trellis_dart_frog hot reload
section](/docs/packages/trellis_dart_frog/#hot-reload).
