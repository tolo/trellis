# Vendored Assets — Arbor Docs Theme

All client-side JavaScript in this theme is **vendored** (committed to the repo)
and served **same-origin**. There is no CDN, no `npm`/Node build step, and no
runtime fetch from an external host. Every `<script>` tag in `layouts/base.html`
carries a per-file Subresource Integrity (SRI) `integrity="sha384-…"` attribute
matching the hash recorded below, plus `crossorigin="anonymous"` and `defer`.

Syntax highlighting and search are **progressive enhancements**: the
documentation is fully readable and navigable with JavaScript disabled.

Vendored: 2026-07-06.

## Syntax highlighter — Prism 1.29.0

Prism core plus explicit per-language grammar components. The **autoloader is not
used** (it fetches grammars from a remote base at runtime and cannot be
vendored); explicit component files replace it. Prism's `dart` grammar extends
`clike`, so `clike` is vendored and loaded before `dart`.

Served path: each file lives at `static/prism/<file>` and is copied to the output
root preserving only the path relative to `static/`, so it is served at
`/prism/<file>` (referenced in templates as `${site.pathPrefix} + 'prism/<file>'`).

| File | Version | Source URL | SRI (sha384) |
|---|---|---|---|
| `static/prism/prism-core.min.js` | 1.29.0 | https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-core.min.js | `sha384-MXybTpajaBV0AkcBaCPT4KIvo0FzoCiWXgcihYsw4FUkEz0Pv3JGV6tk2G8vJtDc` |
| `static/prism/prism-clike.min.js` | 1.29.0 | https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-clike.min.js | `sha384-7LHwxHIDSHTBleLmgDWZbC/IMJsfYfFVOihKhvsrxYW4j47YQcRwZja4ToFE3bA8` |
| `static/prism/prism-markup.min.js` | 1.29.0 | https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-markup.min.js | `sha384-HkMr0bZB9kBW4iVtXn6nd35kO/L/dQtkkUBkL9swzTEDMdIe5ExJChVDSnC79aNA` |
| `static/prism/prism-css.min.js` | 1.29.0 | https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-css.min.js | `sha384-0mV13Neu0xhJFylI+HV43C+XiR13bGSeL7D0/7e6hK7sJgvyvK6HVjeQwmvXTstY` |
| `static/prism/prism-dart.min.js` | 1.29.0 | https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-dart.min.js | `sha384-cfEVSC1pSQWFCAHLhuVkdGm1NrPSw0Jj4pAt0cnC/e9PP3eSnxKk77LgaFFSUqws` |
| `static/prism/prism-yaml.min.js` | 1.29.0 | https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-yaml.min.js | `sha384-AKAiycghK0jDCjD+aavMHzDkLzRR7Yzcwh3+xL/295cvyVMe+cxQfyQC8xxGGcI8` |
| `static/prism/prism-bash.min.js` | 1.29.0 | https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-bash.min.js | `sha384-9WmlN8ABpoFSSHvBGGjhvB3E/D8UkNB9HpLJjBQFC2VSQsM1odiQDv4NbEo+7l15` |
| `static/prism/prism-scss.min.js` | 1.29.0 | https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-scss.min.js | `sha384-kRWiSF1UhVO7HGkpK3GX+OGmVHxBjCBwRxc9EIP3tqScIgDEAizIeCWds1M6ratq` |
| `static/prism/prism-markdown.min.js` | 1.29.0 | https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-markdown.min.js | `sha384-s888ApkYHxfPsp8n81g77Unl/0XYnYltLvWbwqKHcheRE8/dZPlT4IjW3mRGv/Hd` |

Language coverage: `dart`, `markup`/`html`, `css`, `yaml`, `bash`, `scss`,
`markdown` (plus `clike`, the base grammar `dart` extends; `markup`, the base
for HTML and for `markdown`; and `css`, the base for `scss`). A fenced code
block with no language identifier renders as plain, readable, unhighlighted text.

### Provenance verification

Each file's bytes were verified against the cdnjs-published SHA-512 for Prism
1.29.0 before the SHA-384 SRI above was computed. To re-verify a file's SRI:

```bash
cat static/prism/prism-core.min.js | openssl dgst -sha384 -binary | openssl base64 -A
```

## Client-side search — `search.js`

| File | Version | Source | SRI (sha384) |
|---|---|---|---|
| `static/js/search.js` | theme-local (v1.1.0) | Authored in this theme (no third-party library — a self-contained vanilla-JS filter over the generated `search-index.json`) | `sha384-39YMhumgS1xq8+xDAoRuz+/iuKgAJ+ivwijtWn0EXlf/VfgqUsmmuZY94XO7+aDG` |

Served at `/js/search.js` (root-relative via `${site.pathPrefix}`). Same-origin,
SRI-pinned, `crossorigin="anonymous"`, `defer`. **No CDN, no npm, no build step,
no third-party dependency** — the search client is dependency-free vanilla JS
authored in this theme, chosen over a vendored library (Lunr/MiniSearch/Fuse) to
keep the asset small and fully auditable while still satisfying the vendored +
pinned + SRI discipline.

Progressive enhancement: the search `<input>` ships `disabled` in the static
HTML and is enabled only after `search-index.json` loads. On any index-fetch
failure (missing file, network error, non-OK response, malformed payload) the
control hides itself and the page stays fully readable. The index URL is not
hardcoded — it is read from the shell's `data-search-index` attribute, which the
layout computes with `${site.pathPrefix}` so the fetch resolves under any deploy
sub-path.

To re-verify the SRI:

```bash
cat static/js/search.js | openssl dgst -sha384 -binary | openssl base64 -A
```
