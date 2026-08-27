# Theme Authoring Guide

A Trellis theme is a self-contained directory of HTML layouts, SASS stylesheets, and a YAML manifest. Themes are distributed via git and installed with the `trellis` CLI. Site builders configure them entirely through YAML — no forking required.

This guide covers everything you need to create, test, and publish a theme.

Related docs:
- [Theme Usage Guide](theme-usage.md) — how site builders install and configure themes
- [Standard Params Contract](../reference/standard-params.md) — the 18 params every theme must support


## Quick Start

```bash
# Scaffold a new theme
trellis create --template theme my-theme
cd my-theme

# Edit the manifest
# Add layouts and SASS
# Test with the bundled example site
cd example
trellis build
trellis serve
```

You now have a working theme skeleton. The rest of this guide explains each piece in depth.


## Theme Directory Structure

```
my-theme/
  theme.yaml                    # Manifest — name, version, params
  layouts/
    base.html                   # Root HTML shell (tl:define blocks)
    home.html                   # Home page layout
    _default/
      single.html               # Default single page/post layout
      list.html                 # Default section listing layout
    tags/                       # Taxonomy-specific layouts (optional)
      term.html
      list.html
  sass/
    _variables.scss             # All theme params as $trellis-* with !default
    _skins/
      _light.scss               # Light color preset
      _dark.scss                # Dark color preset
    _base.scss                  # Reset and typography
    _layout.scss                # Page structure and breakpoints
    _components.scss            # UI components
    _footer.scss                # Footer styles
    _a11y.scss                  # Accessibility: skip-link, focus rings
    _code.scss                  # Code block styles
    main.scss                   # Entry point — imports all partials
  static/                       # Static assets copied as-is (fonts, images, vendored JS/CSS — see Third-Party and Vendored Assets)
    .gitkeep
  screenshots/
    light.png                   # Preview screenshot (light skin)
    dark.png                    # Preview screenshot (dark skin)
  example/
    trellis_site.yaml           # Minimal preview site config
    content/
      _index.md
      posts/
        _index.md
        welcome.md
    layouts/                    # Optional site-specific overrides for preview
```

> **Verdant reference**: The official Verdant theme at `themes/verdant/` follows this exact structure. Read it alongside this guide.


## theme.yaml Reference

The manifest is the single source of truth for your theme. It declares params with types and defaults, and is parsed by `trellis_site` at build time.

```yaml
# themes/verdant/theme.yaml (abbreviated)
name: verdant
version: 1.0.0
author: Trellis Team
description: >-
  A minimal, accessible blog theme for Trellis. Content-first design with
  three color skins, responsive layout, and full keyboard navigation.
min_trellis_version: 0.8.0
screenshots:
  - screenshots/light.png
  - screenshots/dark.png
features:
  - blog
  - dark-mode
  - responsive
  - accessible

params:
  # Standard params (required by the contract)
  skin:
    type: enum
    values: [light, dark, auto]
    default: auto
    description: Color scheme — auto follows OS prefers-color-scheme

  primary_color:
    type: color
    default: "#2563eb"
    description: Brand/accent color — links, buttons, active states

  # Theme-specific params (optional extensions)
  hero_title:
    type: string
    default: null
    description: Homepage hero title override (null = site title)
```

### Manifest Fields

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Theme identifier. Must match `^[a-z0-9][a-z0-9_-]*$` and equal the name of the directory the manifest sits in |
| `version` | Yes | Semantic version (e.g. `1.0.0`) |
| `author` | No | Author name or organization. Recommended, but nothing reads it — neither `ThemeManifest.load` nor the gallery generator requires it |
| `description` | Yes | One-sentence description for theme galleries. Plain prose — no backticks |
| `min_trellis_version` | No | Minimum `trellis_site` version required |
| `screenshots` | No | Relative paths to preview PNG files, resolving inside the theme directory |
| `features` | Yes | Feature tags. Must contain exactly one **archetype** tag — `docs`, `landing`, or `blog` — plus any number of free-form tags |
| `params` | Yes | Parameter definitions (see below). Required by the standard-params contract below, not by the loader: a theme with no `params:` loads and builds, and simply ignores every `theme_params:` a site sets |

#### Name and archetype rules

The theme gallery is generated from the manifests and CI gates the generated
output (`dart run tool/generate_theme_gallery.dart --check`), so these rules are
checked mechanically. Each one fails the generator with an error naming the
theme:

- **`theme.yaml` parses as a YAML mapping** — a malformed file is reported
  against the theme rather than as a bare parser stack trace.
- **`name` is a non-empty string** matching `^[a-z0-9][a-z0-9_-]*$`. The name
  becomes a directory segment in every site that installs the theme and a path
  segment in the gallery's asset URLs, so it has to be portable on every
  filesystem and safe in a URL. It is also what
  `trellis theme add --theme <name>` accepts.
- **`name` equals the directory name** — a theme in `themes/orchard/` must
  declare `name: orchard`. The installed directory and the configured
  `theme:` value are the same string, so a mismatch would install a theme that
  cannot be selected.
- **`themes/<name>/README.md` exists** — every gallery card links to it, and the
  link is external to the built site, so no link checker would catch a dead one.
- **`description` is a non-empty string** and **contains no backticks**. The
  gallery renders it with `tl:text`, so `` `backticks` `` reach the card as
  literal characters instead of code formatting.
- **`features` is a list of strings** containing **exactly one archetype tag** —
  one of `docs`, `landing`, `blog`. The gallery shows it as the card's archetype
  label, which is how a site builder picks a starting point; zero tags leave the
  card unlabelled and two make the label ambiguous. Every other `features` entry
  (`dark-mode`, `responsive`, `search`, …) is free-form.
- **Every declared `screenshots` path stays inside the theme directory**, both
  as written and after symlinks are resolved — the generator copies those files
  into the published site.

Two screenshot problems are warnings rather than failures, and the card is
published without the image: a file named anything other than `light.png` or
`dark.png` (only those two variants reach a card), and a declared path with no
file behind it.

### Param Types

| Type | YAML example | SASS behavior | CSS custom property |
|---|---|---|---|
| `color` | `"#2563eb"` | `$trellis-primary-color: #2563eb !default` | `--trellis-primary-color: #2563eb` |
| `string` | `"system-ui, sans-serif"` | `$trellis-font-family: system-ui !default` | `--trellis-font-family: system-ui` |
| `boolean` | `true` | `$trellis-show-toc: true !default` | Not emitted as CSS |
| `int` | `160` | `$trellis-excerpt-length: 160 !default` | Not emitted as CSS |
| `enum` | `auto` | `$trellis-skin: auto !default` | Not emitted as CSS |
| `list` | (see nav_links) | Not emitted as SASS or CSS | Not emitted as CSS |

`null` defaults are emitted as `initial` in CSS custom property output (e.g. `--trellis-footer-text: initial;`).

> String params are emitted unquoted (via `#{"…"}` interpolation), so font stacks and lengths
> are usable directly as CSS values; `"`/`\` are escaped and `#{…}` is never evaluated.


## The Params System

### Standard Params (18)

The 18 standard params form a contract between themes and site builders. Every theme MUST support all 18. This lets site builders switch themes and carry their `theme_params:` customizations.

See the [Standard Params Contract](../reference/standard-params.md) for the full specification.

| Category | Params |
|---|---|
| Skin & Colors | `skin`, `primary_color`, `accent_color`, `text_color`, `muted_color`, `bg_color`, `surface_color`, `border_color` |
| Typography | `font_family`, `heading_font_family`, `code_font_family` |
| Layout | `max_width`, `border_radius` |
| Navigation | `nav_links`, `social_links` |
| Footer | `footer_text`, `show_powered_by` |
| Features | `show_rss_link` |

### Theme-Specific Params

Themes may add any number of additional params beyond the 18 standard ones. Convention: place them after the standard block in `theme.yaml` with a comment separating them.

```yaml
params:
  # === Standard Params (18) ===
  skin:
    ...
  # (other standard params)

  # === Blog-Specific Params ===
  show_reading_time:
    type: boolean
    default: true
    description: Show estimated reading time on posts
```

Naming convention for theme-specific params: use `snake_case`, and avoid names that clash with standard params.

`excerpt_length` is an optional, theme-specific content-rendering param. Themes that use generated summaries can declare it
as an `int`; it controls the plain-text summary length. It is not part of the 18 standard params.


## Theme Data Files

A theme can provide YAML data files under `data/` for structured content that belongs to the theme rather than to a
parameter. For example, `data/navigation.yaml` is available to layouts as `${data.navigation.*}`. The filename stem becomes
the key below `${data}`.

Theme data is a fallback. Trellis loads the theme's files first, then the site's `data/*.yaml` files. When both provide the
same stem, the site file replaces the complete theme value – nested maps and lists are not deep-merged. Files with different
stems remain available together. This lets a theme ship useful defaults while a site owns any deliberate replacement.


## SASS Integration

### _variables.scss — The Param Bridge

Every theme param that has a SASS representation must have a corresponding variable in `_variables.scss` using `!default`:

```scss
// themes/verdant/sass/_variables.scss
$trellis-skin: auto !default;
$trellis-primary-color: #2563eb !default;
$trellis-accent-color: #3b82f6 !default;
$trellis-text-color: #1f2937 !default;
$trellis-muted-color: #6b7280 !default;
$trellis-bg-color: #ffffff !default;
$trellis-surface-color: #f3f4f6 !default;
$trellis-border-color: #e5e7eb !default;

$trellis-font-family: system-ui, -apple-system, sans-serif !default;
$trellis-heading-font-family: null !default;
$trellis-code-font-family: ui-monospace, SFMono-Regular, monospace !default;

// Derived variable — heading font falls back to body font when null
$trellis-heading-font: if($trellis-heading-font-family, $trellis-heading-font-family, $trellis-font-family);
```

**The `!default` convention is critical.** The SASS bridge (see below) generates a `_theme_params.scss` file that defines these same variables from the merged params (theme defaults + site `theme_params:`). That file is in the SASS load path before your `_variables.scss`, so bridge values win over your `!default` values. Never omit `!default` from any variable.

### How the SASS Bridge Works

During `trellis build`, the CSS processing pipeline:

1. Reads `theme.yaml` params merged with site `theme_params:`
2. Generates `.trellis/build/_theme_params.scss` with `$trellis-*: <value> !default;` for every param
3. Adds `.trellis/build/` to the SASS load path *before* `sass/`
4. Compiles `sass/main.scss` with the merged load path

Result: site builders control theme appearance entirely through `trellis_site.yaml` — no SASS editing required.

**Load path order** (first match wins for `@import` resolution):
1. `.trellis/build/` — generated bridge files (`_theme_params.scss`, bridge wrappers)
2. `<site>/sass/` — site-level SASS overrides
3. `<theme>/sass/` — your theme's `_variables.scss` etc.

During themed builds, the CLI generates a bridge wrapper that `@import`s `_theme_params.scss` before your `main.scss`. This ensures merged param values override your `!default` declarations.

### Skin Files

Skins are color-only presets imported before `_variables.scss`:

```scss
// themes/verdant/sass/_skins/_light.scss
// WCAG 2.1 AA contrast ratios:
//   #1f2937 on #ffffff = 14.7:1 (body text — passes 4.5:1)
//   #2563eb on #ffffff =  4.6:1 (primary — passes 4.5:1)

$trellis-text-color: #1f2937 !default;
$trellis-muted-color: #6b7280 !default;
$trellis-bg-color: #ffffff !default;
$trellis-surface-color: #f3f4f6 !default;
$trellis-border-color: #e5e7eb !default;
$trellis-primary-color: #2563eb !default;
$trellis-accent-color: #3b82f6 !default;
```

The SASS bridge imports the correct skin based on the `skin` param value.

### main.scss — Entry Point

```scss
// themes/verdant/sass/main.scss
@import 'variables';
@import 'base';
@import 'layout';
@import 'components';
@import 'footer';
@import 'a11y';
@import 'code';

// Auto skin: override CSS custom properties for dark mode at runtime
@media (prefers-color-scheme: dark) {
  :root {
    --trellis-text:    #f3f4f6;
    --trellis-muted:   #9ca3af;
    --trellis-bg:      #111827;
    --trellis-surface: #1f2937;
    --trellis-border:  #374151;
    --trellis-primary: #3b82f6;
    --trellis-accent:  #60a5fa;
  }
}
```

The `@media (prefers-color-scheme: dark)` block handles the `skin: auto` case — it re-declares CSS custom properties for dark mode at runtime. SASS variables are compile-time only; runtime skin switching requires CSS custom property overrides.


## CSS Custom Properties

The SASS bridge also emits a `css/theme-props.css` file with `:root` custom properties for every non-boolean, non-list param:

```css
:root {
  --trellis-primary-color: #2563eb;
  --trellis-font-family: system-ui, -apple-system, sans-serif;
  --trellis-max-width: 800px;
  /* ... */
}
```

Templates reference these via the `<link rel="stylesheet" href="/css/theme-props.css">` tag in `base.html`. Your SASS may also emit a `:root` block from `_variables.scss` for standalone compilation (without the bridge):

```scss
:root {
  --trellis-primary: #{$trellis-primary-color};
  --trellis-text: #{$trellis-text-color};
  /* ... */
}
```

**Note**: Boolean and list params have no CSS custom property equivalent. Use them in templates via `${theme.show_reading_time}` etc.


## Layouts with tl:define Blocks

### base.html — The HTML Shell

`base.html` provides the full HTML document, navigation, and footer. Child layouts inherit it via `tl:extends` and fill named slots via `tl:define`.

Standard `tl:define` blocks (must be present in any theme):

```html
<!-- themes/verdant/layouts/base.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title tl:text="${page.title} + ' — ' + ${site.title}">Page — Site</title>
  <meta name="description"
        tl:attr="content=${page.description} ?: ${page.summary} ?: ${site.description}">

  <link rel="stylesheet" href="/css/main.css">
  <link rel="stylesheet" href="/css/theme-props.css">

  <!-- RSS feed link — conditional on show_rss_link param -->
  <link tl:if="${site.feeds.atom} and ${theme.show_rss_link}"
        rel="alternate" type="application/atom+xml"
        title="Atom Feed" tl:attr="href=${site.feeds.atom}">

  <!-- Extra head slot for child layouts to inject tags -->
  <meta tl:define="head-extra">
</head>
<body>
  <a href="#main-content" class="skip-to-content">Skip to content</a>

  <header class="site-header" tl:define="site-header">
    <!-- nav here -->
  </header>

  <main id="main-content" class="main-content" tl:define="content">
    <!-- child layouts fill this -->
  </main>

  <footer class="site-footer" tl:define="site-footer">
    <!-- footer here -->
  </footer>
</body>
</html>
```

### Child Layout Pattern

```html
<!-- themes/verdant/layouts/home.html -->
<html tl:extends="layouts/base.html" lang="en">
<head><title>Home</title></head>
<body>
  <main tl:define="content">
    <div class="container">
      <section class="hero">
        <h1 tl:text="${theme.hero_title} ?: ${site.title}">Welcome</h1>
      </section>
      <!-- post cards here -->
    </div>
  </main>
</body>
</html>
```

### Cross-Boundary Inheritance

Site builders can override individual `tl:define` blocks without forking the theme:

```html
<!-- site/layouts/base.html — override just the footer -->
<html tl:extends="theme:layouts/base.html" lang="en">
<body>
  <footer tl:define="site-footer">
    <p>Custom footer without touching the theme.</p>
  </footer>
</body>
</html>
```

The `theme:` prefix forces resolution from the theme directory. Without it, `CompositeLoader` checks site layouts first — enabling full replacement.

### Using ${theme.*} in Templates

All merged theme params are available as `${theme.<param_name>}`:

```html
<!-- Navigation from nav_links param -->
<ul class="nav-list">
  <li tl:each="link : ${theme.nav_links}">
    <a tl:href="${link.url}" tl:text="${link.label}">Link</a>
  </li>
</ul>

<!-- Conditional feature toggle -->
<span tl:if="${theme.show_reading_time}"
      tl:with="readTime=${#numbers.max(#numbers.ceil(#strings.length(page.content) / 1000), 1)}">
  <span tl:text="${readTime} + ' min read'">3 min read</span>
</span>
```

Boolean params use truthiness directly in `tl:if`. List params are iterable with `tl:each`. Null params evaluate to falsy.


## The Example Directory

The `example/` directory holds a minimal preview site so theme authors can test the theme locally without needing a real content site.

```yaml
# themes/verdant/example/trellis_site.yaml
title: My Blog
description: A sample blog powered by Trellis and the Verdant theme.
baseUrl: http://localhost:4000

# Resolve the bundled theme by name (see the symlink note below).
theme: verdant

theme_params:
  skin: auto
  nav_links:
    - label: Home
      url: /
    - label: Posts
      url: /posts/

paginate: 5
```

The build resolves a theme by joining `<siteDir>/themes/<value>`, so the example needs a `themes/verdant` entry. Because the example lives *inside* the theme, that entry is a relative symlink pointing back at the theme root — create it once with `ln -s ../.. example/themes/verdant`. Official themes ship this layout. (A bare `theme: ..` does **not** work: it resolves to the example directory itself, not the theme.)

Run the preview:

```bash
cd themes/verdant/example
trellis build
trellis serve
```

Or from the theme root, using the example directory:

```bash
cd example && trellis build && trellis serve
```


## Third-Party and Vendored Assets

A built Trellis site is a **self-contained folder you can host anywhere** — it must keep working with JavaScript disabled and with no reachable third-party host. That model (pure Dart, no external dependencies, offline-capable) sets a default preference order for any asset a theme needs — a font, a script, a stylesheet, a highlighter:

> **Prefer self-contained, build-time-generated output; then vendored, same-origin assets; and only as a last resort, runtime CDN dependencies.**

1. **Build-time output (best)** — generate the asset during `trellis build` and ship the result. No runtime cost, no third-party trust surface. Example: syntax highlighting is produced at build time by `trellis_site`, so themes carry only token CSS and no highlighter JS (see [ADR-010](../../dev/adrs/ADR-010-syntax-highlighting.md)).
2. **Vendored, same-origin asset (acceptable)** — commit the asset and serve it from `static/`, alongside the HTML that loads it. Auditable, pinnable, and outage-independent. Example: Arbor's first-party `search.js` and `code-enhance.js`, documented for provenance in [`themes/arbor/VENDORED.md`](../../themes/arbor/VENDORED.md).
3. **Runtime CDN dependency (last resort)** — fetching a script, font, or stylesheet from an external host at page load trades **availability, privacy, and supply-chain integrity** for convenience: the page breaks if the host is down or blocked, every visitor's request leaks to a third party, and a compromised CDN can inject code into your site.

This is a **default with rationale, not an absolute ban.** Reaching for tier 3 is allowed as a deliberate, documented exception — a conscious trade-off, not the path of least resistance. If you do, record *why* (the way `VENDORED.md` records provenance for tier 2) so the next maintainer can re-evaluate it.

The `static/` directory in the [directory structure](#theme-directory-structure) above holds everything copied verbatim into the build output — fonts, images, and any vendored JS/CSS — all served same-origin (tier 2). Keeping a dependency there instead of on a CDN *is* the line between tiers 2 and 3.

**Worked example — Verdant ships no highlighter.** Verdant, the minimal blog theme, deliberately ships **no** client-side highlighter rather than pulling one from a CDN. Its [`layouts/base.html`](../../themes/verdant/layouts/base.html) records the reasoning inline: a CDN highlighter would break the offline-capable static-site model, so code renders clean but uncolored, and a site that wants color can self-host a highlighter and inherit the theme's token colors. Arbor, the docs sibling, is the theme that historically vendored a full highlighter (tier 2); [ADR-010](../../dev/adrs/ADR-010-syntax-highlighting.md) moves highlighting for both themes to tier 1 (build-time output).


## Publishing

### Repository Naming

Convention: `trellis-theme-<name>` (e.g. `trellis-theme-orchard`). This makes themes discoverable via GitHub search.

A theme can also live under `themes/<name>/` in a repository that carries several — the layout the built-in Trellis themes use. Site builders install one of those with `trellis theme add <url> --theme <name>`, which copies just that subdirectory.

### Version Tagging

Tag releases so site builders can pin to a stable version:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Installation with a pinned ref:

```bash
trellis theme add https://github.com/yourname/trellis-theme-orchard --ref v1.0.0
```

### Screenshots

Place 1280×800 PNG screenshots at `screenshots/light.png` and `screenshots/dark.png`. These are referenced in `theme.yaml` and displayed in theme galleries.

### theme.yaml Checklist Before Publishing

- [ ] All 18 standard params present with correct types and non-null defaults (except optional strings)
- [ ] All SASS variables use `!default`
- [ ] `README.md` in the theme directory — the gallery card links straight to it
- [ ] `screenshots/` paths match `theme.yaml` screenshot entries
- [ ] `example/` site builds cleanly with `trellis build`
- [ ] Light and dark skins both pass WCAG 2.1 AA contrast (4.5:1 body text)
- [ ] Semantic HTML landmarks: `<header>`, `<nav>`, `<main id="main-content">`, `<footer>`, `<article>`
- [ ] Skip-to-content link as first `<body>` element


## Verdant as Reference

The official Verdant theme implements all patterns in this guide:

| Pattern | Verdant file |
|---|---|
| Full manifest: 18 standard + theme-specific params | `themes/verdant/theme.yaml` |
| `_variables.scss` with `!default` | `themes/verdant/sass/_variables.scss` |
| Light and dark skin files | `themes/verdant/sass/_skins/` |
| `main.scss` with auto skin media query | `themes/verdant/sass/main.scss` |
| `base.html` with all four `tl:define` blocks | `themes/verdant/layouts/base.html` |
| Child layout with `tl:extends` | `themes/verdant/layouts/home.html` |
| Reading time via `#numbers` and `#strings` | `themes/verdant/layouts/_default/single.html` |
| Taxonomy layouts | `themes/verdant/layouts/tags/` |
| Example preview site | `themes/verdant/example/` |
