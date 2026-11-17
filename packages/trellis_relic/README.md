# trellis_relic

Serverpod Relic integration for the [Trellis](https://pub.dev/packages/trellis) template engine — response helpers, HTMX detection, and security headers.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Installation

```yaml
dependencies:
  trellis: ^0.13.0
  trellis_relic: ^0.13.0
```

## Quick Start

```dart
import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

// Renders files from templates/ (e.g. templates/pages/index.html); the directory must exist.
final engine = Trellis(loader: FileSystemLoader('templates'));

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
  loader: FileSystemLoader('templates'),
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
htmxTarget(request)      // id of the swap target (nullable)
htmxSource(request)      // id of the triggering element (nullable)
isHtmxBoosted(request)   // HX-Boosted: true
```

The helpers read the HTMX 2 headers (`HX-Target`, `HX-Trigger`, bare ids) and the HTMX 4 headers
(`HX-Target`, `HX-Source`, `tag#id`) alike, so handler code is the same on either version.
`htmxTrigger()` is deprecated in favour of `htmxSource()`.

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

`CspBuilder.strict()` sets `script-src 'self'; style-src 'self'` while preserving the other
security defaults. Use it with `trellisSecurityHeaders(csp: const CspBuilder.strict())`.
The plain `CspBuilder()` retains its existing inline-style allowance for compatibility.
Under the strict preset, inline `<script>` bodies, `<style>` elements, `style="…"` attributes
and `on*` handlers are blocked. Move them to same-origin JS/CSS files; CSSOM property writes
(such as `element.style.top`) remain allowed by browsers. HTMX's injected indicator style
must be disabled with the `htmx-config` meta option `includeIndicatorStyles: false`, with
indicator rules in your stylesheet. CLI app scaffolds do this automatically.

```dart
trellisSecurityHeaders(
  csp: CspBuilder.strict(
    scriptSrc: "'self'",
    connectSrc: "'self' ws:",
  ),
)
```

Set any directive to `null` to omit it. Pass `enableCsp: false` to disable CSP entirely.

### Middleware Scoping

**Important**: Relic middleware only fires for matched routes. Security headers will **not** be added to 404/405 responses. This differs from Shelf's `Pipeline`, where middleware runs for every request. Attach the middleware at `'/'` to cover all matched routes.

## CSRF Protection

CSRF middleware is **not included** in `trellis_relic`. If you need CSRF protection:

- Read the body with `request.readAsString()`, parse it with `Uri.splitQueryString`, and validate the submitted token against a signed cookie.
- Use a JavaScript fetch API with custom headers instead of form submissions (HTMX supports this via `hx-headers`).

---

Part of the [Trellis SDK](https://github.com/tolo/trellis) — a multi-package toolkit for server-rendered web applications in pure Dart.

## API Documentation

- https://pub.dev/documentation/trellis_relic/latest/
