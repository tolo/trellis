# Example

Minimal live-reload setup with `trellis_dev`:

```dart
final loader = FileSystemLoader('templates', devMode: true);

final handler = const Pipeline()
    .addMiddleware(devMiddleware(loader))
    .addHandler(appHandler);
```

This demonstrates:

- Template watching through `FileSystemLoader(devMode: true)`
- SSE reload endpoint wiring
- Automatic script injection for HTML responses

Full example app:

- Shelf starter app with `--dev`: https://github.com/tolo/trellis/tree/main/examples/shelf_app
