# Lattice – Trellis documentation theme

Lattice is a reusable `docs` theme with an expressive, content-driven home page and Arbor-compatible documentation
navigation. It includes light, dark, and automatic skins; sidebar, TOC, search, prev/next links; build-time syntax
highlighting; and progressive enhancements that never gate access to content.

## Use

```yaml
theme: lattice
theme_params:
  skin: auto
  primary_color: "#2E7D4F"
  max_width: "1056px"
```

Lattice implements all 18 standard params, Arbor's docs params, and the following Lattice-specific surface.

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
| `hero_eyebrow`             | `Server-rendered Dart` | Hero eyebrow                  |
| `hero_headlines`           | Two entries            | Structured rotating headlines |
| `hero_lede`                | Theme introduction     | Hero supporting copy          |
| `hero_cta_primary_label`   | `Read the docs`        | Primary CTA label             |
| `hero_cta_primary_url`     | `/docs/`               | Primary CTA URL               |
| `hero_cta_secondary_label` | `View on GitHub`       | Secondary CTA label           |
| `hero_cta_secondary_url`   | Trellis repository     | Secondary CTA URL             |
| `terminal_card_lines`      | Three commands         | Hero terminal commands        |
| `show_terminal_card`       | `true`                 | Hero terminal visibility      |
| `show_code_showcase`       | `true`                 | Code section visibility       |
| `show_why_grid`            | `true`                 | Benefits section visibility   |
| `show_demo`                | `true`                 | Two-view demo visibility      |
| `show_themes_showcase`     | `true`                 | Theme cards visibility        |
| `show_cta`                 | `true`                 | Closing CTA visibility        |
| `cta_title`                | `One dependency away`  | Closing CTA heading           |
| `cta_body`                 | Theme introduction     | Closing CTA body              |
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

`data/lattice.yaml` owns `code_showcase`, `why`, `demo`, and `showcase`. A site's `data/lattice.yaml` replaces that
file as a whole, so provide every shape when overriding it. Optional `showcase.link_label` and `showcase.link_url`
values render a link after the cards when both are non-empty. Showcase `screenshot_light` and `screenshot_dark`
values are prefix-relative tails without a leading slash; the layout prepends the rendered asset base exactly once.

`hero_headlines` is a list of maps with exactly `prefix`, `emphasis`, and `suffix` strings. The server and JavaScript
escape all three values and create only the `<em>` wrapper. Multiline template source belongs in `data/lattice.yaml`,
not `theme_params`, because theme params also pass through the SASS bridge. An empty headline list falls back to the
configured site title; a single entry remains static.

## Assets and accessibility

All runtime assets are same-origin. Fonts use documented system fallbacks and `font-display: swap`; JavaScript only
adds theme choice, headline rotation, demo switching, copy buttons, and search. Without JavaScript the first headline,
both demo panes' default content, docs, and navigation remain readable. Reduced-motion mode disables rotation,
transitions, smooth scrolling, and card lift. See [VENDORED.md](VENDORED.md) for provenance.

## Preview

```bash
cd example
trellis build
trellis serve
```

The screenshots declared by the manifest are 1280×800 captures of this bridged example in auto mode with light and
dark selected manually.
