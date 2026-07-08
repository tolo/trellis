# Standard Theme Params Contract

All official Trellis themes **must** support the 19 core standard params defined in this document. This contract ensures site builders can switch themes and carry their `theme_params:` configuration without modification.

Related docs:
- [Theme Authoring Guide](../guides/theme-authoring.md) — how to implement these params in a theme
- [Theme Usage Guide](../guides/theme-usage.md) — how to configure these params in a site


## Overview

Standard params are defined in `theme.yaml` under `params:`. The Trellis CLI and `trellis_site` build pipeline parse them, merge them with the site's `theme_params:`, and expose them in three ways:

1. **Templates** — `${theme.<param_name>}` (e.g. `${theme.primary_color}`)
2. **SASS variables** — `$trellis-<param-name>` with `!default` (e.g. `$trellis-primary-color`)
3. **CSS custom properties** — `--trellis-<param-name>` on `:root` (e.g. `--trellis-primary-color`)

Boolean, enum, and list params are template-only or SASS-only (see Type Reference below).


## Complete Params Table

All 19 standard params, with their SASS variable names and CSS custom property names:

| Param name | Type | Default | SASS variable | CSS custom property | Description |
|---|---|---|---|---|---|
| **Skin & Colors** | | | | | |
| `skin` | enum | `auto` | `$trellis-skin` | — | Color scheme: `light`, `dark`, or `auto` (follows OS `prefers-color-scheme`) |
| `primary_color` | color | `#2563eb` | `$trellis-primary-color` | `--trellis-primary-color` | Brand/accent color — links, buttons, active states |
| `accent_color` | color | `#3b82f6` | `$trellis-accent-color` | `--trellis-accent-color` | Secondary accent — hover states, highlights |
| `text_color` | color | `#1f2937` | `$trellis-text-color` | `--trellis-text-color` | Main body text |
| `muted_color` | color | `#6b7280` | `$trellis-muted-color` | `--trellis-muted-color` | Secondary text — dates, metadata, captions |
| `bg_color` | color | `#ffffff` | `$trellis-bg-color` | `--trellis-bg-color` | Page background |
| `surface_color` | color | `#f3f4f6` | `$trellis-surface-color` | `--trellis-surface-color` | Elevated surfaces — code blocks, cards |
| `border_color` | color | `#e5e7eb` | `$trellis-border-color` | `--trellis-border-color` | Borders, dividers |
| **Typography** | | | | | |
| `font_family` | string | `"system-ui, -apple-system, sans-serif"` | `$trellis-font-family` | `--trellis-font-family` | Body text font stack |
| `heading_font_family` | string | `null` | `$trellis-heading-font-family` | `--trellis-heading-font-family` | Heading font stack (null = inherit body font) |
| `code_font_family` | string | `"ui-monospace, SFMono-Regular, monospace"` | `$trellis-code-font-family` | `--trellis-code-font-family` | Code/pre font stack |
| **Layout** | | | | | |
| `max_width` | string | `"800px"` | `$trellis-max-width` | `--trellis-max-width` | Maximum content width |
| `border_radius` | string | `"6px"` | `$trellis-border-radius` | `--trellis-border-radius` | Global border radius |
| **Navigation** | | | | | |
| `nav_links` | list | `[{Home, /}, {Blog, /posts/}]` | — | — | Header navigation links — list of `{label, url}` maps |
| `social_links` | list | `[]` | — | — | Footer social links — list of `{platform, url, label?}` maps |
| **Footer** | | | | | |
| `footer_text` | string | `null` | `$trellis-footer-text` | `--trellis-footer-text` | Custom footer text (null = theme default) |
| `show_powered_by` | boolean | `true` | `$trellis-show-powered-by` | — | Show "Powered by Trellis" attribution |
| **Features** | | | | | |
| `show_rss_link` | boolean | `true` | `$trellis-show-rss-link` | — | Display RSS/Atom feed `<link>` in `<head>` |
| `syntax_highlighting` | boolean | `true` | `$trellis-syntax-highlighting` | — | Enable syntax highlighting container styles |

> Verified against `themes/verdant/theme.yaml` and `themes/verdant/sass/_variables.scss`.

> **Defaults are per-theme.** The **Default** column shows the *reference* defaults
> (the values the `verdant` theme ships). The contract fixes each param's **name,
> type, and semantics** — not its default value. A theme may ship its own default
> for any param, and most do: e.g. `arbor` uses `primary_color: "#0f7a4d"` and a
> serif `heading_font_family` (`"Charter, Cambria, Georgia, ui-serif, serif"`),
> while `bloom` ships a purple palette. `heading_font_family: null` still means
> "inherit the body font" wherever a theme (or a site) sets it back to null.


## Categories

### Skin & Colors (8 params)

The eight color params control every visual surface in the theme. The `skin` param selects a built-in color preset; individual color params override specific values within that preset.

```yaml
theme_params:
  skin: dark
  primary_color: "#a78bfa"   # Override just the primary on top of dark skin
```

The `skin` enum values:
- `light` — light background, dark text (default palette)
- `dark` — dark background, light text
- `auto` — follows OS `prefers-color-scheme` media query at runtime

### Typography (3 params)

Font stacks are CSS font-family values. `heading_font_family: null` means headings inherit the body font — the theme derives a combined variable:

```scss
$trellis-heading-font: if($trellis-heading-font-family, $trellis-heading-font-family, $trellis-font-family);
```

To use a custom heading font, load it via a `<link>` in `head-extra` and set:

```yaml
theme_params:
  heading_font_family: "'Playfair Display', Georgia, serif"
```

### Layout (2 params)

`max_width` and `border_radius` accept any valid CSS length. The container centers at `max_width`; `border_radius` applies globally to cards, buttons, and form elements.

### Navigation (2 params)

`nav_links` and `social_links` are lists of maps. In templates, iterate with `tl:each`:

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

List params have no SASS or CSS custom property representation.

### Footer (2 params)

`footer_text` is a free-form string displayed in the footer. `null` means the theme provides its own default text (or nothing). `show_powered_by` controls a "Powered by Trellis" attribution line.

### Features (2 params)

Boolean feature toggles. `show_rss_link` controls whether a `<link rel="alternate">` element is emitted in `<head>` (requires `feeds:` to be configured in `trellis_site.yaml`). `syntax_highlighting` enables the theme's code block container styling.


## Type Reference

### `color`

A CSS hex color string. Stored as a SASS color variable and emitted as a CSS custom property.

```yaml
primary_color: "#2563eb"
```

In SASS: `$trellis-primary-color: #2563eb !default;`
In CSS: `--trellis-primary-color: #2563eb;`
In templates: `${theme.primary_color}` (returns the hex string)

### `string`

A free-form string — font stacks, dimensions, and display text all use this type. Emitted as a SASS variable and a CSS custom property (unless `null`).

```yaml
font_family: "system-ui, -apple-system, sans-serif"
max_width: "800px"
heading_font_family: null    # null omitted from CSS output
```

The SASS variable is emitted **unquoted**: the generator interpolates the value (`#{"…"}`) rather than writing a bare quoted literal, so a theme can use the variable directly (`font-family: $trellis-font-family`, `max-width: $trellis-max-width`) and get valid CSS. (A quoted `"800px"` would win the bridge's `!default` and compile to the invalid `max-width: "800px"`, which browsers drop.) Embedded `"` and `\` are escaped, and a SASS interpolation marker `#{…}` in a value is emitted as literal text — never evaluated. Avoid the structural characters `;`, `{`, `}` in a value; they are not neutralized and fail the SASS compile (tracked as TD-011).

In SASS: `$trellis-font-family: #{"system-ui, -apple-system, sans-serif"} !default;` (compiles to the unquoted `system-ui, -apple-system, sans-serif`)
In CSS: `--trellis-font-family: system-ui, -apple-system, sans-serif;`
In templates: `${theme.font_family}` (returns the raw string)

### `boolean`

`true` or `false`. Emitted as a SASS variable only — not as a CSS custom property. Use in templates for feature toggles:

```html
<span tl:if="${theme.show_reading_time}">3 min read</span>
```

In SASS: `$trellis-show-reading-time: true !default;`

### `int`

An integer value. Emitted as a SASS variable only. Typically used for counts and lengths in theme logic (not in CSS directly).

```yaml
excerpt_length: 160
```

In SASS: `$trellis-excerpt-length: 160 !default;`

### `enum`

A string restricted to a declared set of values. Validated at build time — an invalid value produces a build error. Emitted as a SASS variable only.

```yaml
skin:
  type: enum
  values: [light, dark, auto]
  default: auto
```

In SASS: `$trellis-skin: auto !default;`

### `list`

A YAML list of maps. Not emitted as SASS or CSS — accessed only in templates via `tl:each`.

```yaml
nav_links:
  type: list
  default:
    - label: Home
      url: /
    - label: Blog
      url: /posts/
```


## Naming Conventions

Param names follow `snake_case` in YAML. The build pipeline converts to `kebab-case` for SASS and CSS:

| Context | Convention | Example |
|---|---|---|
| `theme.yaml` params | `snake_case` | `primary_color` |
| `trellis_site.yaml` theme_params | `snake_case` | `primary_color: "#e11d48"` |
| SASS variable | `$trellis-<kebab>` | `$trellis-primary-color` |
| CSS custom property | `--trellis-<kebab>` | `--trellis-primary-color` |
| Template expression | `${theme.<snake>}` | `${theme.primary_color}` |

### Full Mapping Example

```
YAML key:           primary_color
YAML value:         "#2563eb"
SASS variable:      $trellis-primary-color: #2563eb !default;
CSS custom prop:    --trellis-primary-color: #2563eb;
Template:           ${theme.primary_color}
```


## Adding Theme-Specific Params

Themes may extend beyond the 19 standard params. Convention:

1. Place standard params first in `theme.yaml`, clearly marked
2. Place theme-specific params in a separate block after the standard ones
3. Prefix theme-specific param names with the theme name if they're very theme-specific (e.g. `verdant_card_style`) — or use descriptive names that clearly aren't standard (e.g. `hero_title`, `show_reading_time`)

```yaml
params:
  # === Standard Params (19) ===
  skin:
    type: enum
    values: [light, dark, auto]
    default: auto
    description: Color scheme

  # ... (other 18 standard params)

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

Theme-specific params follow the same naming conventions, SASS variable generation, and CSS custom property rules as standard params. They are documented in the theme's own README or authoring notes.
