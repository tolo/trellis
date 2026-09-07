---
title: trellis_relic
description: Serverpod Relic integration for Trellis – response helpers, HTMX detection, and security headers.
weight: 40
---

`trellis_relic` integrates the [Trellis engine](/docs/packages/trellis/) with
[Serverpod Relic](https://pub.dev/packages/relic): response helpers, HTMX
detection, and security headers.

## Installation

```yaml
dependencies:
  trellis: ^0.11.1
  trellis_relic: ^0.11.1
```

## Quick start

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

## Engine pattern

Unlike [trellis_shelf](/docs/packages/trellis_shelf/), Relic has no dependency
injection mechanism. Pass the `Trellis` engine explicitly to each response
helper:

```dart
final engine = Trellis(
  loader: FileSystemLoader(templateDirectory: 'templates'),
);

// Pass the engine directly to helpers
return renderPage(request, engine, 'pages/home', {'title': 'Home'});
```

## Response helpers

### `renderPage`

Renders a full page template. When `htmxFragment` is provided and the request is
an HTMX request, it renders only the named fragment instead:

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

Renders a single named fragment directly, regardless of request type:

```dart
Future<Response> handler(Request request) async {
  return renderFragment(request, engine, 'pages/todos', 'todo-list', {'items': todos});
}
```

### `renderOobFragments`

Renders multiple fragments concatenated – useful for
[HTMX out-of-band swaps](https://htmx.org/docs/#oob_swaps):

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

## HTMX helpers

Inspect HTMX-specific request headers:

```dart
isHtmxRequest(request)   // HX-Request: true
htmxTarget(request)      // id of the swap target (nullable)
htmxSource(request)      // id of the triggering element (nullable)
isHtmxBoosted(request)   // HX-Boosted: true
```

The helpers read the HTMX 2 headers (`HX-Target`, `HX-Trigger`, bare ids) and the HTMX 4 headers
(`HX-Target`, `HX-Source`, `tag#id`) alike, so handler code is the same on either version.
`htmxTrigger()` is deprecated in favour of `htmxSource()`.

Relic returns headers as `Iterable<String>?`. These helpers use `.first`
internally, consistent with HTMX's single-value headers.

## Security headers

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

Customise the CSP:

```dart
trellisSecurityHeaders(
  csp: CspBuilder(
    scriptSrc: "'self' 'unsafe-inline'",
    connectSrc: "'self' ws:",
  ),
)
```

Set any directive to `null` to omit it. Pass `enableCsp: false` to disable CSP
entirely.

### Middleware scoping

Relic middleware only fires for matched routes, so security headers are **not**
added to 404/405 responses – this differs from Shelf's `Pipeline`, where
middleware runs for every request. Attach the middleware at `'/'` to cover all
matched routes.

## CSRF protection

CSRF middleware is **not included** in `trellis_relic`. Relic lacks a built-in
form-body parser, which is required to implement the double-submit cookie
pattern. If you need CSRF protection:

- Implement it manually once Relic adds form-parsing support.
- Use a JavaScript fetch API with custom headers instead of form submissions
  (HTMX supports this via `hx-headers`).
