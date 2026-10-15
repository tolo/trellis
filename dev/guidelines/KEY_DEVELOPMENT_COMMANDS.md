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
Both exclude the machine-specific root visual goldens, as CI does. Run `dart test test/visual_baseline_test.dart`
separately on the baseline-authoring host when comparing those captures.

| Tier | Command |
|---|---|
| fast | `dart run tool/generate_theme_gallery.dart --check && melos run --no-select analyze && melos run --no-select format:check && melos exec --dir-exists=test -- dart test --exclude-tags=e2e && dart test --exclude-tags=visual && dart format --output=none --set-exit-if-changed tool test` |
| full | `dart run tool/generate_theme_gallery.dart --check && melos run --no-select analyze && melos run --no-select format:check && melos exec --dir-exists=test -- dart test && dart test --exclude-tags=visual && dart format --output=none --set-exit-if-changed tool test` |
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
melos exec --dir-exists=test -- dart test --exclude-tags=e2e
dart test                                                    # root suite (release/distribution contracts, tool/)
dart format --output=none --set-exit-if-changed tool test
```

## Release

See [RELEASE-RUNBOOK.md](RELEASE-RUNBOOK.md). Entry point: `tool/release.sh X.Y.Z` on `main` (`--dry-run` to rehearse);
`tool/verify_release.sh X.Y.Z` afterwards. Never run the version bump on a feature branch.
