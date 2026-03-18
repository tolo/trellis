# trellis_relic

Serverpod Relic integration for the [Trellis](https://pub.dev/packages/trellis) template engine — response helpers, HTMX detection, and security headers.

## Installation

```yaml
dependencies:
  trellis: ^0.7.0
  trellis_relic: ^0.1.0
```

## Quick Start

```dart
import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

final engine = Trellis();

void main() async {
  final app = RelicApp()
    ..use('/', trellisSecurityHeaders())
    ..get('/', (request) async {
      return renderPage(request, engine, 'pages/index', {
        'title': 'Home',
      });
    });

  await app.serve(port: 8080);
}
```

## Engine Pattern

Unlike `trellis_shelf`, there is no DI mechanism in Relic. Pass the `Trellis` engine explicitly to each response helper:

```dart
final engine = Trellis(
  loader: FileSystemLoader(templateDirectory: 'templates'),
);

// Pass engine directly to helpers
return renderPage(request, engine, 'pages/home', {'title': 'Home'});
```

## Response Helpers

### `renderPage`

Renders a full page template. When `htmxFragment` is provided and the request is an HTMX request, renders only the named fragment instead:

```dart
Future<Response> handler(Request request) async {
  return renderPage(
    request,
    engine,
    'pages/todos',
    {'items': todos},
    htmxFragment: 'todo-list', // rendered for HTMX, ignored for full-page
  );
}
```

### `renderFragment`

Renders a single named fragment directly (always, regardless of request type):

```dart
Future<Response> handler(Request request) async {
  return renderFragment(request, engine, 'pages/todos', 'todo-list', {'items': todos});
}
```

### `renderOobFragments`

Renders multiple fragments concatenated — useful for [HTMX out-of-band swaps](https://htmx.org/docs/#oob_swaps):

```dart
Future<Response> handler(Request request) async {
  return renderOobFragments(
    request,
    engine,
    'pages/todos',
    ['todo-list', 'todo-count'],
    {'items': todos, 'count': todos.length},
  );
}
```

## HTMX Helpers

Inspect HTMX-specific request headers:

```dart
isHtmxRequest(request)   // HX-Request: true
htmxTarget(request)      // HX-Target value (nullable)
htmxTrigger(request)     // HX-Trigger value (nullable)
isHtmxBoosted(request)   // HX-Boosted: true
```

**Note**: Relic returns headers as `Iterable<String>?`. These helpers use `.first` internally, consistent with HTMX's single-value headers.

## Security Headers

Add security headers to all matched-route responses:

```dart
final app = RelicApp()
  ..use('/', trellisSecurityHeaders())
  ..get('/', myHandler);
```

Default headers applied:

| Header | Default value |
|--------|---------------|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `X-XSS-Protection` | `0` |
| `Content-Security-Policy` | sensible defaults via `CspBuilder` |

### Customising CSP

```dart
trellisSecurityHeaders(
  csp: CspBuilder(
    scriptSrc: "'self' 'unsafe-inline'",
    connectSrc: "'self' ws:",
  ),
)
```

Set any directive to `null` to omit it. Pass `enableCsp: false` to disable CSP entirely.

### Middleware Scoping

**Important**: Relic middleware only fires for matched routes. Security headers will **not** be added to 404/405 responses. This differs from Shelf's `Pipeline`, where middleware runs for every request. Attach the middleware at `'/'` to cover all matched routes.

## CSRF Protection

CSRF middleware is **not included** in `trellis_relic`. Relic lacks a built-in form body parser, which is required to implement the double-submit cookie pattern. If you need CSRF protection:

- Implement it manually once Relic adds form parsing support.
- Use a JavaScript fetch API with custom headers instead of form submissions (HTMX supports this via `hx-headers`).

---

Part of the [Trellis SDK](https://github.com/tolo/trellis) — a multi-package toolkit for server-rendered web applications in pure Dart.
