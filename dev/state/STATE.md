# Project State — Trellis SDK

> Cross-session state tracking. Updated at phase boundaries and when significant context changes.

## Current Phase

**SDK Phase 4** — SSG Theme System (completed 2026-03-20)

**Next up**: SDK Phase 5 — Full CSS Processing (purging, minification). Draft PRD tracked in the private planning repo.

## Recent Completions

| Phase | Completed | Key Deliverables |
|-------|-----------|------------------|
| SDK Phase 4 | 2026-03-20 | Theme manifest + params, ThemeAwareLoader, SASS bridge, CLI theme commands, Verdant theme |
| SDK Phase 3 | 2026-03-17 | trellis_dart_frog, trellis_relic, expression utility objects, RSS, search index |
| SDK Phase 2 | 2026-03-16 | trellis_site (SSG), trellis_css, CLI build/serve, blog starter |
| SDK Phase 1 | 2026-03-15 | Monorepo, trellis_shelf, trellis_dev, template inheritance, trellis_cli |

## Published Versions

- `trellis` (core): **v0.6.0** on pub.dev. **v0.8.0 cut locally** (2026-06-05), pending publish — adds expression utility objects and the merged `testing.dart` (with a `matcher` dep) on top of the never-published 0.7.0 (template inheritance, contextual escaping). `dart pub publish --dry-run`: 0 warnings.
- SDK packages (all unpublished): `trellis_site` **0.2.0**, `trellis_cli` **0.3.0**; `trellis_shelf` / `trellis_dev` / `trellis_css` / `trellis_relic` / `trellis_dart_frog` all **0.1.0**. CHANGELOG/pubspec/version.dart are internally consistent for every package; satellites depend on `trellis: ^0.8.0`.
- No `path:` sibling deps anywhere (all use `^x.y.z`), so nothing structurally blocks publishing. **Publish order:** core → {shelf, dev, css, site, relic} → dart_frog (needs shelf) → cli (needs css + site).
- The 4 `examples/*` packages + root workspace correctly carry `publish_to: none`.

## Decisions

- **2026-06-04 — Core package rename DROPPED.** `trellis` → `trellis_templates` will NOT happen (134 imports deep, name already published on pub.dev). The core package stays named `trellis`.
- **2026-06-05 — Docs split.** Contributor docs (ADRs + research appendices, architecture, guidelines, learnings, tech-debt, this state file) live in the public repo under `dev/`; user-facing docs under `docs/`. Research, diagrams, specs/plans, and the product backlog stay in the private planning repo.

## Test Health

~2,377 total tests across all packages. 1 pre-existing failure in content_discovery_test; 2 pre-existing blog_e2e_test failures (concurrency). `dart analyze`: 56 info-level issues in CLI test fixtures (pre-existing); no errors in library/package code.

## Blockers

None.
