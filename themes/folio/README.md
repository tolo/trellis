# Folio – Trellis field-guide theme

Folio is a self-contained documentation and reference theme with chart-paper texture, green ink, restrained red
rubrication, light/night editions, and semantic apparatus. It remains readable without JavaScript; search and the
optional edition switch are progressive enhancements.

## Use and preview

Set `theme: folio` in `trellis_site.yaml`, or build the complete fixture:

```sh
cd themes/folio/example
trellis build
```

The example symlink `themes/folio -> ../..` makes the theme resolvable from a fresh checkout.

## Parameters

Folio supports all standard parameters: `skin`, `primary_color`, `accent_color`, `text_color`, `muted_color`,
`bg_color`, `surface_color`, `border_color`, `font_family`, `heading_font_family`, `code_font_family`, `max_width`,
`border_radius`, `nav_links`, `social_links`, `footer_text`, `show_powered_by`, and `show_rss_link`. Red rubrication is
controlled only by `accent_color`. `logo` takes an image path, with or without a leading slash, and replaces the
built-in sprout mark in the header; leave it unset to keep the mark. The path is joined with `pathPrefix` exactly once.

Docs parameters are `show_sidebar`, `show_toc`, `show_prev_next`, `show_search`, `toc_title`, and `sidebar_title`.
`excerpt_length` controls generated summaries. Apparatus uses `plate_label`, `show_plate_numbers`, and `show_sidenotes`.

## Layouts

- `layouts/base.html` – prefix-safe shell, header, footer, sidebar, TOC, search, and edition control.
- `layouts/home.html` – content-driven reference landing page.
- `layouts/_default/single.html` – documentation article with breadcrumbs, TOC, and neighbors.
- `layouts/_default/list.html` – section listing.

### Landing page front matter

The home layout reads two optional keys from the landing page itself. Both regions disappear when the key is absent:

```yaml
hero:
  caption: Sea lavender, recorded after the spring tide.
  image: {src: specimens/sea-lavender.webp, alt: Pressed sea lavender}
  ctas:
    - {label: Open the manual, href: /docs/, style: primary}
    - {label: Browse specimens, href: /docs/apparatus/, style: secondary}
```

`caption` labels the herbarium sheet. `image` mounts your own specimen on the sheet — `src` is joined with `pathPrefix`
exactly once, with or without a leading slash, and omitting the key keeps the drawn engraving. Each `ctas` entry needs
`label` and `href`; `style: secondary` renders the outlined variant, anything else renders the filled one. Root-relative
`href` values are joined with `pathPrefix`.

## Semantic apparatus

Article content needs no front matter and no private schema. Put ordinary semantic HTML directly in page content:

```html
<figure class="folio-plate">
  <img src="specimen.webp" alt="Pressed sea lavender">
  <figcaption>Collected after the spring tide.</figcaption>
</figure>
<aside class="folio-sidenote">A short interpretive note.</aside>
<div class="folio-note"><strong>Field caution</strong> Rubricated callout for a warning or aside.</div>
```

Figures remain present when numbering is disabled; captions are optional. Disabling sidenotes hides their decoration and
content without generating empty layout regions. Each direct child of a `folio-plate` gets the mounted inner frame; wrap
a child in `<div class="plate-frame">` when it should carry the frame on behalf of what it holds, as a fenced code block
does. A leading `<strong>` inside `folio-note` becomes the rubricated label.

## Assets and accessibility

Fonts and JavaScript are committed under `static/` and served same-origin. Code highlighting is generated at build time.
Both skins provide visible focus, semantic landmarks, responsive stacking, and reduced-motion handling. See
[`VENDORED.md`](VENDORED.md) for provenance.
