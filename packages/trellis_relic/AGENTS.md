# trellis_relic

Serverpod Relic integration for Trellis: response helpers, HTMX detection, and security-header middleware. See the
[README](README.md).

## Key Development Commands

Run from `packages/trellis_relic/`.

| Task | Command |
|---|---|
| analyze | `dart analyze --fatal-infos` |
| format check | `dart format --output none --set-exit-if-changed .` |
| test (fast and full are the same here; no `e2e` tests) | `dart test` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

## Conventions

- **Depends on `trellis` and `relic` only, not on `shelf` or `trellis_shelf`.** There is no DI layer: the engine is
  passed to each helper explicitly (`dev/architecture/system-architecture.md`, Relic).
- **Targets Relic 2.** Content-Type comes from the `Body` (`mimeType:` or `bodyType:`); one set in response headers
  is dropped on the wire, so a test of what a client receives goes through a real socket.
- **No CSRF support.** It was left out because Relic 1 had no form body parser; Relic 2 has one
  (`request.urlEncodedForm()`), but no CSRF middleware is built on it yet. Relic middleware fires only for matched
  routes, unlike Shelf.
- **`lib/src/htmx_helpers.dart` has near-identical copies in `trellis_shelf` and `trellis_dart_frog`** (ADR-011). Change
  header handling in all three.
