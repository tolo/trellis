# Dart Frog + Trellis Example

A minimal counter application demonstrating [Dart Frog](https://dartfrog.vgv.dev/)
+ [Trellis](https://pub.dev/packages/trellis) + [HTMX](https://htmx.org) integration.

## Quick Start

```bash
dart pub get
dart_frog dev
```

Open [http://localhost:8080](http://localhost:8080) in your browser.

For template hot reload during development:

```bash
DEV=true dart_frog dev
```

## What This Demonstrates

### File-Based Routing

Dart Frog maps route files to URL paths automatically:

- `routes/index.dart` handles `GET /`
- `routes/about.dart` handles `GET /about`
- `routes/counter/increment.dart`, `decrement.dart`, and `reset.dart` handle counter mutations
- `routes/_middleware.dart` applies middleware to all routes

### Provider-Based Dependency Injection

Unlike Relic (no DI) or plain Shelf (request context maps), Dart Frog uses providers.
The Trellis engine is registered once in middleware and accessed per-request:

```dart
// _middleware.dart — register once
handler.use(trellisProvider(_engine))

// index.dart — access via context
renderPage(context, 'pages/index.html', {...});
```

### HTMX SPA Navigation

Navigation uses HTMX for SPA-style page transitions without full page reloads:

- Nav links use `hx-get` + `hx-target="#content"` + `hx-push-url="true"`
- HTMX requests return only the `page-content` fragment
- Direct page loads return the full page with layout
- Browser history is updated via `hx-push-url`

### HTMX Counter Interaction

The counter demonstrates fragment rendering for mutations:

1. `POST /counter/increment` increments the count
2. `POST /counter/decrement` decrements it
3. `POST /counter/reset` resets it to zero
4. Each mutation returns only the `counter` fragment
5. HTMX swaps the fragment in place without custom JavaScript

### Template Inheritance

Templates use Trellis's `tl:extends` and `tl:define`:

- `layouts/base.html` defines the page shell with the `content` block
- `pages/index.html` and `pages/about.html` extend the base and override `content`
- `pages/index.html` also defines the `counter` fragment for HTMX responses

### Security Headers + CSRF Protection

`trellisSecurityHeaders()` middleware adds protective HTTP headers. `trellisCsrf()`
enables double-submit cookie CSRF protection:

- A `csrfToken` is automatically available in the template context
- The base layout injects it via `<meta name="csrf-token">`
- HTMX sends it on every request via `htmx:configRequest`
- Hidden `_csrf` fields remain as a fallback

### Dev Mode Hot Reload

When `DEV=true` is set, `trellis_dev`'s `devMiddleware` watches template files and
injects an SSE script. Template changes are reflected instantly without restarting
the server.

## Project Structure

```
routes/_middleware.dart             — Engine setup, security, CSRF, dev middleware
routes/index.dart                   — Home page handler (full page + HTMX fragment)
routes/about.dart                   — About page explaining Dart Frog patterns
lib/counter_state.dart              — Shared in-memory counter state + page context
routes/counter/increment.dart       — Increment mutation endpoint
routes/counter/decrement.dart       — Decrement mutation endpoint
routes/counter/reset.dart           — Reset mutation endpoint
templates/layouts/base.html         — Base layout with nav, CSRF meta, HTMX script
templates/pages/index.html          — Home page with counter + feature list
templates/pages/about.html          — About page with framework pattern docs
templates/partials/nav.html         — SPA navigation with hx-get + hx-push-url
public/styles.css                   — Application styles
```

## Dependencies

| Package | Description |
|---------|-------------|
| [`dart_frog`](https://pub.dev/packages/dart_frog) | File-based routing web framework |
| [`trellis`](https://pub.dev/packages/trellis) | HTML template engine |
| [`trellis_dart_frog`](https://pub.dev/packages/trellis_dart_frog) | Trellis + Dart Frog integration |
| [`trellis_dev`](https://pub.dev/packages/trellis_dev) | Template hot reload (dev mode) |
