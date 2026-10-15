# trellis_shelf

Shelf integration for Trellis: engine-injecting middleware, response helpers, HTMX request helpers, and security
defaults (CSRF, security headers). See the [README](README.md).

## Key Development Commands

Run from `packages/trellis_shelf/`.

| Task | Command |
|---|---|
| analyze | `dart analyze --fatal-infos` |
| format check | `dart format --output none --set-exit-if-changed .` |
| test (fast and full are the same here; no `e2e` tests) | `dart test` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

## Conventions

- **Depends on `trellis`, `shelf` and `crypto` only.** Core never imports Shelf (ADR-005).
- **HTMX helpers only read request headers** (`HX-Request`, `HX-Target`, `HX-Trigger`, `HX-Boosted`, `HX-Source`) and
  must work for HTMX 2 and 4 (ADR-011, LEARNINGS, HTMX Integration). `lib/src/htmx_helpers.dart` has near-identical
  copies in `trellis_dart_frog` and `trellis_relic`: change header handling in all three.
- **`trellis_dart_frog` bridges `trellisCsrf` and `trellisSecurityHeaders` from here** with `fromShelfMiddleware`
  (`dev/architecture/system-architecture.md`, Dart Frog). Treat their signatures as shared API.
