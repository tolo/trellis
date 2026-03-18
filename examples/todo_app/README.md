# Trellis Todo App Example

Complete Shelf + HTMX example showing file-based templates, fragment-first
rendering, and out-of-band updates.

## Quick Start

Run from this directory:

```bash
dart pub get
dart run bin/server.dart
```

Then open `http://localhost:8080`.

## What to Look At

- `bin/server.dart` -- Shelf router setup, Trellis engine configuration, and
  custom filters
- `lib/handlers.dart` -- full-page vs fragment render strategy for HTMX
- `templates/app.html` -- single template file containing the page shell and
  named fragments
- `static/styles.css` -- application styling

## Key Patterns

- Full-page responses use `renderFile()`
- HTMX partial responses use `renderFragment()` and `renderFragments()`
- Sidebar updates use `hx-swap-oob="true"` so counts and selection state stay
  in sync without a full page refresh
