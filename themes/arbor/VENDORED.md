# Vendored Assets — Arbor Docs Theme

Arbor serves its client-side JavaScript from the site's origin. The build emits
`trellis-search.js` alongside the search index and copies the embedded
`trellis_ui` assets for the combobox and copy button. Search and the code-block copy button are **progressive
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

Last reviewed: 2026-11-18.

## First-party code enhancement

Arbor serves this script from `/js/code-enhance.js`.

| File | Role |
|---|---|
| `static/js/code-enhance.js` | Adds a language label and clones the suite copy button into each code bar. Reads the language from the `language-*` class and the code from `textContent`, so it is independent of the build-time tokenizer (spans are stripped by `textContent`); a block with no language identifier is left unwrapped. |
