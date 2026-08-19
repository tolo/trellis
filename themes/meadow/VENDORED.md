# Vendored assets

All Meadow runtime assets are committed below `static/` and are served same-origin.

| Asset | Source | License | Notes |
|---|---|---|---|
| Bricolage Grotesque Latin WOFF2 | Google Fonts repository | SIL Open Font License 1.1 | Variable display subset |
| Schibsted Grotesk Latin WOFF2 | Google Fonts repository | SIL Open Font License 1.1 | Variable body subset |
| JetBrains Mono Latin WOFF2 | Google Fonts repository | SIL Open Font License 1.1 | Variable code subset |
| `js/meadow.js` | Trellis project | Project license | Skin persistence and guarded copy enhancement |

The corresponding OFL texts are stored beside the fonts. Meadow has no CDN or third-party runtime request. The hero
trellis is first-party inline SVG in `layouts/home.html` so its palette follows theme tokens without another request.
