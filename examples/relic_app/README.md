# Relic + Trellis Example

A minimal web application demonstrating [Relic](https://pub.dev/packages/relic) +
[Trellis](https://pub.dev/packages/trellis) + [HTMX](https://htmx.org) integration.

## Quick Start

```bash
dart pub get
dart run bin/server.dart
```

Open [http://localhost:8080](http://localhost:8080) in your browser.

## What This Demonstrates

### Relic's No-DI Pattern

Relic has no dependency injection or request context mechanism (unlike Shelf's request
context or Dart Frog's providers). The Trellis engine is created as a top-level variable
and passed explicitly to route handlers via closures:

```dart
final engine = Trellis(loader: FileSystemLoader('templates/'));

final app = RelicApp()
  ..get('/', (request) => homePage(request, engine));
```

This is the idiomatic Relic pattern — shared state lives in closures, not injected contexts.

### Middleware Scoping

Relic middleware attached via `app.use('/', ...)` only fires for routes that actually match.
This means:

- Security headers **are** applied to successful responses (200, etc.)
- Security headers are **not** applied to 404 or 405 responses

This is a behavioral difference from Shelf, where middleware wraps the entire handler chain
and applies to all responses.

### HTMX Counter Interaction

The counter demonstrates HTMX fragment rendering:

1. Each button posts to `/counter/increment`, `/counter/decrement`, or `/counter/reset`
2. The server renders only the `counter` fragment from `index.html`
3. HTMX swaps the fragment into the page via `hx-target="#counter" hx-swap="outerHTML"`
4. No JavaScript required beyond HTMX itself

### Template Inheritance

Templates use Trellis's `tl:extends` and `tl:define`:

- `base.html` defines the page shell with a `content` block
- `index.html` and `about.html` extend `base.html` and override `content`

### Security Headers

`trellisSecurityHeaders()` middleware adds:

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `X-XSS-Protection: 0`
- `Content-Security-Policy` (configurable via `CspBuilder`)

### CSRF Protection

`trellisCsrf(secret: ...)` sets a signed `__csrf` cookie on safe requests and rejects a
POST/PUT/DELETE/PATCH with 403 unless it carries the matching token. The render helpers pass
the token to templates as `csrfToken`: `base.html` puts it in a `csrf-token` meta tag that
`static/js/csrf.js` copies into the `X-CSRF-Token` header of HTMX requests, and the counter
also submits it as a hidden `_csrf` field. Set `CSRF_SECRET` in production.

## Project Structure

```
bin/server.dart        — Entry point (engine + router setup)
lib/handlers.dart      — Route handlers
templates/base.html    — Base layout with nav and footer
templates/index.html   — Home page with HTMX counter
templates/about.html   — About page with Relic pattern docs
static/styles.css      — Minimal CSS
static/js/csrf.js      — Sends the CSRF token on HTMX requests
```

## Dependencies

| Package | Description |
|---------|-------------|
| [`relic`](https://pub.dev/packages/relic) | Dart web framework (Serverpod team) |
| [`trellis`](https://pub.dev/packages/trellis) | HTML template engine |
| [`trellis_relic`](https://pub.dev/packages/trellis_relic) | Trellis + Relic integration |
