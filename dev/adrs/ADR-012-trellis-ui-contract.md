# ADR-012: Single Trellis-Owned UI Contract

## Status

Proposed (2026-08-14; amended 2026-08-15 after a verification round)

## Context

Trellis aims to become a complete SDK for server-rendered web applications and
needs an opinionated, rich, polished component capability. The solution must fit
natural HTML and HTMX, expose semantic rather than utility-heavy CSS, require no
Node/npm or JavaScript framework, self-host under strict CSP, use permissive
licences, and sustain accessibility quality with solo-maintainer capacity.

Two research rounds compared a packaged Trellis library, source-copy registry,
direct Basecoat integration, rich Web Components suites, and a layered combination.
No evaluated permissive upstream satisfies the required catalogue benchmark and all
gates. The benchmark defines a complete foundational suite plus date/range/time,
data-grid, tree, and multi-upload capabilities; editors, schedulers, and charts are
separate deferred integrations. UI5 Web Components is the richest suite evaluated
but still lacks a command palette and a complete data-grid benchmark, officially
expects npm/bundling, and imports Fiori/Shadow DOM/provider coupling. Basecoat best
fits Trellis primitives but lacks the advanced benchmark and has no proven
catalogue-wide accessibility programme.

The native-versus-Basecoat spike proved that Basecoat can work with self-hosted
assets, strict CSP, and repeated HTMX swaps while materially reducing Trellis-owned
CSS/JS. It validated only six primitives and found mobile/touch issues.

The first-pass layered architecture scored 4.00/5, but its lead was not robust. It
credited unbuilt advanced integrations and understated the maintenance cost of
package, copied-source, and provider-specific ownership models. Trellis's existing
`AssetLoader` is also not portable to remotely deployed AOT binaries, so packaged
HTML/CSS/JS requires embedding or materialization. Source update reconciliation was
not spiked either.

A 2026-08-15 verification round (research addendum) corrected the candidate record
and re-tested the constraints. Key inputs to the amendment: Vaadin's grid (incl.
tree mode), date picker, combobox, and upload are Apache-2.0 with an audited
accessibility programme; htmx 2 removed the classic Shadow DOM form/attribute
blockers, leaving Node-dependent server-side rendering as the real structural cost;
strict CSP eliminates several popular widgets because nonces cannot apply to
`style=""` attributes; and no server-rendered ecosystem ships a complete suite —
per-widget composition is the universal pattern.

## Decision

Trellis will provide **one optional, versioned, Trellis-owned UI suite** with one
semantic public contract:

1. Trellis fragment names and parameters.
2. Semantic Trellis CSS classes and custom-property tokens.
3. One minimal delegated browser lifecycle compatible with HTMX insertion,
   cleanup, repeated swaps, and history restoration.
4. Trellis-owned documentation, accessibility claims, tests, and compatibility
   policy.

The catalogue promise is **two-tier by design** (amended 2026-08-15):

- **Tier 1 – Trellis UI suite**: the foundational components (the foundational
  benchmark row), Trellis-owned, light-DOM, semantic HTML, rendered server-side as
  natural templates. Only Tier 1 carries the Trellis contract and the
  qualification gate below.
- **Tier 2 – vetted integrations**: advanced widgets (date/range, data grid, tree,
  multi-upload) as documented, version-pinned, CSP-verified integration recipes for
  qualified third-party widgets — not Trellis-owned components and not covered by
  Trellis accessibility claims. Shadow DOM is acceptable here as isolated leaf
  islands outside page structure; it remains excluded from Tier 1.

Trellis does not pursue single-suite catalogue completeness; the rich-suite
benchmark row is satisfied through Tier 2, and editors, schedulers, and charts
remain deferred product decisions.

Permissively licensed upstream implementations may be adapted internally for
individually qualified components. Basecoat is a provisional primitive seed, not
the Trellis UI contract. Basecoat, Tailwind, UI5, or other provider selectors,
attributes, events, types, and conventions must not become public Trellis APIs.

**First-version seed delivery (decided 2026-08-15):** Tier 1 ships pinned,
unmodified, vendored Basecoat assets behind Trellis fragments — no fork, no direct
adoption. Trellis fragments and parameters are the public API; Trellis tokens plus
a `trellis-*` hook class per component root are the styling surface. Basecoat's
internal classes appear in rendered markup but are non-contractual and unstable
pre-1.0: a later semantic-class re-authoring may break user CSS that targets them,
never application templates. Semantic-class re-authoring is deferred behind the
Basecoat revisit triggers. Hard-forking is reserved for upstream death (MIT pinning
keeps it a free later option); Open Props UI is the fallback seed.

Constraint clarifications adopted with the 2026-08-15 amendment:

- The no-Node rule constrains **consumers**, not the Trellis build: Trellis's own
  pipeline may use npm/bundlers to produce prebuilt, vendored assets.
- The licence gate applies **per component**, not per vendor family; open-core
  siblings do not disqualify Apache/MIT components.
- Strict CSP is an explicit, empirically verified screening gate: inline `style=""`
  positioning forces `unsafe-inline` and nonces cannot rescue it.
- The application override seam is tokens, semantic extension classes, and
  composition only; shadowing managed fragments is unsupported.

The first release will expose **one managed delivery model**. A bounded packaging
spike must choose between two mutually exclusive mechanisms:

1. **Package-managed embedded suite** – the Dart package remains authoritative;
   generated Dart carries templates and asset bytes, and deployment may emit those
   assets beside the binary. No canonical component source lives in the project.
2. **CLI-managed vendored bundle** – the CLI installs a versioned, checksummed
   canonical bundle into a generated vendor directory. Upgrades replace that bundle
   as a unit; its files are not an application editing surface.

Both mechanisms keep application changes in separate app-first override files.
Direct edits to managed files are unsupported. Editable component copies are the
deferred source-primary/registry model, not the second spike branch. Direct
package-asset lookup is not an AOT deployment solution.

Copied-source recipes/ejection, provider-specific advanced integration packs, and
a generic provider abstraction are deferred. The layered model remains a future
option map, not a present architecture commitment.

`trellis` core will not depend on the UI suite. If the delivery spike selects a new
publishable `trellis_ui` package, it will remain optional, depend toward core, and
join the SDK's lockstep version policy while ADR-009 remains active.

No Tier 1 component is supported until it passes the Trellis UI qualification gate:
permissive provenance, self-hosting, strict CSP, semantic markup, HTMX lifecycle,
keyboard interaction, automated WCAG A/AA, screen-reader testing against the
support matrix, forced-colour, responsive, zoom, reduced-motion, touch-target, and
visual checks. The gate is bounded to stay solo-maintainer sustainable: the
screen-reader support matrix is VoiceOver + Safari and NVDA + Firefox; automated
checks (axe, keyboard, emulated forced-colour/zoom/reduced-motion) run per release;
manual screen-reader passes re-run only when a component's markup or behaviour
changes.

Tier 2 integrations pass a narrower vetting gate: per-component permissive licence,
self-hosted assets, strict CSP verified in-browser, HTMX swap/history behaviour,
token-level visual fit, and upstream maintenance health. Accessibility conformance
leans on the upstream programme where a credible one exists (currently Vaadin- or
USWDS-tier); otherwise the recipe is documented as unaudited. Trellis tests the
integration seam, not the third-party component.

## Consequences

### Positive

- Applications see one coherent Trellis system regardless of internal provenance.
- Upstream libraries remain replaceable because their contracts are not exposed.
- Accessibility and security fixes are authored and qualified once in canonical
  Trellis releases; the packaging spike must prove how upgrades reach applications.
- Consumer projects do not inherit Tailwind-style authoring, Node/npm, CDN, inline
  script, or framework-runtime requirements.
- The architecture stays small enough to validate one component slice at a time.
- Embedded/vendored delivery is decided by remote-AOT and upgrade evidence rather
  than ideology.

### Negative

- Trellis's catalogue promise is a composed stack (Tier 1 suite plus Tier 2
  integrations), not single-suite completeness; Tier 2 accessibility claims belong
  to upstreams, not Trellis.
- Trellis owns the public behaviour and accessibility contract even when upstream
  code supplies implementation leverage.
- Canonical assets require either package-managed embedding or a CLI-managed
  vendoring workflow.
- Structural application ownership is limited initially to tokens, composition,
  semantic extension classes, and one override seam.
- Advanced widgets are Tier 2 integrations with vetted, version-pinned recipes;
  editors, schedulers, and charts remain fully deferred.

### Neutral

- Basecoat can be replaced without a Trellis API break if the boundary is enforced.
- One aggregate same-origin CSS/JS bundle is acceptable initially; per-component
  bundling waits for measured need, while CSS purging may reduce unused rules.
- The ADR remains Proposed until the packaging spike resolves the delivery model
  and the first slice clears its qualification gate.

## Alternatives Considered

1. **Full layered architecture** – rejected now: the 4.00 target-state score was
   fragile and commits to three ownership/support models before demand.
2. **Source registry as the foundation** – deferred: strongest local-file fit, but
   locally modified copies make update and support effort grow; reconciliation and
   security-fix behaviour remain unproven.
3. **Packaged suite with direct package assets** – rejected: `AssetLoader` cannot
   support remote AOT deployment without source files. Generated embedding or
   materialization remains in the packaging spike.
4. **Direct Basecoat adoption** – rejected: incomplete advanced catalogue, young
   upstream, catalogue accessibility unproven, and unacceptable public lock-in.
5. **Direct UI5 Web Components adoption** – rejected: richest permissive option but
   still incomplete, provider-shaped, Shadow-DOM-constrained, and dependent on a
   Trellis-maintained prebundle for a no-Node consumer path.
6. **Bootstrap foundation** – rejected: mature and compatible but deliberately too
   shallow to satisfy the component objective.
7. **Build the complete suite natively immediately** – rejected: high maintenance
   risk for a solo maintainer unless catalogue scope or maintenance capacity changes.
8. **Vaadin free tier as the whole advanced provider** – deferred to Tier 2
   vetting: the only permissive coverage of the full advanced benchmark, with an
   audited accessibility programme, but Shadow DOM, npm-oriented distribution, and
   unverified CSP behaviour keep it out of Tier 1.
9. **Fork Basecoat** – rejected: full ownership burden (including the Tailwind
   pipeline and all accessibility work) without upstream leverage; pinned vendoring
   preserves fork-on-death as a later option at no cost.

## Implementation Notes

### Required packaging spike

Compare the package-managed embedded suite and CLI-managed vendored bundle with the
same six component candidates from the earlier spike. Compile an executable, move it
to a clean directory without repository/pub-cache sources, then prove rendering and
asset serving. Test strict CSP, repeated HTMX swaps, cleanup/history restore,
application overrides, one version upgrade, override preservation, advisories, and
direct-edit tamper handling. The implementation must refuse or deterministically
restore edits to managed files without a merge engine. Also record provenance,
browser/executable payload, startup, and deployment steps.

Select the model only if it is materially simpler across deployment, upgrade, and
support. Otherwise keep this ADR Proposed and stop before implementation planning.

### Tier 2 vetting

Vet the first integration shortlist upfront — date/range, grid, tree, and upload
demand is predictable, not speculative. Candidates: Cally (date/range), Tom Select
(rich select), Tabulator or AG Grid Community (data grid), Uppy (multi-upload), and
Vaadin's Apache-2.0 free tier (grid incl. tree mode, date picker, combobox, upload)
as a single-provider alternative. A short DevTools spike must first determine
whether Lit/Vaadin components apply styles via `adoptedStyleSheets` (CSP-clean) or
inline `style=""` attributes; the result decides between the single-provider and
per-widget shortlists. Building any Tier 2 widget as a Trellis-owned component
remains gated on the revisit triggers below.

### First component slice

**Prerequisite — core composition primitives (PB-012).** Thymeleaf ecosystem
research (2026-08-15) showed component libraries on fragment engines fail at three
identifiable gaps: content slots, attribute spreading, and attribute pass-through.
Trellis core lacks all three (verified against `fragment_processor.dart` /
`attr_processor.dart`). They must be designed and implemented in `trellis` core —
under their own ADR — before any Tier 1 component is authored, so the suite
consumes core primitives instead of accumulating workarounds.

Field, dialog, dropdown, combobox, table, and toast are candidates, not accepted
scope. Fix the Basecoat spike's mobile table and touch-target failures and run the
full qualification gate before any support claim.

### Revisit triggers

- Add source/ejection only after two independent applications require structural
  changes beyond tokens/composition/overrides and reconciliation is proven.
- Promote a Tier 2 integration to a Trellis-owned Tier 1 component only after two
  independent applications require it and the upstream fails vetting or maintenance
  health; vetting the Tier 2 shortlist itself is upfront work, not demand-gated.
- Reconsider Basecoat when a component fails qualification, two consecutive
  upgrades require substantial bridge/public-markup changes, or provider details
  leak into application templates.
- Do not define a generic provider interface before two real integrations reveal a
  stable shared seam.

## Project Compliance

- **ADR-004** – UI remains optional and depends toward core; core stays minimal.
- **ADR-006** – consumer CSS remains semantic and no-npm; CSS tooling stays optional.
- **ADR-008** – reuses app-first override/local materialization precedents without
  copying the entire four-mechanism theme model.
- **ADR-009** – any publishable UI package joins lockstep versioning pre-1.0.
- **ADR-010** – assets are generated/self-contained or same-origin vendored; no
  runtime CDN dependency.
- **ADR-011** – HTMX coupling remains outside core and confined to the optional UI
  lifecycle.
- Aligns with one-version-at-a-time, opt-in complexity, security-by-default,
  HTMX-first, no-npm, pragmatic-escape-hatch, and maintainer-burnout constraints.

## References

- Research – private planning repo, canonical (no public digest yet):
  `docs/research/trellis-ui-component-architecture/` – bundle, `design-tree.md`, `tradeoff-matrix.md`,
  `recommendation.md`, and the 2026-08-15 verification addendum (`research.md`)
- Spike branch `spike/trellis-ui-registry-vs-basecoat`, commit `21f4a5b`
- [UI5 Web Components](https://ui5.github.io/webcomponents/components/)
- [Basecoat](https://basecoatui.com/introduction/)
- [HTMX lifecycle events](https://htmx.org/events/)
- [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/about/introduction/)
