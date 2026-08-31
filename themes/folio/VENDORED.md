# Vendored assets – Folio

Last reviewed: 2026-08-27.

All runtime assets are committed and served same-origin. No CDN, npm, or client-side syntax highlighter is used.

## First-party scripts

- `static/js/folio.js` – persistent auto-skin edition switch; authored for Folio.
- `static/js/search.js` – progressive search over the generated same-origin index; inherited from Arbor's first-party
  code.

## Fonts

`static/fonts/eb-garamond-latin.woff2` is the theme's entire font payload: 45,524 bytes, SHA-256 `4280300314ed`.

It is generated from a pinned `google/fonts` blob by `tool/subset_fonts.py`. Run
`python3 tool/subset_fonts.py --verify` to re-derive it and fail on any drift from the committed bytes; `--write`
regenerates it. Both hashes here are checked by that command.

Upstream: EB Garamond 1.003, `ofl/ebgaramond/EBGaramond[wght].ttf` at
[`ade3d15`](https://github.com/google/fonts/tree/ade3d1533e06b2b1462ffcde8e08b129627ca360/ofl/ebgaramond), SHA-256
`ef9512f92f6d`, fetched 2026-08-27. Toolchain: fonttools 4.63.0, brotli 1.2.0. The exact command (`<LATIN>` is the
constant in `tool/subset_fonts.py`):

```
fonttools subset EBGaramond[wght].ttf --output-file=eb-garamond-latin.woff2 --flavor=woff2 --unicodes=<LATIN> \
    --no-hinting --name-IDs=* --layout-features+=pnum,tnum --no-recalc-timestamp
```

No instancer step: `wght` is the family's only axis and the theme renders it, so nothing is pinned.
`--no-recalc-timestamp` is load-bearing — without it each run stamps a new `head.modified` and the output hash
changes. `--name-IDs=*` keeps the embedded OFL notice (name IDs 13/14) and the `fvar` instance names.

The subset carries `←` and `→`, which `layouts/_default/list.html` renders in its pager. Google's `latin` subset
definition omits both, so before they were requested explicitly they rendered in the visitor's system sans mid-line,
against a serif page.

No `unicode-range` is declared. Folio ships one file for the one family, so there is nothing to gate: a range could
only ever exclude codepoints the file carries and push them into a system fallback. (Lattice, which splits latin and
latin-ext, does declare ranges — see its `VENDORED.md`.)

### Why one variable file

One variable file replaces per-weight statics: headings need 500 and 600, and two static faces would cost more
(23,848 + 25,308) than the variable one while still missing intermediate weights. `size-adjust: 118%` corrects EB
Garamond's x-height (40.5 per 100px) to the Palatino/Iowan metrics the design was drawn against (47.1–47.9); without
it body copy renders at roughly 15px optical instead of 18px.

The `@font-face` declares `font-weight: 400 800`, the whole range the file carries — `subset_fonts.py` pins no axis
limit for this family, so upstream's full `wght` survives the subset. It declared `400 600` until 0.11: `.site-title`
and `.button` both set `font: 700 … var(--folio-serif)`/`var(--folio-body)`, and both were clamped into the declared
range and drew a real 600. The clamp was invisible to inspection — under `font-synthesis: none` the 700 and 800
renderings were byte-identical to 600, so nothing was faux-bolded and nothing reported it. Measured at 64px on the
same file, advance widths go 419.14 / 441.64 / 452.67 / 460.05 for 400 / 600 / 700 / 800 once the range is declared in
full, against 441.64 flat for everything above 600 before. The approved mockup sets `.brand { font-weight: 700 }` in
system faces that carry a real 700, so 700 is what the design asked for. Widening costs no bytes.

No italic is vendored, so the caption and empty-state rules that set `font-style: italic` on body copy render a
synthesised oblique. EB Garamond Italic exists upstream, but the same latin subset of it measures 49,232 bytes — more
than the upright — taking the theme to 94,756 and past the 50KB budget its contract test holds, for a handful of
captions. Left as is deliberately. (Code comments are italic too, but those are the system mono stack, which has a
real italic.)

No monospace font is vendored. Code and label type use the system stack
(`SFMono-Regular, Consolas, Liberation Mono, monospace`) – the same stack the approved design uses, which also gives
labels a real 700 weight instead of a synthesised one. A system serif fallback keeps content readable if the font
request fails.

## Licensing

EB Garamond is SIL Open Font License 1.1 and the licence text sits beside the font as
`static/fonts/OFL-EB-Garamond.txt`. Its copyright notice declares no Reserved Font Name, so OFL §3 places no naming
restriction on this modified, subsetted copy. Re-verified against the upstream `OFL.txt` on 2026-08-27.
