# Changelog

## 0.2.0

### Added

- `trellis build` for running the full `trellis_site` static-site pipeline from `trellis_site.yaml`.
- `trellis serve` for previewing built output with clean URL handling.
- `trellis create --template blog` for generating a Trellis blog starter with content, layouts, taxonomies, and styles.
- `trellis create --template dart_frog` for generating a Dart Frog + Trellis + HTMX starter with file-based routing, security headers, CSRF protection, and hot reload.
- `trellis create --template relic` for generating a Relic + Trellis + HTMX starter with explicit-engine wiring and counter fragment handling.

### Changed

- Expanded the starter lineup from the original Shelf scaffold to four documented templates: `htmx`, `blog`, `dart_frog`, and `relic`.

## 0.1.0

### Added

- `trellis create <project-name>` for scaffolding a Shelf + Trellis + HTMX application.
- Project-name validation for Dart naming rules and reserved words.
- Starter templates demonstrating template inheritance, HTMX fragments, security middleware, CSRF protection, and optional dev-mode live reload.
- `--help` and `--version` CLI support.
