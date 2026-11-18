# trellis_shelf

Shelf integration for the [Trellis](https://pub.dev/packages/trellis) template engine: middleware that injects the
engine, response helpers that render pages and fragments, HTMX request helpers, CSRF protection, and security headers.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Installation

```yaml
dependencies:
  trellis: ^0.13.0
  trellis_shelf: ^0.13.0
```

## Quick Start

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:trellis/trellis.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() async {
  // Renders files from templates/ (e.g. templates/index.html); the directory must exist.
  final engine = Trellis(loader: FileSystemLoader('templates'));

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

## Features

- `trellisEngine()` puts the engine in the request context; `getEngine()` reads it without globals.
- `renderPage`, `renderFragment` and `renderOobFragments` return HTML responses and merge the CSRF token into the
  template context.
- `isHtmxRequest`, `htmxTarget`, `htmxSource` and `isHtmxBoosted` read HTMX 2 and HTMX 4 request headers alike.
- `trellisCsrf()` is a double-submit cookie with HMAC-SHA256 signing, accepted from a form field or a header.
- `trellisSecurityHeaders()` sets `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `X-XSS-Protection`
  and a `Content-Security-Policy` built with `CspBuilder`.
- `CspBuilder.strict()` gives `script-src 'self'; style-src 'self'` for apps without inline scripts or styles.

## Documentation

- **[Full guide: trellis_shelf](https://tolo.github.io/trellis/docs/packages/trellis_shelf/)** covers each middleware,
  the HTMX CSRF snippet, configuration options, and middleware ordering.
- [Framework integration](https://tolo.github.io/trellis/docs/packages/framework-integration/) compares Shelf, Dart
  Frog, and Relic.
- [API reference](https://pub.dev/documentation/trellis_shelf/latest/)
