# Vendored Assets — Arbor Docs Theme

All client-side JavaScript in this theme is **vendored** (committed to the repo)
and served **same-origin** — no CDN, no `npm`/Node build step, no runtime fetch
from an external host. Search and the code-block copy button are **progressive
enhancements**: the documentation is fully readable and navigable with JavaScript
disabled.

Syntax highlighting is **not** a client-side asset: the SSG bakes `.hljs-*` spans
into the built HTML at build time (ADR-010), styled by `sass/_code.scss`. There is
nothing highlighter-related to vendor or pin — code is colored with JavaScript off.

This file records **provenance** — what is vendored and where it came from — so a
future maintainer can re-fetch or upgrade a dependency. It is not an integrity
manifest: because every script is same-origin and committed alongside the HTML
that loads it, a per-file Subresource Integrity (SRI) hash would guard nothing it
isn't already (anyone who can alter a served script can alter the served HTML),
so the scripts are loaded without `integrity` attributes.

Last reviewed: 2026-07-08.

## First-party — `search.js`, `code-enhance.js`

Authored in this theme (no third-party library), served from `/js/<file>`:

| File | Role |
|---|---|
| `static/js/search.js` | Self-contained vanilla-JS filter over the generated `search-index.json`. The `<input>` ships `disabled` and is enabled only after the index loads; on any index-fetch failure it hides itself so the page stays fully readable. The index URL is read from the shell's `data-search-index` attribute (computed with `${site.pathPrefix}`) so it resolves under any deploy sub-path. |
| `static/js/code-enhance.js` | Adds a language label and copy button to each code block. Reads the language from the `language-*` class and the code from `textContent`, so it is independent of the build-time tokenizer (spans are stripped by `textContent`); a block with no language identifier is left unwrapped. |
