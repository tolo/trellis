# trellis_dart_frog

Dart Frog integration for Trellis: `trellisProvider()` engine injection, page, fragment and out-of-band response
helpers, HTMX detection, and CSRF and security middleware bridged from `trellis_shelf`. See the [README](README.md).

## Key Development Commands

Run from `packages/trellis_dart_frog/`.

| Task | Command |
|---|---|
| analyze | `dart analyze --fatal-infos` |
| format check | `dart format --output none --set-exit-if-changed .` |
| test (fast and full are the same here; no `e2e` tests) | `dart test` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

## Conventions

- **`dart_test.yaml` sets `concurrency: 1`.** Tests start real servers with `serve()`, and parallel files interfere.
  Keep it.
- **Start test servers with `withServer` in `test/test_utils.dart`.** It binds `InternetAddress.loopbackIPv4` on port 0
  and connects by that numeric address. Never bind or connect to `'localhost'` (LEARNINGS, Testing).
- **CSRF and security headers are implemented in `trellis_shelf`** and bridged here with `fromShelfMiddleware`. The CSRF
  bridge reads the body with `request.bytes()` and rebuilds a `shelf.Request`. Change behaviour in `trellis_shelf`, not
  here (`dev/architecture/system-architecture.md`, Dart Frog).
- **`lib/src/htmx_helpers.dart` has near-identical copies in `trellis_shelf` and `trellis_relic`** (ADR-011). Change
  header handling in all three.
