# Vendored assets – Meadow

Last reviewed: 2026-08-27.

All Meadow runtime assets are committed below `static/` and are served same-origin. There is no CDN or third-party
runtime request.

## Fonts

Every face is generated from a pinned `google/fonts` blob by `tool/subset_fonts.py`. Run
`python3 tool/subset_fonts.py --verify` to re-derive the files and fail on any drift from the committed bytes;
`--write` regenerates them. Both hashes below are checked by that command.

Upstream commit: [`ade3d15`](https://github.com/google/fonts/tree/ade3d1533e06b2b1462ffcde8e08b129627ca360/ofl),
fetched 2026-08-27. Toolchain: fonttools 4.63.0, brotli 1.2.0.

| Shipped file                            | Role    | Bytes  | Output SHA-256 |
| --------------------------------------- | ------- | ------ | -------------- |
| `fonts/bricolage-grotesque-latin.woff2` | display | 79,184 | `65a7dfe85937` |
| `fonts/schibsted-grotesk-latin.woff2`   | body    | 47,180 | `03e57aaf70bc` |
| `fonts/jetbrains-mono-latin.woff2`      | code    | 31,368 | `4f914c981bdc` |

Upstream blobs, all under `ofl/` at that commit:

- Bricolage Grotesque 1.001 – `bricolagegrotesque/BricolageGrotesque[opsz,wdth,wght].ttf`, SHA-256 `413e7357809d`
- Schibsted Grotesk 1.100 – `schibstedgrotesk/SchibstedGrotesk[wght].ttf`, SHA-256 `6ceeadf6be8e`
- JetBrains Mono 2.211 – `jetbrainsmono/JetBrainsMono[wght].ttf`, SHA-256 `48715a42ec24`

157,732 bytes total, all of it fetched by any page — Meadow ships one file per family and so declares no
`unicode-range`. With nothing to gate, a range could only ever exclude codepoints the file carries and push them into
a system fallback. Every face uses `font-display: swap`.

`js/meadow.js` is first-party Trellis code under the project licence: skin persistence and a guarded copy
enhancement. The hero trellis is first-party inline SVG in `layouts/home.html`, so its palette follows theme tokens
without another request.

### How each file is cut

Each file keeps only the axes the theme renders. Bricolage Grotesque keeps `opsz` because CSS `font-optical-sizing`
defaults to `auto` and the browser drives the axis from font-size; instantiating it out pins it at the low default and
widens headings by roughly 11%. Bricolage's `wdth` is unused and pinned at its default. JetBrains Mono is restricted
to `wght 400-800` — the theme never renders below 400.

The exact commands, per family (`<LATIN>` and `<SYMBOLS>` are constants in `tool/subset_fonts.py`):

```
fonttools varLib.instancer -o inst.ttf --no-recalc-timestamp <upstream>.ttf wdth=100
fonttools subset inst.ttf --output-file=bricolage-grotesque-latin.woff2 --flavor=woff2 --unicodes=<LATIN> \
    --no-hinting --name-IDs=* --layout-features+=pnum,tnum --no-recalc-timestamp
```

Bricolage pins `wdth=100`; Schibsted Grotesk has no axis to pin; JetBrains Mono limits with `wght=400:800`. Schibsted
Grotesk and JetBrains Mono add `<SYMBOLS>` to the requested set for the arrows and marks below.

`--no-recalc-timestamp` is load-bearing on both steps: without it each run stamps a new `head.modified` and the output
hash changes. `--name-IDs=*` keeps the embedded OFL notice (name IDs 13/14) and the `fvar` instance names.

### Coverage

The subsets must carry every non-ASCII character the theme itself can emit, not just the Google `latin` set.
`layouts/_default/list.html` and `single.html` render `← Back` in the body face, `layouts/base.html` renders `↑`, and
the example content uses `↗`. An earlier trim dropped `←`, `↗`, `†`, `‡`, `‰`, `⇧`, `⚠`, `⚡` and the `U+2000-200A`
spaces, so those rendered in the visitor's system font mid-sentence, at a different weight and baseline. The requested
set now covers them wherever the typeface draws them.

Bricolage Grotesque has no `↗` upstream; the character only ever appears in body copy, which is Schibsted Grotesk, so
that is not reachable in practice. The pictographs the example content uses — `✓` `✦` `⌁` `◇` `◎` `●` `☀` `☾` — are
not drawn by Bricolage or Schibsted at all and fall back to the system font by necessity. JetBrains Mono does carry
`◇` `◎` `●`, so a rule that wants them in the design's own hand can ask for the mono family.

### Weight axes

Each `@font-face` declares the range its file actually carries: Bricolage `200 800`, Schibsted `400 900`, JetBrains
Mono `400 800`. JetBrains previously declared `400 700` while the file carried `400-800`, so `.template-number`'s
weight-800 request clamped to 700 and rendered 100 units light — a monospaced face hides this from advance-width
measurement, and an ink-pixel probe was needed to see it (dark-pixel count flat at 23,925 for 700/750/800 under the
old descriptor, 23,925/25,488/27,025 under the corrected one).

## Licensing

Bricolage Grotesque, Schibsted Grotesk and JetBrains Mono are all SIL Open Font License 1.1, and the licence text sits
beside each font as `static/fonts/OFL-*.txt`. None of the three declares a Reserved Font Name in its copyright notice,
so OFL §3 places no naming restriction on these modified, subsetted copies. Re-verified against the upstream `OFL.txt`
files on 2026-08-27.
