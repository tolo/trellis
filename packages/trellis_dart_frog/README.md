# trellis_dart_frog

Dart Frog integration for the [Trellis](https://pub.dev/packages/trellis) template engine.
Provides a provider middleware, response helpers, HTMX detection utilities, and security middleware (headers + CSRF) for building server-rendered web applications with Trellis and Dart Frog.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Installation

```yaml
dependencies:
  trellis: ^0.7.0
  trellis_dart_frog: ^0.1.0
```

## Quick Start

### 1. Set up middleware in `routes/_middleware.dart`

```dart
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

final _engine = Trellis(loader: FileSystemLoader('templates'));

Handler middleware(Handler handler) {
  return handler
      .use(trellisProvider(_engine))
      .use(trellisSecurityHeaders())
      .use(trellisCsrf(secret: Platform.environment['CSRF_SECRET']!));
}
```

### 2. Render pages in your route handler

```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  return renderPage(context, 'index', {'title': 'Home', 'user': 'Alice'});
}
```

## Provider

`trellisProvider(engine)` makes a `Trellis` engine available to all route handlers via `context.read<Trellis>()`.

```dart
Handler middleware(Handler handler) {
  return handler.use(trellisProvider(engine));
}

Future<Response> onRequest(RequestContext context) async {
  final engine = context.read<Trellis>(); // available anywhere
  return renderPage(context, 'index', {});
}
```

## Response Helpers

All response helpers retrieve the engine via `context.read<Trellis>()` and automatically set `content-type: text/html; charset=utf-8`.

### `renderPage`

Renders a full page. When `htmxFragment` is provided and the request is an HTMX request, renders only the named fragment.

```dart
Future<Response> onRequest(RequestContext context) async {
  return renderPage(
    context,
    'index',                        // template name
    {'title': 'Home'},              // template context
    htmxFragment: 'content',        // optional: fragment for HTMX requests
  );
}
```

### `renderFragment`

Renders a single named fragment from a template.

```dart
Future<Response> onRequest(RequestContext context) async {
  return renderFragment(context, 'todos', 'todo-list', {'items': todos});
}
```

### `renderOobFragments`

Renders multiple named fragments concatenated for HTMX out-of-band swaps.

```dart
Future<Response> onRequest(RequestContext context) async {
  return renderOobFragments(
    context,
    'todos',
    ['todo-list', 'todo-count'],
    {'items': todos, 'count': todos.length},
  );
}
```

## HTMX Detection

Helpers that read HTMX request headers from `RequestContext`:

```dart
Future<Response> onRequest(RequestContext context) async {
  if (isHtmxRequest(context)) {
    // HTMX partial request
  }
  final target = htmxTarget(context);   // HX-Target header value or null
  final trigger = htmxTrigger(context); // HX-Trigger header value or null
  final boosted = isHtmxBoosted(context); // HX-Boosted: true
  // ...
}
```

## Security Headers

`trellisSecurityHeaders()` adds `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `X-XSS-Protection`, and `Content-Security-Policy` to all responses.

```dart
Handler middleware(Handler handler) {
  return handler.use(trellisSecurityHeaders());
}
```

Custom CSP:

```dart
trellisSecurityHeaders(
  csp: CspBuilder(
    scriptSrc: "'self' 'nonce-{nonce}'",
    connectSrc: "'self' ws:",
  ),
)
```

Disable CSP:

```dart
trellisSecurityHeaders(enableCsp: false)
```

## CSRF Protection

`trellisCsrf(secret: ...)` implements CSRF protection using a double-submit cookie pattern with HMAC-SHA256 signing.

```dart
Handler middleware(Handler handler) {
  return handler.use(trellisCsrf(secret: 'my-secret-key'));
}
```

The CSRF token is automatically merged into the template context as `csrfToken` by all response helpers:

```html
<!-- In your Trellis template -->
<form method="POST">
  <input type="hidden" name="_csrf" tl:attr="value=${csrfToken}">
  ...
</form>
```

You can also access the token directly:

```dart
final token = csrfToken(context); // String? — null if middleware not applied
```

## Hot Reload

For hot reload during development, use [`trellis_dev`](https://pub.dev/packages/trellis_dev) alongside `dart_frog dev`. The SSE-based browser refresh works independently of Dart Frog's hot restart.

## API Documentation

- https://pub.dev/documentation/trellis_dart_frog/latest/

## License

MIT
