# ADR-004 Research Appendix: SDK Package Architecture

Curated research supporting [ADR-004](../ADR-004-sdk-package-architecture.md).

This appendix condenses the package-architecture portions of the SDK expansion research (March 2026). It covers the decision to evolve Trellis from a single-package template engine into a multi-package SDK, and the choice of repository structure. CSS strategy, server-framework selection, and Melos tooling specifics were also researched but belong to their own ADRs and are not reproduced here.

## Decision: Package Architecture

The core question was how to structure the SDK as it grows beyond the single `trellis` template engine into server integration, developer tools, CSS processing, static site generation, and a CLI. Three options were weighed:

| Option | Pros | Cons | Risk |
|---|---|---|---|
| **A: Single package** | Simplest onboarding; coordinated versioning | Dependency bloat; violates "small footprint"; pub.dev scoring penalty | High — loses identity |
| **B: Multi-package ecosystem (separate repos)** | Maximum flexibility; independent versioning | Version matrix coordination; cross-package release coordination | Medium — fragmentation |
| **C: Monorepo with independent packages** (selected) | Atomic cross-package changes; shared CI; pub.dev independence | Repository complexity; contributor learning curve | Low-medium |

**Selected: Option C — monorepo with independently publishable packages.**

**Reversibility: High.** Packages can be extracted to separate repositories later if the team grows, so the decision is low-commitment.

### Why not a single package (Option A)

A single package is the simplest to onboard, but it forces every consumer who only wants templating to pull in Shelf, csslib, sass, and other heavy dependencies. This directly violates Trellis's foundational "small runtime footprint" principle — a core part of project identity. Large dependency-heavy packages are also penalized by pub.dev scoring, and a breaking change in any subsystem would force a major version bump across everything. The risk was assessed as high because the project loses its identity.

### Why not separate repos (Option B)

Independent repositories give maximum versioning flexibility, but introduce version-matrix coordination across repos and require synchronized releases whenever a cross-package breaking change lands. There are no atomic commits spanning packages, and more CI/CD infrastructure must be maintained. The risk here is fragmentation of the ecosystem.

### Why the monorepo (Option C)

A monorepo with independently publishable packages keeps each package separately versioned and published (so each earns its own pub.dev score) while allowing atomic, single-PR cross-cutting changes and a single shared CI test matrix that covers both packages and their integration. This combination is what makes the ecosystem practical for a small — potentially solo — team. Package boundaries can be redrawn (extracted or merged) as they become clearer, preserving the high reversibility noted above.

## Two Complementary Layers

The research distinguishes two layers that together enable the monorepo pattern. They are complementary, not alternatives:

- **Dart native workspaces** — provide shared dependency resolution, a single `pubspec.lock`, and local package linking across the workspace. Available in Dart 3.7+ (Trellis targets 3.10+).
- **A monorepo management tool layer** on top — adds versioning, changelog generation, publishing orchestration (topological, leaves-first ordering), and cross-package scripts/filtering. The specifics of this tooling are covered in a separate ADR.

The single shared `pubspec.lock` that comes with workspaces is the main trade-off: version conflicts must be reconciled across all packages rather than isolated per package.

## Ecosystem Precedent

The monorepo-with-independent-packages pattern is the standard for multi-package Dart projects. Established examples include FlutterFire, the Flame engine, Riverpod, and Supabase Flutter. Choosing it aligns Trellis with idiomatic Dart ecosystem conventions rather than inventing a bespoke structure.

## CUPID Assessment (Architecture-Relevant Properties)

The proposed architecture was evaluated against the CUPID properties. The properties most directly tied to the package-decomposition decision:

| Property | Score | Notes |
|---|---|---|
| Composable | 5/5 | Independent packages, adapter pattern, dialect system |
| Unix Philosophy | 5/5 | Each package does one thing |
| Idiomatic | 5/5 | Dart workspaces, pub.dev publishing conventions |
| Domain-Aligned | 4/5 | Package boundaries match web concerns; "Thymeleaf-inspired" framing may confuse some Dart developers |

(The full CUPID assessment also scored Predictability, which relates to runtime template/HTMX behavior rather than package architecture.)

## Decomposition Rationale Summary

The decision drivers that shaped the package boundaries:

- Trellis core must retain its single-dependency (`package:html`) footprint and stay unaffected by SDK expansion.
- Users should opt in to only the packages they need, with the same pub.dev DX as any other package.
- A small (potentially solo) team must be able to maintain the whole ecosystem — atomic cross-package changes are what make this feasible.
- Each package should score well independently on pub.dev.
- Cross-package changes (for example, a core API change affecting a server integration package) must be possible atomically in a single PR.

These drivers point consistently toward the monorepo of independently publishable packages: optional features (CSS, SSG, dev tools) never become transitive dependencies of core, while the shared repository keeps cross-cutting evolution cheap.
