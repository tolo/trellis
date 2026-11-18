# trellis_relic

Serverpod Relic integration for the [Trellis](https://pub.dev/packages/trellis) template engine: response helpers, HTMX
detection, security headers, and CSRF protection.

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

## Features

- `renderPage`, `renderFragment` and `renderOobFragments` take the engine as an explicit argument, since Relic has no
  dependency injection.
- `isHtmxRequest`, `htmxTarget`, `htmxSource` and `isHtmxBoosted` read HTMX 2 and HTMX 4 request headers alike.
- `trellisSecurityHeaders()` sets `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `X-XSS-Protection`
  and a `Content-Security-Policy` built with `CspBuilder`, on matched routes only (not 404/405).
- `trellisCsrf()` is a double-submit cookie with HMAC-SHA256 signing, accepted from the `X-CSRF-Token` header or a
  form field; the handler can still read the form.
- `CspBuilder.strict()` gives `script-src 'self'; style-src 'self'` for apps without inline scripts or styles.

## Documentation

- **[Full guide: trellis_relic](https://tolo.github.io/trellis/docs/packages/trellis_relic/)** covers the engine
  pattern, response helpers, middleware scoping, and CSRF configuration.
- [Framework integration](https://tolo.github.io/trellis/docs/packages/framework-integration/) compares Shelf, Dart
  Frog, and Relic.
- [API reference](https://pub.dev/documentation/trellis_relic/latest/)
