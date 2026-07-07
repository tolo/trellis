# ADR-007: Monorepo Tooling — Dart Workspaces + Melos

## Status
Accepted (implemented — Dart workspaces + Melos)

## Context
ADR-004 established that the Trellis SDK will use a monorepo with independently publishable packages. This ADR decides the specific tooling for managing the monorepo: dependency resolution, versioning, changelog generation, publishing, and CI scripting.

Research: [Research appendix](research/ADR-007-research.md)

## Decision Drivers

- Multi-package publishing must handle topological dependency ordering
- Versioning should be automated to reduce manual coordination burden
- CI should be able to run tests only on changed packages
- The tooling must support pure Dart packages (no Flutter requirement)

## Options

### 1. Dart native workspaces only
Use Dart's built-in workspace feature (`resolution: workspace`) without additional tooling.

- (+) Official, built-in, zero extra tool installation
- (+) Shared `pubspec.lock`, automatic local package linking, better IDE analysis
- (-) No automated versioning or changelog generation
- (-) No publishing orchestration — must manually publish in correct dependency order
- (-) No cross-package script execution or filtering

### 2. Dart native workspaces + Melos v7 (Recommended)
Use Dart workspaces as the foundation, Melos on top for automation.

- (+) Melos v7 requires and builds on native workspaces — complementary, not competing
- (+) `melos version` — automated versioning via Conventional Commits
- (+) `melos publish` — topological publish ordering, dry-run default
- (+) `melos exec --since` — run commands only on changed packages (CI optimization)
- (+) Cross-package scripts with concurrency, fail-fast, filtering
- (+) CHANGELOG generation per package and workspace-level
- (+) Used by FlutterFire, Riverpod, Flame, 40+ major projects — proven at scale
- (-) Extra tool installation (`dart pub global activate melos`)
- (-) Invertase-dependent maintenance (mitigated: 143 contributors, Apache-2.0)

### 3. Dart native workspaces + mono_repo
Use Google's `mono_repo` package for CI configuration generation.

- (+) Google-maintained
- (-) Last published 12 months ago — less active
- (-) Narrower scope — CI generation only, no versioning/changelog/publishing
- (-) Fewer users and less community support than Melos

### 4. Manual scripts
Shell scripts for versioning, changelog, and publishing.

- (+) Full control, no dependencies
- (-) Maintenance burden scales with package count
- (-) Reinventing what Melos already provides
- (-) Error-prone manual publish ordering

## Decision

**Option 2: Dart native workspaces + Melos v7.**

Melos v7 is designed to layer on top of Dart workspaces. They handle different concerns:
- **Dart workspaces**: dependency resolution, shared lockfile, local package linking
- **Melos**: versioning, changelogs, publishing, scripts, filtering

### Configuration

Root `pubspec.yaml`:
```yaml
name: trellis_workspace
publish_to: none
environment:
  sdk: ^3.10.0
workspace:
  - packages/trellis
  - packages/trellis_shelf
  - packages/trellis_dev
  - packages/trellis_cli
dev_dependencies:
  melos: ^7.4.0

melos:
  repository: https://github.com/tolo/trellis
  command:
    version:
      workspaceChangelog: false # root CHANGELOG.md was removed at SDK Phase 1; per-package changelogs are hand-written (ADR-009)
      linkToCommits: true
  scripts:
    analyze:
      run: dart analyze .
      exec:
        concurrency: 1
    test:
      run: dart test
      exec:
        failFast: true
        orderDependents: true
    format:check:
      run: dart format --output none --set-exit-if-changed .
      exec: {}
```

Each package's `pubspec.yaml` includes `resolution: workspace`.

### Conventions
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `BREAKING CHANGE`)
- `melos version` determines semver bumps automatically
- `melos publish` is dry-run by default — explicit `--no-dry-run` to actually publish

### Versioning fallback
When commit messages do not follow Conventional Commits (e.g., during initial development or for imported history), use `melos version --manual-version` to set versions explicitly. Automated versioning via CC is the steady-state workflow; manual override is the escape hatch.

## Consequences

### Positive
- Automated versioning eliminates manual coordination across 5-7 packages
- Topological publish ordering prevents "dependency not found" errors on pub.dev
- `--since` filtering keeps CI fast as the package count grows
- Proven at scale by FlutterFire and Riverpod (closest structural analogs)
- Conventional Commits provide clear, machine-readable git history

### Negative
- Melos must be available on CI — either via `dart pub global activate melos` or pinned in root `dev_dependencies` (as shown in the config above)
- Invertase maintenance dependency (low risk given 143 contributors and Apache-2.0 license)

### Neutral
- Melos v7 config lives in root `pubspec.yaml` (cleaner than the old separate `melos.yaml`)
- `melos bootstrap` is mostly redundant with native workspaces — retained only for lifecycle hooks
- If Melos were abandoned, the core workflow (workspaces) still functions; versioning/publishing reverts to manual
