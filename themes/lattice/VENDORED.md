# Vendored assets – Lattice

Last reviewed: 2026-08-27.

Every runtime asset is committed with the theme and served same-origin. No page performs a CDN or third-party request.

## Fonts

Every face is generated from a pinned `google/fonts` blob by `tool/subset_fonts.py`. Run
`python3 tool/subset_fonts.py --verify` to re-derive all eleven SDK font files and fail on any drift from the
committed bytes; `--write` regenerates them. Both hashes below are checked by that command.

Upstream commit: [`ade3d15`](https://github.com/google/fonts/tree/ade3d1533e06b2b1462ffcde8e08b129627ca360/ofl),
fetched 2026-08-27. Toolchain: fonttools 4.63.0, brotli 1.2.0.

| Shipped file                             | Bytes  | Upstream        | Output SHA-256 |
| ---------------------------------------- | ------ | --------------- | -------------- |
| `fonts/fraunces-latin.woff2`             | 69,620 | Fraunces        | `6522c36d54be` |
| `fonts/fraunces-latin-ext.woff2`         | 58,724 | Fraunces        | `1284a99a8e71` |
| `fonts/fraunces-italic-latin.woff2`      | 43,256 | Fraunces Italic | `3b741b314ef4` |
| `fonts/instrument-sans-latin.woff2`      | 29,696 | Instrument Sans | `4a59ce2e8216` |
| `fonts/instrument-sans-latin-ext.woff2`  | 10,732 | Instrument Sans | `85949406008d` |
| `fonts/spline-sans-mono-latin.woff2`     | 36,012 | Spline Sans Mono| `3f72e1f08739` |
| `fonts/spline-sans-mono-latin-ext.woff2` | 19,984 | Spline Sans Mono| `7f80c96ef3a2` |

Upstream blobs, all under `ofl/` at that commit:

- Fraunces 1.000 – `fraunces/Fraunces[SOFT,WONK,opsz,wght].ttf`, SHA-256 `177ff6c0f14e`
- Fraunces Italic 1.000 – `fraunces/Fraunces-Italic[SOFT,WONK,opsz,wght].ttf`, SHA-256 `b24448c43702`
- Instrument Sans 1.000 – `instrumentsans/InstrumentSans[wdth,wght].ttf`, SHA-256 `b24f18125848`
- Spline Sans Mono 1.004 – `splinesansmono/SplineSansMono[wght].ttf`, SHA-256 `e20c1df32aa2`

268,024 bytes in the repository; 135,328 fetched by a page whose content is latin-only, since each family splits on
`unicode-range` and the italic loads only where italic Fraunces is actually rendered. Fallbacks are Georgia/serif for
Fraunces, the system sans for Instrument Sans and `ui-monospace, monospace` for Spline Sans Mono; every face uses
`font-display: swap`.

### How each file is cut

The upright faces keep only the axes the theme renders. Fraunces keeps `opsz` alongside `wght` because the headline
sets `font-variation-settings: "opsz" 100` and CSS `font-optical-sizing` defaults to `auto`, so the browser drives the
axis from font-size; instantiating it out pins the axis at its low default and widens display text by roughly 19%.
Fraunces' `SOFT`/`WONK` and Instrument Sans' `wdth` are unused and pinned at their defaults.

The exact commands, per family (`<LATIN>` and `<LATIN_EXT>` are the two constants in `tool/subset_fonts.py`):

```
fonttools varLib.instancer -o inst.ttf --no-recalc-timestamp <upstream>.ttf SOFT=0 WONK=1
fonttools subset inst.ttf --output-file=fraunces-latin.woff2 --flavor=woff2 --unicodes=<LATIN> \
    --no-hinting --name-IDs=* --layout-features+=pnum,tnum --no-recalc-timestamp
```

`--no-recalc-timestamp` is load-bearing on both steps: without it each run stamps a new `head.modified` and the output
hash changes. `--name-IDs=*` keeps the embedded OFL notice (name IDs 13/14) and the `fvar` instance names.

### Italic

The approved A3 mockup loads `Fraunces:ital,opsz,wght@1,9..144,500`, and `main.scss` sets `font-style: italic` on the
hero's emphasised word. With no italic face the browser shears the upright, which is most visible at the hero's
38–64px. One instance is vendored — `wght` pinned to 500, `opsz` kept because the headline drives it, `SOFT`/`WONK`
instanced out:

```
fonttools varLib.instancer -o inst.ttf --no-recalc-timestamp \
    Fraunces-Italic[SOFT,WONK,opsz,wght].ttf SOFT=0 WONK=1 wght=500
```

Latin only. Emphasis inside latin-ext text still falls back to the sheared upright; a latin-ext italic measures
36,652 bytes and was judged not worth it.

Because the face carries weight 500 alone, an `<em>` inside an h2 or h3 — which Fraunces renders at 600 — gets a
synthetic bold. The hero, the one case the mockup specifies, is exactly 500 and is unaffected. Removing the h2/h3 case
means vendoring the full-`wght` variable italic at 84,140 bytes instead of 43,256, a 15% payload increase for a
construction the design does not use. Left as is deliberately.

### unicode-range

Each upright family ships a latin and a latin-ext file, so both need a `unicode-range` to stop latin-only pages
downloading the extended one. **Every declared range is the exact cmap of the file it gates**, and
`lattice_theme_contract_test.dart` asserts that equality against the shipped bytes.

Equality is the only correct state, because both inequalities are defects. A range narrower than its file makes the
browser refuse the webfont for the codepoints it omits, so a word breaks across two typefaces mid-line. A range wider
than its file matches the face, pays for the download, finds no glyph and reaches the system fallback anyway — the
same visual defect, now behind a font request that looked like coverage.

That is why the ranges are written from the built cmaps rather than from the `<LATIN>`/`<LATIN_EXT>` constants the
subsetter is given. Those constants are one request shared by all eight SDK families, and a family whose designer drew
none of a codepoint gets none of it:

- `U+2190-2193` is requested for every latin face and drawn only by Instrument Sans. Fraunces and Spline Sans Mono
  carry no arrows at all upstream, so only `instrument-sans-latin.woff2` declares them. A `→` in a `var(--mono)`
  context therefore matches no Lattice face and falls straight to the stack's next font.
- `U+0309` and `U+0329` are requested and drawn by none of the three families, so they appear in no range here.
- Of the combining marks, `U+0300-0304` and `U+0308` are in all three latin faces; `U+0323` is only in
  `fraunces-italic-latin.woff2` and `spline-sans-mono-latin.woff2`.

Where latin and latin-ext overlap (`U+0304`, `U+0308`) the `latin` face wins, being declared second, and carries both.
Folio and Meadow declare no `unicode-range` because they ship one file per family: with nothing to gate, a range there
could only ever exclude.

## Licensing

Fraunces, Instrument Sans and Spline Sans Mono are all SIL Open Font License 1.1, and the licence text sits beside
each font as `static/fonts/OFL-*.txt`. None of the three declares a Reserved Font Name in its copyright notice, so
OFL §3 places no naming restriction on these modified, subsetted copies. Re-verified against the upstream `OFL.txt`
files on 2026-08-27.

## First-party JavaScript

`static/js/lattice.js` and `static/js/search.js` are dependency-free first-party scripts. They progressively enhance
the server-rendered page and do not own content needed for reading or navigation.

## First-party artwork

The SVG theme-card previews under `static/showcase/` and the reusable fallback `static/favicon.svg` are original
artwork shipped with Lattice. `static/trellis-logo.png` is the first-party compact Trellis wordmark, copied
byte-for-byte from the repository's canonical `assets/logo-small-with-text.png`; `static/trellis-mark.png` is copied
byte-for-byte from the canonical square `assets/logo-small.png`. The canonical gallery images are
`screenshots/light.png` and `screenshots/dark.png`, captured from the bridged example.
