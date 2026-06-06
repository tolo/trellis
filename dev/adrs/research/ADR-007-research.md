# ADR-007 Research Appendix: Monorepo Tooling

Curated research supporting [ADR-007](../ADR-007-monorepo-tooling.md).

This appendix condenses the monorepo-tooling research originally captured in the SDK expansion research (Section 6, "Melos for Monorepo Management," plus the related package-architecture trade-off). It covers the choice of monorepo structure, the tooling options for versioning, publishing, changelog generation, and CI, and the rationale behind selecting Dart native workspaces with Melos v7.

## 1. Monorepo Structure Rationale

ADR-007 assumes a monorepo of independently publishable packages (decided in ADR-004). The supporting trade-off analysis weighed three package-architecture options:

| Option | Pros | Cons | Risk |
|---|---|---|---|
| A: Single package | Simplest onboarding; coordinated versioning | Dependency bloat; violates "small footprint"; pub.dev scoring penalty | High — loses identity |
| B: Multi-package ecosystem (separate repos) | Maximum flexibility; independent versioning | Version matrix hell; cross-package coordination | Medium — fragmentation |
| C: Monorepo with independent packages (chosen) | Atomic cross-package changes; shared CI; pub.dev independence | Repository complexity; contributor learning curve | Low-medium |

The monorepo (Option C) was selected for atomic cross-package changes, shared CI, and per-package independence on pub.dev. Reversibility is high — packages can be extracted into separate repos later if needed. This structural choice is what creates the need for the monorepo tooling that ADR-007 decides on.

## 2. Tooling Layers — Dart Workspaces and Melos

Dart native workspaces and Melos address different concerns and are designed to work together rather than compete:

- **Dart workspaces** (`resolution: workspace`): shared `pubspec.lock`, local package linking, dependency resolution.
- **Melos adds**: versioning (via Conventional Commits), changelog generation, publishing orchestration, cross-package scripts, and change-based filtering.

### Melos v7 Architecture Change

Melos v7 dropped its own bootstrapping and now **requires** Dart native workspaces. Configuration moved from a separate `melos.yaml` to a `melos:` section in the root `pubspec.yaml`. This makes the two tools complementary layers rather than alternatives — Melos sits on top of the native workspace foundation.

### Melos at a Glance (v7.4.0, January 2026)

- 898 likes, ~823K weekly downloads, 160/160 pub points
- 1,439 GitHub stars, 143 contributors
- Maintained by Invertase.io under Apache-2.0
- Used by FlutterFire, Flame Engine, Riverpod, Supabase Flutter, GetStream, and 40+ projects — proven at scale

## 3. Key Melos Capabilities for the SDK

| Feature | Command | Value |
|---|---|---|
| Versioning | `melos version` | Reads conventional commits, determines semver bump per package, updates `pubspec.yaml`, generates CHANGELOG, creates git tags |
| Publishing | `melos publish` | Topological ordering (leaves first), dry-run by default, lifecycle hooks |
| Cross-package execution | `melos exec` | Run any command across all/filtered packages with concurrency and fail-fast |
| Named scripts | `melos run analyze` | Composable scripts with steps, hooks, and filters |
| Change-based filtering | `--since="origin/main"` | Run tests only on changed packages — essential for keeping CI fast |
| Dependent version bumping | Automatic | When the `trellis` core bumps, dependents (e.g. `trellis_shelf`) automatically get a constraint update |
| IDE integration | Auto-generated | IntelliJ / VS Code run configurations |

These capabilities map directly to the ADR's decision drivers: topological publish ordering handles dependency ordering, `melos version` automates versioning, and `--since` filtering keeps CI scoped to changed packages.

## 4. Alternatives Considered

Beyond "workspaces + Melos," two other approaches were evaluated against the same drivers:

- **mono_repo** (Google-maintained): narrower scope (CI configuration generation only), with no versioning, changelog, or publishing orchestration. Less active and a smaller user base than Melos.
- **Manual shell scripts**: full control and no dependencies, but the maintenance burden scales with package count, publish ordering is error-prone, and it reinvents what Melos already provides.

Dart workspaces alone (no automation layer) is official and zero-install but provides no automated versioning, changelog generation, or publishing orchestration — which is why Melos is layered on top.

## 5. Gotchas and Trade-offs

1. `dart install melos` does not work (upstream bug #984) — install via `dart pub global activate melos`, or pin Melos in the root `dev_dependencies`.
2. Reported Windows test failures (bug #757) — relevant only if CI runs on Windows.
3. A single shared `pubspec.lock` forces reconciling version conflicts across all packages.
4. Glob support in workspaces requires Dart 3.7+ (the SDK targets 3.10+, so this is not a constraint).
5. `melos bootstrap` is largely redundant with pub workspaces — its remaining value is lifecycle hooks.

A key resilience property: if Melos were ever abandoned, the core workflow (Dart workspaces) still functions; only versioning and publishing would revert to manual processes.

## 6. Reference Configuration

```yaml
# root pubspec.yaml
name: trellis_workspace
publish_to: none
environment:
  sdk: ^3.10.0
workspace:
  - packages/trellis
  - packages/trellis_shelf
  - packages/trellis_dev
  - packages/trellis_cli

melos:
  repository: https://github.com/tolo/trellis
  command:
    version:
      workspaceChangelog: true
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

Each package's `pubspec.yaml` includes `resolution: workspace` to opt into the shared workspace.
