# ADR-012: Single Trellis-Owned UI Contract

## Status

Accepted (2026-10-04). Proposed 2026-08-14, amended 2026-08-15 after a verification
round, amended and accepted 2026-10-04 after the delivery, CSP, behaviour-layer and
seed spikes – see [Amendments](#amendments).

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
fit Trellis primitives in that round but lacks the advanced benchmark and has no
proven catalogue-wide accessibility programme.

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
blockers. Server-side rendering is not a structural cost of Shadow DOM itself:
Declarative Shadow DOM lets Trellis fragments emit shadow roots without Node, and
only third-party suites whose markup lives in JavaScript need Node-based SSR. The
costs that keep Shadow DOM out of Tier 1 structure are that form controls and
ID-based label/ARIA references do not cross the shadow boundary (fixing either needs
JavaScript or the unshipped Reference Target feature), and that application CSS
reaches inside only through custom properties and `::part`. Strict CSP eliminates
several popular widgets (screening mechanism under § Constraint clarifications), and
no server-rendered ecosystem ships a complete suite – per-widget composition is the
universal pattern.

The native-versus-Basecoat spike (2026-08) showed Basecoat working with self-hosted
assets, strict CSP, and repeated HTMX swaps, but validated only six primitives and
found mobile/touch issues. A 2026-10 seed re-evaluation (research/14) found Basecoat
unfit as an unmodified seed: one maintainer, with 46% of external issues and PRs
unanswered over 12 months; a toast API that builds inline `onclick` handlers, which
`script-src 'self'` blocks; components inert after HTMX history restore without a
forced re-init; and keyboard defects in menu, select, and combobox. It then spiked a
Trellis-owned port of shadcn/ui against Web Awesome Free on the same five components
(dropdown menu, HTMX-populated combobox, tabs, toast, field with select) under
`script-src 'self'; style-src 'self'`:

- The port passed every behaviour gate in Chrome (35 of 35) and Firefox (40 of 40)
  with a 14.5 KB gzip payload and 242 hand-written JS lines. Its pipeline regenerated
  shadcn's style CSS without Node across two syncs covering 2025-12 to 2026-10; each
  cost at most 4 template lines, 3 hand CSS lines, and one pipeline config entry.
  The 2025-12 to 2026-06 window was measured in reverse, so adopting new upstream
  hooks is unmeasured.
- Web Awesome Free passed only with four Trellis seams for HTMX swaps and history,
  ships as ES modules only (no `file://` natural-template previews), renders
  unstyled text until its elements are defined (CLS 0.24 on slow 4G), and weighs
  about 118 KB gzip.

## Decision

Trellis will provide **one optional, versioned, Trellis-owned UI suite** with one
semantic public contract:

1. Trellis fragment names and parameters.
2. Semantic Trellis CSS classes and custom-property tokens.
3. One browser lifecycle compatible with HTMX insertion, cleanup, repeated swaps,
   and history restoration: Trellis-authored behaviour is light-DOM custom elements
   wrapping server-rendered fragment markup (`connectedCallback` /
   `disconnectedCallback`), shipped as one classic, import-free script so it also
   runs in `file://` natural-template previews. Wrapper tags carry
   `display: contents` and no styling. No client framework or controller library.
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
individually qualified components. Provider selectors, attributes, events, types,
and conventions (shadcn/ui, Base UI, Tailwind, Web Awesome, UI5, or any other) must
not become public Trellis APIs, except the shadcn token names adopted below.

**Tier 1 seed – Trellis-owned port of shadcn/ui (decided 2026-10-04):** Tier 1 is a
Trellis-owned vanilla HTML/CSS/JS port of shadcn/ui, tracked against upstream by a
porting pipeline rather than frozen. It replaces the 2026-08-15 seed (pinned,
unmodified, vendored Basecoat).

- **Style.** shadcn's `vega` style is the one verified style. shadcn components
  carry semantic `cn-*` hooks that each style file maps to Tailwind utilities; the
  pipeline renames `cn-` to `trellis-` and compiles the result into plain CSS that
  Trellis commits. Another shadcn style is one generation run plus its own visual
  baselines, added when an application asks for it. Applications restyle through
  tokens and the public part classes; the `cn-` to `trellis-` mapping is documented
  so an application can port another shadcn style file by hand or with a coding
  agent.
- **Behaviour.** The custom elements of item 3 reproduce the `data-*` attribute
  contract of shadcn's Base UI base (shadcn's default since 2026-07-02): `data-slot`,
  boolean state attributes (`data-open`, `data-active`, `data-highlighted`, …),
  `data-side`/`data-align`, and the `group/*`/`peer/*` marker classes the style CSS
  selects on.
- **Public styling surface.** Public and semver-tracked: shadcn's token names
  verbatim (`--primary`, `--radius`, …, so a shadcn theme block applies unchanged)
  and the `trellis-<component>[-<part>]` classes. An upstream hook rename that
  changes a public class is a breaking change in the changelog. Non-contractual
  pre-1.0: `data-slot`, state attributes, `group/*`/`peer/*` markers, and
  custom-element internals.
- **Touch targets.** A Trellis override layer sets at least 44 px under
  `(pointer: coarse)`, at least 24 px elsewhere (WCAG 2.2 AA), and a 16 px input
  font on coarse pointers.
- **Fallback.** If owning behaviour and accessibility proves unsustainable, Web
  Awesome Free is the recorded alternative seed, at two known costs: it ships as ES
  modules only, so its components lose `file://` previews, and its payload is about
  8× the port's. Switching would also break application CSS written against the
  public styling surface below, though not application templates.

**Upstream sync.** A coding agent runs each sync through a project skill plus
scripts, per batch of shadcn releases (monthly or bimonthly): bump the pinned tag,
regenerate, run the sync gates locally (slot parity, the behaviour gates, an
appearance check per component state, and a check that the committed CSS regenerates
unchanged), triage each upstream change (mechanical, hand-layer edit, or new
component to port, defer, or skip), record a reason for every parity-ignore entry,
and write a sync report for owner review. The gates run locally, not in CI; a
scheduled CI job that runs the skill and opens a sync pull request is a later
option, with no trigger set. The port
degrades into a fork if parity-ignore entries stop being reviewed or generated CSS
is edited by hand.

Constraint clarifications (adopted 2026-08-15, amended 2026-10-04):

- The no-Node rule binds the Trellis toolchain as well as consumers: build, release,
  tests, and asset preparation run without Node or npm. Third-party browser assets
  are vendored as prebuilt, checksummed files obtained by download. Build tools that
  need no Node install may run as downloaded, version-pinned, checksummed binaries,
  scoped to the porting pipeline (the Tailwind standalone CLI); generated CSS is
  committed, so build, tests, and release outside the porting pipeline never invoke
  them. The sole other exception
  is a GitHub Actions step where no non-Node option exists.
- The licence gate applies **per component**, not per vendor family; open-core
  siblings do not disqualify Apache/MIT components.
- Strict CSP is an explicit, empirically verified screening gate. `style-src-attr`
  (authored `style=""` and `setAttribute('style', …)`) cannot be rescued by a nonce
  – a nonce is an element attribute and an inline style attribute has no element of
  its own. CSSOM writes (`el.style.prop`, `setProperty`, `cssText`) are outside CSP's
  scope entirely and are how conforming libraries position overlays. The
  disqualifying pattern in practice is runtime `<style>` **element** injection
  (`style-src-elem`), which a nonce can rescue only where the library exposes a nonce
  hook.
- The application override seam is tokens, CSS against the public `trellis-*`
  classes, semantic extension classes, and composition; shadowing managed fragments
  is unsupported.

The first release exposes **one managed delivery model: a package-managed embedded
suite** (packaging spike, 2026-08-18). `trellis_ui` is a publishable package whose
generated Dart carries fragment templates and CSS/JS bytes as base64 constants; apps
depend on it and it joins the ADR-009 lockstep version policy. Applications may
optionally have the runtime materialize those assets into a directory beside the
binary for static serving, HTTP validators and dev-time watching; the embedded bytes
and their sha256 digests remain authoritative and any divergence in a materialized
file is deterministically overwritten at startup – no merge engine, no
reconciliation. A CLI-managed vendored bundle is **rejected**: a shipped
`trellis_cli` is AOT and cannot read package assets, so vendoring either duplicates a
package the app already depends on or moves the whole suite into the CLI binary,
while adding an install step, a manifest, drift-repair commands, a second deployable
artefact and a silent binary/bundle skew mode. Application changes remain confined
to the override seam above and separate app-first override files; managed files are
not an editing surface. Editable component copies are the deferred
source-primary/registry model. Direct package-asset lookup is not an AOT deployment
solution.

Copied-source recipes/ejection, provider-specific advanced integration packs, and
a generic provider abstraction are deferred. The layered model remains a future
option map, not a present architecture commitment.

`trellis` core will not depend on the UI suite. `trellis_ui` remains optional,
depends toward core, and stays in the SDK's lockstep version policy while ADR-009
remains active.

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
- Applications get shadcn's look and token vocabulary without React, Tailwind, or
  Node; a shadcn theme block applies unchanged.
- Upstream behaviour and runtime contracts are not exposed, so application templates
  survive a seed change; shadcn token names and the hook-derived `trellis-*` part
  classes are public, so application CSS may not.
- Accessibility and security fixes are authored and qualified once in canonical
  Trellis releases and reach applications as a `trellis_ui` package version.
- Consumer projects do not inherit Tailwind-style authoring, Node/npm, CDN, inline
  script, or framework-runtime requirements.
- The architecture stays small enough to validate one component slice at a time.
- The embedded delivery model was chosen on remote-AOT and upgrade evidence
  (research/11), not ideology.

### Negative

- Trellis's catalogue promise is a composed stack (Tier 1 suite plus Tier 2
  integrations), not single-suite completeness; Tier 2 accessibility claims belong
  to upstreams, not Trellis.
- Trellis owns all Tier 1 behaviour and accessibility (an estimated 500–550 JS lines
  for the catalogue) plus a recurring upstream sync. The expensive sync event is
  upstream adding or re-implementing a component (toast: a sonner wrapper replaced by
  Base UI toast), not restyling.
- shadcn's naming becomes Trellis's public naming: a hook rename that changes a
  `trellis-*` class is a Trellis breaking change.
- Embedded assets cost 1.33× their payload in the binary, and a map-shaped asset
  registry forfeits per-component tree-shaking.
- Structural application ownership is limited initially to the override seam.
- Advanced widgets are Tier 2 integrations with vetted, version-pinned recipes;
  editors, schedulers, and charts remain fully deferred.

### Neutral

- Stopping the upstream sync leaves a working Trellis-owned suite (a fork), not a
  broken one; no Trellis API depends on shadcn's release cadence.
- One aggregate same-origin CSS/JS bundle is acceptable initially; per-component
  bundling waits for measured need, while CSS purging may reduce unused rules.
- Acceptance does not qualify any component: each Tier 1 component still passes the
  qualification gate before a support claim, and a first-slice failure is a revisit
  trigger, not a reason to reopen acceptance.

## Alternatives Considered

1. **Full layered architecture** – rejected now: the 4.00 target-state score was
   fragile and commits to three ownership/support models before demand.
2. **Source registry as the foundation** – deferred: strongest local-file fit, but
   locally modified copies make update and support effort grow; reconciliation and
   security-fix behaviour remain unproven.
3. **Packaged suite with direct package assets** – rejected: `AssetLoader` cannot
   support remote AOT deployment without source files; generated embedding was
   chosen instead (research/11).
4. **Direct Basecoat adoption** – rejected: incomplete advanced catalogue, young
   upstream, catalogue accessibility unproven, and unacceptable public lock-in.
5. **Direct UI5 Web Components adoption** – rejected: richest permissive option but
   still incomplete, provider-shaped, Shadow-DOM-constrained, and dependent on a
   Trellis-maintained prebundle for a no-Node consumer path.
6. **Bootstrap foundation** – rejected: mature and compatible but deliberately too
   shallow to satisfy the component objective.
7. **Build the complete suite natively immediately** – rejected 2026-08-15 as a
   maintenance risk for a solo maintainer; reversed in part 2026-10-04. Trellis now
   owns the suite, but takes its styling mechanically from shadcn rather than
   authoring it, and the measured hand layer (242 JS lines for five components) and
   sync cost (at most 4 template lines, 3 CSS lines, and one config entry per sync)
   bring ownership within solo capacity.
8. **Vaadin free tier as the whole advanced provider** – rejected on empirically
   verified strict-CSP failure (2026-08-18 spike): Vaadin injects all component and
   global theme CSS as `<style>` elements and exposes no nonce API; overlays collapse
   to `position: static` and render zero items under `style-src 'self'`.
9. **Fork Basecoat** – rejected: a frozen snapshot that inherits Basecoat's defects,
   with no maintained precedent among Basecoat forks; the shadcn port owns the code
   too but keeps an upstream for styling.
10. **Floor option – keep the 2026-08-15 seed (pinned, unmodified, vendored
    Basecoat)** – replaced 2026-10-04 (research/14): Basecoat fails the upstream
    responsiveness criterion and the strict-CSP gate (toast), and needs day-one
    patches for history restore and keyboard defects, so "unmodified" cannot hold.
11. **Web Awesome Free as seed** – rejected as seed, kept as the recorded fallback:
    best upstream health (5 maintainers), but ES-module-only delivery breaks
    `file://` previews, components render unstyled until defined, it needed four
    HTMX seams, and it does not give the shadcn look.
12. **Oat as seed** – rejected: pre-1.0 with announced breaking changes, no
    combobox, drawer, popover, or command palette, and history-restore defects.
13. **Own suite on native platform features, styling authored by Trellis** –
    rejected: the same behaviour layer as the shadcn port, but the look is authored
    and maintained by hand.
14. **Radix as the reproduced shadcn base** – rejected: no longer shadcn's default,
    its toast is a wrapper with no part structure, and its state attributes are
    strings.
15. **CLI-managed vendored bundle** – rejected (packaging spike): an AOT CLI cannot
    read package assets.
16. **Stimulus controllers** – rejected (research/13): equal authored code, 15.2 KB
    gzip dependency, no release since 2023-08. **Dart compiled to JS/Wasm** –
    rejected: Wasm needs `'wasm-unsafe-eval'`, dart2js needs a JS shim per element
    and ships its runtime.

## Implementation Notes

### Delivery (packaging spike, resolved 2026-08-18)

Assets are embedded as base64 constants, not string literals (1.33× against 2.0× of
payload). `dart compile exe` tree-shakes unreferenced embedded assets to +0 B, so a
map-shaped registry forfeits per-component elimination.

### Porting pipeline

- Inputs pinned by shadcn tag and vendored with the MIT notice: the component TSX of
  the Base UI base, `style-vega.css`, `tailwind.css`, and the colour tokens. The
  Tailwind standalone CLI compiles the generated input with no content scan.
- The pipeline, its gates, and the sync skill live in the public repository next to
  `trellis_ui`.
- `@apply` cannot apply `group/*` or `peer/*` markers, so templates carry them as
  literal classes.
- Structural classes with no `cn-` hook are not generated; the pipeline reports them
  and the hand CSS supplies them.
- Upstream CSS written for a runtime Trellis does not have (Base UI's toast stacking)
  is skipped per hook and revisited at every sync. Behaviour gates do not see such
  breakage, which is why the appearance check exists.
- Licence notices in the suite: shadcn/ui (MIT), Lucide (ISC) plus the Feather MIT
  notice for Lucide's Feather-derived icons, tw-animate-css (MIT), and Tailwind CSS
  (MIT, for the preflight and banner in the compiled CSS).

### HTMX lifecycle

- `htmx.config.includeIndicatorStyles` must be `false` under strict CSP
  (`includeIndicatorCSS` under HTMX 4), with the indicator rules shipped as a
  same-origin stylesheet.
- HTMX's settle step re-applies old `style` attributes with `setAttribute`, which
  `style-src 'self'` blocks; CSSOM-positioned popups drop their `style` attribute
  before `htmx:beforeSwap` and `htmx:beforeHistorySave`.

### Tier 2 vetting

Tier 2 shortlist (CSP-verified 2026-08-18): Cally 0.8.x (date/range), Tabulator 6.x
(data grid and tree), Uppy 4.x (multi-upload). AG Grid Community is the documented
grid fallback, requiring a `styleNonce` policy. Vaadin's free tier is excluded. Tom
Select was dropped 2026-10-04: the Tier 1 combobox covers rich select. Web Awesome
Free's tree is not on the shortlist; Tabulator's `dataTree` covers the tree row.

Per the vetting gate, Cally has **no audited accessibility programme**, so its
recipe ships documented as unaudited. Uppy was assembled with a bundler in the CSP
spike; its recipe must use an upstream prebuilt bundle or Uppy fails the no-Node
rule. A widget that rewrites DOM is destroyed on `htmx:beforeHistorySave` so history
snapshots hold the server markup. Building any Tier 2 widget as a Trellis-owned
component remains gated on the revisit triggers below.

### First component slice

**Prerequisite — core composition primitives (PB-012, ADR-014).** Thymeleaf
ecosystem research (2026-08-15) showed component libraries on fragment engines fail
at three identifiable gaps: content slots, attribute spreading, and attribute
pass-through. Trellis core lacks all three (verified against
`fragment_processor.dart` / `attr_processor.dart`). They must be designed and
implemented in `trellis` core — under their own ADR — before any Tier 1 component is
authored, so the suite consumes core primitives instead of accumulating workarounds.

Field, dialog, dropdown, combobox, table, and toast are candidates, not accepted
scope. Before any support claim the first slice runs the full qualification gate,
including Safari (automation hung in the 2026-10 spikes; a working WebDriver setup
or a manual pass) and VoiceOver, neither of which has evidence yet. Known inputs from
the spikes: vega's destructive button measures 4.02:1 contrast upstream, below AA;
`renderFragment` cannot render a parameterised fragment by bare name, so an OOB
fragment takes its values from the context until core addresses it.

### Revisit triggers

- Add source/ejection only after two independent applications require structural
  changes beyond tokens/composition/overrides and reconciliation is proven.
- Promote a Tier 2 integration to a Trellis-owned Tier 1 component only after two
  independent applications require it and the upstream fails vetting or maintenance
  health; vetting the Tier 2 shortlist itself is upfront work, not demand-gated.
- Reconsider the seed (Web Awesome Free is the recorded fallback) when a Tier 1
  component fails qualification, two consecutive syncs need hand-layer JS rewrites,
  shadcn drops the `cn-*` style map or the Base UI base, or provider details leak
  into application templates.
- Add a second verified shadcn style when an application asks for one.
- Screen Web Awesome Free's tree under strict CSP when an application needs a
  navigation tree view rather than a tree grid.
- Do not define a generic provider interface before two real integrations reveal a
  stable shared seam.

## Project Compliance

- **ADR-004** – UI remains optional and depends toward core; core stays minimal.
- **ADR-006** – consumer CSS remains semantic and no-npm; Tailwind is a Trellis-side
  porting tool and consumers receive compiled CSS.
- **ADR-008** – reuses app-first override/local materialization precedents without
  copying the entire four-mechanism theme model.
- **ADR-009** – `trellis_ui` joins lockstep versioning pre-1.0.
- **ADR-010** – assets are generated/self-contained or same-origin vendored; no
  runtime CDN dependency.
- **ADR-011** – HTMX coupling remains outside core and confined to the optional UI
  lifecycle; scaffolds self-host HTMX by default (ADR-011 amendment 2026-10-04), so
  the Relic scaffold meets `script-src 'self'`; the Shelf and Dart Frog scaffolds
  still need `'unsafe-inline'` for their inline CSRF script.
- **ADR-014** – composition primitives are the prerequisite for Tier 1 authoring.
- Aligns with one-version-at-a-time, opt-in complexity, security-by-default,
  HTMX-first, no-npm, pragmatic-escape-hatch, and maintainer-burnout constraints.

## References

- Research – private planning repo, canonical (no public digest yet):
  `docs/research/trellis-ui-component-architecture/` – bundle, `design-tree.md`,
  `tradeoff-matrix.md`, `recommendation.md`, and the 2026-08-15 verification addendum
  (`research.md`); `docs/research/11-trellis-ui-packaging-spike.md`,
  `12-trellis-ui-csp-spike.md`, `13-trellis-ui-behaviour-layer-spike.md`, and
  `14-trellis-ui-seed-reevaluation/` (brief, O5 and O6 spikes, stress sync)
- Spike branches: `spike/trellis-ui-registry-vs-basecoat` (`21f4a5b`),
  `spike/trellis-ui-o6-shadcn-port` (`d30c65e`, Firefox `27b6c3a`),
  `spike/trellis-ui-o5-webawesome` (`d428fd1`)
- [shadcn/ui](https://ui.shadcn.com/) and its
  [style files](https://github.com/shadcn-ui/ui/tree/main/apps/v4/registry/styles)
- [Base UI](https://base-ui.com/)
- [Tailwind CSS standalone CLI](https://tailwindcss.com/blog/standalone-cli)
- [Web Awesome](https://webawesome.com/)
- [UI5 Web Components](https://ui5.github.io/webcomponents/components/)
- [Basecoat](https://basecoatui.com/introduction/)
- [HTMX lifecycle events](https://htmx.org/events/)
- [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/about/introduction/)

## Amendments

- **2026-08-15** – verification round: two-tier catalogue, Basecoat seed delivery,
  constraint clarifications, bounded qualification gate.
- **2026-10-04** – accepted. Delivery model resolved to the embedded package
  (research/11); strict-CSP gate re-scoped to `<style>` element injection and the
  Tier 2 shortlist fixed (research/12); behaviour layer named as light-DOM custom
  elements (research/13); seed changed from vendored Basecoat to a Trellis-owned
  shadcn/ui port with a sync process, public styling surface, and touch-target layer
  (research/14); no-Node rule extended to the Trellis toolchain, with pinned non-Node
  tool binaries allowed for the porting pipeline; Shadow DOM context corrected; Tom
  Select dropped from Tier 2; acceptance decoupled from the first slice.
