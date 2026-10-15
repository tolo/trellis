# trellis_css

CSS utilities for Trellis: Dart-native SASS/SCSS compilation (`TrellisCss.compileSass`, `compileSassString`) and
fragment-scoped CSS through `tl:scope` (`CssDialect`, `ScopeProcessor`). See the [README](README.md).

## Key Development Commands

Run from `packages/trellis_css/`.

| Task | Command |
|---|---|
| analyze | `dart analyze --fatal-infos` |
| format check | `dart format --output none --set-exit-if-changed .` |
| test (fast and full are the same here; no `e2e` tests) | `dart test` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

## Conventions

- **SASS compiles in-process through `package:sass`.** No Node.js, npm or Sass binary (ADR-006, ADR-013).
- **`compileSass` cannot silence the `@import` deprecation.** `fatalImportDeprecation: true` makes it an error, which
  is how the theme gate proves sources are ready for Dart Sass 3.0 (ADR-013, The hard cut). New SASS here uses `@use`.
- **`tl:scope` is an optional processor registered by `CssDialect`, not part of core.** It wraps a fragment's `<style>`
  in `@scope (.tl-scope-{fragment})` and expects a single-root fragment (ADR-006, `tl:scope` integration contract).
- SASS fixtures for tests live in `test_fixtures/`.
