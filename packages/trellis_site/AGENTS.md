# trellis_site

Static site generator: Markdown content, Trellis templates, front matter, taxonomies, feeds, sitemap, search index,
and the theme system (manifest, params, layout cascade, SASS bridge). See the [README](README.md).

## Key Development Commands

Run from `packages/trellis_site/`.

| Task | Command |
|---|---|
| analyze | `dart analyze --fatal-infos` |
| format check | `dart format --output none --set-exit-if-changed .` |
| test (fast and full are the same here; no `e2e` tests) | `dart test` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

## Conventions

- **Themes live in the repo-root `themes/`, not in this package**, but tests here discover and compile all of them
  (`test/theme_sass_use_gate_test.dart`). A theme change is verified with `dart test` here as well as in the root.
  Theme layout and params: ADR-008, `docs/guides/theme-authoring.md`, `docs/reference/standard-params.md`.
- **Theme SASS reaches the theme through a generated `@use … with()` wrapper** built by one function,
  `ThemeBuildConfig.bridgeWrapperSource`, which `trellis build` calls and tests compile. Do not duplicate its text.
  Only `!default` `$trellis-*` variables in `sass/_variables.scss` are configurable, entries start with
  `@forward 'variables'`, and every colour param has a `<name>_dark` twin (ADR-013).
- **Sass load strings are URLs**: embed a path as `p.toUri(path).path`, not a native path or a `file:` URL (LEARNINGS,
  Themes & SSG).
- **Syntax highlighting runs at build time only** (`code_highlighter.dart`, ADR-010). Nothing it emits needs a runtime
  highlighter in the browser.
- **This package cannot depend on `trellis_cli`.** Scaffold checks live in the CLI package.
- **`lib/src/version.dart` is rewritten by `tool/version_lockstep.sh`.** Do not edit the version by hand (ADR-009).
- **Goldens and fixtures must not depend on the machine.** Pin file mtimes with `test/fixture_mtimes.dart`, give
  fixture dates an explicit zone, and sweep files with `sweepFiles` in `test/theme_sass_sources.dart` (LEARNINGS,
  Testing).
