# trellis_dev

Developer tools for the [Trellis](https://pub.dev/packages/trellis) template engine — SSE-based browser hot reload.

## Overview

`trellis_dev` provides live reload for Trellis template development. When a template file changes on disk, all connected browser tabs automatically refresh via Server-Sent Events (SSE).

Three public APIs are provided:

- **`liveReloadHandler()`** — a Shelf `Handler` that serves SSE events
- **`devMiddleware()`** — a Shelf `Middleware` combining SSE endpoint with optional script injection
- **`liveReloadScript()`** — the vanilla JS `EventSource` snippet

## Installation

```yaml
dev_dependencies:
  trellis_dev: ^0.1.0
```

## Usage

### Quick Start with `devMiddleware()`

The simplest approach — adds both the SSE endpoint and auto-injects the reload script into HTML responses:

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

### Manual Setup with `liveReloadHandler()`

For more control, use the handler and script separately:

```dart
final loader = FileSystemLoader('templates', devMode: true);

// Mount the SSE endpoint.
final sseHandler = liveReloadHandler(loader);

// Add the script to your HTML template manually.
final script = liveReloadScript();
// Insert `script` before </body> in your templates.
```

### Custom SSE Path

Both `devMiddleware()` and `liveReloadScript()` accept a custom `ssePath`:

```dart
final middleware = devMiddleware(loader, ssePath: '/my/reload');
final script = liveReloadScript(ssePath: '/my/reload');
```

## Requirements

- The `FileSystemLoader` **must** be created with `devMode: true` to enable file watching. If `devMode` is `false`, a `StateError` is thrown.

## Lifecycle

File watching is owned by `FileSystemLoader`. Call `loader.close()` to stop watching and clean up resources. The SSE connections will close automatically.

## API Reference

### `liveReloadHandler(FileSystemLoader loader)`

Returns a Shelf `Handler` that serves SSE events. Each connected client receives a `reload` event when any template file changes.

### `devMiddleware(FileSystemLoader loader, {String ssePath, bool injectScript})`

Returns a Shelf `Middleware` that:
- Routes `ssePath` (default `/_dev/reload`) to the SSE handler
- When `injectScript` is `true` (default), injects the reload script before `</body>` in buffered HTML responses

### `liveReloadScript({String ssePath})`

Returns a `<script>` block containing a self-contained IIFE that connects to the SSE endpoint and reloads the page on `reload` events.
