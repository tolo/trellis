# Theme Usage Guide

Trellis themes provide complete site designs that are fully configurable through YAML. You don't need to fork a theme or edit its source to change colors, fonts, navigation, or layout — all customization happens via `theme_params:` in `trellis_site.yaml`.

Related docs:
- [Theme Authoring Guide](theme-authoring.md) — how to create and publish themes
- [Standard Params Contract](../reference/standard-params.md) — all 19 configurable standard params


## Installing a Theme

### From a Git URL

```bash
trellis theme add https://github.com/tolo/trellis-theme-verdant
```

This clones the theme into `themes/verdant/` and sets `theme: verdant` in `trellis_site.yaml`.

### Pinning to a Version

```bash
trellis theme add https://github.com/tolo/trellis-theme-verdant --ref v1.0.0
```

Use `--ref` to pin to a git tag, branch, or commit SHA. Recommended for production sites.

### From a Local Path (development)

```bash
trellis theme add ./path/to/my-theme
```

Useful when authoring a theme alongside a site, or testing before publishing to git.


## Configuring a Theme

After installing, set `theme:` in `trellis_site.yaml`:

```yaml
# trellis_site.yaml
title: My Blog
description: Notes about Dart and the web.
base_url: https://example.com
taxonomies:
  - tags
paginate: 10

# Theme — use the name from theme.yaml
theme: verdant

# Theme params — all are optional (defaults from theme.yaml apply)
theme_params:
  skin: auto
  primary_color: "#7c3aed"
  nav_links:
    - label: Home
      url: /
    - label: Posts
      url: /posts/
    - label: About
      url: /about/
  social_links:
    - platform: GitHub
      url: https://github.com/yourname
  footer_text: "© 2024 My Blog"
  show_powered_by: true
  show_reading_time: true
```

Any param not listed in `theme_params:` uses the theme's default from `theme.yaml`. You only need to specify what you want to change.


## The 19 Standard Params

Every official Trellis theme supports the same 19 standard params, grouped into six categories:

| Category | Params |
|---|---|
| Skin & Colors | `skin`, `primary_color`, `accent_color`, `text_color`, `muted_color`, `bg_color`, `surface_color`, `border_color` |
| Typography | `font_family`, `heading_font_family`, `code_font_family` |
| Layout | `max_width`, `border_radius` |
| Navigation | `nav_links`, `social_links` |
| Footer | `footer_text`, `show_powered_by` |
| Features | `show_rss_link`, `syntax_highlighting` |

See the [Standard Params Contract](../reference/standard-params.md) for types, defaults, and descriptions of all 19 params.

Themes may also define additional params beyond the 19 standard ones (e.g. Verdant adds `show_reading_time`, `hero_title`, `date_format`, etc.).


## Customization Without Forking

There are four dimensions of customization, from simplest to most powerful:

1. **Params** — change values via YAML
2. **Layout override** — replace a layout file entirely
3. **Block override** — override one `tl:define` slot via `tl:extends`
4. **SASS variable override** — change compiled-in values

Use the simplest approach that achieves your goal.

### Dimension 1: Params

The most common case — just set values in `trellis_site.yaml`:

```yaml
theme_params:
  skin: dark
  primary_color: "#e11d48"
  font_family: "Georgia, serif"
  max_width: "720px"
  hero_title: "My Personal Blog"
  show_reading_time: false
  nav_links:
    - label: Writing
      url: /posts/
    - label: Projects
      url: /projects/
    - label: About
      url: /about/
```

This covers the vast majority of customization needs.

### Dimension 2: Layout Override at Same Path

To fully replace a theme layout, create a file at the same relative path in your site's `layouts/` directory. The SSG checks your site layouts before the theme:

```
my-site/
  layouts/
    _default/
      single.html    # Replaces theme's _default/single.html entirely
```

Your layout can start from scratch or re-extend the theme's base:

```html
<!-- my-site/layouts/_default/single.html -->
<html tl:extends="theme:layouts/base.html" lang="en">
<head><title>Post</title></head>
<body>
  <main tl:define="content">
    <div class="container">
      <!-- Your custom post layout here -->
      <article>
        <h1 tl:text="${page.title}">Title</h1>
        <div tl:utext="${page.content}">Content</div>
      </article>
    </div>
  </main>
</body>
</html>
```

Using `theme:layouts/base.html` (with the `theme:` prefix) ensures you get the theme's base layout even though you're in the site's layout directory.

### Dimension 3: tl:extends Block Override

To override just one section of the theme (e.g. the footer) without replacing the entire layout:

```html
<!-- my-site/layouts/base.html -->
<!-- Inherits all of the theme's base.html, but replaces the footer block -->
<html tl:extends="theme:layouts/base.html" lang="en">
<body>
  <footer tl:define="site-footer">
    <div class="container">
      <p>Custom footer — <a href="/colophon/">Colophon</a></p>
    </div>
  </footer>
</body>
</html>
```

Standard `tl:define` blocks provided by themes (Verdant example):

| Block name | Location in base.html |
|---|---|
| `head-extra` | Inside `<head>` — inject extra `<meta>`, `<script>`, etc. |
| `site-header` | The `<header>` element |
| `content` | The `<main>` element |
| `site-footer` | The `<footer>` element |

### Dimension 4: SASS Variable Override

For fine-grained control over compiled styles, add a SASS file to your site's `sass/` directory. The site SASS directory is in the SASS load path before the theme:

```scss
/* my-site/sass/_variables.scss — overrides theme variables */
$trellis-primary-color: #7c3aed;   /* Purple instead of blue */
$trellis-border-radius: 2px;       /* Sharp corners */
$trellis-max-width: 700px;
```

Because site SASS takes precedence over theme SASS, these values override the theme's `!default` declarations. Note: this only affects compiled SASS values, not the CSS custom properties (which come from params). For full control, use both `theme_params:` and SASS overrides together.


## Updating a Theme

```bash
# Update all themes to latest
trellis theme update

# Update a specific theme
trellis theme update verdant
```

If you need to change the pinned version, remove and re-add with a new `--ref`:

```bash
trellis theme remove verdant
trellis theme add https://github.com/tolo/trellis-theme-verdant --ref v2.0.0
```


## Listing and Inspecting Themes

```bash
# List all installed themes
trellis theme list

# Show details for a specific theme
trellis theme info verdant
```

`trellis theme info` outputs the theme manifest: name, version, author, description, params, and features.


## Removing a Theme

```bash
trellis theme remove verdant
```

This deletes the theme directory from `themes/` and clears the `theme:` entry from `trellis_site.yaml`. If `theme_params:` is still present, a warning is printed — remove it manually if no longer needed.


## Building with a Theme

No special flags are needed — the theme pipeline runs automatically:

```bash
trellis build
```

The build process:
1. Reads `theme:` from `trellis_site.yaml`
2. Merges `theme_params:` with theme defaults
3. Generates `.trellis/build/_theme_params.scss` and `css/theme-props.css`
4. Compiles `<theme>/sass/main.scss` with the merged params
5. Copies theme `static/` assets (site `static/` wins on conflict)
6. Resolves layouts: site layouts checked first, then theme layouts as fallback

```bash
# Build with verbose output to see theme resolution steps
trellis build --verbose
```
