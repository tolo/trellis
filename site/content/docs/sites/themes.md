---
title: Themes
description: Install, configure, customize, update, and remove Trellis themes.
weight: 40
---

Themes package reusable layouts, styles, assets, and configuration defaults.

## Install a theme

Install one of the themes in the Trellis repository:

```bash
trellis theme add https://github.com/tolo/trellis --theme lattice --ref v0.11.0
```

For a repository containing one theme, omit `--theme`:

```bash
trellis theme add https://github.com/yourname/trellis-theme-orchard
```

Pin production sites to a tag or branch with `--ref`. The ref must already
exist on the remote. During local theme development, install from a directory:

```bash
trellis theme add ../trellis-theme-orchard
trellis theme add ../trellis --theme lattice
```

The command copies the theme under `themes/` and updates `theme:` in
`trellis_site.yaml`.

> A site layout wins over a theme layout at the same path. The `blog` starter
> includes its own layouts, so remove or rename those files when you want an
> installed theme to supply the complete page structure.

## Configure a theme

Select the installed directory name and override any declared parameters:

```yaml
theme: lattice
theme_params:
  skin: auto
  primary_color: "#2E7D4F"
  max_width: 1056px
  nav_links:
    - label: Docs
      url: /docs/
```

Unspecified values come from the theme's `theme.yaml`. Run
`trellis theme info lattice` to inspect its full parameter surface.

## The 18 standard params

Every standard-contract theme accepts these 18 standard parameters:

| Param | Controls |
|---|---|
| `skin` | `light`, `dark`, or `auto` color mode |
| `primary_color` | Primary accent |
| `accent_color` | Secondary accent |
| `text_color` | Body text |
| `muted_color` | Secondary text |
| `bg_color` | Page background |
| `surface_color` | Card and surface background |
| `border_color` | Borders and dividers |
| `font_family` | Body font stack |
| `heading_font_family` | Heading font stack |
| `code_font_family` | Monospace font stack |
| `max_width` | Main content width |
| `border_radius` | Shared corner radius |
| `nav_links` | Header navigation entries |
| `social_links` | Footer social entries |
| `footer_text` | Footer copy |
| `show_powered_by` | Trellis attribution |
| `show_rss_link` | Feed discovery link |

Individual themes can add their own parameters; those are documented in the
theme manifest and README.

## Four customization dimensions

Use these four customization dimensions from the smallest change to the
largest. They let a site stay on the theme's update path without maintaining a
fork.

### 1. Params

Use `theme_params` for colors, fonts, widths, navigation, feature flags, and
other values declared by the theme. This is the first choice for a supported
variation.

### 2. Layout override at the same path

Place a file in the site's `layouts/` at the same relative path as a theme
layout. For example, `layouts/_default/single.html` replaces only the theme's
single-page layout while all other theme files remain active.

### 3. `tl:extends` block override

Extend a theme layout and replace named blocks when the theme exposes them:

```html
<html tl:extends="theme:layouts/base.html">
  <main tl:define="content">Site-specific content</main>
</html>
```

This keeps the theme's outer shell and changes only the declared block.

### 4. SASS variable override

Put `_variables.scss` in the site's SASS directory to override variables the
theme marks with `!default`. Parameter values still arrive through the
generated SASS bridge; use variables for theme-specific styling that is not a
manifest parameter.

For designing and publishing a new theme, see
[Theme Authoring](/docs/themes/authoring/). Browse the shipped designs in the
[theme gallery](/docs/themes/gallery/).

## Update, inspect, and remove

```bash
trellis theme update
trellis theme update lattice
trellis theme list
trellis theme info lattice
trellis theme remove lattice
```

An installed single-theme git repository can update in place. A theme copied
from a multi-theme repository with `--theme` carries no git metadata; remove
and re-add it at the desired ref instead.

## Build

No theme-specific build flag is needed:

```bash
trellis build
```

The build merges defaults with `theme_params`, compiles the theme's SASS,
copies its static assets, and resolves site layouts before theme fallbacks.
Use `trellis build --verbose` to inspect those steps.
