# trellis_cli

CLI tool for the [Trellis](https://pub.dev/packages/trellis) template engine — project scaffolding and developer utilities.

## Installation

```bash
dart pub global activate trellis_cli
```

Or run directly without installing:

```bash
dart pub global run trellis_cli:trellis create my_app
```

## Quick Start

```bash
trellis create my_app
cd my_app
dart pub get
dart run bin/server.dart
```

Then open http://localhost:8080 in your browser.

## Commands

### `trellis create <project-name>`

Generates a complete Shelf + HTMX + Trellis project.

Options:
- `--template` (`-t`): Project template (default: `htmx`)

The generated project includes:
- `bin/server.dart` — Shelf server with all trellis_shelf middleware and live reload
- `lib/handlers.dart` — Route handlers using `renderPage`
- `templates/layouts/base.html` — Base layout with `tl:define` blocks
- `templates/pages/index.html` — Index page using `tl:extends` and `tl:each`
- `templates/partials/nav.html` — Nav partial with `tl:fragment`
- `static/styles.css` — Starter stylesheet
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

### `trellis --version`

Prints the CLI version.

### `trellis --help`

Prints usage information.

## Project Name Rules

Project names must follow Dart package naming conventions:
- Lowercase letters, digits, and underscores only
- Must start with a letter
- Cannot be a Dart reserved word
