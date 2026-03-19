# trellis_cli

CLI tool for the [Trellis](https://pub.dev/packages/trellis) template engine — project scaffolding, static site building, and local preview.

## Installation

```bash
dart pub global activate trellis_cli
```

Or run directly without installing:

```bash
dart pub global run trellis_cli:trellis create my_app
```

## Quick Start

### Dynamic server app (Shelf + HTMX)

```bash
trellis create my_app
cd my_app
dart pub get
dart run bin/server.dart
```

Then open http://localhost:8080 in your browser.

### Static blog site

```bash
trellis create my_blog --template blog
cd my_blog
dart pub get
trellis build
trellis serve
```

Then open http://localhost:8080 in your browser.

### Dart Frog app

```bash
trellis create my_frog_app --template dart_frog
cd my_frog_app
dart pub get
dart_frog dev
```

Then open http://localhost:8080 in your browser.

### Relic app

```bash
trellis create my_relic_app --template relic
cd my_relic_app
dart pub get
dart run bin/server.dart
```

Then open http://localhost:8080 in your browser.

## Commands

### `trellis create <project-name>`

Generates a new Trellis project from a starter template.

Options:
- `--template` (`-t`): Project template to use

Available templates:

| Template | Description |
|---|---|
| `htmx` (default) | Shelf + HTMX counter app with Home/About pages, CSRF, security headers, and hot reload |
| `blog` | Static blog site built with trellis_site (Markdown content, layouts, taxonomies) |
| `dart_frog` | Dart Frog + HTMX counter app with file-based routing, CSRF, security headers, and hot reload |
| `relic` | Relic + HTMX counter app with explicit-engine wiring and security headers |

**`htmx` template** generates:
- `bin/server.dart` — Shelf server with logging, security headers, Trellis engine injection, CSRF, and optional live reload
- `lib/handlers.dart` — Home/about handlers plus counter mutation endpoints using `renderPage()` and `renderFragment()`
- `templates/layouts/base.html` — Base layout with HTMX, CSRF meta tag, and shared page shell
- `templates/pages/index.html` — Home page with counter fragment and feature list
- `templates/pages/about.html` — About page covering Shelf middleware ordering, request context, CSRF, and hot reload
- `templates/partials/nav.html` — HTMX SPA navigation partial (`hx-get` + `hx-target="#content"` + `hx-push-url="true"`)
- `static/styles.css` — Starter stylesheet
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

**`blog` template** generates:
- `trellis_site.yaml` — Site configuration (title, baseUrl, taxonomies)
- `content/` — Markdown content with front matter (`_index.md`, posts, about page)
- `layouts/` — Trellis HTML layouts (base, home, single, list, post)
- `static/styles.css` — Starter stylesheet
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

**`dart_frog` template** generates:
- `routes/_middleware.dart` — Trellis provider, security headers, CSRF middleware, and optional hot reload bridge
- `routes/index.dart` and `routes/about.dart` — file-based routes for Home/About page rendering
- `lib/counter_state.dart` — shared in-memory counter state and page context
- `routes/counter/increment.dart`, `decrement.dart`, `reset.dart` — HTMX mutation endpoints returning the counter fragment
- `templates/layouts/base.html` — base layout with HTMX, CSRF meta tag, and shared shell
- `templates/pages/index.html` — home page using template inheritance with a counter fragment
- `templates/pages/about.html` — About page covering providers, routing, middleware, CSRF, and hot reload
- `templates/partials/nav.html` — HTMX SPA navigation partial
- `public/styles.css` — starter stylesheet served by Dart Frog
- `dart_frog.yaml`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

**`relic` template** generates:
- `bin/server.dart` — Relic server setup with security headers, explicit Trellis engine wiring, routes, and static CSS serving
- `lib/handlers.dart` — Home/about handlers plus counter mutation endpoints using `trellis_relic` response helpers
- `templates/base.html` — Base layout with HTMX-powered Home/About navigation
- `templates/index.html` — Home page with the counter fragment and shared feature list
- `templates/about.html` — About page covering Relic's no-DI pattern, middleware scoping, and fragment rendering
- `static/styles.css` — starter stylesheet
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

### `trellis build`

Builds a static site from the current directory. Reads `trellis_site.yaml` for configuration, runs the full trellis_site pipeline, and compiles any SASS/SCSS files in the static directory.

Options:
- `--output` (`-o`): Output directory (default: from config, or `output`)
- `--drafts`: Include draft content (default: `false`)
- `--verbose` (`-v`): Show detailed build log

```bash
trellis build
trellis build --output dist --drafts --verbose
```

### `trellis serve`

Starts a local static file server to preview a built site. Serves from the output directory with clean URL support (`/about/` resolves to `/about/index.html`).

Options:
- `--port` (`-p`): Port to listen on (default: `8080`)
- `--output` (`-o`): Output directory to serve (default: from config, or `output`)

```bash
trellis serve
trellis serve --port 3000
```

### `trellis --version`

Prints the CLI version.

### `trellis --help`

Prints usage information.

## Maintainer Validation

Before publishing CLI or starter changes from the monorepo, run the E2E suite:

```bash
cd packages/trellis_cli
dart test -t e2e \
  test/generated_app_e2e_test.dart \
  test/dart_frog_e2e_test.dart \
  test/relic_e2e_test.dart \
  test/examples_smoke_test.dart
```

That verifies generated Shelf, Dart Frog, and Relic starters plus the checked-in
example apps under `examples/`.

## Project Name Rules

Project names must follow Dart package naming conventions:
- Lowercase letters, digits, and underscores only
- Must start with a letter
- Cannot be a Dart reserved word

## API Documentation

- https://pub.dev/documentation/trellis_cli/latest/
