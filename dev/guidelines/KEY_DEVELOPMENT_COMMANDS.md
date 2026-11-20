# Key Development Commands

The tiers below run through [mise](https://mise.jdx.dev) tasks defined in `mise.toml`, the same ones `ci.yml` runs.
mise installs the pinned Dart 3.13.0 and Node 22 on first use. Prerequisite: `brew install mise`, then `mise trust` once
per clone or worktree. `mise tasks` lists every task.

## Build

```bash
# Activate melos 7.4.0 and install / sync dependencies
mise run setup
```

## Code Quality

> **Line width: 120 chars** — enforced in analysis_options.yaml.

```bash
# Format every package and the root tool/ and test/ in place
mise run fmt

# Theme gallery check, analyze and format checks (writes nothing)
mise run lint
```

## Testing

Run these tiers from the repository root. The fast tier matches CI's checks; full also runs package E2E tests.
Both exclude `visual` and `ui-gate`, the local release gates. `release-gate` includes those on the maintainer's
baseline-authoring host. Harness fixture tests remain untagged and run in fast/full. For Firefox checks, put
geckodriver 0.37.1 on `PATH` or set `GECKODRIVER` to the binary's absolute path; `FIREFOX_PATH` overrides Firefox
discovery. See [UI qualification gate](TESTING-STRATEGY.md#ui-qualification-gate) for browser setup.

| Tier | Command |
|---|---|
| fast | `mise check` |
| full | `mise check-full` |
| release-gate | `mise release-gate` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

```bash
# Root suite only (release/distribution contracts, tool/); package suites run through the tiers above
dart test

# Single test file: run from its package directory so the package's dart_test.yaml applies
cd packages/trellis && dart test test/engine_test.dart
```

## Workspace-wide (Melos, from the repo root)

```bash
# The commands behind `mise check`, for running one step on its own
dart run tool/generate_theme_gallery.dart --check
melos run --no-select analyze
melos run --no-select format:check
dart format --output=none --set-exit-if-changed tool test
melos exec --dir-exists=test -- dart test --exclude-tags=e2e --exclude-tags=ui-gate
dart test --exclude-tags=visual --exclude-tags=ui-gate          # root suite without local release gates
```

## Trellis UI sync

Follow [`trellis-ui-sync`](../../.claude/skills/trellis-ui-sync/SKILL.md) from the repository root.
`dart run packages/trellis_ui/tool/port.dart sync "$tag"` builds the new pin. Validate the completed report with
`dart run packages/trellis_ui/tool/port.dart sync --check-report "$report"`. The checker uses the generated
`packages/trellis_ui/tool/sync-inventory.json` for the active pin.

With both browsers and the recorded host OS, run the same gate at release prep through these tests.

- From `packages/trellis_ui/`, `dart test test/qualification_gate_test.dart` sweeps the active gallery subjects.
- From `packages/trellis_cli/`, `dart test test/ui_surfaces_gate_test.dart` sweeps the admin example and both UI
  scaffold routes for Shelf, Relic and Dart Frog.

## Release

See [RELEASE-RUNBOOK.md](RELEASE-RUNBOOK.md). Entry point: `mise release X.Y.Z` (`tool/release.sh`) on `main` (`--dry-run` to rehearse);
`tool/verify_release.sh X.Y.Z` afterwards. Never run the version bump on a feature branch.
