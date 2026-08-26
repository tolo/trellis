# Vendored assets

All Meadow runtime assets are committed below `static/` and are served same-origin.

| Asset | Source | License | Notes |
|---|---|---|---|
| Bricolage Grotesque Latin WOFF2 | Google Fonts repository | SIL Open Font License 1.1 | Variable display subset, `opsz`+`wght` (76,868 B) |
| Schibsted Grotesk Latin WOFF2 | Google Fonts repository | SIL Open Font License 1.1 | Variable body subset, `wght` (46,864 B) |
| JetBrains Mono Latin WOFF2 | Google Fonts repository | SIL Open Font License 1.1 | Variable code subset, `wght` (31,340 B) |
| `js/meadow.js` | Trellis project | Project license | Skin persistence and guarded copy enhancement |

Each file carries only the variable axes the theme renders. Bricolage Grotesque keeps `opsz` because automatic optical
sizing moves it at display sizes — instantiating it out widens headings by roughly 11%. Its `wdth` axis and the other
families' unused axes are pinned at their defaults. Dropping them cut the set from 241,292 to 155,072 bytes with
byte-identical metrics at every weight the theme uses.

The corresponding OFL texts are stored beside the fonts. Meadow has no CDN or third-party runtime request. The hero
trellis is first-party inline SVG in `layouts/home.html` so its palette follows theme tokens without another request.
