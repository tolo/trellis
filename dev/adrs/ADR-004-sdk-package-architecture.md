# ADR-004: SDK Package Architecture

## Status
Accepted (implemented across SDK Phases 1–4)

Amendment, 0.11: the top-level `starters/` in the layout sketch below was never realized. Scaffold templates ship inside the CLI package at `packages/trellis_cli/lib/src/templates/`, and the empty directory was removed. The sketch is left as recorded; the decision it carries is unaffected.

## Context
Trellis is expanding from a single-package template engine (v0.6) into a multi-package SDK. The SDK will include server integration (`trellis_shelf`), developer tools (`trellis_dev`), CSS processing (`trellis_css`), static site generation (`trellis_site`), and a CLI (`trellis_cli`). Testing utilities are built into core `trellis` via `testing.dart`. The architecture decision affects publishing, versioning, dependency management, developer onboarding, and long-term maintenance.

Research: [Research appendix](research/ADR-004-research.md)

## Decision Drivers

- Trellis core must retain its single-dependency (`package:html`) footprint
- Users should opt in to only the packages they need
- A small team (potentially solo) must be able to maintain the ecosystem
- Each package should score well independently on pub.dev
- Cross-package changes (e.g., a core API change affecting `trellis_shelf`) must be atomic

## Options

### 1. Single large package
All SDK functionality in one `trellis` package.

- (+) Simplest onboarding — `dart pub add trellis` gets everything
- (+) One version number, one CHANGELOG
- (-) Dependency bloat — users who want only templating pull in Shelf, csslib, sass, etc.
- (-) Violates "small runtime footprint" principle — foundational to project identity
- (-) pub.dev scoring penalizes large packages with many dependencies
- (-) Breaking change in any subsystem forces major version bump on everything

### 2. Multi-package ecosystem, separate repos
Independent packages in separate repositories, each with its own pubspec and version.

- (+) Maximum flexibility, independent versioning
- (-) Version matrix coordination across repos
- (-) Cross-package breaking changes require synchronized releases across repos
- (-) More CI/CD infrastructure to maintain
- (-) No atomic commits across packages

### 3. Monorepo with independently publishable packages (Recommended)
All packages in one repository using Dart workspaces + Melos. Each package has its own pubspec and is published independently to pub.dev.

- (+) Atomic commits across packages — one PR for a cross-cutting change
- (+) Shared CI — one test matrix covers all packages and integration
- (+) Each package published independently with its own pub.dev score
- (+) Dart workspace support (3.7+) and Melos v7 make this a first-class pattern
- (+) Easy to extract or merge packages as boundaries become clearer
- (-) More complex repository setup (workspace config, publishing scripts)
- (-) Contributors must understand package boundary conventions

## Decision

**Option 3: Monorepo with independently publishable packages.**

The existing `trellis-public` repo becomes the monorepo root. Current `lib/`, `test/`, `pubspec.yaml` move into `packages/trellis/`. New packages are added alongside. Dart native workspaces provide shared dependency resolution; Melos v7 adds versioning, changelog generation, publishing orchestration, and cross-package scripts.

```
trellis/                              # monorepo root
├── pubspec.yaml                      # workspace root + Melos config
├── packages/
│   ├── trellis/                      # core template engine
│   ├── trellis_shelf/                # Shelf integration
│   ├── trellis_dev/                  # developer tools
│   ├── trellis_css/                  # CSS processing
│   ├── trellis_site/                 # static site generation
│   ├── trellis_cli/                  # CLI tool
│   # trellis_test merged into core trellis (testing.dart)
├── starters/
├── examples/
└── docs/
```

## Package Dependency Rules

To prevent boundary drift and cyclic dependencies:

1. **`trellis` (core) depends on no SDK package** — only `package:html`
2. **Integration packages** (`trellis_shelf`, `trellis_dev`) may depend on `trellis`, never the reverse
3. **Tooling packages** (`trellis_css`, `trellis_cli`) may depend on runtime packages only for orchestration, not for embedding framework logic
4. **No cyclic package dependencies** — the dependency graph is a DAG
5. **Optional features stay optional** — CSS, SSG, and dev tools never become transitive dependencies of core

```
trellis_cli ──► trellis_shelf ──► trellis ──► package:html
                     │
                     └──► shelf
trellis_dev ──► trellis
     │
     └──► shelf
trellis_css ──► csslib (no dependency on trellis core)
trellis_site ──► trellis, markdown, yaml
```

## Consequences

### Positive
- Core `trellis` stays minimal — single dependency, unaffected by SDK expansion
- Users `dart pub add trellis_shelf` — same pub.dev DX as any other package
- Atomic cross-package changes make it practical for a small team
- Melos automates versioning, changelogs, and topological publish ordering
- `--since` filtering enables efficient CI (test only changed packages)

### Negative
- Repository setup is more complex than a single package
- Melos adds a dev-time dependency (must be globally activated or pinned in root pubspec)
- Contributors must understand workspace conventions and dependency rules
- Single `pubspec.lock` forces reconciling version conflicts across packages

### Neutral
- Packages can be extracted to separate repos later if the team grows (high reversibility)
- This is the standard pattern for multi-package Dart projects (FlutterFire, Riverpod, Flame)
