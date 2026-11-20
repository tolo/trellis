# trellis_dart_frog

Dart Frog integration for the [Trellis](https://pub.dev/packages/trellis) template engine: a provider middleware,
response helpers, HTMX detection utilities, and security middleware (headers and CSRF).

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Installation

```yaml
dependencies:
  trellis: ^0.14.0
  trellis_dart_frog: ^0.14.0
```

## Quick Start

Set up the middleware in `routes/_middleware.dart`:

```dart
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

final _engine = Trellis(loader: FileSystemLoader('templates'));

Handler middleware(Handler handler) {
  return handler
      .use(trellisProvider(_engine))
      .use(trellisCsrf(secret: Platform.environment['CSRF_SECRET']!))
      .use(trellisSecurityHeaders()); // last `.use` is outermost
}
```

Render pages in your route handler:

```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  return renderPage(context, 'index', {'title': 'Home', 'user': 'Alice'});
}
```

## Features

- `trellisProvider()` provides the engine through `context.read<Trellis>()`.
- `renderPage`, `renderFragment` and `renderOobFragments` return HTML responses and merge the CSRF token into the
  template context.
- `isHtmxRequest`, `htmxTarget`, `htmxSource` and `isHtmxBoosted` read HTMX 2 and HTMX 4 request headers alike.
- `trellisCsrf()` is a double-submit cookie with HMAC-SHA256 signing.
- `trellisSecurityHeaders()` sets `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `X-XSS-Protection`
  and a `Content-Security-Policy` built with `CspBuilder`.
- `CspBuilder.strict()` gives `script-src 'self'; style-src 'self'` for apps without inline scripts or styles.

## Documentation

- **[Full guide: trellis_dart_frog](https://tolo.github.io/trellis/docs/packages/trellis_dart_frog/)** covers the
  middleware order, response helpers, CSP customisation, CSRF, and hot reload with `trellis_dev`.
- [Framework integration](https://tolo.github.io/trellis/docs/packages/framework-integration/) compares Shelf, Dart
  Frog, and Relic.
- [API reference](https://pub.dev/documentation/trellis_dart_frog/latest/)

## License

MIT
