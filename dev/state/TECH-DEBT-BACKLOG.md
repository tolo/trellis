# Tech Debt Backlog — Trellis SDK

> Known technical debt. Items here are acknowledged but not yet prioritized for a milestone.

## Open Items

| ID | Area | Description | Severity | Discovered |
|----|------|-------------|----------|------------|
| TD-001 | trellis_cli | 56 info-level analyzer issues in test fixtures | Low | SDK Phase 1 |
| TD-003 | trellis_site | 2 pre-existing blog_e2e_test failures (concurrency) | Medium | SDK Phase 2 |
| TD-004 | trellis (core) | `ProcessorContext.domProcessor` typed as `dynamic` to avoid circular import | Low | v0.3 |
| TD-005 | CI / publish | Publish workflow logs "Node.js 20 is deprecated" — from `dart-lang/setup-dart` pinned inside the upstream reusable workflow (`@v1`); harmless now (jobs force-run on Node 24). Clears automatically when upstream bumps to Node 24; no local fix possible | Low | v0.8.2 |
| TD-006 | themes / trellis_css / trellis_site | Dart Sass 3.0 forward-compat: theme SASS and the `_theme_params.scss` bridge use `@import` (deprecated, removed in Dart Sass 3.0.0) — warn-only today (Dart Sass 1.x), will not compile on Sass 3.0. **This is a bridge REDESIGN, not a mechanical find-replace** (assessed 2026-07-06): the site-first param override works by generating `_theme_params.scss` (`$trellis-*: <merged> !default;`) and `@import`-ing it *before* the theme's `_variables.scss` in one global scope, so bridge values win over the theme's `!default`s. `@use` isolates/namespaces module scope, so this load-order trick doesn't survive — migration means (a) switching the bridge to `@use '<theme-main>' with (<all params>)` module configuration in `theme_sass_generator.dart` + the CLI wrapper (`build_command.dart` `_compileSass`), (b) making every theme's `_variables.scss` `@use ... with()`-configurable and each partial `@use 'variables' as *` (Arbor partials carry 100s of `$trellis-*` refs; Verdant similarly), and (c) re-testing the param-override + skin contract for both themes. Scoped as its own effort; do not bundle with unrelated work. The deprecated `if()` builtin in `arbor/sass/_variables.scss` was already modernized to `@if`. | Medium | docs-site |
| TD-007 | trellis_site | `_resolvePrevNext` (`page_generator.dart`) recomputes `orderedSectionPages` per rendered single page — re-filters + re-sorts the full page set: O(k·n log n) per section, quadratic-ish at scale. Unmeasured; current docs corpus builds in ~300 ms. **Do not optimize without a benchmark**: memoize per `sectionPath` within one `generateAll` pass only after a large-site benchmark (e.g. 1000 pages) shows measurable cost against the PRD <5 s NFR. Source: docs-site mixed review 2026-07-06 (`docs/specs/docs-site/docs-site-mixed-review-claude-2026-07-06.md`, L4, private repo) | Low | docs-site |
| TD-008 | trellis_site | `NavigationBuilder._buildLevel` rescans the entire eligible page list at every recursion level (O(S×N)); unobservable at current scale. **Do not optimize without a benchmark**: pre-group pages by `sectionPath` lineage once in `build()` only after a deeply-nested large-tree benchmark shows real cost. Source: docs-site mixed review 2026-07-06 (`docs/specs/docs-site/docs-site-mixed-review-claude-2026-07-06.md`, L5, private repo) | Low | docs-site |

## Resolved

| ID | Package | Description | Severity | Origin | Resolution |
|----|---------|-------------|----------|--------|------------|
| TD-002 | trellis_site | 1 pre-existing failure in content_discovery_test | Medium | SDK Phase 2 | 2026-07-06 — root cause was the `empty_site/content` fixture dir, which git cannot track when empty (failed on fresh clones); the test now provisions the empty dir itself. Verified by deleting the dir and running the suite: 772/772 green. |
