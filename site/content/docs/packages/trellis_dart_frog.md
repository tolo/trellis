---
title: trellis_dart_frog
description: Dart Frog integration for Trellis – provider middleware, response helpers, HTMX detection, and security middleware.
weight: 30
---

`trellis_dart_frog` integrates the [Trellis engine](/docs/packages/trellis/)
with [Dart Frog](https://dartfrog.vgv.dev/): a provider middleware, response
helpers, HTMX detection utilities, and security middleware (headers + CSRF) for
building server-rendered web applications.

## Installation

```yaml
dependencies:
  trellis: ^0.11.0
  trellis_dart_frog: ^0.11.0
```

## Quick start

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

`trellisProvider(engine)` makes a `Trellis` engine available to all route
handlers via `context.read<Trellis>()`:

```dart
Handler middleware(Handler handler) {
  return handler.use(trellisProvider(engine));
}

Future<Response> onRequest(RequestContext context) async {
  final engine = context.read<Trellis>(); // available anywhere
  return renderPage(context, 'index', {});
}
```

## Response helpers

All response helpers retrieve the engine via `context.read<Trellis>()` and set
`content-type: text/html; charset=utf-8` automatically.

### `renderPage`

Renders a full page. When `htmxFragment` is provided and the request is an HTMX
request, it renders only the named fragment instead:

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

Renders a single named fragment from a template:

```dart
Future<Response> onRequest(RequestContext context) async {
  return renderFragment(context, 'todos', 'todo-list', {'items': todos});
}
```

### `renderOobFragments`

Renders multiple named fragments concatenated for HTMX out-of-band swaps:

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

## HTMX detection

Helpers that read HTMX request headers from `RequestContext`:

```dart
Future<Response> onRequest(RequestContext context) async {
  if (isHtmxRequest(context)) {
    // HTMX partial request
  }
  final target = htmxTarget(context);     // id of the swap target, or null
  final source = htmxSource(context);     // id of the triggering element, or null
  final boosted = isHtmxBoosted(context); // HX-Boosted: true
  // ...
}
```

The helpers read the HTMX 2 headers (`HX-Target`, `HX-Trigger`, bare ids) and the HTMX 4 headers
(`HX-Target`, `HX-Source`, `tag#id`) alike, so handler code is the same on either version.
`htmxTrigger()` is deprecated in favour of `htmxSource()`.

## Security headers

`trellisSecurityHeaders()` adds `X-Content-Type-Options`, `X-Frame-Options`,
`Referrer-Policy`, `X-XSS-Protection`, and `Content-Security-Policy` to all
responses:

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

Disable CSP with `trellisSecurityHeaders(enableCsp: false)`.

## CSRF protection

`trellisCsrf(secret: ...)` implements CSRF protection using a double-submit
cookie pattern with HMAC-SHA256 signing:

```dart
Handler middleware(Handler handler) {
  return handler.use(trellisCsrf(secret: 'my-secret-key'));
}
```

The token is merged into the template context as `csrfToken` by all response
helpers:

```html
<form method="POST">
  <input type="hidden" name="_csrf" tl:attr="value=${csrfToken}">
  ...
</form>
```

You can also read it directly – `csrfToken(context)` returns a `String?` (null
if the middleware is not applied).

## Hot reload

For hot reload during development, use
[trellis_dev](/docs/packages/trellis_dev/) alongside `dart_frog dev`. The
SSE-based browser refresh works independently of Dart Frog's hot restart.
