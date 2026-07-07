# Changelog

## 0.9.0

### Added

- `trellis build --path-prefix <value>` overrides the site's `pathPrefix` (sub-path) from the command line, for building a path-prefixed variant without editing `trellis_site.yaml`.

### Fixed

- `trellis build` now carries `pathPrefix` from `trellis_site.yaml` into the build (it was dropped when the CLI reconstructed the config, so path-prefix builds silently produced root-absolute URLs).
- `trellis build` now compiles theme SASS for a theme referenced by a relative `theme:` path that escapes the site directory (e.g. `../../themes/arbor`); the theme directory is normalized before the SASS scan, so such sites no longer build silently unstyled.
- `theme_params: { skin: light | dark }` now forces the corresponding palette. The SASS bridge imports the theme's `_skins/_light.scss` / `_skins/_dark.scss` before `_theme_params.scss`, so the skin's `!default` colors win over the theme's light defaults. `skin: auto` (and unset) is unchanged — no skin import, byte-for-byte identical output. Previously the skin file was never imported, so `light`/`dark` were dead config and only `auto`'s `prefers-color-scheme` block had any effect.

## 0.8.2

### Fixed

- `trellis_cli --version` now reports the correct version — the internal version constant had drifted from the package version (stuck at 0.8.0).

## 0.8.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.0

### Changed

- Version aligned to the unified Trellis SDK lockstep versioning scheme — all SDK packages now share a single version number and are released together. No functional changes since 0.3.0.

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
