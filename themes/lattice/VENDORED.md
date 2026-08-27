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

Each file carries only the variable axes the theme actually renders. Fraunces keeps `opsz` as well as `wght`: the
headline sets `font-variation-settings: "opsz" 100`, and automatic optical sizing moves the axis at display sizes, so
instantiating it out widens the headline by roughly 19%. Instrument Sans and Spline Sans Mono keep `wght` only —
Fraunces' `SOFT`/`WONK` and Instrument Sans' `wdth` are unused and instantiated at their defaults. Dropping them cut
the set from 359,412 to 225,200 bytes (133,820 served for latin-only content) with byte-identical metrics at every
weight the theme uses.

SHA-256 (Latin / Latin-ext): Fraunces `48282a…a64e43` / `f12008…fa40e2`; Instrument Sans
`6219bc…ca2311` / `21fac8…cfe3e0`; Spline Sans Mono
`2b193a…77e9ec` / `bde42c…ebc8d6`.

## First-party JavaScript

`static/js/lattice.js` and `static/js/search.js` are dependency-free first-party scripts. They progressively enhance
the server-rendered page and do not own content needed for reading or navigation.

## First-party artwork

The SVG theme-card previews under `static/showcase/` and the reusable fallback `static/favicon.svg` are original
artwork shipped with Lattice. `static/trellis-logo.png` is the first-party compact Trellis wordmark, copied
byte-for-byte from the repository's canonical `assets/logo-small-with-text.png`; `static/trellis-mark.png` is copied
byte-for-byte from the canonical square `assets/logo-small.png`. The canonical gallery images are
`screenshots/light.png` and `screenshots/dark.png`, captured from the bridged example.
