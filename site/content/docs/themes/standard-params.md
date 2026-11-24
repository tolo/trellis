---
title: Standard Params
description: The 25-param contract every official Trellis theme supports – types, reference defaults, SASS variables, CSS custom properties, and how each param reaches templates and SASS.
weight: 15
---

All official Trellis themes **must** support the 25 core standard params defined
on this page. The contract lets site builders switch themes and carry their
`theme_params:` configuration without modification.

> **Per-mode colors.** Each of the seven color params has a `<name>_dark` twin
> that sets the same entry in the dark palette. See
> [Skin and colors](#skin-and-colors-15-params).

> **Syntax highlighting is not a theme param.** `trellis_site` highlights code
> at build time, configured site-side with the `highlight:` key in
> `trellis_site.yaml`
> ([ADR-010](https://github.com/tolo/trellis/blob/main/dev/adrs/ADR-010-syntax-highlighting.md)).
> A theme only styles the emitted `.hljs-*` spans. A `syntax_highlighting` key
> in `theme_params:` has no effect; `trellis build --verbose` reports it as an
> unknown theme param.

For how to implement these params in a theme, see
[Theme Authoring](/docs/themes/authoring/). For how to configure them in a site,
see [Themes](/docs/sites/themes/).

## Overview

Standard params are defined in `theme.yaml` under `params:`. The Trellis CLI and
the `trellis_site` build pipeline parse them, merge them with the site's
`theme_params:`, and expose them in three ways:

1. **Templates** – `${theme.<param_name>}` (for example
   `${theme.primary_color}`).
2. **SASS variables** – `$trellis-<param-name>`, declared `!default` in the
   theme's `_variables.scss` (for example `$trellis-primary-color`). The build
   configures each one with the merged value as `@use "main.scss" with (…)`. A
   param whose variable the theme does not declare `!default` is inert in SASS.
3. **CSS custom properties** – `--trellis-<param-name>` on `:root` (for example
   `--trellis-primary-color`), in the generated `css/theme-props.css`.

Boolean, enum, and list params have no CSS custom property (see
[Type reference](#type-reference)).

## Complete params table

All 25 standard params, with their SASS variable names and CSS custom property
names:

| Param name | Type | Default | SASS variable | CSS custom property | Description |
|---|---|---|---|---|---|
| **Skin & Colors** | | | | | |
| `skin` | enum | `auto` | `$trellis-skin` | – | Color scheme: `light`, `dark`, or `auto` (follows OS `prefers-color-scheme`) |
| `primary_color` | color | `#2563eb` | `$trellis-primary-color` | `--trellis-primary-color` | Brand/accent color – links, buttons, active states |
| `accent_color` | color | `#3b82f6` | `$trellis-accent-color` | `--trellis-accent-color` | Secondary accent – hover states, highlights |
| `text_color` | color | `#1f2937` | `$trellis-text-color` | `--trellis-text-color` | Main body text |
| `muted_color` | color | `#6b7280` | `$trellis-muted-color` | `--trellis-muted-color` | Secondary text – dates, metadata, captions |
| `bg_color` | color | `#ffffff` | `$trellis-bg-color` | `--trellis-bg-color` | Page background |
| `surface_color` | color | `#f3f4f6` | `$trellis-surface-color` | `--trellis-surface-color` | Elevated surfaces – code blocks, cards |
| `border_color` | color | `#e5e7eb` | `$trellis-border-color` | `--trellis-border-color` | Borders, dividers |
| `primary_color_dark` | color | `#3b82f6` | `$trellis-primary-color-dark` | `--trellis-primary-color-dark` | `primary_color` in the dark palette |
| `accent_color_dark` | color | `#60a5fa` | `$trellis-accent-color-dark` | `--trellis-accent-color-dark` | `accent_color` in the dark palette |
| `text_color_dark` | color | `#f3f4f6` | `$trellis-text-color-dark` | `--trellis-text-color-dark` | `text_color` in the dark palette |
| `muted_color_dark` | color | `#9ca3af` | `$trellis-muted-color-dark` | `--trellis-muted-color-dark` | `muted_color` in the dark palette |
| `bg_color_dark` | color | `#111827` | `$trellis-bg-color-dark` | `--trellis-bg-color-dark` | `bg_color` in the dark palette |
| `surface_color_dark` | color | `#1f2937` | `$trellis-surface-color-dark` | `--trellis-surface-color-dark` | `surface_color` in the dark palette |
| `border_color_dark` | color | `#374151` | `$trellis-border-color-dark` | `--trellis-border-color-dark` | `border_color` in the dark palette |
| **Typography** | | | | | |
| `font_family` | string | `"system-ui, -apple-system, sans-serif"` | `$trellis-font-family` | `--trellis-font-family` | Body text font stack |
| `heading_font_family` | string | `null` | `$trellis-heading-font-family` | `--trellis-heading-font-family` | Heading font stack (null = keep the theme's heading font; the scaffold's is null, so the body font) |
| `code_font_family` | string | `"ui-monospace, SFMono-Regular, monospace"` | `$trellis-code-font-family` | `--trellis-code-font-family` | Code/pre font stack |
| **Layout** | | | | | |
| `max_width` | string | `"800px"` | `$trellis-max-width` | `--trellis-max-width` | Maximum content width |
| `border_radius` | string | `"6px"` | `$trellis-border-radius` | `--trellis-border-radius` | Global border radius |
| **Navigation** | | | | | |
| `nav_links` | list | `[{Home, /}, {Blog, /posts/}]` | – | – | Header navigation links – list of `{label, url}` maps |
| `social_links` | list | `[]` | – | – | Footer social links – list of `{platform, url, label?}` maps |
| **Footer** | | | | | |
| `footer_text` | string | `null` | `$trellis-footer-text` | `--trellis-footer-text` | Custom footer text (null = theme default) |
| `show_powered_by` | boolean | `true` | `$trellis-show-powered-by` | – | Show "Powered by Trellis" attribution |
| **Features** | | | | | |
| `show_rss_link` | boolean | `true` | `$trellis-show-rss-link` | – | Display RSS/Atom feed `<link>` in `<head>` |

> Defaults verified against `themes/verdant/theme.yaml` and
> `themes/verdant/sass/_skins/_dark.scss` (the `_dark` defaults).

> **The SASS variable column is a naming convention.** A theme declares only the
> variables it uses, and a param without a declaration is inert in SASS. Verdant,
> for example, declares none for `footer_text`, `show_powered_by`, or
> `show_rss_link`, and its templates read them as `${theme.<name>}`.

> **`--trellis-<name>-dark` has no reader.** The generated `css/theme-props.css`
> lists every non-boolean, non-enum, non-list param, so it gains the seven `-dark`
> entries. Nothing in a theme reads them: the dark views take their colors from
> the dark palette inside the theme's own CSS, and a `<name>_dark` param reaches
> them through it.

> **Defaults are per-theme.** The **Default** column shows the *reference*
> defaults (the values the `verdant` theme ships). The contract fixes each
> param's **name, type, and semantics**, not its default value. A theme may ship
> its own default for any param, and most do: `arbor` uses
> `primary_color: "#0f7a4d"` and a serif `heading_font_family`
> (`"Charter, Cambria, Georgia, ui-serif, serif"`), while `bloom` ships a purple
> palette. `heading_font_family: null` never blanks a theme's own heading font:
> Sass treats a `null` passed through `with()` as unset, so the theme's non-null
> default wins. To use the body font for headings on such a theme, set
> `heading_font_family` to the `font_family` stack.

## Categories

### Skin and colors (15 params)

`skin` plus seven color params and their seven `_dark` twins control every
visual surface in the theme. A skin is a complete palette (a map of color
entries in the theme's `sass/_skins/`), and a color param sets one entry in it:

- `primary_color` sets the **light** palette's `primary-color` entry.
  `primary_color_dark` sets the **dark** palette's.
- The `skin` param selects which palette the theme emits: `light` the light one,
  `dark` the dark one, `auto` the light one plus a
  `@media (prefers-color-scheme: dark)` block carrying the dark one.

**Precedence rule.** A plain color param sets the light entry only, under every
skin. It never reaches a dark view, so with `skin: dark` (or in the dark block of
`skin: auto`) it changes nothing. The `_dark` twin is how a site recolors dark
mode.

**Dark is never derived.** A theme does not compute its dark colors from the
light ones (no inversion, no lightness shift). Both palettes are authored, and
both are overridden independently.

```yaml
theme_params:
  skin: dark
  primary_color_dark: "#a78bfa"   # The dark palette's primary
```

With `skin: auto`, set both to recolor both modes:

```yaml
theme_params:
  skin: auto
  primary_color: "#7c3aed"        # Light mode
  primary_color_dark: "#a78bfa"   # Dark mode
```

The `skin` enum values:

- `light` – light background, dark text (default palette)
- `dark` – dark background, light text
- `auto` – follows the OS `prefers-color-scheme` media query at runtime

### Typography (3 params)

Font stacks are CSS font-family values. A theme whose `heading_font_family`
default is `null` (Verdant, Bloom, and the `trellis create --template theme`
scaffold) gives headings the body font. The theme derives a combined variable:

```scss
$trellis-heading-font: $trellis-font-family;
@if $trellis-heading-font-family {
  $trellis-heading-font: $trellis-heading-font-family;
}
```

To use a custom heading font, load it via a `<link>` in `head-extra` and set:

```yaml
theme_params:
  heading_font_family: "'Playfair Display', Georgia, serif"
```

### Layout (2 params)

`max_width` and `border_radius` accept any valid CSS length. The container
centers at `max_width`; `border_radius` applies globally to cards, buttons, and
form elements.

### Navigation (2 params)

`nav_links` and `social_links` are lists of maps. In templates, iterate with
`tl:each`:

```html
<li tl:each="link : ${theme.nav_links}">
  <a tl:href="${link.url}" tl:text="${link.label}">Link</a>
</li>
```

```html
<li tl:each="link : ${theme.social_links}">
  <a tl:href="${link.url}"
     tl:text="${link.label} ?: ${link.platform}">GitHub</a>
</li>
```

Templates that group `nav_links` by section can read `${site.headerNavigation}`. It is available when the theme
provides `nav_links` and keeps the configured order. Each item has `label`, `url` and `children`. A link to a
section with children gets a list of `{label, url}` entries starting with the section's landing page. Descendants
assigned to another configured link appear under that link. Direct links have an empty `children` list. Compare
`url` to `page.url` for `aria-current`; both carry the serving prefix.

List params have no CSS custom property representation.

### Footer (2 params)

`footer_text` is a free-form string displayed in the footer. `null` means the
theme provides its own default text (or nothing). `show_powered_by` controls a
"Powered by Trellis" attribution line.

### Features (1 param)

`show_rss_link` controls whether a `<link rel="alternate">` element is emitted in
`<head>` (it requires `feeds:` to be configured in `trellis_site.yaml`).

## Type reference

The `type` in `theme.yaml` is a hint. The build does not validate a value against
it or against an enum's `values:`, with one exception: `skin` must be `light`,
`dark`, or `auto`, and any other value fails the build with `Unknown skin`.

### `color`

A CSS color string, normally hex. Stored as a SASS color variable and emitted as
a CSS custom property.

```yaml
primary_color: "#2563eb"
```

- In SASS: `$trellis-primary-color: #2563eb !default;` (the build configures it:
  `@use "main.scss" with ($trellis-primary-color: tp.$trellis-primary-color)`).
- In CSS: `--trellis-primary-color: #2563eb;`.
- In templates: `${theme.primary_color}` (returns the string).

### `string`

A free-form string. Font stacks, dimensions, and display text all use this type.
Emitted as a SASS variable and a CSS custom property (a `null` is emitted as
`initial`).

```yaml
font_family: "system-ui, -apple-system, sans-serif"
max_width: "800px"
heading_font_family: null    # emitted as initial in CSS output
```

The SASS value is emitted **unquoted**: the generator interpolates it (`#{"…"}`)
rather than writing a bare quoted literal, so a theme can use the variable
directly (`font-family: $trellis-font-family`, `max-width: $trellis-max-width`)
and get valid CSS. A quoted `"800px"` configured onto the theme's `!default`
variable would compile to the invalid `max-width: "800px"`, which browsers drop.
Embedded `"` and `\` are escaped, and a SASS interpolation marker `#{…}` in a
value is emitted as literal text, never evaluated.

Avoid the structural characters `;`, `{`, and `}` in a value. They are **not**
neutralized, so a string value carrying them compiles but silently corrupts the
emitted CSS rather than failing loudly (only a raw `color`-typed value with the
same characters aborts the compile). Tracked as TD-011 in the
[tech debt backlog](https://github.com/tolo/trellis/blob/main/dev/state/TECH-DEBT-BACKLOG.md).

- In SASS: the generated `_theme_params.scss` holds
  `$trellis-font-family: #{"system-ui, -apple-system, sans-serif"};` (compiles to
  the unquoted `system-ui, -apple-system, sans-serif`), and the theme declares
  `$trellis-font-family: system-ui, -apple-system, sans-serif !default;`.
- In CSS: `--trellis-font-family: system-ui, -apple-system, sans-serif;`.
- In templates: `${theme.font_family}` (returns the raw string).

### `boolean`

`true` or `false`. Emitted as a SASS variable only, not as a CSS custom
property. Use it in templates for feature toggles:

```html
<span tl:if="${theme.show_reading_time}">3 min read</span>
```

In SASS: `$trellis-show-reading-time: true !default;`.

### `int`

An integer. Emitted as a SASS variable and a CSS custom property. Typically used
for counts and lengths in theme logic (not in CSS directly).

```yaml
excerpt_length: 160
```

- In SASS: `$trellis-excerpt-length: 160 !default;`.
- In CSS: `--trellis-excerpt-length: 160;`.

### `enum`

A string restricted to a declared set of values. Emitted as a SASS variable only.
Declaring `values:` documents the set but the build does not enforce it, except
for `skin` (see above).

```yaml
skin:
  type: enum
  values: [light, dark, auto]
  default: auto
```

In SASS: `$trellis-skin: auto !default;`.

### `list`

A YAML list, usually of maps. Not emitted as a CSS custom property. The generated
`_theme_params.scss` carries it as a Sass list of maps, which site stylesheets
can read (`tp.$trellis-nav-links`), but a theme's own SASS sees it only if it
declares the variable `!default`. Themes normally read lists in templates with
`tl:each`.

```yaml
nav_links:
  type: list
  default:
    - label: Home
      url: /
    - label: Blog
      url: /posts/
```

## Naming conventions

Param names are `snake_case` in YAML. The build pipeline converts them to
`kebab-case` for SASS and CSS:

| Context | Convention | Example |
|---|---|---|
| `theme.yaml` params | `snake_case` | `primary_color` |
| `trellis_site.yaml` `theme_params` | `snake_case` | `primary_color: "#e11d48"` |
| SASS variable | `$trellis-<kebab>` | `$trellis-primary-color` |
| CSS custom property | `--trellis-<kebab>` | `--trellis-primary-color` |
| Template expression | `${theme.<snake>}` | `${theme.primary_color}` |

### Full mapping example

```
YAML key:           primary_color
YAML value:         "#2563eb"
SASS variable:      $trellis-primary-color: #2563eb !default;
CSS custom prop:    --trellis-primary-color: #2563eb;
Template:           ${theme.primary_color}
```

## Adding theme-specific params

Themes may extend beyond the 25 standard params. Convention:

1. Place the standard params first in `theme.yaml`, clearly marked.
2. Place theme-specific params in a separate block after the standard ones.
3. Prefix very theme-specific param names with the theme name (for example
   `verdant_card_style`), or use descriptive names that clearly are not standard
   (for example `hero_title`, `show_reading_time`).

```yaml
params:
  # === Standard Params (25) ===
  skin:
    type: enum
    values: [light, dark, auto]
    default: auto
    description: Color scheme

  # ... (other 24 standard params)

  # === Blog-Specific Params ===
  show_reading_time:
    type: boolean
    default: true
    description: Show estimated reading time on posts

  hero_title:
    type: string
    default: null
    description: Homepage hero title override (null = site title)

  date_format:
    type: string
    default: "MMM d, yyyy"
    description: Date display format string
```

Theme-specific params follow the same naming conventions, SASS variable
generation, and CSS custom property rules as standard params. They are
documented in the theme's own README or authoring notes.
