# Vendored assets – Folio

All runtime assets are committed and served same-origin. No CDN, npm, or client-side syntax highlighter is used.

## First-party scripts

- `static/js/folio.js` – persistent auto-skin edition switch; authored for Folio.
- `static/js/search.js` – progressive search over the generated same-origin index; inherited from Arbor's first-party
  code.

## Fonts

- `static/fonts/eb-garamond-latin.woff2` – EB Garamond 400 normal latin subset from the
  [Google Fonts CSS API](https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400); upstream source and metadata
  are in [`google/fonts/ofl/ebgaramond`](https://github.com/google/fonts/tree/main/ofl/ebgaramond). SIL Open Font
  License in `static/fonts/OFL-EB-Garamond.txt`.
- `static/fonts/ibm-plex-mono-latin.woff2` – IBM Plex Mono 400 normal latin subset from the
  [Google Fonts CSS API](https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400); upstream source and metadata
  are in [`google/fonts/ofl/ibmplexmono`](https://github.com/google/fonts/tree/main/ofl/ibmplexmono). SIL Open Font
  License in `static/fonts/OFL-IBM-Plex-Mono.txt`.

System serif and monospace fallbacks keep content readable if a font request fails.
