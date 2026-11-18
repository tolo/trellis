# trellis_dev

Developer tools for the [Trellis](https://pub.dev/packages/trellis) template engine: SSE-based browser hot reload.
When a template file changes on disk, every connected browser tab refreshes via Server-Sent Events. Template
validation runs at startup and on each change.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Installation

```yaml
dependencies:
  trellis_dev: ^0.13.0
```

`devMiddleware()` is imported from server code (`bin/` or Dart Frog `routes/`), so list it under `dependencies`, as
the examples do, and leave it out of the production pipeline.

## Quick start

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:trellis/trellis.dart';
import 'package:trellis_dev/trellis_dev.dart';

void main() async {
  final loader = FileSystemLoader('templates', devMode: true);
  final engine = Trellis(loader: loader);

  final handler = const Pipeline()
      .addMiddleware(devMiddleware(loader, staticDirectory: 'static'))
      .addHandler(myAppHandler);

  await io.serve(handler, 'localhost', 8080);
  print('Listening on http://localhost:8080');
}
```

## Features

- `devMiddleware()`: Shelf middleware serving the SSE endpoint and injecting the reload script before `</body>`.
- Reloads on template edits and, with `staticDirectory`, on `.css`/`.js` edits under it.
- Serves the client as `/_dev/reload.js`, so it works under `script-src 'self'; style-src 'self'`.
- `liveReloadHandler()`: the SSE endpoint alone, for manual setups.
- `liveReloadScript()`: the vanilla JS `EventSource` snippet.
- Template validation at startup and on each change, in the `dart run trellis:validate` format.
- Configurable SSE path (`ssePath`).

## Documentation

**[Full guide: tolo.github.io/trellis/docs/packages/trellis_dev/](https://tolo.github.io/trellis/docs/packages/trellis_dev/)**
covers manual setup, the `devMode: true` requirement, lifecycle, the API reference, and Dart Frog use.

API reference: <https://pub.dev/documentation/trellis_dev/latest/>
