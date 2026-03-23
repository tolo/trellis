# Changelog

## 0.3.0

### Added

- `trellis theme` command group with five subcommands: `add`, `update`, `list`, `info`, `remove`.
- `trellis theme add <url|path>` installs themes from git URLs (shallow clone) or local paths, with optional `--ref` pinning.
- `trellis theme update [<name>]` updates installed themes via git pull or pinned ref checkout, with `min_trellis_version` compatibility warning.
- `trellis theme list` shows installed themes with active marker and versions.
- `trellis theme info <name>` displays manifest metadata and all params with current/default values.
- `trellis theme remove <name>` deletes theme directory, clears `theme:` from config, warns about orphaned `theme_params:`.
- `trellis create --template theme` scaffolds a new theme project with `theme.yaml`, layouts, SASS architecture, skins, and example preview site.
- SASS bridge wiring: `trellis build` generates a bridge wrapper that imports `_theme_params.scss` before the theme's SCSS, ensuring merged params override `!default` declarations.
- Theme SASS compilation from the theme's `sass/` directory during `trellis build`.

### Fixed

- `trellis build` now preserves `themeConfig`, `feeds`, and `searchConfig` when applying CLI overrides (previously dropped, breaking themed builds, feed generation, and search indexing).

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
