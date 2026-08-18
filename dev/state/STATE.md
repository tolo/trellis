# Project State — Trellis SDK

> Cross-session state tracking. Updated at phase boundaries and when significant context changes.

## Current Phase

**0.10.0** (shipped 2026-07-25 from branch `feature/0.10.0`) — a multi-slice release hardening the SDK for distribution: binary distribution gains a **Scoop** channel (plus release-workflow hardening and conflict resolution); **build-time syntax highlighting** lands (ADR-010: `trellis_site` bakes `.hljs-*` spans at build time, retiring the vendored client-side Prism); the **`bloom`** landing theme ships alongside `verdant`/`arbor` polish; the theme **SASS-bridge** escaping is hardened; and **TD-009** (CLI CWD mutation) is resolved so the `trellis_cli` suite is parallel-safe.

**0.10.1 shipped 2026-08-18** — first release cut through [`dev/guidelines/RELEASE-RUNBOOK.md`](../guidelines/RELEASE-RUNBOOK.md) (`tool/release.sh` + the CI tag gate; both gates held for CI and released cleanly): `FragmentHost` typing for `ProcessorContext.domProcessor`, SSG prev/next perf, HTMX 2.0.10 scaffolds, push CI (`ci.yml`, TD-010), release tooling. The first ubuntu CI run surfaced two macOS-only assumptions (TZ-baked golden; Linux `recursive` watch gap → TD-013/TD-014).

**0.10.2 in progress** (branch `feat/0.10.2`, not yet released) — patch: **TD-013** resolved — `FileSystemLoader` watches each template directory individually on Linux, so dev-mode hot reload now sees edits in sub-folders there (macOS/Windows unchanged); plus the `trellis_cli` generated-app e2e twin binding/connecting via numeric loopback (**TD-015** files the remaining scaffold `'localhost'` bind). Cut with `tool/release.sh 0.10.2` on `main` after squash-merge.

**Next up**: 0.11 — doc-site redesign & three new built-in themes (private `docs/specs/0.11/`, 5 stories spec-ready), then TD-006 SASS `@use` migration; later candidates: CSS processing, composition primitives, Trellis UI (private `docs/specs/0.next-*/`). Open follow-ups: TD-014 (date-only front matter timezone) and TD-015 (Shelf scaffold `'localhost'` bind).

## Recent Completions

| Phase | Completed | Key Deliverables |
|-------|-----------|------------------|
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
- Releases follow `dev/guidelines/RELEASE-RUNBOOK.md`: `tool/release.sh` (lockstep bump, gate, release commit, local tag), then one push; publish is OIDC tag-triggered (`publish.yml`, global `vX.Y.Z` tag per ADR-009) behind the CI release gate (`release-gate.yml`).
- The 4 `examples/*` packages + root workspace correctly carry `publish_to: none`.

## Decisions

- **2026-06-04 — Core package rename DROPPED.** `trellis` → `trellis_templates` will NOT happen (134 imports deep, name already published on pub.dev). The core package stays named `trellis`.
- **2026-06-05 — Docs split.** Contributor docs (ADRs + research appendices, architecture, guidelines, learnings, tech-debt, this state file) live in the public repo under `dev/`; user-facing docs under `docs/`. Research, diagrams, specs/plans, and the product backlog stay in the private planning repo.

## Test Health

On `feature/0.10.0`: `trellis_site` **835 pass / 0 fail**; `trellis_cli` **253 pass** at default concurrency (parallel-safe after **TD-009** removed the CWD mutation the `examples_smoke_test` flakiness traced to — no more `-j 1` workaround); repo-root `test/` **34 pass** (incl. the release-distribution contract tests). `dart analyze --fatal-infos` clean across the workspace. Dart Sass 3.0 forward-compat tech-debt remains logged as TD-006 (`@import` in theme SASS + the bridge).

## Blockers

None.
