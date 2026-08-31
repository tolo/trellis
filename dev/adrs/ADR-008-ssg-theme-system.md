# ADR-008: SSG Theme System

## Status
Accepted (implemented in SDK Phase 4)

## Context

The Trellis SSG (`trellis_site`) has Hugo-inspired layout resolution and SASS
compilation but no pluggable theme system. Users must write all layouts and CSS
from scratch or copy files manually. This is the primary adoption blocker for
the SSG — themes are the #1 driver of SSG ecosystem growth (Hugo has 400+ themes).

Research into Hugo, Zola, Jekyll, and Eleventy (see the [research appendix](research/ADR-008-research.md))
identified two viable approaches: a minimal directory-based system and a manifest +
params system. The params approach scored higher on weighted criteria (84.5% vs 81.2%)
because it enables zero-fork customization — the most important capability for
theme adoption.

Trellis has unique advantages over existing SSGs: `tl:extends`/`tl:define` enables
block-level layout overrides (Hugo only supports file-level replacement),
`CompositeLoader` already handles multi-directory template resolution, and
Dart-native SASS compilation integrates cleanly with a params-to-variables bridge.

## Decision

**We will implement a manifest + params theme system with git-based distribution.**

A theme is a directory under `themes/` containing a `theme.yaml` manifest, layouts,
static assets, SASS source, and optionally data files. Themes declare configurable
params with defaults. Site builders customize themes via `theme_params:` in
`trellis_site.yaml` without forking.

### Theme structure

```
themes/<name>/
  theme.yaml              # Manifest: name, version, params with defaults
  layouts/                # Theme layouts (cascading — site layouts win)
  sass/                   # Theme SASS source (with !default variables)
  static/                 # Theme static assets (fonts, images, JS)
  data/                   # Theme-provided global data (optional)
```

### Configuration

```yaml
# trellis_site.yaml
theme: aurora
theme_params:
  primary_color: "#e11d48"
  dark_mode: false
```

### Override model (4 dimensions)

1. **Params** (YAML) — change colors, fonts, feature toggles without touching files
2. **Layout cascading** — site `layouts/` files override theme layouts at the same path
3. **`tl:extends` block overrides** — extend a theme layout and redefine specific blocks
4. **SASS variable overrides** — site `sass/_variables.scss` overrides theme `!default` vars

### Build pipeline integration

- Auto-generate `_theme_params.scss` from merged params (SASS variables)
- Auto-generate CSS custom properties (`:root { --trellis-* }`) for runtime overrides
- Theme SASS compiled with load path: `[site/sass/, theme/sass/]`
- Theme static assets merged with site static (site wins on conflict)
- Merged params injected into template context as `${theme.*}`

### Distribution

Git-based (like Hugo modules). Installation via `trellis theme add <git-url>` clones a single-theme repository into
`themes/` and updates config. `trellis theme add <git-url> --theme <name>` selects `themes/<name>/` from a repository
that carries multiple themes, copying only that subtree into the site. No package registry in v1.

### CLI commands

- `trellis theme add <git-url> [--theme <name>]` — install a whole theme repository or select one from a
  multi-theme repository
- `trellis theme update [<name>]` — update whole-repository installs that retain git metadata
- `trellis theme list` — list installed themes
- `trellis theme info <name>` — show params, features, version
- `trellis theme remove <name>` — uninstall theme
- `trellis create --template theme` — scaffold a new theme

## Consequences

### Positive

- Zero-fork customization for 90%+ of theme use cases via params
- Block-level layout overrides via `tl:extends`/`tl:define` — unique advantage over Hugo
- Dart-native SASS integration with auto-generated variable bridge
- CSS custom properties enable no-SASS overrides (plain CSS)
- Theme manifest enables future discoverability (gallery, search)
- `CompositeLoader` makes template inheritance work across theme/site boundary transparently
- `tl:scope` fragment CSS works in themes for HTMX-ready components

### Negative

- ~1,950 LOC across 3 packages (`trellis_site`, `trellis_cli`, `trellis_css`)
- Theme authors must learn `theme.yaml` manifest format and SASS `!default` convention
- Auto-generated `_theme_params.scss` adds build pipeline complexity
- Single active theme only (no multi-theme composition in v1)
- Git-based distribution requires git knowledge; no graphical theme browser

### Neutral

- No changes to core `trellis` package
- Theme params live in `${theme.*}` namespace, separate from `${site.params.*}`
- Themes are committed to the site repo (no external dependency resolution at build time)
- `theme.yaml` type hints are advisory in v1 (no runtime validation)

## Alternatives Considered

### Option 1: Minimal Cascading (directory convention only)
- **Pros**: ~410 LOC, zero new concepts, theme = directory
- **Cons**: No params (forking required for color changes), no manifest (no discoverability),
  no standard customization convention, ecosystem fragmentation risk
- **Rejected because**: The #1 theme use case (changing colors/fonts) requires forking,
  which kills adoption. Zola has this problem and it's their most-cited complaint.

### Eleventy-style (starter templates, no theme system)
- **Pros**: Zero implementation, maximum flexibility
- **Cons**: No update path, no override mechanism, no discoverability
- **Rejected because**: This is what Trellis has today. It's not working.

### pub.dev package themes
- **Pros**: Dart-native distribution, semver, dependency resolution
- **Cons**: Themes are static files, not Dart code — pub.dev adds ceremony without value.
  Dart compilation overhead for assets. Users must understand pub.dev.
- **Rejected because**: Git distribution is simpler and matches established SSG conventions
  (Hugo modules, Zola themes). Can be reconsidered if ecosystem grows beyond ~50 themes.

## Implementation Notes

- Layout resolver changes from single `layoutsDir` to `List<String> layoutSearchPaths`
- `CompositeLoader` already exists — theme integration creates `[site, theme]` loader chain
- SASS `!default` is the standard mechanism for overridable variables (no Trellis-specific invention)
- CSS custom properties generated with `--trellis-{param}` naming convention
- Theme param deep merge: maps merged recursively, scalars/lists replaced (site wins)
- `trellis theme add` does a shallow git clone + config update (simple, no Go toolchain). A whole-repository install
  retains its git metadata and supports `theme update`; a `--theme` install copies only the selected subtree, so it
  must be removed and re-added to change versions.

## References

- Research: [Research appendix](research/ADR-008-research.md)
- Hugo Themes: https://gohugo.io/hugo-modules/theme-components/
- Hugo Modules: https://gohugo.io/hugo-modules/use-modules/
- Zola Themes: https://www.getzola.org/documentation/themes/installing-and-using-themes/
- Zola SASS override issue: https://github.com/getzola/zola/issues/837
- Hugo params merge issue: https://github.com/gohugoio/hugo/issues/8633
- Jekyll Gem Themes: https://jekyllrb.com/docs/themes/
