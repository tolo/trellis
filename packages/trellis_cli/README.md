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

## Commands

### `trellis create <project-name>`

Generates a new Trellis project from a starter template.

Options:
- `--template` (`-t`): Project template to use

Available templates:

| Template | Description |
|---|---|
| `htmx` (default) | Shelf server with HTMX, hot reload, and trellis_shelf middleware |
| `blog` | Static blog site built with trellis_site (Markdown content, layouts, taxonomies) |
| `dart_frog` | Dart Frog + HTMX server app using trellis_dart_frog middleware and helpers |

**`htmx` template** generates:
- `bin/server.dart` — Shelf server with all trellis_shelf middleware and live reload
- `lib/handlers.dart` — Route handlers using `renderPage`
- `templates/layouts/base.html` — Base layout with `tl:define` blocks
- `templates/pages/index.html` — Index page using `tl:extends` and `tl:each`
- `templates/partials/nav.html` — Nav partial with `tl:fragment`
- `static/styles.css` — Starter stylesheet
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

**`blog` template** generates:
- `trellis_site.yaml` — Site configuration (title, baseUrl, taxonomies)
- `content/` — Markdown content with front matter (`_index.md`, posts, about page)
- `layouts/` — Trellis HTML layouts (base, home, single, list, post)
- `static/styles.css` — Starter stylesheet
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

**`dart_frog` template** generates:
- `routes/_middleware.dart` — Trellis provider, security headers, and CSRF middleware
- `routes/index.dart` and `routes/todos/index.dart` — file-based routes with HTMX fragment responses
- `templates/layouts/base.html` — base layout with HTMX and shared shell
- `templates/pages/index.html` — home page using template inheritance
- `templates/partials/nav.html` and `templates/partials/todo_list.html` — reusable partials
- `public/styles.css` — starter stylesheet served by Dart Frog
- `dart_frog.yaml`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

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

## Project Name Rules

Project names must follow Dart package naming conventions:
- Lowercase letters, digits, and underscores only
- Must start with a letter
- Cannot be a Dart reserved word
