# Tooltip

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S02

## Feature Overview and Goal

**Intent**: Public-web authors can give readers a short hint on an existing control with the same fragment on strict-CSP pages.

**Expected Outcomes**:

- [OC01] Pointer and keyboard users can read and dismiss a hint without losing their place.
- [OC02] Each control keeps its own name and action, and its essential information is available on touch devices.
- [OC03] The embedded Tooltip passes the suite's automated qualification checks.

## Required Context

- `dev/spec/0.15/prd.md#fr2-tooltip`
- `dev/spec/0.15/prd.md#edge-cases`
- `dev/spec/0.15/prd.md#non-functional-requirements`
- `dev/spec/0.15/s01-popover-and-shared-positioning.md#architecture-decision`
- `dev/PRODUCT.md#proportionality`
- `dev/adrs/ADR-012-trellis-ui-contract.md#porting-pipeline`
- `dev/adrs/ADR-012-trellis-ui-contract.md#htmx-lifecycle`
- `dev/adrs/ADR-012-trellis-ui-contract.md#browser-emulation-fallback`
- `packages/trellis_ui/tool/pins.json`
- `dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate`
- `dev/guidelines/RELEASE-RUNBOOK.md#trellis-ui-release-prep`
- [LEA-41](https://linear.app/leafnode/issue/LEA-41/product-requirements-document-trellis-ui-public-web-components-015)

## Acceptance Scenarios

- **S01 [OC01,OC02] [runtime] Hover opens a hint that can be hovered**
  - **Given** an embedded Tooltip on a focusable “Colour mode” control with a top side, space above it and explicit open and close delays.
  - **When** the pointer enters and leaves before the open delay, then returns and stays through the delay, moves from the control onto the hint, leaves both and briefly re-enters during the close delay before leaving for good.
  - **Then** the short pass produces no hint. The sustained pass shows the text above the trigger. The hint stays visible during the crossing and while hovered, then hides after the close delay. Returning before that delay expires cancels the dismissal.

- **S02 [OC01,OC02] [runtime] Keyboard focus describes the same control**
  - **Given** the control has a name and an existing description before the Tooltip mounts.
  - **When** the reader Tabs onto and then away from the control.
  - **Then** the hint opens on focus without waiting for hover. The control has one tab stop, its name and original description remain, and its `aria-describedby` includes the hint's unique ID. The hint has `role="tooltip"` and closes on blur, including when the pointer remains over the former trigger.

- **S03 [OC01] [runtime] Escape dismisses the active hint once**
  - **Given** the active hint opened through focus or through pointer hover alone.
  - **When** the reader presses Escape with focus on the trigger or elsewhere, as applicable.
  - **Then** the hint closes and focus stays where it was. Pending timers and a still-focused or still-hovered trigger do not reopen it. A fresh focus or pointer entry can open it again.

- **S04 [OC02] [runtime] A touch reader can use the control without a hint**
  - **Given** the gallery's control has an independent accessible name and has no hover available.
  - **When** a reader taps it.
  - **Then** the control activates normally and its essential information is available independently of the hint.

- **S05 [OC01,OC03] [runtime] A swap or history restore starts with a closed hint**
  - **Given** a gallery region contains a Tooltip with a pending hover timer or an open CSSOM-positioned hint.
  - **When** real HTMX navigation replaces the region or saves and restores it on Back.
  - **Then** the old timer cannot show a detached hint, saved markup has no temporary positioning style, and the replacement or restored trigger opens and closes one hint per interaction.

- **S06 [OC03] [runtime] Tooltip qualifies in the component sweep**
  - **Given** the served Tooltip gallery loads the embedded suite under `script-src 'self'; style-src 'self'`.
  - **When** the ADR-012 qualification matrix runs in Chrome and Firefox.
  - **Then** all automated items pass under ADR-012's two-browser rule with zero CSP violations and both browser results appear in the tracked record.

## Structural Criteria

- **SC01 [runtime]** The pinned Base UI Tooltip builds through the existing no-Node pipeline, with licence, slot and class provenance. The port stays within the PRD's hand-edit allowance on subsequent syncs.
- **SC02** The reference and catalogue describe the fragment's arguments and trigger slot. The reference explains how to keep essential information available on non-hover devices, and support status derives from the gate record.

## Scope & Boundaries

### Work Areas

- `packages/trellis_ui` Tooltip fragment, hand behaviour, upstream port and embedded assets (TI01–TI02).
- Gallery, release inventory, gate manifest, evidence and records (TI02–TI03).
- Component reference, generated reference data and package catalogue (TI04).

### What We're NOT Doing

- Interactive popup content belongs in story S01's Popover. The Tooltip renders short text.
- Story S06 proves Tooltip stacking and two Escape presses inside Sheet and composes the Lattice consumer.

## Architecture Decision

**Approach**: Port the pinned Tooltip appearance onto a light-DOM element with a native manual popover, sharing the positioning and cancellable hover timing from story S01.
**Why this over the floor**: A `title` attribute cannot provide FR2's keyboard focus, Escape dismissal and hoverable hint.

**Flow**:

- `trellis-ui/tooltip :: tooltip(id, text, side, openDelay, closeDelay)` projects one native, focusable, independently named element through the `trigger` slot. `id` identifies the text hint. The upgrade adds that ID to the slotted element's description tokens. The fragment adds no interactive wrapper. Delays are milliseconds, and explicit zero is valid.
- Register both trigger and hint with S01's hover seam and use its CSSOM placement and lifecycle. The active innermost Tooltip consumes Escape, including when opened by pointer alone, so the enclosing Sheet can receive the next Escape.

## Constraints & Gotchas

- Cancel pending transitions on Escape, blur, disconnect and before history capture. An inactive enclosing modal cannot gain a delayed Tooltip. Keep the pointer hit region usable across the gap between trigger and hint.
- The maintainer records VoiceOver with Safari, NVDA with Firefox and the Safari pass at release prep on the integrated feature branch before squash.

## Implementation Plan

### Implementation Tasks

- **TI01** The current pin reproduces the Tooltip port in the embedded assets.
  - **Verify**: `cmd: dart run packages/trellis_ui/tool/port.dart parity && dart run packages/trellis_ui/tool/port.dart check && dart run packages/trellis_ui/tool/embed.dart --check` – tracked licence and slot/class mappings agree with the active pin and generated output.
  - **SATISFIES**: SC01

- **TI02** The served gallery exercises Tooltip with real input and HTMX.
  - Follow `packages/trellis_ui/test/behaviour_browser_test.dart` for the embedded gallery, local server, position and HTMX checks. Cover omitted delay values with the gallery's default example.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/tooltip_browser_test.dart` – observe S01–S05 with pointer and keyboard input, a native touch tap for S04 (CDP touch input and WebDriver touch pointer actions, verifying pointerType and the activated control; record genuine unsupported emulation per ADR-012), real swaps and Back for S05, and CSP violation collection.
  - **SATISFIES**: S01, S02, S03, S04, S05

- **TI03** Tooltip joins the active component qualification inventory.
  - Use the existing manifest and appearance capture, including open/default states and applicable input and forced-colour checks.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/gate_records_test.dart test/qualification_gate_test.dart test/budget_test.dart test/release_gates_test.dart` – reproduce and validate both browser results and stay within the story S01 suite limits.
  - **SATISFIES**: S06

- **TI04** The catalogue and reference advertise the tested composition and fallback.
  - **Verify**: `cmd: dart run tool/generate_ui_reference.dart --check && git grep -n 'aria-describedby' -- site/content/docs/ui/components/tooltip.md` – the generated support state matches the record, and the reference and package catalogue agree with the signature, trigger slot and non-hover fallback guidance.
  - **SATISFIES**: SC02
