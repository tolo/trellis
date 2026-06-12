# ADR-009: Package Versioning Strategy — Lockstep

## Status
Accepted (2026-06-12)

## Context

ADR-004 established a monorepo of independently *publishable* packages, and ADR-007 chose Dart workspaces + Melos to manage it. Neither ADR fixed a *versioning policy* — whether each package carries its own version line or whether they move together. By default the packages drifted apart: `trellis` 0.8.0, `trellis_site` 0.2.0, `trellis_cli` 0.3.0, and the remaining five at 0.1.0.

Two facts make this drift costly:

1. **Tight coupling.** Every satellite (`trellis_shelf`, `trellis_dev`, `trellis_css`, `trellis_site`, `trellis_cli`, `trellis_dart_frog`, `trellis_relic`) depends on `trellis` core. They do not evolve on independent timelines — they move whenever core moves.
2. **Pre-1.0 caret semantics.** In pub, `^0.8.0` desugars to `>=0.8.0 <0.9.0`: below 1.0 the *minor* slot is treated as breaking. Under independent versioning, every `0.8 → 0.9` bump of core forces a constraint bump *and* republish of all dependents, plus a compatibility matrix users must reason about.

The project is solo-maintained and pre-first-multi-package-release, so the bookkeeping of independent versioning is pure overhead with no second maintainer to benefit.

## Decision Drivers

- Minimize release coordination cost for a single maintainer
- Avoid the pre-1.0 caret-republish cascade across tightly-coupled packages
- Give users a single, legible "what version of the SDK am I on?" answer
- Keep packages independently *publishable* (do not regress ADR-004)

## Options

### 1. Independent versioning (status quo)
Each package versions on its own cadence.

- (+) Precise — only the changed package bumps
- (+) Idiomatic for loosely-coupled package families
- (−) Pre-1.0 caret churn: every core minor forces dependent constraint bumps + republish
- (−) Compatibility matrix burden with no payoff given tight coupling
- (−) Drift already happened (five packages stuck at 0.1.0 behind core 0.8.0)

### 2. Lockstep / fixed versioning (Recommended)
All publishable packages share one version and bump together.

- (+) Compatibility matrix collapses to a single number — "Trellis SDK 0.8" means every package is 0.8
- (+) Sidesteps the caret cascade: everything is published at the same version simultaneously, and Melos rewrites every dependent constraint in one pass
- (+) Clean product/marketing story for an SDK
- (+) Trivial mental model for a solo maintainer
- (−) Unchanged packages receive "empty" version bumps and republishes (cheap; pub.dev tolerates it, and publishing of byte-identical packages can be skipped)

### 3. Hybrid / grouped
Core + tightly-coupled satellites lockstep; externally-paced integrations (`trellis_dart_frog`, `trellis_relic`) independent.

- (+) Avoids empty bumps for the niche integrations that track external (Dart Frog / Relic) release cadences
- (−) Reintroduces a (smaller) compatibility matrix and per-group bookkeeping
- (−) Premature: no package has shipped even once; not worth the complexity yet

## Decision

**Option 2: lockstep versioning through 1.0.** All publishable packages share a single version. The first lockstep release aligns everything to **0.8.0** (core's current version — formalizing where core already is rather than inventing a new milestone).

Packages remain independently *publishable* (ADR-004 stands); only their *version numbers* are coupled.

### Mechanism

Melos 7 has **no native lockstep mode** — it versions independently even with Conventional Commits. Lockstep is therefore enforced by policy + tooling:

- **`tool/version_lockstep.sh <version>`** drives a single `melos version` pass with an explicit `--manual-version <pkg>:<version>` for every publishable package. Melos rewrites inter-package constraints (`trellis: ^x.y.z` etc.) in the same run.
- The `melos.command.version` block in root `pubspec.yaml` pins releases to `main`, generates a workspace-level CHANGELOG, and links commits.

### Git tagging

Releases use a **single global tag per release** (`vX.Y.Z`, e.g. `v0.8.0`), continuing the pre-monorepo convention — one SDK version means one tag. Do **not** use Melos's default *per-package* tag format (`trellis-vX.Y.Z`, `trellis_shelf-vX.Y.Z`, …): under lockstep every package shares the version, so per-package tags are pure noise. When `melos version` drives tagging, set its tag format accordingly or pass `--no-git-tag-version` and tag manually (`git tag vX.Y.Z && git push origin vX.Y.Z`). A tag points at the commit whose published source matches that version (i.e. the actual release HEAD, not necessarily the version-bump commit).

### Re-evaluation trigger

Revisit at **core 1.0.0**. After 1.0, `^1.x` provides proper compatible-range caret semantics (minor bumps are non-breaking), packages will have stabilized and genuinely decoupled, and independent — or hybrid (Option 3) — versioning starts earning its keep. Lockstep is a pre-1.0 simplification, not a permanent commitment.

## Consequences

### Positive
- One number describes the whole SDK; no compatibility matrix
- No pre-1.0 caret-republish cascade — dependent constraints update atomically with the release
- Releases are one script invocation for a solo maintainer

### Negative
- Packages with no functional change still bump and republish (mitigated: cheap; skip byte-identical publishes)
- Lockstep is a manual policy, not a Melos-enforced invariant — discipline (and the release script) must be followed

### Neutral
- `tool/version_lockstep.sh` is the canonical release entry point; ad-hoc `melos version` per package is disallowed while lockstep is in force
- This ADR refines, but does not reverse, ADR-004 (independent publishability) and ADR-007 (Melos tooling)

## Related
- ADR-004: SDK Package Architecture (independently publishable packages)
- ADR-007: Monorepo Tooling — Dart Workspaces + Melos
