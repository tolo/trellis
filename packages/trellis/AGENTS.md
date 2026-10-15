# trellis

Core template engine: natural-HTML templates with `tl:*` attributes, expression evaluator, processor pipeline,
fragment rendering, template inheritance, caching and validation. Also ships `package:trellis/testing.dart` and the
`dart run trellis:validate` executable (`bin/validate.dart`). Syntax: [README](README.md); authoring guide:
[doc/trellis-for-agents.md](doc/trellis-for-agents.md).

## Key Development Commands

Run from `packages/trellis/`.

| Task | Command |
|---|---|
| analyze | `dart analyze --fatal-infos` |
| format check | `dart format --output none --set-exit-if-changed .` |
| test (fast and full are the same here; no `e2e` tests) | `dart test` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

## Conventions

- **Core depends on no other SDK package and no web framework** (ADR-004 dependency rules, ADR-005). CSS, SSG and dev
  tools never become transitive dependencies of core. `matcher` is a regular dependency, not a dev one, because
  `testing.dart` exports matcher-based APIs.
- **AOT-safe: no `dart:mirrors`, reflection or code generation.** Context is `Map<String, dynamic>`; objects reach
  templates through dynamic `toMap()` then `toJson()` dispatch (`dev/state/LEARNINGS.md`, Object Context).
- **Rendering is sync-first, and cached DOM is cloned before every render** so cached templates stay immutable
  (`dev/architecture/template-engine.md`, Design Philosophy).
- **`package:html` parses before any `tl:*` processor runs** and silently rewrites malformed markup, so such bugs show
  no error at render time. The validator surfaces them from parse errors (LEARNINGS, HTML5 Parser Boundary).
- Before touching the evaluator, processors, or `FileSystemLoader` watching, read the matching LEARNINGS sections
  (Expression Evaluator, DOM Processing, Processor System, File Watching).
- In tests, build engines with `MapLoader({})` rather than the no-arg `Trellis()`: `FileSystemLoader` checks its
  directory at construction.
