---
title: Themes
description: Install, configure, customize, update, and remove Trellis themes.
weight: 40
---

Themes package reusable layouts, styles, assets, and configuration defaults.
You don't need to fork a theme or edit its source to change colors, fonts,
navigation, or layout: all customization happens through `theme_params:` in
`trellis_site.yaml`.

A theme is executable site code, not a passive style preset. Its layouts are
rendered during the build, its SASS is compiled, and its JavaScript runs in
visitors' browsers. Inspect third-party themes before installing them, and pin a
reviewed tag or branch with `--ref` in production.

## Install a theme

Run these commands from the site root, where `trellis_site.yaml` lives.

### A built-in theme

The six themes that ship with Trellis (`arbor`, `bloom`, `folio`, `lattice`,
`meadow`, `verdant`) live under `themes/<name>/` in the
[tolo/trellis](https://github.com/tolo/trellis) repository. `--theme <name>`
installs one of them out of that repository:

```bash
trellis theme add https://github.com/tolo/trellis --theme lattice --ref v0.14.0
```

This copies `themes/lattice/` into your site's `themes/lattice/` and sets
`theme: lattice` in `trellis_site.yaml`. Browse the
[theme gallery](/docs/themes/gallery/) to pick one.

### A single-theme repository

When a theme is the whole repository, omit `--theme`. The theme name is derived
from the repository name, without a `.git` suffix or a `trellis-theme-` prefix:

```bash
trellis theme add https://github.com/yourname/trellis-theme-orchard
```

This clones the repository into `themes/orchard/` and sets `theme: orchard`.

### Pin a version

Use `--ref` to pin a git tag or branch (not a commit SHA). It is recommended for
production sites. `--ref` becomes `git clone --branch`, so the value must be a
ref that already exists on the remote: pick one from the
[releases](https://github.com/tolo/trellis/releases). An unpushed tag fails with
`Remote branch <tag> not found`. The command also records the ref as
`theme_ref:` in `trellis_site.yaml`, which `trellis theme update` reads.

### A local path

During local theme development, install from a directory:

```bash
trellis theme add ./path/to/my-theme

# Or one theme out of a local multi-theme checkout
trellis theme add ../trellis --theme lattice
```

This is useful when authoring a theme alongside a site, or testing before
publishing to git. The directory is copied without its `.git/` directory or any
symlinks.

## Site layouts win over theme layouts

Layouts resolve **site-first**: for `layouts/base.html`, the generator uses your
site's `layouts/base.html` if it exists and falls back to the theme's only
otherwise. That is what makes
[layout overrides](#2-layout-override-at-the-same-path) work, but it also means a
site that already has a full set of layouts shadows the whole theme.

That is the case when you add a theme to a project scaffolded with
`trellis create --template blog`. The scaffold writes `layouts/base.html`,
`layouts/home.html`, `layouts/_default/single.html`,
`layouts/_default/list.html`, and `layouts/posts/single.html`, which covers
everything a theme provides. The build succeeds and copies the theme's CSS into
the output, but no page links it, so the site renders unstyled.

`trellis theme add` lists the shadowing files when it installs. `trellis build`
flags a theme whose stylesheets ended up in the output with no page linking
them: the warning appears with `--verbose` and is counted in the build summary.
To fix it, either:

- delete or rename the site layouts you want the theme to render, or
- keep them and pull the theme in explicitly with the `theme:` prefix, for
  example `<html tl:extends="theme:layouts/base.html">` (see
  [`tl:extends` block override](#3-tlextends-block-override)).

`trellis theme add` reports *any* shadowed layout, since at install time there is
no build to check. `trellis build` is narrower: it only reports a theme no
emitted page links. An override that keeps the theme's stylesheet link, such as a
`base.html` copied from the theme or a layout rendering inside the theme's shell,
builds silently. Replacing `base.html` with a shell of your own is reported,
because nothing links the theme after that.

## Configure a theme

Set `theme:` to the installed directory name under `themes/` and override any
declared parameters:

```yaml
theme: lattice
theme_params:
  skin: auto
  primary_color: "#2E7D4F"
  primary_color_dark: "#6FCF97"
  max_width: 1056px
  nav_links:
    - label: Docs
      url: /docs/
  social_links:
    - platform: GitHub
      url: https://github.com/yourname
  footer_text: "© 2026 My Site"
  show_powered_by: true
```

Any param not listed in `theme_params:` uses the theme's default from
`theme.yaml`, so you only specify what you want to change. Run
`trellis theme info lattice` to inspect the full parameter surface.

## The 25 standard params

Every standard-contract theme accepts the same 25 params, so you can switch
themes and keep your `theme_params:`. The
[standard params reference](/docs/themes/standard-params/) lists each one with
its type, default, and what it controls.

Colors are per mode. A plain color param such as `primary_color` sets the
theme's light palette only, under every skin; its `_dark` twin sets the dark
palette. `skin: light` emits the light palette, `skin: dark` the dark one, and
`skin: auto` the light one plus a block that applies the dark one when the
visitor's OS prefers dark. With `skin: dark`, `primary_color` therefore changes
nothing – set `primary_color_dark`. Trellis never derives a dark color from a
light one, because a color chosen for a white background has no verified
contrast on a dark one.

Individual themes can add their own parameters, for example Verdant's
`show_reading_time`, `hero_title`, and `date_format`. Those are documented in
the theme manifest and README.

## Four customization dimensions

Use these four customization dimensions from the smallest change to the
largest. They let a site stay on the theme's update path without maintaining a
fork.

### 1. Params

Use `theme_params` for colors, fonts, widths, navigation, feature flags, and
other values declared by the theme. This is the first choice for a supported
variation and covers the vast majority of customization:

```yaml
theme_params:
  skin: dark
  primary_color_dark: "#fb7185"   # skin: dark uses the dark palette
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

### 2. Layout override at the same path

To replace a theme layout, create a file at the same relative path in the site's
`layouts/` directory. The generator checks site layouts before the theme's, so
`layouts/_default/single.html` replaces only the theme's single-page layout while
all other theme files remain active:

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

The `theme:` prefix in `theme:layouts/base.html` loads the theme's base layout
even though you are in the site's layouts directory.

### 3. `tl:extends` block override

To override one section of the theme, such as the footer, without replacing the
entire layout, extend the theme layout and replace the named block:

```html
<!-- my-site/layouts/base.html -->
<!-- Inherits all of the theme's base.html, but replaces the footer block -->
<html tl:extends="theme:layouts/base.html" lang="en">
<body>
  <footer tl:define="site-footer">
    <div class="container">
      <p>Custom footer – <a href="/colophon/">Colophon</a></p>
    </div>
  </footer>
</body>
</html>
```

This keeps the theme's outer shell and changes only the declared block. The
standard `tl:define` blocks themes provide (Verdant's `base.html` as the
example) are:

| Block name | Location in `base.html` |
|---|---|
| `head-extra` | Inside `<head>`: inject extra `<meta>`, `<script>`, and so on |
| `site-header` | The `<header>` element |
| `content` | The `<main>` element |
| `site-footer` | The `<footer>` element |

### 4. Site stylesheets

Add your own SASS in the site's `sass/` directory or as `static/*.scss`. They are
compiled with the site's `sass/` and the theme's `sass/` on the load path, and
they can read the theme's merged parameters through the generated `theme_params`
module:

```scss
// my-site/static/site.scss – compiled to output/site.css
@use 'theme_params' as tp;

.callout {
  border-left: 4px solid tp.$trellis-primary-color;   // the merged value, e.g. from theme_params:
  border-radius: tp.$trellis-border-radius;
}
```

These files cannot reconfigure the theme. A `sass/_variables.scss` in your site
does not change the theme's variables: Sass resolves the theme's own
`@forward 'variables'` relative to the theme file before it consults any load
path, and a configured module cannot be reconfigured afterwards. `theme_params`
is the one way to change a theme's values.

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

`trellis theme update` without a name updates the active theme from
`trellis_site.yaml`. It runs inside the installed theme's git checkout: `git pull`,
or, when the site pins a `theme_ref:`, `git fetch origin` followed by
`git checkout <ref>`. So it only works for a theme installed from a
single-theme git repository. A theme installed with `--theme <name>` or from a
local path carries no git metadata; remove and re-add it instead. To change the
pinned version, remove and re-add with a new `--ref`:

```bash
trellis theme remove lattice
trellis theme add https://github.com/tolo/trellis --theme lattice --ref v0.14.0
```

`trellis theme list` shows each installed theme with its version and marks the
active one with `*`. `trellis theme info <name>` prints the manifest: name,
version, author, description, the minimum `trellis_site` version, features, and
every param with its type, default, and, for the active theme, the value your
site sets.

`trellis theme remove` deletes the theme directory and, when it was the active
theme, clears `theme:` and `theme_ref:` from `trellis_site.yaml`. It leaves
`theme_params:` in place and prints a warning; remove that block by hand if you
no longer need it.

## Upgrading from 0.11

Themes installed with 0.11 use `@import` in their SASS. From 0.12 the build
compiles theme SASS with `@use` and treats `@import` as an error, so a theme left
at its 0.11 version fails with a message naming the theme and the file:

```
Build failed: theme "lattice" uses @import at themes/lattice/sass/main.scss:12:9.
```

There are two ways out:

- **Re-add the theme at 0.12 or later.** Remove it and install it again at the
  current release tag (the `--ref` value from [Pin a version](#pin-a-version)).
  The six built-in themes are migrated from `v0.12.0` on.

  ```bash
  trellis theme remove lattice
  trellis theme add https://github.com/tolo/trellis --theme lattice --ref v0.14.0
  ```

  `theme remove` clears `theme:` from `trellis_site.yaml` and leaves
  `theme_params:` in place, and `theme add` sets `theme:` again, so your params
  apply to the new copy. If you edited files inside `themes/<name>/`, copy those
  edits over by hand first.
- **Migrate the theme yourself.** For a third-party or locally modified theme,
  convert its SASS to the `@use` contract described in
  [Theme Authoring](/docs/themes/authoring/).

A site's own stylesheets under `static/` may keep `@import`.

## Build

No theme-specific build flag is needed:

```bash
trellis build
```

The theme pipeline runs automatically:

1. Read `theme:` from `trellis_site.yaml`.
2. Merge `theme_params:` with the theme's defaults.
3. Generate `.trellis/build/_theme_params.scss` and `css/theme-props.css`.
4. Compile every non-partial stylesheet in the theme's `sass/` directory (usually
   `main.scss`) to `css/` through a generated `@use … with (…)` wrapper that
   configures the theme's `!default` variables with the merged params.
5. Copy the theme's `static/` assets; the site's `static/` wins on conflict.
6. Resolve layouts: site layouts first, then the theme's as fallback.

Use `trellis build --verbose` to see the theme resolution steps.
