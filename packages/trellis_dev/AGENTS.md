# trellis_dev

Developer tooling for Trellis: SSE browser hot reload (`devMiddleware`, `liveReloadHandler`) driven by the template
loader's file watcher, or by any change stream (`liveReloadMiddleware`, used by `trellis dev`). See the
[README](README.md).

## Key Development Commands

Run from `packages/trellis_dev/`.

| Task | Command |
|---|---|
| analyze | `dart analyze --fatal-infos` |
| format check | `dart format --output none --set-exit-if-changed .` |
| package suite (branch CI and full) | `dart test` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

## Conventions

- **Dev-only: nothing in core or another runtime package may depend on this package** (ADR-002, ADR-004 rule 5).
  It depends on `trellis` and `shelf` only. `trellis_cli` depends on it: the CLI is a dev tool, not a runtime package.
- **The `FileSystemLoader` passed in must be created with `devMode: true`**, or its `changes` stream is null and
  `devMiddleware` throws a `StateError`.
- **`devMiddleware` re-validates every template on each change event**, so a burst of events repeats a full scan. If
  that matters, coalesce in the middleware, not the loader (LEARNINGS, File Watching).
