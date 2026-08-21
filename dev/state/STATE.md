# Project State — Trellis SDK

Last Updated: 2026-08-19

> Cross-session state tracking. Updated at phase boundaries and when significant context changes.

## Current Phase

**0.11 implementation complete** — Lattice, the redesigned site and six-theme generated gallery, Folio, Meadow,
authoring guidance, architecture, and unreleased lockstep changelog collateral are complete on `feat/0.11`. Post-plan
owner review and the separate 0.11.0 version bump, tag, and publication remain pending.

## Recent Completions

| Phase | Completed | Key Deliverables |
|-------|-----------|------------------|
| 0.11.0 (implementation) | 2026-08-19 | Lattice docs theme and Lattice-powered site; deterministic six-theme gallery; Folio reference theme; Meadow product-landing theme; theme-data authoring guidance; architecture and unreleased 0.11.0 changelog collateral. Owner review and release remain pending. |
| 0.10.0 (pre-release) | 2026-07-11 | Binary distribution: **Scoop** channel + release-workflow hardening (both tap jobs skip without `TAP_TOKEN`); build-time syntax highlighting (ADR-010: `CodeHighlighter`/`package:highlight`, `.hljs-*` spans, `highlight:` config key, vendored Prism removed); `bloom` landing theme + `verdant`/`arbor` polish; theme SASS-bridge escaping hardened; **TD-009** resolved (`ProcessRunner`, no CWD mutation → parallel-safe CLI suite). |
| Docs Site | 2026-07-06 | Engine: weighted ordering + nested sections + `orderedSectionPages` seam, `${site.menu}` nav tree (section-weight ordered), `pathPrefix` (with unprefixed on-disk layout + content-link rewriting), in-section prev/next; `arbor` docs theme (build-time `.hljs-*` highlighting, WCAG-AA skins, responsive, search shell); `site/` (marketing landing + curated docs IA: getting-started, complete `tl:*` syntax reference, 8 package guides, theme-authoring); client-side search; GitHub Pages CI deploy + pure-Dart link-integrity checker. Deploy target: `tolo.github.io/trellis/` (`pathPrefix: /trellis/`). |
| SDK Phase 4 | 2026-03-20 | Theme manifest + params, ThemeAwareLoader, SASS bridge, CLI theme commands, Verdant theme |
| SDK Phase 3 | 2026-03-17 | trellis_dart_frog, trellis_relic, expression utility objects, RSS, search index |
| SDK Phase 2 | 2026-03-16 | trellis_site (SSG), trellis_css, CLI build/serve, blog starter |
| SDK Phase 1 | 2026-03-15 | Monorepo, trellis_shelf, trellis_dev, template inheritance, trellis_cli |

## Published Versions

- **Published on pub.dev: v0.8.2** (all 8 SDK packages, lockstep per ADR-009; verified against the pub.dev API 2026-07-07): `trellis`, `trellis_shelf`, `trellis_dev`, `trellis_cli`, `trellis_css`, `trellis_site`, `trellis_dart_frog`, `trellis_relic`.
- **v0.9.0 published 2026-07-07** (docs-site engine features + arbor theme + skin-forcing fix); docs site live at `www.leafnode.se/trellis/` (the account-level custom domain applies to project pages; `tolo.github.io/trellis/` 301s there).
- **v0.9.1** (2026-07-07): patch release fixing the theme SASS bridge quoting string params into invalid CSS (serif-fallback fonts, unconstrained layout on every bridge-built theme) + `version_lockstep.sh`/melos `workspaceChangelog` fix.
- **v0.10.0** (2026-07-25): build-time syntax highlighting (ADR-010), Scoop distribution channel, `bloom` theme + theme polish, TD-009.
- **v0.10.1** (2026-08-18): `FragmentHost` contract (source-break for direct `ProcessorContext` construction, deliberate), SSG prev/next perf, HTMX 2.0.10 scaffolds, push CI + release gate/tooling. Verified with `tool/verify_release.sh 0.10.1`: pub.dev ×8, Release + 11 assets, Homebrew, Scoop.
- **v0.10.2** (2026-08-18): TD-013 Linux nested-template watching + dev-watch hardening (rename/atomic-save reloads), `listTemplates()` symlink alignment, e2e numeric loopback. Verified with `tool/verify_release.sh 0.10.2`: pub.dev ×8 latest=0.10.2, Release + 11 assets, Homebrew, Scoop.
- Releases follow `dev/guidelines/RELEASE-RUNBOOK.md`: `tool/release.sh` (lockstep bump, gate, release commit, local tag), then one push; publish is OIDC tag-triggered (`publish.yml`, global `vX.Y.Z` tag per ADR-009) behind the CI release gate (`release-gate.yml`).
- The 4 `examples/*` packages + root workspace correctly carry `publish_to: none`.

## Decisions

- **2026-06-04 — Core package rename DROPPED.** `trellis` → `trellis_templates` will NOT happen (134 imports deep, name already published on pub.dev). The core package stays named `trellis`.
- **2026-06-05 — Docs split.** Contributor docs (ADRs + research appendices, architecture, guidelines, learnings, tech-debt, this state file) live in the public repo under `dev/`; user-facing docs under `docs/`. Research, diagrams, specs/plans, and the product backlog stay in the private planning repo.

## Test Health

On `feat/0.11`: all eight package test suites pass (one existing Linux-only skip in `trellis`), the repo-root suite
passes **80/80**, and workspace analyze and format gates pass across all 12 packages. Root and `/trellis/` docs builds
each produce 27 pages and 39 static files with 1,279 internal references and no broken links. Dart Sass 3.0
forward-compat tech debt remains logged as TD-006 (`@import` in theme SASS + the bridge).

## Blockers

None.
