# Example

Minimal Relic integration with `trellis_relic`:

```dart
final engine = Trellis(loader: MapLoader({'index.html': '<h1>Hello</h1>'}));

final app = RelicApp()
  ..use('/', trellisSecurityHeaders())
  ..get('/', (request) => renderPage(request, engine, 'index.html', {'title': 'Hello'}));
```

This demonstrates:

- Relic's explicit-engine pattern
- Security headers middleware
- Template rendering inside Relic handlers

Full example app:

- Relic starter app: https://github.com/tolo/trellis/tree/main/examples/relic_app
