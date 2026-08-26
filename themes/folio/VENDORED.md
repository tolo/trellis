# Vendored assets – Folio

All runtime assets are committed and served same-origin. No CDN, npm, or client-side syntax highlighter is used.

## First-party scripts

- `static/js/folio.js` – persistent auto-skin edition switch; authored for Folio.
- `static/js/search.js` – progressive search over the generated same-origin index; inherited from Arbor's first-party
  code.

## Fonts

- `static/fonts/eb-garamond-latin.woff2` – EB Garamond **variable** (weight 400–600) normal latin subset from the
  [Google Fonts CSS API](https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400..600); upstream source and
  metadata are in [`google/fonts/ofl/ebgaramond`](https://github.com/google/fonts/tree/main/ofl/ebgaramond). SIL Open
  Font License in `static/fonts/OFL-EB-Garamond.txt`. 44,172 bytes – the theme's entire font payload.

  One variable file replaces per-weight statics: headings need 500 and 600, and two static faces would cost more
  (23,848 + 25,308) than the variable one while still missing intermediate weights. `size-adjust: 118%` corrects EB
  Garamond's x-height (40.5 per 100px) to the Palatino/Iowan metrics the design was drawn against (47.1–47.9);
  without it body copy renders at roughly 15px optical instead of 18px.

No monospace font is vendored. Code and label type use the system stack
(`SFMono-Regular, Consolas, Liberation Mono, monospace`) – the same stack the approved design uses, which also gives
labels a real 700 weight instead of a synthesised one. A system serif fallback keeps content readable if the font
request fails.
