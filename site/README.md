# Trellis docs site

The Trellis documentation site, built with the pure-Dart Trellis SSG and published
to GitHub Pages. No npm/Node/JS build step anywhere — building the site and checking
its links is all Dart.

## Deploy target (config-driven)

The live site is served from the **GitHub Project Pages sub-path**
`https://tolo.github.io/trellis/`.

The target is a config value in [`trellis_site.yaml`](trellis_site.yaml), never
hardcoded in templates or links:

- `baseUrl: https://tolo.github.io` — the canonical origin (used for sitemap/feed URLs).
- `pathPrefix: /trellis/` — the sub-path the site is mounted at.

`trellis build` prefixes every root-absolute internal link/asset with `pathPrefix`
and writes files at their **unprefixed** disk paths (`output/docs/index.html`), so the
whole `output/` tree is published as the Pages artifact root and GitHub mounts it under
`/trellis/`. Relative links, anchors, and external URLs are left untouched.

Moving to a custom root domain later is a **config edit, not a code change**: clear
`pathPrefix` to `''` (or drop it) and point `baseUrl` at the new host. Nothing in the
deploy workflow hardcodes the domain.

## Preview locally

From the repository root, [`tool/serve_docs.sh`](../tool/serve_docs.sh) builds a
root-served variant and serves it at `http://localhost:8765`:

```sh
tool/serve_docs.sh
```

Pass a different port as the only argument when needed, for example
`tool/serve_docs.sh 9000`. Stop the server with Ctrl-C. Rerun the script after
changing site content, layouts, or theme assets — it regenerates the themes
gallery first, so a theme manifest or screenshot change shows up in the preview
and the regenerated files are ready to commit.

## Build locally

From this directory (`site/`):

```sh
trellis build            # uses pathPrefix from trellis_site.yaml → output/
```

To preview the root-served variant (no sub-path):

```sh
trellis build --path-prefix '' --output output-root
```

## Link-integrity check

A green `trellis build` is **not** proof of a working site — a wrong-base-path link
emits valid HTML and no build error but a dead link in production. The pure-Dart
checker at [`../tool/link_check.dart`](../tool/link_check.dart) is the real gate: it
walks the built output, resolves every internal `href`/`src`/`srcset` — plus the
`data-light`/`data-dark` attributes themes use to swap assets per skin — against the
output filesystem the way a static host serves it, and exits non-zero on any broken
reference. External URLs (`http(s):`, `//host`, `mailto:`, `tel:`, `data:`) and pure
in-page anchors (`#frag`) are never reported.

Run it from the repo root against the built output. The `--base-path` **must** match
`pathPrefix` in `trellis_site.yaml`, so a root-absolute link that failed to pick up the
prefix is caught:

```sh
# Production (sub-path) build — matches the live deploy:
dart run tool/link_check.dart site/output --base-path /trellis/

# Root-served variant — no base-path:
dart run tool/link_check.dart site/output-root
```

It exits `0` with a summary count when every internal reference resolves, `1` (listing
each broken ref as `page -> target (reason)`) when any is broken, and `2` on a usage
error. The check is deterministic — no network, no environment lookups — so it produces
the same result locally and in CI. See `dart run tool/link_check.dart --help` for usage.

## CI deploy

[`.github/workflows/deploy-docs-site.yml`](../.github/workflows/deploy-docs-site.yml)
runs on every push to `main` (and via manual `workflow_dispatch`). It:

1. sets up Dart, `dart pub get`, and activates the `trellis` CLI;
2. builds the production (sub-path) site with `trellis build`;
3. runs the link-integrity check against `site/output` with `--base-path /trellis/` as
   a **required gate** — a broken link fails the pipeline and blocks the deploy;
4. builds and checks a root-served variant as an FR10 portability regression guard
   (pipeline-gating, does not change the live deploy);
5. publishes `site/output` to GitHub Pages — only after the build and both checks pass,
   so nothing partial or broken reaches Pages.
