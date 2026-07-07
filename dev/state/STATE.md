# Project State — Trellis SDK

> Cross-session state tracking. Updated at phase boundaries and when significant context changes.

## Current Phase

**Docs Site** — public front door (marketing landing + curated docs) built entirely with Trellis (`trellis_site` + the new `arbor` docs theme), plus the five docs-shaped engine features (completed 2026-07-06, in the working tree, uncommitted).

**Next up**: commit + squash-merge the docs-site work; a single **lockstep version bump** (`tool/version_lockstep.sh`, ADR-009) for the `trellis_site`/`trellis_cli` engine features before publish; then SDK Phase 5 — Full CSS Processing.

## Recent Completions

| Phase | Completed | Key Deliverables |
|-------|-----------|------------------|
| Docs Site | 2026-07-06 | Engine: weighted ordering + nested sections + `orderedSectionPages` seam, `${site.menu}` nav tree (section-weight ordered), `pathPrefix` (with unprefixed on-disk layout + content-link rewriting), in-section prev/next; `arbor` docs theme (vendored Prism + SRI, WCAG-AA skins, responsive, search shell); `site/` (marketing landing + curated docs IA: getting-started, complete `tl:*` syntax reference, 8 package guides, theme-authoring); client-side search; GitHub Pages CI deploy + pure-Dart link-integrity checker. Deploy target: `tolo.github.io/trellis/` (`pathPrefix: /trellis/`). |
| SDK Phase 4 | 2026-03-20 | Theme manifest + params, ThemeAwareLoader, SASS bridge, CLI theme commands, Verdant theme |
| SDK Phase 3 | 2026-03-17 | trellis_dart_frog, trellis_relic, expression utility objects, RSS, search index |
| SDK Phase 2 | 2026-03-16 | trellis_site (SSG), trellis_css, CLI build/serve, blog starter |
| SDK Phase 1 | 2026-03-15 | Monorepo, trellis_shelf, trellis_dev, template inheritance, trellis_cli |

## Published Versions

- **Published on pub.dev: v0.8.2** (all 8 SDK packages, lockstep per ADR-009; verified against the pub.dev API 2026-07-07): `trellis`, `trellis_shelf`, `trellis_dev`, `trellis_cli`, `trellis_css`, `trellis_site`, `trellis_dart_frog`, `trellis_relic`.
- **v0.9.0 published 2026-07-07** (docs-site engine features + arbor theme + skin-forcing fix); docs site live at `www.leafnode.se/trellis/` (the account-level custom domain applies to project pages; `tolo.github.io/trellis/` 301s there).
- **v0.9.1** (2026-07-07): patch release fixing the theme SASS bridge quoting string params into invalid CSS (serif-fallback fonts, unconstrained layout on every bridge-built theme) + `version_lockstep.sh`/melos `workspaceChangelog` fix.
- Releases are cut with `tool/version_lockstep.sh` (single `melos version` pass); publish is OIDC tag-triggered (`publish.yml`, global `vX.Y.Z` tag per ADR-009).
- The 4 `examples/*` packages + root workspace correctly carry `publish_to: none`.

## Decisions

- **2026-06-04 — Core package rename DROPPED.** `trellis` → `trellis_templates` will NOT happen (134 imports deep, name already published on pub.dev). The core package stays named `trellis`.
- **2026-06-05 — Docs split.** Contributor docs (ADRs + research appendices, architecture, guidelines, learnings, tech-debt, this state file) live in the public repo under `dev/`; user-facing docs under `docs/`. Research, diagrams, specs/plans, and the product backlog stay in the private planning repo.

## Test Health

~2,377 total tests across all packages (+ docs-site additions). After the docs-site work: `trellis_site` **754 pass / 1 fail** (the pre-existing `content_discovery_test` empty-dir failure, TD-002); `trellis_cli` **240 pass** serially (the `examples_smoke_test` is parallel-flaky — passes with `-j 1`); repo-root `test/` (`link_check` + `search_client`) 24 pass. `dart analyze --fatal-infos` clean across `trellis_site`, `trellis_cli`, and the new `tool/link_check.dart`. New Dart Sass 3.0 forward-compat tech-debt logged as TD-006 (`@import` in theme SASS + the bridge).

## Blockers

None.
