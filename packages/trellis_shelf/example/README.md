# Example

Minimal Shelf integration with `trellis_shelf`:

```dart
final handler = const Pipeline()
    .addMiddleware(trellisSecurityHeaders())
    .addMiddleware(trellisEngine(engine))
    .addMiddleware(trellisCsrf(secret: 'dev-secret'))
    .addHandler((request) => renderPage(request, 'index.html', {'title': 'Hello'}));
```

This demonstrates:

- Shelf middleware ordering
- Trellis engine injection via request context
- CSRF protection and response helpers

Full example apps:

- Shelf starter app: https://github.com/tolo/trellis/tree/main/examples/shelf_app
- Full Shelf todo app: https://github.com/tolo/trellis/tree/main/examples/todo_app
