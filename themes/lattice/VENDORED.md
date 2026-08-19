# Vendored assets – Lattice

Last reviewed: 2026-08-19.

Every runtime asset is committed with the theme and served same-origin. No page performs a CDN or third-party request.

## Fonts

| Asset                                        | Source and license                                                                                 | Fallback                |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------- |
| `static/fonts/fraunces-latin*.woff2`         | [Fraunces v38](https://fonts.gstatic.com/s/fraunces/v38/), SIL Open Font License 1.1               | Georgia, serif          |
| `static/fonts/instrument-sans-latin*.woff2`  | [Instrument Sans v4](https://fonts.gstatic.com/s/instrumentsans/v4/), SIL Open Font License 1.1    | system sans-serif       |
| `static/fonts/spline-sans-mono-latin*.woff2` | [Spline Sans Mono v13](https://fonts.gstatic.com/s/splinesansmono/v13/), SIL Open Font License 1.1 | ui-monospace, monospace |

The corresponding OFL text is stored beside each font. Files contain the latin/latin-ext coverage used by the theme
and are loaded with `font-display: swap`.

SHA-256 (Latin / Latin-ext): Fraunces `94bb7e…14251` / `bfbcc5…85ad8`; Instrument Sans
`19f8ec…13f5e4` / `7bb992…b98016`; Spline Sans Mono `2b193a…7e9ec` / `bde42c…bc8d6`.

## First-party JavaScript

`static/js/lattice.js` and `static/js/search.js` are dependency-free first-party scripts. They progressively enhance
the server-rendered page and do not own content needed for reading or navigation.

## First-party artwork

The SVG theme-card previews under `static/showcase/` and the reusable fallback `static/favicon.svg` are original
artwork shipped with Lattice. `static/trellis-logo.png` is the first-party Trellis wordmark, copied byte-for-byte from
the repository's canonical `assets/logo-with-text.png`; `static/trellis-mark.png` is a square favicon crop of that same
source. The canonical gallery images are `screenshots/light.png` and `screenshots/dark.png`, captured from the bridged
example.
