# Lattice – Trellis documentation theme

Lattice is a reusable `docs` theme with an expressive, content-driven home page and Arbor-compatible documentation
navigation. It includes light, dark, and automatic skins; sidebar, TOC, search, prev/next links; build-time syntax
highlighting; and progressive enhancements that never gate access to content.

## Use

Install it from the Trellis repository:

```sh
trellis theme add https://github.com/tolo/trellis --theme lattice --ref v0.11.0
```

That copies `themes/lattice/` into your site's `themes/` and sets `theme: lattice` in `trellis_site.yaml`. `theme:`
names a directory under `themes/`, so setting it without installing the theme first fails with
`Theme 'lattice' not found in themes/`. Then customize:

```yaml
theme: lattice
theme_params:
  skin: auto
  primary_color: "#2E7D4F"
  max_width: "1056px"
```

Lattice implements all 18 standard params, two branding params, Arbor's docs params, and the following
Lattice-specific surface.

### Standard params

| Param                 | Default                | Purpose                                     |
| --------------------- | ---------------------- | ------------------------------------------- |
| `skin`                | `auto`                 | `light`, `dark`, or OS-aware automatic skin |
| `primary_color`       | `#2E7D4F`              | Light-skin primary accent                   |
| `accent_color`        | `#6E9B45`              | Light-skin secondary accent                 |
| `text_color`          | `#1C2B21`              | Light-skin body text                        |
| `muted_color`         | `#47584C`              | Light-skin secondary text                   |
| `bg_color`            | `#FBFAF5`              | Light-skin page background                  |
| `surface_color`       | `#FFFFFF`              | Light-skin card background                  |
| `border_color`        | `#E7E3D4`              | Light-skin borders and lattice              |
| `font_family`         | Instrument Sans stack  | Body font stack                             |
| `heading_font_family` | Fraunces stack         | Heading font stack                          |
| `code_font_family`    | Spline Sans Mono stack | Code font stack                             |
| `max_width`           | `1056px`               | Maximum content width                       |
| `border_radius`       | `8px`                  | Global corner radius                        |
| `logo`                | unset                  | Optional prefix-relative header logo        |
| `favicon`             | `favicon.svg`          | Prefix-relative browser icon                |
| `nav_links`           | Home and Docs          | Header links                                |
| `social_links`        | `[]`                   | Footer social links                         |
| `footer_text`         | unset                  | Optional footer copy                        |
| `show_powered_by`     | `true`                 | Trellis attribution                         |
| `show_rss_link`       | `true`                 | Feed discovery link                         |

### Docs params

| Param            | Default         | Purpose                 |
| ---------------- | --------------- | ----------------------- |
| `show_sidebar`   | `true`          | Docs sidebar            |
| `show_toc`       | `true`          | Page table of contents  |
| `show_prev_next` | `true`          | Previous and next links |
| `show_search`    | `true`          | Client-side docs search |
| `toc_title`      | `On this page`  | TOC heading             |
| `sidebar_title`  | `Documentation` | Sidebar heading         |

### Lattice params

| Param                      | Default                | Purpose                       |
| -------------------------- | ---------------------- | ----------------------------- |
| `excerpt_length`           | `160`                  | Generated summary length      |
| `hero_eyebrow`             | `Your tagline here`    | Hero eyebrow                  |
| `hero_headlines`           | Two entries            | Structured rotating headlines |
| `hero_lede`                | Placeholder sentence   | Hero supporting copy          |
| `hero_cta_primary_label`   | `Read the docs`        | Primary CTA label             |
| `hero_cta_primary_url`     | `/docs/`               | Primary CTA URL               |
| `hero_cta_secondary_label` | `Get started`          | Secondary CTA label           |
| `hero_cta_secondary_url`   | `/docs/getting-started/` | Secondary CTA URL           |
| `terminal_card_lines`      | Five entries           | Structured terminal narrative |
| `show_terminal_card`       | `true`                 | Hero terminal visibility      |
| `show_code_showcase`       | `true`                 | Code section visibility       |
| `show_why_grid`            | `true`                 | Benefits section visibility   |
| `show_demo`                | `true`                 | Two-view demo visibility      |
| `show_site_demo`           | `false`                | Markdown-to-page demo         |
| `show_themes_showcase`     | `true`                 | Theme cards visibility        |
| `show_cta`                 | `true`                 | Closing CTA visibility        |
| `cta_title`                | `Ready when you are`   | Closing CTA heading           |
| `cta_body`                 | Placeholder sentence   | Closing CTA body              |
| `cta_commands`             | Two commands           | Closing CTA commands          |

Light-skin color tokens map as follows:

| Param           | Token                                      |
| --------------- | ------------------------------------------ |
| `primary_color` | `--leaf`                                   |
| `accent_color`  | `--tendril`                                |
| `bg_color`      | `--paper`                                  |
| `surface_color` | `--card`                                   |
| `text_color`    | `--ink`                                    |
| `muted_color`   | `--ink-soft`                               |
| `border_color`  | `--lattice` and derived `--lattice-strong` |

The dark palette is deliberately theme-owned. Font stacks, `max_width`, and `border_radius` affect every skin.

## Structured home data

`data/lattice.yaml` owns `code_showcase`, `why`, `demo`, `site_demo`, and `showcase`. A site's `data/lattice.yaml` replaces that
file as a whole, so provide every shape when overriding it. Each home section renders only when its `show_*` param
is on **and** every key that section renders is present — not merely its enclosing block. A block that omits one of
them is dropped whole, so a partial override never publishes an empty heading, a blank code pane, or an empty grid,
and never fails the build. The required keys are `code_showcase.title` / `.template_html` / `.output_html`,
`why.title` / `.cells`, `demo.title` / `.template_html` / `.prototype_title` / `.rendered_posts`, and
`site_demo.title` / `.markdown_html` / `.page_title`, and `showcase.title` / `.cards`. Optional `site_demo.body`,
`site_demo.source_label`, `site_demo.arrow_label`, and `site_demo.page_body` values complete the Markdown-to-page
story. Optional `showcase.link_label` and `showcase.link_url` values render a link after
the cards when both are non-empty. Showcase `screenshot_light` and `screenshot_dark` values are prefix-relative tails
without a leading slash; the layout prepends the rendered asset base exactly once.

The theme's own defaults are content-neutral placeholders — Lattice ships a shape, not a pitch. Replace them with
your own copy; nothing in them names a product or bakes in a release version.

### Pre-marked code panes

`code_showcase.template_html`, `code_showcase.output_html`, `demo.template_html`, and `site_demo.markdown_html` are
**HTML**, rendered with
`tl:utext`. No client-side highlighter ships in an official theme (ADR-010), so the panes carry their token spans
from the data file and stay coloured with JavaScript off. Escape `<`, `>`, and `&`, and wrap tokens in the classes
the theme styles:

| Class     | Covers                                     |
| --------- | ------------------------------------------ |
| `t-tag`   | Element names                              |
| `t-attr`  | Plain attribute names                      |
| `t-tl`    | `tl:*` attribute names (highlighted chip)  |
| `t-str`   | Attribute value strings                    |
| `t-expr`  | `${...}` expressions inside a string       |
| `t-dim`   | Angle brackets and slashes                 |

Markdown code fences elsewhere on a site are highlighted at build time by the SSG and styled through the
`.hljs-*` map instead; both maps clear WCAG AA against the code surface in each skin.

`hero_headlines` is a list of maps with exactly `prefix`, `emphasis`, and `suffix` strings. The server and JavaScript
escape all three values and create only the `<em>` wrapper. The heading crossfades inside a fixed-height slot, fits
long entries down without changing surrounding geometry, and remains on the server-rendered first entry when reduced
motion is requested. Multiline template source belongs in `data/lattice.yaml`, not `theme_params`, because theme
params also pass through the SASS bridge. An empty headline list falls back to the configured site title; a single
entry remains static. `terminal_card_lines` entries have `prefix`, `text`, and `kind` (`command` or `output`) fields.

`logo` and `favicon` are asset tails resolved through the configured path prefix. They let a site supply one coherent
identity without hardcoding Trellis branding into reusable Lattice markup. The bundled compact Trellis wordmark and
square mark are available as `trellis-logo.png` and `trellis-mark.png`; the Trellis documentation site opts into them
explicitly.

## Assets and accessibility

All runtime assets are same-origin. Fonts use documented system fallbacks and `font-display: swap`; JavaScript only
adds theme choice, headline fitting and rotation, demo switching, copy buttons, and search. Controls that JavaScript
cannot back are server-rendered `hidden` and revealed once the capability exists: the skin toggle, the copy buttons
(which need a secure context for the Clipboard API), and the whole search shell, which appears only after the search
index has loaded. Results are announced through an `aria-live="polite"` list that scrolls in place rather than pushing
the section tree off the sidebar. Without JavaScript the first headline renders at its full designed size, code panes
stay coloured, and both demo panes' default content, docs, and navigation remain readable. Reduced-motion is tracked
live — turning it on stops the headline rotation without a reload — and also disables transitions, smooth scrolling,
and card lift. See [VENDORED.md](VENDORED.md) for provenance.

## Preview

```bash
cd example
trellis build
trellis serve
```

The screenshots declared by the manifest are 1280×800 captures of this bridged example in auto mode with light and
dark selected manually.
