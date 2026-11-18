# Key Development Commands

## Build

```bash
# Install / sync dependencies
dart pub get
```

## Code Quality

> **Line width: 120 chars** — enforced in analysis_options.yaml.

```bash
# Format
dart format lib test

# Analyze
dart analyze
```

## Testing

Run these tiers from the repository root. The fast tier matches CI's checks; full also runs package E2E tests.
Both exclude `visual` and `ui-gate`, the local release gates. `release-gate` includes those on the maintainer's
baseline-authoring host. Harness fixture tests remain untagged and run in fast/full. For Firefox checks, put
geckodriver 0.37.1 on `PATH` or set `GECKODRIVER` to the binary's absolute path; `FIREFOX_PATH` overrides Firefox
discovery. See [UI qualification gate](TESTING-STRATEGY.md#ui-qualification-gate) for browser setup.

| Tier | Command |
|---|---|
| fast | `dart run tool/generate_theme_gallery.dart --check && melos run --no-select analyze && melos run --no-select format:check && melos exec --dir-exists=test -- dart test --exclude-tags=e2e --exclude-tags=ui-gate && dart test --exclude-tags=visual --exclude-tags=ui-gate && dart format --output=none --set-exit-if-changed tool test` |
| full | `dart run tool/generate_theme_gallery.dart --check && melos run --no-select analyze && melos run --no-select format:check && melos exec --dir-exists=test -- dart test --exclude-tags=ui-gate && dart test --exclude-tags=visual --exclude-tags=ui-gate && dart format --output=none --set-exit-if-changed tool test` |
| release-gate | `melos exec --dir-exists=test -- dart test --exclude-tags=e2e && dart test` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

```bash
# Root suite only (release/distribution contracts, tool/); package suites run through the tiers above
dart test

# Single test file: run from its package directory so the package's dart_test.yaml applies
cd packages/trellis && dart test test/engine_test.dart
```

## Workspace-wide (Melos, from the repo root)

```bash
# CI's `check` tier — run all five before pushing
melos run --no-select analyze
melos run --no-select format:check
melos exec --dir-exists=test -- dart test --exclude-tags=e2e --exclude-tags=ui-gate
dart test --exclude-tags=visual --exclude-tags=ui-gate          # root suite without local release gates
dart format --output=none --set-exit-if-changed tool test
```

## Trellis UI sync

Follow [`trellis-ui-sync`](../../.claude/skills/trellis-ui-sync/SKILL.md) from the repository root.
`dart run packages/trellis_ui/tool/port.dart sync "$tag"` builds the new pin. Validate the completed report with
`dart run packages/trellis_ui/tool/port.dart sync --check-report "$report"`.

With both browsers and the recorded host OS, run the same gate at release prep through these tests.

- From `packages/trellis_ui/`, `dart test test/qualification_gate_test.dart` sweeps the 25 gallery subjects.
- From `packages/trellis_cli/`, `dart test test/ui_surfaces_gate_test.dart` sweeps the admin example and both UI
  scaffold routes for Shelf, Relic and Dart Frog.

## Release

See [RELEASE-RUNBOOK.md](RELEASE-RUNBOOK.md). Entry point: `tool/release.sh X.Y.Z` on `main` (`--dry-run` to rehearse);
`tool/verify_release.sh X.Y.Z` afterwards. Never run the version bump on a feature branch.
