# Popover and shared positioning

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S01

## Feature Overview and Goal

**Intent**: Public-web authors can attach interactive panels to controls without writing positioning or dismissal code under a strict CSP.

**Expected Outcomes**:

- [OC01] Readers can open, use and dismiss a visible panel at any edge, including after a viewport change.
- [OC02] An author can compose a Popover from embedded fragments and use it with HTMX under strict CSP.
- [OC03] Maintainers can prove Popover belongs in the shipped catalogue on the same release path as the existing suite.
- [OC04] Card readers see only the title, description and body copy the author supplies.

## Required Context

- `dev/spec/0.15/prd.md#fr1-popover-and-shared-positioning`
- `dev/spec/0.15/prd.md#in-scope`
- `dev/spec/0.15/prd.md#non-functional-requirements`
- `dev/spec/0.15/prd.md#edge-cases`
- `dev/spec/0.15/prd.md#decisions-log`
- `dev/PRODUCT.md#proportionality`
- `dev/adrs/ADR-012-trellis-ui-contract.md#porting-pipeline`
- `dev/adrs/ADR-012-trellis-ui-contract.md#htmx-lifecycle`
- `dev/adrs/ADR-011-htmx-version-policy.md#amendment-2026-09-04-version-agnostic-adapters-pin-unchanged`
- `dev/adrs/ADR-012-trellis-ui-contract.md#tier-2-vetting`
- `dev/adrs/ADR-012-trellis-ui-contract.md#browser-emulation-fallback`
- `dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate`
- `dev/guidelines/RELEASE-RUNBOOK.md#trellis-ui-release-prep`

## Acceptance Scenarios

- **S01 [OC01,OC02] [runtime] Public fragment opens on the served gallery route**
  - **Given** the embedded Popover renders an “Options” button and an interactive panel in a real same-origin gallery page with `script-src 'self'; style-src 'self'` and space around the trigger.
  - **When** the reader activates the button by click, Enter or Space in separate trials.
  - **Then** the native top-layer panel opens at its configured side, alignment and offset, focus moves inside it, and the trigger exposes expanded state with zero CSP violations. A size and position check observes the actual panel box.

- **S02 [OC01] [runtime] Dismissal returns focus**
  - **Given** the reader is using a Popover panel.
  - **When** the reader presses Escape or clicks outside it, including on a focusable control.
  - **Then** the panel closes, the trigger exposes collapsed state and the trigger has focus.

- **S03 [OC01] [runtime] Edge placement flips and clamps**
  - **Given** a panel that can fit on each requested side when there is room.
  - **When** it opens near each corresponding viewport edge, then the reader scrolls or resizes until neither side can contain the natural panel size.
  - **Then** it first opens on the opposite side, stays attached as the trigger moves and remains within the viewport when neither side fits. An oversized panel scrolls internally and regains its natural placement and size when room returns.

- **S04 [OC02] [runtime] Real HTMX history and swap remove transient positioning**
  - **Given** an open, positioned Popover in an HTMX region.
  - **When** a real HTMX swap removes its trigger, or a history-enabled request saves the region and Back restores it.
  - **Then** the old panel closes and HTMX's saved markup has no positioning `style` attribute. Restored or replacement markup starts closed without `style`. The new trigger opens its own panel once, with zero CSP violations.

- **S05 [OC02] [runtime] Script loss leaves a visible trigger and a hidden panel**
  - **Given** a served gallery page loads without JavaScript.
  - **When** the reader visits and activates the trigger.
  - **Then** the trigger remains visible and the panel stays hidden.

- **S06 [OC03] [runtime] Popover qualifies under the existing browser rule**
  - **Given** the Popover gallery exercises all applicable ADR-012 automated items.
  - **When** the qualification gate runs in Chrome and Firefox.
  - **Then** each item has a passing browser and a pass or documented unsupported emulation in the other, all CSP observations pass, and both browser records can be reproduced in the component sweep.

- **S07 [OC04] [runtime] Omitted Card slots contribute no demo text**
  - **Given** a consumer uses `trellis-ui/card :: card()` with the named title “On this page” and an anonymous paragraph, and omits the description.
  - **When** the public loader renders it with the suite stylesheet in a browser.
  - **Then** its visible text contains exactly the supplied heading and paragraph, in order. A body-only Card shows just its body and a title-only Card shows just its heading. The filled Card on `/components/card` shows its supplied title, description, body and footer in order. Each supplied title is an `h2`.

## Structural Criteria

- **SC01** ADR-012 records the 0.15 Tier 2 shortlist and pins, pristine-markup restore and remount rule, native date and Cally decision with Calendar revisit trigger, CSSOM positioning and revised JS estimate. Record the amendment before raising either gate ceiling.
- **SC02 [runtime]** The existing budget check enforces at most 700 owned JS lines and excludes app-owned recipe glue.
- **SC03 [runtime]** The existing payload check enforces at most 30,000 bytes across level-9 gzip of the three separate embedded suite responses.
- **SC04 [runtime]** The pinned Base UI Popover goes through the existing no-Node pipeline to embedded assets with licence and slot/class provenance. Keep subsequent sync within the PRD hand-edit limits.
- **SC05 [runtime]** Existing Dropdown Menu and Combobox preserve their default placement and lifecycle. The shared hover delay cancels opposite pending transitions and can be cleared when an instance disconnects.
- **SC06 [runtime]** Popover joins the required release subjects. A failed manual item blocks release, and neither an unsupported nor a removed disposition can waive it. Record each manual item as `release-prep` until the maintainer runs it.
- **SC07** The reference includes the fragment signature and navigation fallback guidance. The suite guide identifies HTMX 2.0.10 as the qualified runtime for interactive swap, error and history handling. Support status derives from recorded manual outcomes.

## Scope & Boundaries

### Work Areas

- ADR-012, release runbook, and system architecture's embedded UI section.
- Pinned Popover source, generation, hand layers and embedded output in `packages/trellis_ui`.
- Shared popup positioning and hover delays, Popover fragment and real browser proof.
- Popover gallery, qualification policy, manifest, records, appearance baseline and component reference.

### What We're NOT Doing

- Tooltip and Navigation Menu interactions belong to stories S02 and S05. Nested Sheet Escape order belongs to story S03. Story S09 owns the Cally example and its runnable recipe.
- Tier 1 Calendar port, 0.16 integrations and overlay exit animations are outside this slice. See the PRD's Scope and story S12.

## Architecture Decision

**Approach**: Use a light-DOM wrapper and the native Popover API with the suite's CSSOM placement and HTMX cleanup.
**Why this over the floor**: Documenting the existing Dropdown Menu would leave authors without FR1's focusable content slot and four-sided placement.

**Flow**:
- `trellis-ui/popover :: popover(id, side, align, offset)` takes named `trigger` and `content` slots. The trigger is a button. Activation comes from the upgrade so it does not toggle a panel when the suite is absent.
- `place(anchor, popup, {side = 'bottom', align = 'start', offset = 4} = {})` and `TlElement.trackPopup(anchor, popup, options)` use CSSOM. Sides are `top`, `right`, `bottom`, `left`, and alignment is `start`, `center`, `end` across the perpendicular axis. Existing callers omit options. Keep their resolved `data-side`, `data-align`, `--anchor-width`, `--available-height` and transform-origin contract.
- `hoverIntent({open, close, openDelay, closeDelay})` returns `{enter, leave, cancel}`. A consumer wires both trigger and popup to the same instance and calls `cancel` on disconnect. Delays in milliseconds come from the consumer.

## Constraints & Gotchas

- Native light dismissal can precede the HTMX request. Make the swap proof remove the anchor while the panel is still open. Test real history restoration as well as cleanup at the event.
- Measure placement from natural dimensions before applying a new cap so previously clipped boxes can grow again. Position writes use CSSOM, and persisted/restored markup cannot carry their attributes.
- The component story adds its upstream TSX to the current pin, runs `port.dart fetch` and `build`, and verifies the generated SOURCE.md, scan report and parity against that TSX. A tag-to-tag sync rejects the current tag. Its checked report is historical evidence; later real syncs measure the hand-edit allowance. Follow the existing standalone-CLI pipeline and use the hand CSS ordering in AGENTS.md.
- The maintainer records VoiceOver with Safari, NVDA with Firefox and the Safari pass at release prep on the integrated feature branch before squash. A Popover failure blocks release and requires rerunning the affected dependents. The maintainer records the upstream sync disposition signoff in the applicable sync report.

## Implementation Plan

### Implementation Tasks

- **TI01** ADR-012 records the approved 0.15 policy.
  - Include Cally 0.9.2. Record Tabulator 6.7.1, Uppy 6.0.8 and FilePond 4.32.14 as candidates for later recipes, with the latter's Chrome-only evidence. Retain AG Grid Community 36.3.0 as the legacy/noStyle grid fallback. Source is the 2026-11-18 research provenance in the PRD. Record the Cally/date and Calendar promotion decisions, exact-pin and checksum expectations, and the 600-line estimate separately from the enforced ceiling.
  - **Verify**: `inspect: dev/adrs/ADR-012-trellis-ui-contract.md:381` – all SC01 decisions and their evidence limits are recorded before TI02 and TI03.
  - **SATISFIES**: SC01

- **TI02** Owned behaviour budget counts the same suite inputs with the agreed ceiling.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/budget_test.dart` – the 700-line cap counts existing authored JS sources, excluding app recipe sources.
  - **SATISFIES**: SC02

- **TI03** The Testing Strategy’s UI qualification section and the release payload gate use the new JS and payload limits. The gate measures the current three embedded responses at the agreed ceiling.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/release_gates_test.dart` – gzip level 9 total ≤ 30,000 bytes.
  - **SATISFIES**: SC03

- **TI04** The new fragment and stylesheet reproduce from the active pin through embedding.
  - Update the package catalogue and `dev/architecture/system-architecture.md#embedded-ui-delivery-014` for the extended popup subsystem and bump its Current through marker.
  - **Verify**: `cmd: dart run packages/trellis_ui/tool/port.dart parity && dart run packages/trellis_ui/tool/port.dart check && dart run packages/trellis_ui/tool/embed.dart --check && (cd packages/trellis_ui && dart test test/sync_skill_test.dart)` – check the active tag-transition report against its inventory; Popover slot provenance and generated CSS/embedded bytes agree with the pinned inputs and committed source.
  - **SATISFIES**: SC04

- **TI05** The shared placement seam and hover-delay cancellation preserve existing consumers.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/behaviour_browser_test.dart` – cover the existing no-options positioning and cleanup tests plus open/close cancellation and disconnect of a pending hover transition through the gallery browser harness.
  - **SATISFIES**: SC05

- **TI06** The served Popover exercises the full reader and HTMX lifecycle.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/popover_browser_test.dart` – run real gallery DOM, keyboard/pointer, viewport, actual HTMX requests and fallback checks for S01–S05, using the gallery harness from `test/behaviour_browser_test.dart`.
  - **SATISFIES**: S01, S02, S03, S04, S05

- **TI07** The gallery subject joins required qualification with tracked dual-browser evidence.
  - Add the manifest, reviewed appearance baseline and records. Mirror required status in the ADR-012 disposition section and release runbook. Add a Popover specific failed-manual and forbidden-disposition assertion to the required-component test.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/gate_records_test.dart test/readme_test.dart test/qualification_gate_test.dart` – inventory and package catalogue include Popover, its automated record reproduces the two-browser observations, and a failed manual item with either proposed disposition still blocks release.
  - **SATISFIES**: S06, SC06

- **TI08** The public reference displays Popover composition and its fallback limit.
  - In the suite guide distinguish ADR-011's version-agnostic server request helpers from the client lifecycle. The gallery uses HTMX 2.0.10. Open-popup replacement and remote Combobox failures use `htmx:beforeSwap` and `htmx:responseError`; HTMX 4.0.0 emits `htmx:before:swap` and `htmx:response:error`. Those 4.x interactions are unqualified. Studio reproduced a remote Combobox HTTP 500 in Chromium with 0.14: on HTMX 2.0.10 it settles and announces “No results”; on HTMX 4.0.0 with error swaps cancelled it stays searching, with a closed popup and empty live region. Record that observed difference separately from the untested 4.x open-popup replacement. Static fragments have no dependency on those events.
  - **Verify**: `cmd: dart run tool/generate_ui_reference.dart --check && git grep -n -e '2.0.10' -e 'htmx:before:swap' -e 'htmx:response:error' -- site/content/docs/ui/guide.md` – check inventory and support state, then read the fallback and the interactive runtime boundary beside the installation instructions.
  - **SATISFIES**: SC07

- **TI09** Remove the three demo strings from the Card fragment’s slot fallbacks and regenerate the embedded package assets. Keep gallery copy in `gallery/pages/card.html` and preserve public part hooks.
  - **Verify**: `cmd: cd packages/trellis_ui && dart run tool/embed.dart --check && CI=true dart test test/css_only_components_test.dart test/css_only_browser_test.dart` – assert the three partial Cards’ exact visible text through the exported loader. On the served gallery Card, assert “Project details”, “A card with named slots.”, “All data stays on your server.” and “Updated today” in order. Assert `h2` for every supplied title and retain the filled-gallery layout check.
  - **SATISFIES**: S07

## Discovered Requirements

- **Title** Unobscured sequential focus. **Description** Close the panel when Tab or Shift+Tab moves focus
  out of it and preserve the browser's new focus. **Rationale** Independent visual review found the focused
  gallery link fully covered by the open panel, failing WCAG 2.2 AA 2.4.11. **Interpretation** Native traversal
  continues at the surrounding control. Escape and pointer light dismissal still return to the opener.
  **Traced from** TI06. **Date** 2026-11-20.
- **Title** Compact title in the reference preview. **Description** Retain the suite's Popover title typography
  in the live example. **Rationale** Visual review found Lattice's document heading font and size leaking into
  the panel. **Interpretation** Reset typography only inside the preview, preserving the Lattice headings around
  it. **Traced from** TI08. **Date** 2026-11-20.

## Implementation Observations

- ASSUMPTION: Popover forwards caller attributes to its panel and exposes the three shadcn content helpers as
  anonymous-slot fragments, following the suite catalogue and the pinned port's slot parity. Revisit the helpers'
  signatures if compositions need a separate trigger attribute target.
- Firefox focuses the destination of a same-document link after native light dismissal. Popover restores the
  trigger after the hash change with `preventScroll`, preserving the link's URL and scroll behavior.
- The shared positioning seam publishes `--available-width` as well as `--available-height`. Consumers using
  `data-trellis-popup` inherit both caps. A horizontal popup with a minimum width must keep that rule compatible
  with the available-width cap.
- The hover-intent helper remains internal. The gallery-browser probe exercises its callbacks and lifecycle before
  Tooltip and Navigation menu adopt it.
- The trigger can be an HTMX swap target by itself. Popover closes before losing that anchor and uses a live
  trigger lookup for later clicks, focus and positioning. Closed state is reflected before history serialization,
  while open state is reflected after the native opening succeeds.
- Hiding an empty Card title preserves its part hook and keeps an unnamed `h2` out of heading navigation.
- The viewport-recovery proof waits for placement animations after the scrollbar disappears. Chrome
  reported an intermediate 152.58 px rendered box with three animations running and a 164 px layout
  height, then rendered the expected 164 px box after they finished.
