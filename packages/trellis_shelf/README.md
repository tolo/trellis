# trellis_shelf

Shelf integration for the [Trellis](https://pub.dev/packages/trellis) template engine — middleware, HTMX helpers, and security defaults.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Installation

```yaml
dependencies:
  trellis: ^0.11.0
  trellis_shelf: ^0.11.0
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
  final target = htmxTarget(request);   // id of the swap target, or null
  final source = htmxSource(request);   // id of the triggering element, or null
  final boosted = isHtmxBoosted(request);
}
```

The helpers read the HTMX 2 headers (`HX-Target`, `HX-Trigger`, bare ids) and the HTMX 4 headers
(`HX-Target`, `HX-Source`, `tag#id`) alike, so handler code is the same on either version.
`htmxTrigger()` is deprecated in favour of `htmxSource()`.

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

HTMX requests can submit the token from the request-configuration event (`htmx:configRequest`
in HTMX 2, `htmx:config:request` in HTMX 4). Add this to your base layout:

```html
<!-- In <head>: render the token into a meta tag -->
<meta name="csrf-token" tl:attr="content=${csrfToken}" content="">

<!-- Also in <head>: inject it into every HTMX request -->
<script>
  (function () {
    function setCsrfHeader(headers) {
      if (!headers) return;
      var token = document.querySelector('meta[name="csrf-token"]').content;
      if (token) headers['X-CSRF-Token'] = token;
    }
    document.addEventListener('htmx:configRequest', function(evt) { setCsrfHeader(evt.detail.headers); });
    document.addEventListener('htmx:config:request', function(evt) { setCsrfHeader(evt.detail.ctx.request.headers); });
  })();
</script>
```

The `tl:attr` renders the CSRF token into the `content` attribute at request time.
The listeners then read it and set the header on every HTMX request; HTMX 4 exposes the outgoing
headers at `evt.detail.ctx.request.headers`, HTMX 2 at `evt.detail.headers`.

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

## API Documentation

- https://pub.dev/documentation/trellis_shelf/latest/
