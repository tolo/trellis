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

For each plan story, run the fast static checks plus the tests named in its FIS. Select the test files, named cases
or browser manifests that exercise the change and its affected callers. A story that changes browser behavior still
proves it in the browser. Reuse the result when a task, story review or batch asks for the same check on unchanged inputs.

Branch CI runs the workspace tests. The full tier adds package E2E tests. Both exclude `visual` and `ui-gate`.
The local release gate covers those on the maintainer's baseline-authoring host. For Firefox checks, put
geckodriver 0.37.1 on `PATH` or set `GECKODRIVER` to the binary's absolute path; `FIREFOX_PATH` overrides Firefox
discovery. See [UI qualification gate](TESTING-STRATEGY.md#ui-qualification-gate) for browser setup.

| Tier | Command |
|---|---|
| fast | `mise run lint` |
| branch CI | `mise check` |
| full | `mise check-full` |
| release-gate | `CI=true mise run release-gate` |
| run one test | `dart test "{file}" --plain-name "{test}"` |

Run mise commands at the repository root and test commands in the package that owns the test. In a multi-story plan,
assign the workspace suites, complete component catalogue and full app-surface sweep to final integration. If an
existing FIS names a whole sweep for one subject, run the subject now and record the sweep against the integrated
revision. A deferred sweep counts as pending until its command passes.

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

For one changed gallery subject, supply its manifest name. For example, this compares Tooltip with its baseline
in Chrome and Firefox and writes the result to scratch:

```bash
CI=true dart run tool/ui_gate.dart --serve 'dart run packages/trellis_ui/tool/gallery.dart --port 0' \
  --records .agent_temp/ui-gate/records tooltip
```

For an app route, pass its manifest path and the running app's `--base` URL with its app baseline directory.
On the integrated release tree, `CI=true mise run release-gate` includes both sweeps:

- From `packages/trellis_ui/`, `dart test test/qualification_gate_test.dart` sweeps the active gallery subjects.
- From `packages/trellis_cli/`, `dart test test/ui_surfaces_gate_test.dart` sweeps the admin example and both UI
  scaffold routes for Shelf, Relic and Dart Frog.

## Release

See [RELEASE-RUNBOOK.md](RELEASE-RUNBOOK.md). Entry point: `mise release X.Y.Z` (`tool/release.sh`) on `main` (`--dry-run` to rehearse);
`tool/verify_release.sh X.Y.Z` afterwards. Never run the version bump on a feature branch.
