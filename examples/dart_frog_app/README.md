# Dart Frog + Trellis Example

A todo application demonstrating [Dart Frog](https://dartfrog.vgv.dev/) +
[Trellis](https://pub.dev/packages/trellis) + [HTMX](https://htmx.org) integration.

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
- `routes/todos/index.dart` handles `GET|POST|PUT|DELETE /todos`
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

### HTMX Todo Interaction

The todo list demonstrates full CRUD via HTMX fragment rendering:

1. `POST /todos` adds a new todo (form submission)
2. `PUT /todos` toggles done state (button click)
3. `DELETE /todos` removes a todo (button click)
4. Each mutation returns only the `todo-list` fragment — HTMX swaps it in place
5. No JavaScript required beyond HTMX itself

### Template Inheritance

Templates use Trellis's `tl:extends` and `tl:define`:

- `layouts/base.html` defines the page shell with `content` and `footer` blocks
- `pages/index.html` extends the base layout and overrides `content`
- `partials/todo_list.html` defines the `todo-list` fragment for HTMX responses

### Security Headers + CSRF Protection

`trellisSecurityHeaders()` middleware adds protective HTTP headers. `trellisCsrf()`
enables double-submit cookie CSRF protection:

- A `csrfToken` is automatically available in the template context
- The base layout injects it via `<meta name="csrf-token">`
- HTMX sends it on every request via `htmx:configRequest`
- Forms include a hidden `_csrf` field

### Dev Mode Hot Reload

When `DEV=true` is set, `trellis_dev`'s `devMiddleware` watches template files and
injects an SSE script. Template changes are reflected instantly without restarting
the server.

## Project Structure

```
routes/_middleware.dart           — Engine setup, security, CSRF, dev middleware
routes/index.dart                 — Home page handler
routes/todos/index.dart           — Todo CRUD handlers (GET/POST/PUT/DELETE)
templates/layouts/base.html       — Base layout with nav, CSRF meta, HTMX script
templates/pages/index.html        — Home page with features list and todo app
templates/partials/nav.html       — Navigation partial
templates/partials/todo_list.html — Todo list fragment for HTMX responses
public/styles.css                 — Application styles
```

## Dependencies

| Package | Description |
|---------|-------------|
| [`dart_frog`](https://pub.dev/packages/dart_frog) | File-based routing web framework |
| [`trellis`](https://pub.dev/packages/trellis) | HTML template engine |
| [`trellis_dart_frog`](https://pub.dev/packages/trellis_dart_frog) | Trellis + Dart Frog integration |
| [`trellis_dev`](https://pub.dev/packages/trellis_dev) | Template hot reload (dev mode) |
