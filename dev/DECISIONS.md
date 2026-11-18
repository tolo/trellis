# Decisions

<!-- Maintenance:
     - The andthen:architecture skill auto-registers ADRs here.
     - Status enum: Proposed | Accepted | Deprecated.
     - Superseded decisions move to the dedicated table; never delete lineage. -->

## Current ADRs

| ID | Title | Status | Scope |
|---|---|---|---|
| [ADR-001](adrs/ADR-001-expression-evaluator-strategy.md) | Expression Evaluator Strategy | Accepted | Core expression parsing |
| [ADR-002](adrs/ADR-002-browser-hot-reload-strategy.md) | Browser Hot Reload Strategy | Accepted | Development reload transport |
| [ADR-003](adrs/ADR-003-precompiled-template-strategy.md) | Pre-Compiled Template Strategy | Proposed | Template cold-start optimization |
| [ADR-004](adrs/ADR-004-sdk-package-architecture.md) | SDK Package Architecture | Accepted | SDK package boundaries |
| [ADR-005](adrs/ADR-005-server-integration-strategy.md) | Server Integration Strategy | Accepted | Server framework integrations |
| [ADR-006](adrs/ADR-006-css-strategy.md) | CSS Strategy | Accepted | Optional Dart-native CSS tooling |
| [ADR-007](adrs/ADR-007-monorepo-tooling.md) | Monorepo Tooling | Accepted | Dart workspaces and Melos |
| [ADR-008](adrs/ADR-008-ssg-theme-system.md) | SSG Theme System | Accepted | Theme distribution and overrides |
| [ADR-009](adrs/ADR-009-package-versioning-strategy.md) | Package Versioning Strategy | Accepted | Pre-1.0 lockstep releases |
| [ADR-010](adrs/ADR-010-syntax-highlighting.md) | Syntax Highlighting Strategy | Accepted | Build-time code highlighting |
| [ADR-011](adrs/ADR-011-htmx-version-policy.md) | HTMX Version Policy | Accepted (amended 2026-09-04, 2026-10-04) | Hypermedia coupling boundary; HTMX 4-compatible adapters, pin unchanged; scaffolds self-host HTMX, CDN opt-in |
| [ADR-012](adrs/ADR-012-trellis-ui-contract.md) | Single Trellis-Owned UI Contract | Accepted (2026-10-04) | UI component public contract and expansion boundary; Tier 1 is a Trellis-owned shadcn/ui port |
| [ADR-013](adrs/ADR-013-sass-module-bridge.md) | SASS Module Bridge and Per-Mode Colour Params | Accepted (owner, 2026-10-04) | `@use … with()` theme bridge, palette-map skins, per-mode colour params; hard cut, implemented in 0.12 |
| [ADR-014](adrs/ADR-014-component-composition-primitives.md) | Component Composition Primitives | Accepted (owner, 2026-10-15) | Core slots, attribute spreading, pass-through, bare-name top-level rendering of parameterised fragments (Linear LEA-16); implementation in 0.13 |
| [ADR-015](adrs/ADR-015-url-scheme-blocking.md) | Block Script-Capable URL Schemes in Dynamic URL Attributes | Accepted (owner, 2026-11-18) | `javascript:`/`vbscript:`/non-image `data:` in dynamic `href`/`src`/`action`/`formaction`/`data`/`xlink:href` become `about:invalid#trellis-unsafe-url`; `TrustedUrl` opt-out; implementation in 0.14 |

## Superseded

| Prior Decision | Superseded By | Notes |
|---|---|---|
| [ADR-012](adrs/ADR-012-trellis-ui-contract.md) Tier 1 seed: pinned, unmodified, vendored Basecoat (2026-08-15) | [ADR-012](adrs/ADR-012-trellis-ui-contract.md) amendment 2026-10-04: Trellis-owned shadcn/ui port | Basecoat failed upstream responsiveness and strict CSP (toast); research/14 |
| [ADR-012](adrs/ADR-012-trellis-ui-contract.md) clarification: Trellis's own build may use npm/bundlers (2026-08-15) | No Node anywhere in Trellis (Still Current, 2026-10-03), in ADR-012 since 2026-10-04 | Owner decision; pinned non-Node tool binaries allowed for the porting pipeline |
| Spec working documents in the private repo's `docs/specs/<version>/` or `docs/specs/0.next-<slug>/`, PRD as `prd.md` (2026-10-03) | Planning in Linear, working material in `dev/spec/<milestone>/` (Still Current, 2026-11-17) | Owner decision to retire the private planning repo; PRDs 0.1–0.14 migrated to Linear issues 2026-11-17 |
| Research, diagrams, specs/plans and product backlog stay in the private planning repo (Docs split, 2026-06-05) | Docs split as amended 2026-11-17 | Backlog and PRDs moved to Linear, Product to `dev/PRODUCT.md`, this index to `dev/DECISIONS.md` |
| [ADR-008](adrs/ADR-008-ssg-theme-system.md) – SASS bridge mechanism only (`@import` load order, skin files as `!default` presets, "site `sass/_variables.scss` overrides theme vars") | [ADR-013](adrs/ADR-013-sass-module-bridge.md) | Partly superseded 2026-10-04: ADR-008 stays Accepted for theme structure, layout resolution, override dimensions 1–3 and distribution. Bridge bullets annotated in place, original text kept. |

## Still Current

- **Release sequence after 0.11** (2026-09-02): 0.12 = SASS `@use` migration
  (TD-006, PRD 0.12, Linear LEA-39, folder moved from
  `0.next-sass-use-migration`), 0.13 = composition primitives (ADR-014), 0.14 =
  Trellis UI Tier 1 slice (ADR-012). Rationale: the migration forbids bundling
  and must land before Trellis UI adds theme SASS; composition primitives are a
  hard prerequisite for Tier 1 authoring. 0.12 was gated on the ADR-012 amendment
  sign-off (done 2026-10-04; FIS D3 decided 2026-10-03: option (a), in-package gate
  test); 0.13 on the ADR-014 acceptance pass (done 2026-10-15). The app-conventions todo
  experiment runs during 0.13 as design-only work alongside the Trellis UI PRD,
  whose preview asset folder it co-decides; its release stays unassigned
  (owner, 2026-10-03).
- **Planning lives in Linear; working material in `dev/spec/<milestone>/`** (owner,
  2026-11-17): the product backlog, one milestone per release, and every release's
  PRD (the description of its issue, `Record: tracker`) live in the maintainers'
  Linear project `Trellis`; GitHub Issues stay the public intake, synced one way
  into Linear. Plans, FIS, briefs and amendment proposals for the release in flight
  go under `dev/spec/<milestone>/` in this repository and are deleted at release
  prep. 0.14's moved there from the private repo on 2026-11-18, after its
  implementation. The private planning repo is being retired. Tracker details:
  `dev/guidelines/ISSUE-TRACKER.md`.
- **ADR location**: Contributor-facing ADRs live in this repository under
  `dev/adrs/`; research bundles link to them rather than duplicating the
  authoritative record.
- **Docs split** (2026-06-05, amended 2026-11-17): Contributor docs (product,
  decisions, ADRs + research appendices, architecture, guidelines, learnings,
  tech-debt) live in this repository under `dev/`; user-facing docs under
  `site/content/docs/`. The public `dev/state/STATE.md` was retired 2026-10-13 (0.12
  review D1); release status lives in the Linear milestones.
- **Core package rename dropped** (2026-06-04): `trellis` → `trellis_templates`
  will NOT happen (134 imports deep, name already published on pub.dev). The core
  package stays named `trellis`.
- **Site-redesign themes release target**: The feature milestone shipped as
  `v0.11.0` on 2026-08-31 with all eight publishable packages bumped in lockstep.
  S05 supplied the hand-written changelog sections; the owner-driven release step
  created the SDK-wide version commit and tag.
- **Site-redesign visual acceptance workflow**: Public implementation stories may
  reach `done` after their automated and transient bridged visual gates; the whole
  five-story plan remains executable without a manual hold. After plan completion,
  the project owner reviews the built result. Requested adjustments become focused
  follow-up requirements/specs rather than blocking or reopening this plan. Release
  remains a separate later owner-driven action.
- **Theme parameter compatibility for this milestone**: The standard contract
  remains the existing 18 parameters and permits its documented nullable optional
  strings. `excerpt_length` is an optional theme-specific content-rendering
  parameter, not a nineteenth standard parameter. The gallery recognizes the
  current informal built-in archetype tokens (`docs`, `landing`, `blog`) without
  settling LEA-17's future typing model.
- **Lattice/site implementation comparator**: The project owner approved the A3
  Lattice direction; implementation-time Lattice and migrated-site homepage
  comparisons used that asset. The shipped result and review evidence are
  summarized in the 0.11 PRD outcome.
  Named docs pages without an approved mockup are inspection surfaces, not
  fabricated parity comparisons.
- **Folio implementation comparator**: The project owner approved the Folio
  light and dark directions on 2026-08-16 after responsive and independent visual
  validation. Implementation compared bridged builds against those assets.
- **Meadow implementation comparator**: The project owner approved the Meadow
  light and dark directions on 2026-08-16 after responsive and independent visual
  validation. Implementation compared bridged builds against those assets.
- **Trellis UI delivery — package-managed embedded suite** (spike 2026-08-18,
  research 11, Trellis UI packaging spike (maintainer's private research repo)): `trellis_ui` is a
  publishable lockstep package carrying templates and assets as **base64**
  constants, with optional deploy-time materialization beside the binary as a
  flag, not a second mechanism; embedded bytes/digests are authoritative and
  divergence is overwritten at startup. The CLI-managed vendored bundle is
  **rejected**: a shipped `trellis_cli` is itself AOT and cannot read package
  assets, so vendoring either duplicates a package dependency the app already
  needs or moves the suite into the CLI (+410 KB), while adding an install step,
  a manifest, drift-repair commands and silent binary/bundle skew. Embedding
  costs +394 KB for a 296 KB payload (1.33×; string literals would be 2.0×), and
  unreferenced embedded assets tree-shake to +0 B — but a map-shaped registry is
  all-or-nothing, so per-component elimination is forfeited.
- **Trellis UI Tier 2 provider — per-widget fillers, not Vaadin** (CSP spike
  2026-08-18, research 12, Trellis UI CSP spike (maintainer's private research repo)): under
  `style-src 'self'` with no escape hatch, Cally, Tom Select, Tabulator and Uppy
  pass with zero violations; AG Grid Community passes via its documented
  `styleNonce`; both Vaadin 24.7.6 builds fail (the Lit build only recoverable
  with a nonce plus an unsupported `document.createElement` monkey-patch). The
  screening mechanism is corrected: CSSOM writes (`el.style.top`, `cssText`) are
  outside CSP entirely, so the gate is runtime `<style>` **element** injection
  (`style-src-elem`), not inline `style=""` attributes. Tom Select dropped
  2026-10-04: the Tier 1 combobox covers rich select.
- **No Node anywhere in Trellis** (owner, 2026-10-03): the no-Node rule binds the
  Trellis toolchain too, not only consumers – build, release, tests, and asset
  preparation. Sole exception: a GitHub Actions step where no non-Node option
  exists. Third-party browser assets are obtained as prebuilt, checksummed files
  (download, no npm/bundler). Build tools that need no Node install (the Tailwind
  standalone CLI) may run as downloaded, pinned, checksummed binaries, scoped to the
  Trellis UI porting pipeline (owner, 2026-10-04). Recorded in
  [ADR-012](adrs/ADR-012-trellis-ui-contract.md) § Constraint
  clarifications.
- **Trellis UI behaviour layer — light-DOM custom elements** (owner, 2026-10-03,
  research 13, Trellis UI behaviour layer spike (maintainer's private research repo)): Trellis-authored
  behaviour is plain-JS custom elements wrapping server-rendered markup, not
  Stimulus (same authored size, 15.2 KB gzip dependency avoided) and not Dart
  compiled to JS/Wasm. Wrapper tags get `display: contents`; behaviour ships as one
  classic script because `type="module"` never runs from `file://`, which the
  app-conventions preview requirement needs. Recorded in
  [ADR-012](adrs/ADR-012-trellis-ui-contract.md) § Decision
  item 3.
- **Trellis UI seed — Trellis-owned shadcn/ui port** (owner, 2026-10-04,
  research 14, Trellis UI seed re-evaluation (maintainer's private research repo)): replaces vendored
  Basecoat. Vega style only, Base UI `data-*` contract, shadcn token names and
  `trellis-*` part classes public; synced per shadcn release batch by an agent-run
  skill with local gates, no CI gates for now; Web Awesome Free is the recorded
  fallback. Details in
  [ADR-012](adrs/ADR-012-trellis-ui-contract.md) § Decision.
- **Component composition primitives accepted** (owner, 2026-10-15,
  [ADR-014](adrs/ADR-014-component-composition-primitives.md)):
  `tl:slot` attribute-marked regions, `tl:attrs="${map}"` spreading, opt-in
  `...attrs` rest-parameter pass-through, ships in 0.13. All 15 amendment candidates
  from the acceptance pass were accepted as briefed
  (PRD 0.13 Outcome, Linear LEA-16). Three
  changed the design: a spread key starting with the engine prefix (`tl:`) throws,
  because the engine would otherwise run it as a directive (AC-02, security); a
  parameterised fragment renders top-level by its bare name with parameters read
  from the context, and a name with arguments (`toast('error')`) throws while an
  empty `()` still resolves (AC-06, from the 2026-10-08 PRD amendment, narrowed
  2026-10-15); a surviving `tl:insert` host keeps its own directive results and also
  forwards them, so adding `...rest` never changes the rendered host of an existing
  `tl:insert` caller (AC-09).

## Pending

None open.
