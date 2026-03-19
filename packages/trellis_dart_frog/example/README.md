# Example

Minimal Dart Frog integration with `trellis_dart_frog`:

```dart
Handler middleware(Handler handler) {
  return handler
      .use(trellisProvider(engine))
      .use(trellisSecurityHeaders())
      .use(trellisCsrf(secret: 'dev-secret'));
}

Future<Response> onRequest(RequestContext context) async {
  return renderPage(context, 'index.html', {'title': 'Hello'});
}
```

This demonstrates:

- Provider-based Trellis engine injection
- Security and CSRF middleware
- Template rendering from `RequestContext`

Full example app:

- Dart Frog starter app: https://github.com/tolo/trellis/tree/main/examples/dart_frog_app
