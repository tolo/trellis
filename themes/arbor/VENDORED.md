# Vendored Assets — Arbor Docs Theme

All client-side JavaScript in this theme is **vendored** (committed to the repo)
and served **same-origin** — no CDN, no `npm`/Node build step, no runtime fetch
from an external host. Syntax highlighting, search, and the code-block copy
button are **progressive enhancements**: the documentation is fully readable and
navigable with JavaScript disabled.

This file records **provenance** — what is vendored and where it came from — so a
future maintainer can re-fetch or upgrade a dependency. It is not an integrity
manifest: because every script is same-origin and committed alongside the HTML
that loads it, a per-file Subresource Integrity (SRI) hash would guard nothing it
isn't already (anyone who can alter a served script can alter the served HTML),
so the scripts are loaded without `integrity` attributes.

Last reviewed: 2026-07-08.

## Third-party — Prism 1.29.0

Prism core plus explicit per-language grammar components. The **autoloader is not
used** (it fetches grammars from a remote base at runtime and cannot be
vendored); explicit component files replace it. Prism's `dart` grammar extends
`clike`, so `clike` is vendored and loaded before `dart`.

Each file lives at `static/prism/<file>` and is copied to the output root
preserving its path relative to `static/`, so it is served at `/prism/<file>`
(referenced in templates via `${site.pathPrefix} + 'prism/<file>'`). All files
are the minified 1.29.0 builds from cdnjs:

`https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/<file>`

| File | Grammar / role |
|---|---|
| `prism-core.min.js` | Prism core (required first) |
| `prism-clike.min.js` | C-like base (extended by `dart`) |
| `prism-markup.min.js` | `markup`/HTML base (extended by `markdown`) |
| `prism-css.min.js` | `css` base (extended by `scss`) |
| `prism-dart.min.js` | Dart |
| `prism-scss.min.js` | SCSS |
| `prism-yaml.min.js` | YAML |
| `prism-bash.min.js` | Bash |
| `prism-markdown.min.js` | Markdown |

A fenced code block with no language identifier renders as plain, readable,
unhighlighted text.

To upgrade Prism: re-download the same component set at the new version from
cdnjs into `static/prism/`, update the version above, and re-check highlighting
in `example/`.

## First-party — `search.js`, `code-enhance.js`

Authored in this theme (no third-party library), served from `/js/<file>`:

| File | Role |
|---|---|
| `static/js/search.js` | Self-contained vanilla-JS filter over the generated `search-index.json`. The `<input>` ships `disabled` and is enabled only after the index loads; on any index-fetch failure it hides itself so the page stays fully readable. The index URL is read from the shell's `data-search-index` attribute (computed with `${site.pathPrefix}`) so it resolves under any deploy sub-path. |
| `static/js/code-enhance.js` | Adds a language label and copy button to each code block. Reads the language from the `language-*` class and the code from `textContent`, so it needs neither Prism nor tokenization; a block with no language identifier is left unwrapped. |
