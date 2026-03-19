# Shelf + Trellis Example

A minimal Shelf application demonstrating [Trellis](https://pub.dev/packages/trellis)
+ [trellis_shelf](https://pub.dev/packages/trellis_shelf) + [HTMX](https://htmx.org).

## Quick Start

```bash
dart pub get
dart run bin/server.dart
```

Open [http://localhost:8080](http://localhost:8080) in your browser.

For template hot reload during development:

```bash
dart run bin/server.dart --dev
```

## What This Demonstrates

### Shelf Middleware Pipeline

The app wraps the router with logging, security headers, Trellis engine
injection, CSRF protection, and optional hot reload. The order matters because
each middleware builds on state added by the previous stage.

### Request Context + Response Helpers

`trellisEngine(engine)` stores the Trellis engine in the request context. Route
handlers then call `renderPage()` and `renderFragment()` without global state,
and the response helpers automatically merge request-scoped values like
`csrfToken` into the template context.

### HTMX SPA Navigation

Navigation links use `hx-get` + `hx-target="#content"` + `hx-push-url="true"`.
Direct requests return full pages, while HTMX requests receive only the
`page-content` fragment for faster page transitions.

### CSRF + Dev Hot Reload

`trellisCsrf()` enables the double-submit cookie pattern for mutations, and
`devMiddleware()` watches templates and injects an SSE client when you run the
server in dev mode.

## Project Structure

```
bin/server.dart              — Shelf server, middleware pipeline, and routes
lib/handlers.dart            — Home/about handlers and counter mutations
templates/layouts/base.html  — Shared shell with HTMX and CSRF meta tag
templates/pages/index.html   — Home page with counter + feature list
templates/pages/about.html   — About page covering Shelf-specific patterns
templates/partials/nav.html  — HTMX SPA navigation
static/styles.css            — Shared starter stylesheet
```
