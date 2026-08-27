# Bloom — Trellis Landing/Marketing Theme

A bold landing/marketing page theme for the [Trellis](https://pub.dev/packages/trellis)
SDK. Bloom renders everything a product or app homepage needs — a gradient hero,
a feature grid, a showcase slot, alternating story sections, pricing cards, an
FAQ accordion, and a call-to-action band — all driven from the home page's front
matter, with semantic landmarks, a skip-to-content link, WCAG 2.1 AA color
contrast, `prefers-reduced-motion` support, and a mobile-first responsive layout.

Bloom is a sibling of the `arbor` docs theme and the `verdant` blog theme and
shares their conventions (manifest shape, the SASS param bridge,
`tl:extends`/`tl:define` layout inheritance, the 18 standard params). It differs
in intent: instead of a content tree, the landing page is a **data-driven
composition** — each section renders only when its front-matter block is present,
so a site builder assembles the whole page from `content/_index.md` with zero
hand-authored output HTML.

## Features

- **Data-driven landing page** — hero, features, showcase, story sections,
  pricing, FAQ, and CTA band all read from `${page.<field>}`; each section is
  guarded with `tl:if` and rendered only when its data exists.
- **Gradient hero** — centered or split (with image), a multi-line gradient
  title, eyebrow/badge pill, subtitle, lede, and primary/ghost CTA buttons.
- **Responsive feature grid** — 3-col desktop / 2-col tablet / 1-col mobile;
  each icon is an emoji, a single character, or raw inline SVG.
- **Overridable showcase slot** — a default placeholder grid a site shadows with
  its own `layouts/partials/showcase.html` (see below).
- **Alternating story rows** — two-column text/visual sections that reverse and
  stack on mobile; full-width prose when no image is supplied.
- **Pricing cards** — highlighted tier gets an accent border and a badge; a
  checklist of features and a per-tier CTA.
- **FAQ accordion** — native `<details>`/`<summary>`, no JavaScript.
- **CTA band** — full-width accent-gradient band with an optional embed slot
  (e.g. a newsletter form).
- **Light + dark skins** (and `auto`, following the OS preference), both passing
  WCAG 2.1 AA body-text contrast.
- **Accessible + responsive** — semantic `<header>`/`<nav>`/`<main>`/`<footer>`
  landmarks, `aria-labelledby` on every section, a skip-to-content link,
  focus-visible outlines, and reduced-motion support. No horizontal scroll at
  375px. No CDN, no JavaScript required.

## Using the theme

Install it from the Trellis repository:

```bash
trellis theme add https://github.com/tolo/trellis --theme bloom
```

That copies `themes/bloom/` into your site's `themes/` and sets `theme: bloom`
in `trellis_site.yaml`. `theme:` names a directory under `themes/`, so setting
it without installing the theme first fails with
`Theme 'bloom' not found in themes/`. Then customize:

```yaml
theme: bloom

theme_params:
  skin: auto            # light | dark | auto
  hero_align: split     # center | split (split needs a hero image)
  accent_gradient_start: "#6d28d9"
  accent_gradient_end: "#db2777"
  pill_badges: true
  nav_links:
    - { label: Features, url: "#features" }
    - { label: Pricing,  url: "#pricing" }
    - { label: FAQ,      url: "#faq" }
```

Then author the landing page in `content/_index.md` with `layout: home` and the
section blocks in front matter. See [`example/content/_index.md`](example/content/_index.md)
for a complete reference that exercises every section.

## Home front-matter shape

```yaml
layout: home
hero:      { eyebrow, title, subtitle, lede, image, image_alt,
             ctas: [{ label, href, style: primary|ghost }] }
features:  [{ icon, title, body }]
showcase:  { title, subtitle }
sections:  [{ eyebrow, title, body, image, image_alt, reverse }]
pricing:   { title, subtitle, note,
             tiers: [{ name, price, period, description, highlight, badge,
                       features: [...], cta: { label, href } }] }
faq:       { title, items: [{ q, a }] }
cta_band:  { title, body, html, cta: { label, href } }
```

The page's Markdown body (below the front matter) renders as centered prose
directly after the hero.

## Overriding the showcase slot

The showcase section inserts a fragment from
[`layouts/partials/showcase.html`](layouts/partials/showcase.html), which ships a
neutral placeholder grid. A site **shadows** it by dropping its own
`layouts/partials/showcase.html` — the Trellis SSG resolves site templates before
theme templates (`CompositeLoader([site, theme])`), so the site copy wins with no
theme fork:

```
your-site/
  layouts/
    partials/
      showcase.html   # your product screenshots — replaces the theme default
```

The override's fragment must be named `showcase` and expose the tiles directly
(the theme's copy uses a `<tl:block tl:fragment="showcase">` so the tiles drop
straight into the `.showcase-grid` host). To pull the theme default back in
explicitly, insert it with the `theme:` prefix:
`~{theme:layouts/partials/showcase.html :: showcase}`.

## Other layouts

- **`_default/single.html`** — prose pages (privacy, support, press): narrow
  measure, page title, rendered Markdown, and a "← Back" link.
- **`_default/list.html`** — a simple listing of child pages (title + summary).

## Preview

```bash
cd example
trellis build && trellis serve
```

## Theme-specific params

| Param | Type | Default | Description |
|---|---|---|---|
| `hero_align` | enum | `center` | `center` or `split` (split needs a hero image) |
| `accent_gradient_start` | color | `#6d28d9` | Gradient start — hero title + primary buttons |
| `accent_gradient_end` | color | `#db2777` | Gradient end — hero title + primary buttons |
| `pill_badges` | boolean | `true` | Render eyebrow/badge labels as rounded pills |
| `logo` | string | `null` | Optional header logo image path (null = text title) |

Plus all 18 [standard params](../../docs/reference/standard-params.md).
