# trellis_shelf

Shelf integration for the [Trellis](https://pub.dev/packages/trellis) template engine — middleware, HTMX helpers, and security defaults.

## Installation

```yaml
dependencies:
  trellis: ^0.7.0
  trellis_shelf: ^0.1.0
```

## Quick Start

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:trellis/trellis.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() async {
  final engine = Trellis();

  final handler = const Pipeline()
      .addMiddleware(trellisSecurityHeaders())
      .addMiddleware(trellisEngine(engine))
      .addMiddleware(trellisCsrf(secret: 'your-secret-key'))
      .addHandler(myHandler);

  await io.serve(handler, 'localhost', 8080);
}

Future<Response> myHandler(Request request) async {
  return renderPage(request, 'index', {'title': 'Hello'});
}
```

## Engine Middleware

Injects a `Trellis` engine into the Shelf request context so handlers can
retrieve it without globals.

```dart
// Add to pipeline
.addMiddleware(trellisEngine(engine))

// Retrieve in handler
final engine = getEngine(request);
```

`getEngine()` throws `StateError` if the middleware has not been applied.

## Security Headers

Adds configurable security headers to all responses:

| Header | Default |
|--------|---------|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `X-XSS-Protection` | `0` |
| `Content-Security-Policy` | Sensible defaults via `CspBuilder` |

```dart
// Use defaults
.addMiddleware(trellisSecurityHeaders())

// Customize CSP
.addMiddleware(trellisSecurityHeaders(
  csp: CspBuilder(
    scriptSrc: "'self' 'unsafe-inline'",
    connectSrc: "'self' ws:",
  ),
))

// Disable CSP entirely
.addMiddleware(trellisSecurityHeaders(enableCsp: false))
```

## HTMX Helpers

Convenience functions for reading HTMX request headers:

```dart
if (isHtmxRequest(request)) {
  final target = htmxTarget(request);   // HX-Target value or null
  final trigger = htmxTrigger(request); // HX-Trigger value or null
  final boosted = isHtmxBoosted(request);
}
```

## CSRF Protection

Double-submit cookie pattern with HMAC-SHA256 signing. Generates a token on
safe methods (GET/HEAD/OPTIONS), validates on state-changing methods
(POST/PUT/DELETE/PATCH).

```dart
.addMiddleware(trellisCsrf(secret: 'your-secret-key'))
```

Access the token in handlers or templates:

```dart
// In handler
final token = csrfToken(request);

// In template — automatically merged by response helpers
<input type="hidden" name="_csrf" tl:attr="value=${csrfToken}">
```

HTMX requests can submit the token via the `htmx:configRequest` event. Add
this to your base layout:

```html
<!-- In <head>: render the token into a meta tag -->
<meta name="csrf-token" tl:attr="content=${csrfToken}" content="">

<!-- Also in <head>: inject it into every HTMX request -->
<script>
  document.addEventListener('htmx:configRequest', function(evt) {
    var token = document.querySelector('meta[name="csrf-token"]').content;
    if (token) evt.detail.headers['X-CSRF-Token'] = token;
  });
</script>
```

The `tl:attr` renders the CSRF token into the `content` attribute at request time.
The event listener then reads it and sets the header on every HTMX request.

Configuration options:

```dart
trellisCsrf(
  secret: 'your-secret-key',
  cookieName: '__csrf',         // cookie name (default)
  fieldName: '_csrf',           // form field name (default)
  headerName: 'X-CSRF-Token',  // header name (default)
  excludedPaths: ['/api/webhook'],  // paths that skip validation
)
```

## Response Helpers

Convenience functions that use `getEngine()`, merge request-context values
(e.g. CSRF token), and return `htmlResponse()`:

```dart
// Full page (or fragment for HTMX requests)
return renderPage(request, 'index', {'title': 'Home'},
    htmxFragment: 'content');

// Single fragment
return renderFragment(request, 'todos', 'todo-list', {'items': todos});

// Multiple fragments for HTMX OOB swaps
return renderOobFragments(request, 'todos',
    ['todo-list', 'todo-count'], {'items': todos, 'count': 5});
```

## Response Utility

```dart
return htmlResponse('<h1>Hello</h1>');
return htmlResponse('Not Found', statusCode: 404);
```

Returns a `Response` with `content-type: text/html; charset=utf-8`.

## Middleware Ordering

Apply middleware in this order for correct behavior:

```dart
const Pipeline()
    .addMiddleware(trellisSecurityHeaders())  // outermost — wraps response
    .addMiddleware(trellisEngine(engine))     // injects engine for handlers
    .addMiddleware(trellisCsrf(secret: '...'))  // CSRF after engine
    .addHandler(handler);
```

Security headers should be outermost so they apply to all responses.
CSRF middleware must be after `trellisEngine()` since response helpers need
the engine from request context.
