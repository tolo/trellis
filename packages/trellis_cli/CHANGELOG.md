# Changelog

## 0.11.0

### Added

- `trellis theme add <url-or-path> --theme <name>` installs a single theme out of a source that carries several,
  copying only its `themes/<name>/` directory into the site. The built-in themes are distributed this way – they live
  under `themes/` in the `tolo/trellis` repository, not in one repository each – so
  `trellis theme add https://github.com/tolo/trellis --theme lattice --ref v0.11.0` installs just that theme from the
  release tag. `--ref` also accepts a branch, and the temporary clone is removed on every path, failures included.
  Whole-repository git installs additionally validate the directory name derived from the URL before cloning; all
  install paths now warn when the installed manifest requires a newer Trellis version. A theme installed this way
  carries no git metadata, so
  `trellis theme update` does not apply to it – remove and re-add instead.
- `validateThemeName`, exported from `package:trellis_cli/trellis_cli.dart`, is the rule a `--theme` value is checked
  against: `^[a-z0-9][a-z0-9_-]*$`. A name outside that charset is rejected before anything is cloned, so `--theme`
  cannot traverse out of the site's `themes/`. A source whose own `themes/<name>` is a symlink resolving outside the
  source tree is rejected as well, and nothing is copied.

### Changed

- **`trellis theme add` warns when site layouts shadow the theme it just installed**, naming each shadowing file.
  Layouts resolve site-first, so a scaffold that ships its own `layouts/` silently wins over the theme. Installing
  still succeeds and still exits 0.
- **`trellis theme add` validates `trellis_site.yaml` before installing anything.** Invalid field types exit 1
  without creating `themes/` or rewriting the configuration.
- **`trellis build` warns when an active theme is inert** – its stylesheets and scripts were published to the output
  and no emitted page links any of them, which is the case that renders an unstyled site. Only `.css` and `.js` count;
  a page carrying the theme's favicon or a font it never applies is still unstyled. The build still exits 0. An
  override that keeps a link to the theme's stylesheet is not reported – a `base.html` copied from the theme, or a
  layout rendering inside the theme's shell. Replacing `base.html` with a shell of your own *is* reported, because
  nothing links the theme after that.
- The blog scaffold's sample post now explains that a date-only `date:` is anchored at UTC midnight, and shows the
  zone-explicit form (`date: 2026-03-15T09:30:00Z`) for pinning an exact instant. Matches the front-matter date
  resolution `trellis_site` 0.11.0 ships.

### Documentation

- The README's built-in Lattice examples now install from `https://github.com/tolo/trellis` with
  `--theme lattice --ref v0.11.0`. They previously pointed at a per-theme repository
  (`tolo/trellis-theme-verdant`) that does not exist. `--ref` is documented as becoming `git clone --branch`, so it
  takes a tag or branch that already exists on the remote.
- `trellis theme add --help` described `--ref` as taking a tag, branch **or commit**. It becomes `git clone --branch`,
  which does not accept a commit SHA, so the help text now says tag or branch. The README already said this.

## 0.10.2

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.10.1

### Changed

- Scaffolded projects now load HTMX 2.0.10 (was 2.0.8). The version, its Subresource Integrity hash, and the `<script>` tag itself come from a single constant (`src/templates/htmx_asset.dart`) instead of being copy-pasted into each layout, so future bumps are one edit. HTMX 4 adoption is deferred — see ADR-011 for the version policy and its revisit trigger.

### Fixed

- The Relic scaffold's HTMX `<script>` tag now carries `integrity` and `crossorigin` attributes, matching the Shelf and Dart Frog scaffolds. Generated Relic projects previously loaded HTMX from the CDN without Subresource Integrity. The `relic_app` and `todo_app` examples, which had the same gap, are SRI-pinned too, and a test asserts every example carries the current hash.

## 0.10.0

### Changed

- `trellis build` no longer prints Dart Sass's `@import` deprecation warning. The generated theme bridge and theme partials deliberately use `@import` (the `@use` migration is tracked as TD-006); the build now silences that one deprecation so build output stays clean. Other Sass warnings are unaffected.

### Fixed

- `trellis theme add`/`update` now exit 1 with an actionable error message when git cannot be spawned (missing git, or any other spawn failure such as `EACCES`), instead of surfacing an uncaught `ProcessException` stack trace.
- `trellis theme add <local-path>` now skips symlinks — printing a `Skipped symlink:` notice — instead of recursing into self-referential example scaffolding links (e.g. `example/themes/<name> → ../..`), which could otherwise recurse unboundedly.
- Scaffolded themes (`trellis create --template theme`) no longer include the retired `syntax_highlighting` param (ADR-010); the generated `theme.yaml` now declares the 18-param contract and highlighting is controlled via `trellis_site.yaml`'s `highlight:` block.

## 0.9.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

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
