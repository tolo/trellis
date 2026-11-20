# Sheet

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S03

## Feature Overview and Goal

**Intent**: Give site authors a side panel they can use for narrow-screen navigation and other modal content.

**Expected Outcomes**:

- [OC01] A reader can open, navigate and dismiss a labelled Sheet with pointer or keyboard.
- [OC02] A reader stays oriented through navigation, content swaps and nested popups.
- [OC03] The same content stays reachable when the viewport widens or the suite fails to load.

## Required Context

- `dev/spec/0.15/prd.md#fr3-sheet`
- `dev/spec/0.15/prd.md#fr6-theme-and-docs-site-adoption` for the responsive consumer.
- `dev/spec/0.15/prd.md#edge-cases`
- `dev/spec/0.15/prd.md#non-functional-requirements`
- `dev/adrs/ADR-012-trellis-ui-contract.md#browser-emulation-fallback`
- `dev/adrs/ADR-012-trellis-ui-contract.md#porting-pipeline`
- `dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate`

## Acceptance Scenarios

- **S01 [OC01] [runtime] A four-edge panel opens modally and contains focus**
  - **Given** a Sheet has a title, a button trigger and a content slot with a link and an input.
  - **When** a reader opens it with pointer or keyboard for each side (top, right, bottom and left).
  - **Then** the Sheet slides in from the chosen edge, announces its title as a modal dialog and focuses the first eligible element or the title. Tab and Shift+Tab wrap inside it and the page behind it is inert.

- **S02 [OC01] [runtime] Ordinary dismissal restores trigger focus**
  - **Given** a reader has opened a Sheet and moved focus inside.
  - **When** they press Escape, activate Close or click the backdrop in separate trials.
  - **Then** the Sheet closes, the trigger reports collapsed state and focus returns to the trigger.

- **S03 [OC02] [runtime] A link hands focus to its destination**
  - **Given** the Sheet contains a same-page anchor link to a focusable heading and a regular page link.
  - **When** the reader activates either link in separate trials.
  - **Then** the Sheet closes without a focus bounce to its trigger. The heading receives focus and the URL fragment changes for the anchor link, and the other link navigates to its page.

- **S04 [OC01] [runtime] Reduced-motion users receive an immediate state change**
  - **Given** the browser reports reduced motion.
  - **When** the reader opens and dismisses a Sheet.
  - **Then** both state changes complete without a slide animation or a delay before the intended focus move.

- **S05 [OC02] [runtime] An HTMX content update keeps the same modal usable**
  - **Given** focus is inside the Sheet's swappable content.
  - **When** an HTMX request replaces that content and removes the focused element.
  - **Then** the same Sheet stays modal and focus ends up at a usable location inside it. The Sheet still traps focus and dismisses once.

- **S06 [OC02] [runtime] The nested popup dismisses before its Sheet**
  - **Given** a story S01 Popover is open inside an open Sheet.
  - **When** the reader presses Escape twice, then reopens both and dismisses the Sheet with its Close button.
  - **Then** the popup is visually above the Sheet and interactive. The first Escape closes only the popup and returns focus to its trigger. The second Escape closes the Sheet. Closing the Sheet directly also clears the nested popup, so reopening the Sheet starts with the popup closed.

- **S07 [OC03] [runtime] Losing enhancement leaves readable content**
  - **Given** the gallery response includes a Sheet with navigation links.
  - **When** a reader loads it with browser JavaScript disabled, with only the suite script blocked and its stylesheet loaded, or with both suite assets blocked.
  - **Then** the links and content remain visible, keyboard reachable and usable in the normal page flow.

- **S08 [OC03] [runtime] A responsive Sheet becomes static above its configured width**
  - **Given** a Sheet with `inlineAbove=700` is open at 700 px.
  - **When** the viewport widens to 701 px and then narrows back to 700 px.
  - **Then** the modal and its backdrop close on widening and the same content is visible and usable inline. Narrowing restores a closed Sheet with an operable trigger.

## Structural Criteria

- **SC01 [runtime]** The pinned shadcn Sheet port reproduces through the existing no-Node slot/CSS generation and embedding path with licence provenance and the PRD's subsequent sync hand-edit limits.
- **SC02 [runtime]** The served Sheet passes each automated ADR-012 item in Chrome and Firefox under the documented emulation rule, reports zero strict-CSP violations, and measures its Close target at least 24 × 24 px for a fine pointer and 44 × 44 px for a coarse pointer in the final touch layer.
- **SC03 [runtime]** Sharing Sheet and Dialog behavior preserves existing Dialog and Alert Dialog entry points, focus restoration, backdrop rules and HTMX history behavior. The suite stays within the ceilings set by story S01.
- **SC04** The component reference publishes the fragment signature, slots, inline breakpoint semantics, focus behavior and fallback. The catalogue derives support from the gate record.

## Scope & Boundaries

### Work Areas

- Pinned UI port, Sheet fragment, shared Dialog behavior and hand, contrast and touch CSS.
- Served gallery, Sheet browser tests, qualification record and component reference.

### What We're NOT Doing

- Story S06 consumes the Sheet in Lattice and Meadow. Its integration fixture covers the Escape sequence for story S02 Tooltip and story S01 Popover inside the Sheet.
- Story S12 owns normal-motion exit animations. Swipe Drawer is outside 0.15.

## Architecture Decision

**Approach**: Extend the suite's native Dialog behavior with Sheet placement, link dismissal and an optional inline breakpoint.
**Why this over the floor**: Styling the current Dialog as a panel would leave FR3's link-focus transfer and FR6's responsive sidebar behavior to each caller.
**Flow**: `trellis-ui/sheet :: sheet(id, side, title, inlineAbove)` accepts named `trigger` and `content` slots. `inlineAbove` is an optional CSS-pixel threshold. Omitting it gives the same modal behavior on all viewport sizes. The suite manages the breakpoint so both layouts can render one content instance.

## Constraints & Gotchas

- Native dialog closure and the suite's explicit restoration can each move focus. Observe trigger focus events as well as final destination focus in S03. Keep ordinary Dialog's return-focus behavior.
- Exercise a real HTMX response that removes the focused control while preserving the outer dialog. Browser history may save a different region from the swap target.
- The maintainer records VoiceOver with Safari, NVDA with Firefox and the Safari pass at release prep on the integrated feature branch before squash.

## Implementation Plan

### Implementation Tasks

- **TI01** The vendored Sheet and embedded fragment reproduce from the active pin.
  - Follow `packages/trellis_ui/assets/fragments/dialog.html` for the suite's fragment composition. Keep intentional porting differences and licence provenance in the pin’s SOURCE.md, current scan report and parity exceptions.
  - **Verify**: `cmd: dart run packages/trellis_ui/tool/port.dart parity && dart run packages/trellis_ui/tool/port.dart check && dart run packages/trellis_ui/tool/embed.dart --check` – slot/CSS checks include Sheet and committed embedded bytes reproduce.
  - **SATISFIES**: SC01

- **TI02** A Sheet opens with edge placement, focus containment and dismissal appropriate to the action.
  - Share the existing Dialog lifecycle in `packages/trellis_ui/assets/js/50-dialog.js#TlDialog`.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/sheet_browser_test.dart` – gallery interaction covers S01 through S04, including edge geometry, browser focus transitions, destination activation and reduced motion.
  - **SATISFIES**: S01, S02, S03, S04

- **TI03** The Sheet's browser lifecycle preserves usable content through swaps, nested dismissal, enhancement loss and resize.
  - Reuse the real swap test harness from `packages/trellis_ui/test/dialog_browser_test.dart`.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/sheet_browser_test.dart` – assert modal identity and focus after the real swap, popup hit-testing and two-step Escape order, links with script/assets blocked, and the open-narrow/wide/closed-narrow sequence.
  - **SATISFIES**: S05, S06, S07, S08

- **TI04** Existing dialog consumers and suite limits hold.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/dialog_fragments_test.dart test/dialog_browser_test.dart test/budget_test.dart test/release_gates_test.dart` – both existing fragments and browser lifecycles behave as before, and the story stays inside the owned JS and combined gzip budgets.
  - **SATISFIES**: SC03

- **TI05** The Sheet gallery is a reproducible qualification subject with the standard touch layer.
  - Register the manifest, automated record, appearance baseline and release subject. Initialise the manual items to `release-prep`.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/gate_records_test.dart test/qualification_gate_test.dart` – the Sheet record replays in both browsers, strict CSP reports zero violations and measured Close dimensions meet SC02 in fine and coarse modes.
  - **SATISFIES**: SC02

- **TI06** The component reference and catalogue describe the shipped Sheet.
  - **Verify**: `cmd: dart run tool/generate_ui_reference.dart --check` – the Sheet's published fragment contract and catalogue status match its fragment and gate record. Read the authored reference for the inline, focus and fallback guidance in SC04.
  - **SATISFIES**: SC04

## Discovered Requirements

- **Title** Keep the stylesheet-free fallback in normal flow. **Description** Render the Sheet body as a labelled section and move its existing children into a native dialog on enhancement. **Rationale** Browsers position `<dialog open>` absolutely without author CSS. **Interpretation** The server sends one set of links and controls. Enhancement supplies native modal behavior, and the inline breakpoint keeps the same nodes. **Traced from** TI03. **Date** 2026-11-20.

## Implementation Observations

- ASSUMPTION: Omitting or supplying an unrecognised side selects `right`, the pinned Vega default. Optional attributes go to the panel, following the suite convention.
- ASSUMPTION: Ordinary link activation dismisses the Sheet. A modified click leaves it open while the browser handles the link.
- Sheet is in the automated release inventory. ADR-012 still governs which subjects may have a recorded disposition. Its three manual items remain at release prep.
- A text-only HTMX swap has no element to emit `htmx:afterSettle`. The reviewed focus recovery observes actual child removal inside the modal. Routing: Fix applied.
- Where author markup supplies positive `tabindex`, the shared Dialog calculation uses sequential focus order for wrap boundaries. Routing: Fix applied.
- The visual review found a 34 px gap at the end of top and bottom sheets, caused by the native dialog width cap. The repaired geometry proof checks the full edge span. Routing: Fix applied.
- To retain a list or navigation element supplied in the named content slot, place it inside `<tl:block tl:slot="content">`. The live reference checks its two list links and their 44 px targets. S06 can use the same composition for its theme navigation.
- P3 gallery spacing. At 390 and 699 px the related-pages launcher touches the row above it. Both buttons retain distinct borders and hit areas. Routing: Note.
- The pinned Sheet styles add `--container-sm` and `--ease-in-out` to the shared theme. The browser gate captures all root tokens, including on existing components and app routes. The observed additions update each affected capture mode without changing existing values.
- The Sheet appearance recipe establishes visible keyboard focus on its first link before capturing the active panel. Firefox otherwise varied incidental link focus paint while measuring the inert background trigger. Routing: Fix applied.
