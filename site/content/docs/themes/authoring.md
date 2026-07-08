---
title: Theme Authoring
description: Create, test, and publish a Trellis theme – the theme.yaml manifest, tl:extends/tl:define layouts, the SASS bridge, and the 19-param standard contract.
weight: 10
---

A Trellis theme is a self-contained directory of HTML layouts, SASS stylesheets,
and a YAML manifest. Themes are distributed via git and installed with the
[trellis CLI](/docs/packages/trellis_cli/). Site builders configure them
entirely through YAML – no forking required.

This guide covers creating, testing, and publishing a theme. It assumes you know
the template language ([Getting Started](/docs/getting-started/),
[Syntax Reference](/docs/syntax/)) and, in particular, template inheritance –
[`tl:extends` and `tl:define`](/docs/syntax/inheritance/) are the backbone of a
theme's layouts. For how the static site generator consumes a theme, see
[trellis_site](/docs/packages/trellis_site/).

## Author versus site builder

A theme has two audiences:

- **You, the author**, ship layouts, SASS, and a manifest that declares the
  params you support.
- **Site builders** install your theme and configure it through
  `theme_params:` in `trellis_site.yaml` – they change colors, fonts,
  navigation, and layout without touching your source.

The standard-params contract (below) is what makes this work: because every
theme supports the same 19 params, a site builder can switch themes and carry
their customizations across.

## Quick start

```bash
# Scaffold a new theme
trellis create --template theme my-theme
cd my-theme

# Edit the manifest, add layouts and SASS
# Test with the bundled example site
cd example
trellis build
trellis serve
```

You now have a working theme skeleton. The rest of this guide explains each
piece in depth.

## Theme directory structure

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
  static/                       # Static assets copied as-is (fonts, images)
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

## The theme.yaml manifest

The manifest is the single source of truth for your theme. It declares params
with types and defaults, and is parsed by
[trellis_site](/docs/packages/trellis_site/) at build time.

```yaml
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

### Manifest fields

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Lowercase, hyphen-separated identifier |
| `version` | Yes | Semantic version (e.g. `1.0.0`) |
| `author` | Yes | Author name or organization |
| `description` | Yes | One-sentence description for theme galleries |
| `min_trellis_version` | No | Minimum `trellis_site` version required |
| `screenshots` | No | Relative paths to preview PNG files |
| `features` | No | Feature tags (free-form strings for gallery filtering) |
| `params` | Yes | Parameter definitions (see below) |

### Param types

| Type | YAML example | SASS behavior | CSS custom property |
|---|---|---|---|
| `color` | `"#2563eb"` | `$trellis-primary-color: #2563eb !default` | `--trellis-primary-color: #2563eb` |
| `string` | `"system-ui, sans-serif"` | `$trellis-font-family: system-ui !default` | `--trellis-font-family: system-ui` |
| `boolean` | `true` | `$trellis-show-toc: true !default` | Not emitted as CSS |
| `int` | `160` | `$trellis-excerpt-length: 160 !default` | Not emitted as CSS |
| `enum` | `auto` | `$trellis-skin: auto !default` | Not emitted as CSS |
| `list` | (see nav_links) | Not emitted as SASS or CSS | Not emitted as CSS |

`null` defaults are emitted as `initial` in CSS custom property output (e.g.
`--trellis-footer-text: initial;`).

## The standard-params contract

The 19 standard params form a contract between themes and site builders. **Every
theme must support all 19.** This is what lets site builders switch themes and
carry their `theme_params:` customizations across.

| Category | Params |
|---|---|
| Skin & Colors | `skin`, `primary_color`, `accent_color`, `text_color`, `muted_color`, `bg_color`, `surface_color`, `border_color` |
| Typography | `font_family`, `heading_font_family`, `code_font_family` |
| Layout | `max_width`, `border_radius` |
| Navigation | `nav_links`, `social_links` |
| Footer | `footer_text`, `show_powered_by` |
| Features | `show_rss_link`, `syntax_highlighting` |

### Theme-specific params

Themes may add any number of params beyond the 19 standard ones. By convention,
place them after the standard block in `theme.yaml` with a comment separating
them, and use `snake_case` names that do not clash with the standard params:

```yaml
params:
  # === Standard Params (19) ===
  skin:
    ...
  # (other standard params)

  # === Blog-Specific Params ===
  show_reading_time:
    type: boolean
    default: true
    description: Show estimated reading time on posts
```

## SASS integration

### _variables.scss – the param bridge

Every theme param that has a SASS representation must have a corresponding
variable in `_variables.scss` using `!default`:

```scss
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

**The `!default` convention is critical.** The SASS bridge (below) generates a
`_theme_params.scss` file that defines these same variables from the merged
params (theme defaults + site `theme_params:`). That file is in the SASS load
path *before* your `_variables.scss`, so bridge values win over your `!default`
values. Never omit `!default` from any variable.

### How the SASS bridge works

During `trellis build`, the CSS processing pipeline:

1. Reads `theme.yaml` params merged with the site's `theme_params:`.
2. Generates `.trellis/build/_theme_params.scss` with
   `$trellis-*: <value> !default;` for every param.
3. Adds `.trellis/build/` to the SASS load path *before* `sass/`.
4. Compiles `sass/main.scss` with the merged load path.

Result: site builders control theme appearance entirely through
`trellis_site.yaml` – no SASS editing required.

**Load path order** (first match wins for `@import` resolution):

1. `.trellis/build/` – generated bridge files (`_theme_params.scss`, bridge
   wrappers).
2. `<site>/sass/` – site-level SASS overrides.
3. `<theme>/sass/` – your theme's `_variables.scss` etc.

During themed builds, the CLI generates a bridge wrapper that `@import`s
`_theme_params.scss` before your `main.scss`, so merged param values override
your `!default` declarations.

### Skin files

Skins are color-only presets imported before `_variables.scss`:

```scss
// _skins/_light.scss
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

### main.scss – entry point

```scss
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

The `@media (prefers-color-scheme: dark)` block handles the `skin: auto` case –
it re-declares CSS custom properties for dark mode at runtime. SASS variables
are compile-time only, so runtime skin switching requires CSS custom property
overrides.

### CSS custom properties

The SASS bridge also emits a `css/theme-props.css` file with `:root` custom
properties for every non-boolean, non-list param:

```css
:root {
  --trellis-primary-color: #2563eb;
  --trellis-font-family: system-ui, -apple-system, sans-serif;
  --trellis-max-width: 800px;
  /* ... */
}
```

Templates reference these via a
`<link rel="stylesheet" href="/css/theme-props.css">` tag in `base.html`. Your
SASS may also emit a `:root` block from `_variables.scss` for standalone
compilation (without the bridge). Boolean and list params have no CSS
custom-property equivalent – use them in templates via
`${theme.show_reading_time}` etc.

## Layouts with tl:define blocks

Theme layouts are built with template inheritance:
[`tl:extends`](/docs/syntax/inheritance/) points a child layout at a parent, and
`tl:define` fills named slots the parent declared.

### base.html – the HTML shell

`base.html` provides the full HTML document, navigation, and footer. Child
layouts inherit it via `tl:extends` and fill named slots via `tl:define`.
Standard `tl:define` blocks (present in any theme):

```html
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

### Child layout pattern

```html
<!-- home.html -->
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

### Using ${theme.*} in templates

All merged theme params are available as `${theme.<param_name>}`:

```html
<!-- Navigation from the nav_links param -->
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

Boolean params use truthiness directly in `tl:if`; list params are iterable with
`tl:each`; null params evaluate to falsy.

## What site builders can override

Site builders customize your theme along four dimensions, from simplest to most
powerful. Design your theme so the common cases only need dimension 1.

1. **Params** – change values via `theme_params:` in `trellis_site.yaml`. This
   covers the vast majority of customization.
2. **Layout override** – a file at the same relative path in the site's
   `layouts/` replaces yours entirely (site layouts are checked before the
   theme's).
3. **Block override** – override one `tl:define` slot via `tl:extends`:

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

   The `theme:` prefix forces resolution from the theme directory; without it,
   the site's own layouts are checked first – which is what enables the full
   replacement in dimension 2.
4. **SASS variable override** – a file in the site's `sass/` directory (in the
   load path before the theme) overrides your `!default` variables.

Because of this precedence, the `theme:` prefix and the `!default` convention
are what make cross-boundary customization work without forking.

## The example directory

The `example/` directory holds a minimal preview site so you can test the theme
locally without a real content site:

```yaml
# example/trellis_site.yaml
title: My Blog
description: A sample blog powered by Trellis and this theme.
baseUrl: http://localhost:4000
author: Your Name

# Use a relative path to the theme directory
theme: ..

theme_params:
  skin: auto
  nav_links:
    - label: Home
      url: /
    - label: Posts
      url: /posts/

paginate: 5
```

Run the preview from the example directory:

```bash
cd example && trellis build && trellis serve
```

## Publishing

### Repository naming

Convention: `trellis-theme-<name>` (e.g. `trellis-theme-verdant`). This makes
themes discoverable via GitHub search.

### Version tagging

Tag releases so site builders can pin to a stable version:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Installation with a pinned ref:

```bash
trellis theme add https://github.com/yourname/trellis-theme-verdant --ref v1.0.0
```

### Screenshots

Place 1280×800 PNG screenshots at `screenshots/light.png` and
`screenshots/dark.png`. These are referenced in `theme.yaml` and displayed in
theme galleries.

### Pre-publishing checklist

- [ ] All 19 standard params present with correct types and non-null defaults
      (except optional strings).
- [ ] All SASS variables use `!default`.
- [ ] `screenshots/` paths match the `theme.yaml` screenshot entries.
- [ ] The `example/` site builds cleanly with `trellis build`.
- [ ] Light and dark skins both pass WCAG 2.1 AA contrast (4.5:1 body text).
- [ ] Semantic HTML landmarks: `<header>`, `<nav>`,
      `<main id="main-content">`, `<footer>`, `<article>`.
- [ ] A skip-to-content link as the first `<body>` element.

The official Verdant theme implements every pattern in this guide – the full
manifest, `_variables.scss` with `!default`, light and dark skins, a `main.scss`
with the auto-skin media query, a `base.html` with all four `tl:define` blocks,
child layouts with `tl:extends`, taxonomy layouts, and an example preview site.
Read it alongside this guide as a reference.
