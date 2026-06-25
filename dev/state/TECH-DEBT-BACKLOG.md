# Tech Debt Backlog — Trellis SDK

> Known technical debt. Items here are acknowledged but not yet prioritized for a milestone.

## Open Items

| ID | Area | Description | Severity | Discovered |
|----|------|-------------|----------|------------|
| TD-001 | trellis_cli | 56 info-level analyzer issues in test fixtures | Low | SDK Phase 1 |
| TD-002 | trellis_site | 1 pre-existing failure in content_discovery_test | Medium | SDK Phase 2 |
| TD-003 | trellis_site | 2 pre-existing blog_e2e_test failures (concurrency) | Medium | SDK Phase 2 |
| TD-004 | trellis (core) | `ProcessorContext.domProcessor` typed as `dynamic` to avoid circular import | Low | v0.3 |
| TD-005 | CI / publish | Publish workflow logs "Node.js 20 is deprecated" — from `dart-lang/setup-dart` pinned inside the upstream reusable workflow (`@v1`); harmless now (jobs force-run on Node 24). Clears automatically when upstream bumps to Node 24; no local fix possible | Low | v0.8.2 |

## Resolved

_None yet._
