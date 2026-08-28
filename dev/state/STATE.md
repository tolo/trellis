# Project State — Trellis SDK

Last Updated: 2026-08-27

> Cross-session state tracking. Updated at phase boundaries and when significant context changes.

## Current Phase

**0.11 remediated through three release-gate reviews; gate green; awaiting the owner's release decision.** Lattice,
the redesigned site and six-theme generated gallery, Folio, Meadow, authoring guidance, architecture, and unreleased
lockstep changelog collateral are on `feat/0.11`. Owner UI inspection (2026-08-24/26) fixed rendering defects the story
reviews missed; TD-014 was found unimplemented and landed.

Three release-gate reviews each returned NO-GO, and each found a defect class one step outside the previous one:
defects in themes (20 HIGH) → classes unpropagated across themes (7) → everything adjacent to themes (1 CRITICAL +
7 HIGH: the gallery, the docs site, the CLI install journey, the package changelogs, the SDK's own CSP). Severity fell
across the three. The third round was remediated on 2026-08-28 (`5b0f46b`..`1016455`) under an explicit decision that
there would be **no fourth open-ended review** — the widening-scope process has no fixed point for a pre-1.0 minor, so
the standing verdict is a judgment about acceptable known debt, recorded as TD-038…TD-047. Full record in
`../trellis-private/docs/specs/0.11/prd.md` § Outcome.

Two of the third review's findings were **wrong**, and both failure shapes are worth carrying: a finding can be
internally rigorous and still not bear on its target (a correctly measured render change, of an element below the
captured screenshot frame), and naming one instance of a defect is not the same as bounding it (two findings turned
out to have siblings the review had not named).

## Recent Completions

| Phase | Completed | Key Deliverables |
|-------|-----------|------------------|
| 0.11.0 (implementation) | 2026-08-19 | Lattice docs theme and Lattice-powered site; deterministic six-theme gallery; Folio reference theme; Meadow product-landing theme; theme-data authoring guidance; architecture and unreleased 0.11.0 changelog collateral. |
| 0.11.0 (UI remediation) | 2026-08-26 | Owner-found rendering defects in Folio and Meadow; Folio design-gap closure against the mockup; compact branding assets; font payloads re-subset; landing showcase set to Arbor/Lattice/Folio. |
| 0.10.0 (pre-release) | 2026-07-11 | Binary distribution: **Scoop** channel + release-workflow hardening (both tap jobs skip without `TAP_TOKEN`); build-time syntax highlighting (ADR-010: `CodeHighlighter`/`package:highlight`, `.hljs-*` spans, `highlight:` config key, vendored Prism removed); `bloom` landing theme + `verdant`/`arbor` polish; theme SASS-bridge escaping hardened; **TD-009** resolved (`ProcessRunner`, no CWD mutation → parallel-safe CLI suite). |
| Docs Site | 2026-07-06 | Engine: weighted ordering + nested sections + `orderedSectionPages` seam, `${site.menu}` nav tree (section-weight ordered), `pathPrefix` (with unprefixed on-disk layout + content-link rewriting), in-section prev/next; `arbor` docs theme (build-time `.hljs-*` highlighting, WCAG-AA skins, responsive, search shell); `site/` (marketing landing + curated docs IA: getting-started, complete `tl:*` syntax reference, 8 package guides, theme-authoring); client-side search; GitHub Pages CI deploy + pure-Dart link-integrity checker. Deploy target: `tolo.github.io/trellis/` (`pathPrefix: /trellis/`). |
| SDK Phase 4 | 2026-03-20 | Theme manifest + params, ThemeAwareLoader, SASS bridge, CLI theme commands, Verdant theme |
| SDK Phase 3 | 2026-03-17 | trellis_dart_frog, trellis_relic, expression utility objects, RSS, search index |
| SDK Phase 2 | 2026-03-16 | trellis_site (SSG), trellis_css, CLI build/serve, blog starter |
| SDK Phase 1 | 2026-03-15 | Monorepo, trellis_shelf, trellis_dev, template inheritance, trellis_cli |

## Published Versions

- **Published on pub.dev: v0.8.2** (all 8 SDK packages, lockstep per ADR-009; verified against the pub.dev API 2026-07-07): `trellis`, `trellis_shelf`, `trellis_dev`, `trellis_cli`, `trellis_css`, `trellis_site`, `trellis_dart_frog`, `trellis_relic`.
- **v0.9.0 published 2026-07-07** (docs-site engine features + arbor theme + skin-forcing fix); docs site live at `www.leafnode.se/trellis/` (the account-level custom domain applies to project pages; `tolo.github.io/trellis/` 301s there).
- **v0.9.1** (2026-07-07): patch release fixing the theme SASS bridge quoting string params into invalid CSS (serif-fallback fonts, unconstrained layout on every bridge-built theme) + `version_lockstep.sh`/melos `workspaceChangelog` fix.
- **v0.10.0** (2026-07-25): build-time syntax highlighting (ADR-010), Scoop distribution channel, `bloom` theme + theme polish, TD-009.
- **v0.10.1** (2026-08-18): `FragmentHost` contract (source-break for direct `ProcessorContext` construction, deliberate), SSG prev/next perf, HTMX 2.0.10 scaffolds, push CI + release gate/tooling. Verified with `tool/verify_release.sh 0.10.1`: pub.dev ×8, Release + 11 assets, Homebrew, Scoop.
- **v0.10.2** (2026-08-18): TD-013 Linux nested-template watching + dev-watch hardening (rename/atomic-save reloads), `listTemplates()` symlink alignment, e2e numeric loopback. Verified with `tool/verify_release.sh 0.10.2`: pub.dev ×8 latest=0.10.2, Release + 11 assets, Homebrew, Scoop.
- Releases follow `dev/guidelines/RELEASE-RUNBOOK.md`: `tool/release.sh` (lockstep bump, gate, release commit, local tag), then one push; publish is OIDC tag-triggered (`publish.yml`, global `vX.Y.Z` tag per ADR-009) behind the CI release gate (`release-gate.yml`).
- The 4 `examples/*` packages + root workspace correctly carry `publish_to: none`.

## Decisions

- **2026-06-04 — Core package rename DROPPED.** `trellis` → `trellis_templates` will NOT happen (134 imports deep, name already published on pub.dev). The core package stays named `trellis`.
- **2026-06-05 — Docs split.** Contributor docs (ADRs + research appendices, architecture, guidelines, learnings, tech-debt, this state file) live in the public repo under `dev/`; user-facing docs under `docs/`. Research, diagrams, specs/plans, and the product backlog stay in the private planning repo.

## Test Health

On `feat/0.11` (2026-08-28, macOS): all eight package test suites pass (one existing Linux-only skip in `trellis`) —
`trellis` 1282, `trellis_site` 849, `trellis_cli` 251 — the repo-root suite passes **149/149** including the visual
tier, `generate_theme_gallery.dart --check` is current, `subset_fonts.py --verify` reproduces 11/11 vendored faces
byte-identically, and workspace analyze (`--fatal-infos`) and both format gates pass across all 12 packages.
**The root suite is 149 only on macOS**: CI runs `dart test --exclude-tags=visual` because the committed baselines are
macOS recordings, so the `transform`/`opacity`/`border-radius` class has no gate on CI at all (TD-035, TD-043). Root and `/trellis/` docs builds
each produce 27 pages and 39 static files with 1,279 internal references and no broken links. Dart Sass 3.0
forward-compat tech debt remains logged as TD-006 (`@import` in theme SASS + the bridge).

**Green does not mean covered — and this suite has proved it three times.** The 2026-08-27 review mutation-tested the
suite and 8 of 11 deliberate regressions passed, including truncating every vendored `woff2` to zero bytes. Those are
closed: the theme suites now assert rendered geometry, per-file `wOF2` magic bytes and byte floors, `@font-face` axis
containment, and (since 2026-08-28) that each gallery card's screenshots live under its own theme directory.

Two holes remain open and are the ones to distrust. **`subset_fonts.py --verify` re-derives its expectation from the
same constants it checks** (TD-038): narrow `ARROWS`/`MARKS`, re-run `--write`, and six codepoints vanish while
`--verify` reports `11 ok` and every suite stays green. **`site/` is outside every rendered check** (TD-039) — which is
how a WCAG 1.4.10 reflow failure reached the flagship gallery page with the whole gate green. A gate that derives its
expected value from the artifact's own recipe cannot fail when the recipe changes; it redefines the truth instead.

## Blockers

None.
