# trellis_cli

The `trellis` command: project scaffolding (`create`: htmx, Dart Frog, Relic, blog and theme templates), static site
build (`build`), site preview with rebuild and browser reload (`dev`), static output server (`serve`), and theme
management (`theme add|list|info|update|remove`). See the
[README](README.md).

## Key Development Commands

Run from `packages/trellis_cli/`. `dart_test.yaml` declares the `e2e` tag, which generates and boots real apps.

| Task | Command |
|---|---|
| analyze | `dart analyze --fatal-infos` |
| format check | `dart format --output none --set-exit-if-changed .` |
| package suite in branch CI | `dart test --exclude-tags=e2e --exclude-tags=ui-gate` |
| package suite in the full tier | `dart test --exclude-tags=ui-gate` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

## Conventions

- **Scaffold output is Dart source, not asset files.** Each generated file is a string template under
  `lib/src/templates/` (with `blog/`, `dart_frog/`, `relic/` and `theme/` subfolders), written by a `*ProjectGenerator`.
  Change a scaffold by editing its template and the matching `test/*_project_generator_test.dart`.
- **The theme scaffold follows the theme contract.** A change to theme params or SASS (ADR-013, standard params) needs
  a matching edit in `templates/theme/`. `theme_scaffold_sass_test.dart` compiles the scaffold with `@import` fatal and
  per-mode colour overrides, since `trellis_site` cannot depend on this package (LEARNINGS, Release & Publishing,
  propagation sweep).
- **`cliVersion` in `lib/src/version.dart` must equal the pubspec version.** `tool/version_lockstep.sh` syncs it, and
  `test/version_test.dart` fails on drift. Every `trellis*` constraint a scaffold writes must admit it
  (`test/scaffold_pubspec_constraints_test.dart`).
- **Scaffolds support HTMX 2 and 4 and self-host the pinned build by default** (`templates/htmx_asset.dart`).
  `--htmx-cdn` opts into the SRI-pinned jsDelivr URL. The layouts
  register both `htmx:configRequest` and `htmx:config:request` for the CSRF header.
- **E2E tests boot servers with `bootServer` in `test/_e2e_server.dart`**: a port allocated per run, a numeric loopback
  address, and the child's output kept for failure messages. Never use fixed ports or kill by port (LEARNINGS,
  Testing).
