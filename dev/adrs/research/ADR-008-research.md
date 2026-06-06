# ADR-008 Research Appendix: SSG Theme System

Curated research supporting [ADR-008](../ADR-008-ssg-theme-system.md).

This appendix condenses the background research behind the decision to adopt a
manifest + params theme system for the Trellis SSG (`trellis_site`). It covers
prior art from established static site generators, the Trellis-specific
advantages that shaped the design, and the weighted comparison of the two
viable options.

## Objective

Design a pluggable theme system for `trellis_site` that allows distributing and
reusing pre-built themes, supports customization without forking, and integrates
with the existing layout resolution, SASS pipeline, and Trellis-specific
features.

## Prior Art

### Hugo

- **Distribution**: Hugo Modules (Go modules, recommended) or git submodules
  (classic). Modules provide semver, lock files, and CLI management
  (`hugo mod get/tidy/vendor`).
- **Structure**: Theme mirrors the site directory — `layouts/`, `static/`,
  `assets/`, `data/`, `i18n/`. Metadata in `theme.toml` (name, license, tags,
  min_version).
- **Override model**: Unified file system, project wins over theme(s).
  Multi-theme composition via `theme = ["shortcodes", "base-theme"]` (array,
  left-to-right precedence).
- **Params**: `[params]` block in `hugo.toml`. Theme documents configurable
  params in README and `exampleSite/`. Merge is shallow — overriding one key of
  a nested block requires reproducing the whole block.
- **Asset pipeline**: Hugo Pipes (extended build) — SASS, PostCSS, ESBuild,
  image processing. Theme assets in `assets/` processed via template functions;
  module mounts needed for asset composition.
- **Pain points**: Go toolchain requirement for modules; shallow param merge;
  `extended` vs standard binary confusion; steep documentation learning curve.

### Zola

- **Distribution**: `git clone` into `themes/` only. No package manager, no
  version management, no lock files.
- **Structure**: `templates/`, `static/`, `sass/`, `content/`. Metadata in
  `theme.toml`.
- **Override model**: Two-layer — site files win per path. Tera block-level
  inheritance via `{% extends %}`. Single theme only (no composition).
- **Params**: `[extra]` section in `theme.toml` with defaults; site overrides in
  `config.toml`. Shallow merge (same limitation as Hugo).
- **Asset pipeline**: Built-in grass (Rust SASS). Critical limitation: **cannot
  override theme SASS files** from the site `sass/` directory. Theme authors
  work around this with CSS custom properties or by asking users to fork.
- **Pain points**: No SASS override (most-cited complaint); no multi-theme; no
  version management; no CLI theme commands.

### Jekyll

- **Distribution**: Ruby gems via Bundler (`gem "minima"` in Gemfile). Best
  versioning story (semver + `Gemfile.lock`).
- **Override**: Same-path wins. Theme files discovered via
  `bundle info --path`. SASS override requires copying the root entry file.
- **Pain points**: Ruby/Bundler barrier; gem-hidden files confusing; ecosystem
  shrinking.

### Eleventy

- **No theme system** by design. Starter templates (git clone + customize) are
  the community pattern. No override mechanism, no update path. Maximum
  flexibility, zero discoverability.

## Key Insight

The #1 user action with a theme is **changing colors and fonts**. Without a
params system, this requires SASS knowledge or forking — which kills adoption.
Zola's inability to override theme SASS is its most-cited pain point. Hugo's
`[params]` block is what makes themes usable by non-developers.

## Trellis-Specific Advantages

1. **`tl:extends` + `tl:define`** — Block-level layout overrides without
   full-file replacement. Hugo only supports file-level overrides. A site
   builder can extend a theme's base layout and replace one block.
2. **`CompositeLoader`** — Already supports multi-directory template resolution
   with fallback. Theme integration is a natural extension (an
   `[site, theme]` loader chain).
3. **Dart-native SASS** — `trellis_css` provides SASS compilation with no npm.
   Theme SASS variables with `!default` plus an auto-generated params bridge is
   clean and requires no Trellis-specific invention.
4. **`tl:scope`** — Fragment-scoped CSS travels with HTMX partial responses, so
   theme components can carry their own styles.
5. **Expression utility objects** — `${#strings.*}`, `${#dates.*}`, etc. are
   available in theme templates for rich content formatting.

## Options Evaluated

### Option 1: Minimal Cascading (Hugo-lite)

A theme is just a directory. No manifest, no params, no CLI commands. One config
field (`theme: name`). Site files override theme files. Installation via git
submodule.

- **Score**: 81.2% weighted
- **Strength**: ~410 LOC, trivial implementation
- **Weakness**: No standard customization without forking; theme authors must
  invent their own param conventions; ecosystem fragmentation risk

### Option 2: Manifest + Params (Hugo+ with params)

Themes have a `theme.yaml` manifest declaring params with defaults, types, and
descriptions. Site overrides params in `trellis_site.yaml`. The build pipeline
auto-generates SASS variables and CSS custom properties from merged params. CLI
commands manage themes.

- **Score**: 84.5% weighted
- **Strength**: Zero-fork customization for 90%+ of cases; auto-generated
  SASS/CSS bridge; `tl:extends` block-level overrides; theme discovery via
  manifest
- **Weakness**: ~1,950 LOC; theme authors learn one more concept (`theme.yaml`)

### Comparison Summary

| Dimension | Option 1: Minimal Cascading | Option 2: Manifest + Params |
|---|---|---|
| Weighted score | 81.2% | 84.5% |
| Implementation cost | ~410 LOC | ~1,950 LOC |
| Zero-fork customization | No (forking required) | Yes (90%+ of cases) |
| Manifest / discoverability | None | `theme.yaml` |
| SASS/CSS params bridge | Manual | Auto-generated |
| CLI theme commands | None | Yes |
| New concepts for authors | Zero | `theme.yaml` manifest |

### Cross-SSG distribution & override comparison

| SSG | Distribution | Param merge | SASS override | Multi-theme |
|---|---|---|---|---|
| Hugo | Go modules / git submodule | Shallow | Yes (via mounts) | Yes (array) |
| Zola | `git clone` only | Shallow | **No** | No |
| Jekyll | Ruby gems (Bundler) | n/a (config) | Copy entry file | No |
| Eleventy | Starter clone (no theme system) | n/a | n/a | n/a |
| Trellis (chosen) | Git-based (`trellis theme add`) | Deep (site wins) | Yes (`!default`) | No (v1) |

## Recommendation

**Option 2: Manifest + Params.** The params system is the difference between
"themes exist" and "themes are usable." The implementation effort (~1,950 LOC
across three packages) is moderate and contained. Trellis's `tl:extends`
block-level overrides are a genuine differentiator versus Hugo, and the
`CompositeLoader` plus Dart-native SASS pipeline make the integration clean. The
formal decision and its consequences are recorded in ADR-008.

## External References

- Hugo Themes: https://gohugo.io/hugo-modules/theme-components/
- Hugo Modules: https://gohugo.io/hugo-modules/use-modules/
- Zola Themes: https://www.getzola.org/documentation/themes/installing-and-using-themes/
- Zola SASS override issue: https://github.com/getzola/zola/issues/837
- Hugo params merge issue: https://github.com/gohugoio/hugo/issues/8633
- Jekyll Gem Themes: https://jekyllrb.com/docs/themes/
