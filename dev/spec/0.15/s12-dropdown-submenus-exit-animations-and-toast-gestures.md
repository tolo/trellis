# Dropdown submenus, exit animations and toast gestures

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S12

## Feature Overview and Goal

**Intent**: Let authors offer grouped commands, visible overlay dismissals and touch-friendly notifications without app-specific interaction code.

**Expected Outcomes**:

- [OC01] A reader can enter a group of dropdown commands and return to the same place in the parent menu.
- [OC02] Overlays show a short exit to readers who accept motion while dismissal still hands off focus correctly.
- [OC03] A reader can distinguish and dismiss one of several notifications.
- [OC04] Maintainers can reproduce the qualification evidence for every subject this work changes.

## Required Context

- `dev/spec/0.15/prd.md#fr11-014-unported-behaviour`
- `dev/spec/0.15/prd.md#mvp-boundary`
- `dev/spec/0.15/prd.md#non-functional-requirements`
- `dev/spec/0.15/prd.md#edge-cases`
- `dev/spec/0.15/s01-popover-and-shared-positioning.md#architecture-decision`
- `dev/spec/0.15/s03-sheet.md#acceptance-scenarios`
- `dev/adrs/ADR-012-trellis-ui-contract.md#htmx-lifecycle`
- `dev/adrs/ADR-012-trellis-ui-contract.md#browser-emulation-fallback`
- `dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate`
- `dev/guidelines/RELEASE-RUNBOOK.md#trellis-ui-release-prep`

## Acceptance Scenarios

- **S01 [OC01] [runtime] A submenu opens and closes one level at a time**
  - **Given** a focused dropdown menu item opens a submenu whose first eligible command follows a disabled item.
  - **When** the reader presses Arrow Right, then closes the submenu with Arrow Left or Escape in separate trials.
  - **Then** the submenu opens beside its trigger, exposes its expanded state and focuses its first eligible command. Closing it returns focus to the submenu trigger in the still-open parent, and a second Escape closes the parent.

- **S02 [OC01] [runtime] Submenu controls work with pointer and keyboard**
  - **Given** a dropdown includes plain items, a checkbox item and a submenu trigger.
  - **When** the reader opens the submenu by click, Enter or Space and navigates its commands, then activates one.
  - **Then** navigation stays within the active menu level. The submenu trigger expands without selecting a command, and the activated command sends the normal selection event once. Existing plain and checkbox selections keep their behaviour.

- **S03 [OC02] [runtime] Each overlay plays its exit before hiding**
  - **Given** a Dialog, Sheet, Popover or Dropdown Menu is open under ordinary motion.
  - **When** it is dismissed by its ordinary close action, including native Escape or outside dismissal where applicable.
  - **Then** a visible exit runs to completion before the overlay hides. The closing surface stops accepting interaction, and focus reaches its existing return target. A Sheet link retains its navigation or anchor focus handoff.

- **S04 [OC02] [runtime] Reduced motion closes each overlay immediately**
  - **Given** the browser emulates reduced motion with the same four overlays.
  - **When** the reader dismisses each one.
  - **Then** the overlay hides without an exit animation or a delay in focus handoff.

- **S05 [OC01,OC02] [runtime] Navigation and reopen clear an interrupted exit**
  - **Given** a dropdown with an open submenu or a nested Popover in a Sheet, including an overlay already closing.
  - **When** rapid reopen interrupts a close, or a real HTMX swap or history save removes or snapshots the region.
  - **Then** a reopened overlay stays open and usable. Replaced or restored markup has no stale open state, transient CSSOM attributes or leftover exit layer. Escape closes only the innermost open popup before closing the Sheet.

- **S06 [OC03] [runtime] A rightward swipe dismisses the touched toast**
  - **Given** three individually reachable toasts, including real HTMX out-of-band inserts in the existing viewport.
  - **When** the reader swipes one to the right, toward the edge where the toasts are stacked.
  - **Then** only that toast disappears, and the others continue to stack without overlap. The close buttons, timer and pause-on-hover or focus still work independently.

- **S07 [OC03] [runtime] Scrolling or cancelling a gesture leaves the toast available**
  - **Given** a reader touches a toast.
  - **When** they scroll vertically, swipe left, make a short movement or cancel the pointer.
  - **Then** the toast stays visible, any temporary swipe position clears and normal interaction resumes.

- **S08 [OC04] [runtime] The current release gate accepts the updated subjects**
  - **Given** the affected subjects include the new interactions on real gallery routes and existing composed app routes.
  - **When** the automated component and app sweeps run in Chrome and Firefox.
  - **Then** each applicable gate item qualifies per ADR-012 and the changed surfaces produce zero strict-CSP violations. The gate reproduces each updated record.

## Structural Criteria

- **SC01** Keep the existing public fragment calls and toast viewport contract. The component reference documents how to compose a submenu and use swipe and motion preferences.
- **SC02 [runtime]** Submenu slots and hooks match the pinned port inventory. Preserve the rationale for each retained upstream exception, and keep the embedded assets reproducible within the S01 suite budgets.
- **SC03** Each changed subject's three manual entries are reset to `release-prep`, with prior pass evidence cleared.

## Scope & Boundaries

### Work Areas

- Dropdown fragments and runtime (TI01, TI04).
- Dialog, Sheet, Popover and Dropdown Menu close paths, styles and real browser interactions (TI02, TI03).
- Toast gestures on the current viewport and toast lifecycle (TI05).
- Pinned parity, embedding, reference, changelog and gate records (TI04, TI06, TI07).

### What We're NOT Doing

- Swipe Drawer, a replacement toast manager or hover-triggered dropdown submenus. Retain the existing viewport stack and component lifecycle.
- FR11 is the first release cut. Stories S01–S06 ship independently.

## Architecture Decision

**Approach**: Extend the existing dropdown, overlay and toast implementations. Reuse S01 placement for submenu panels, S03 modal semantics for Sheet and the toast viewport's CSS grid for stacking. Keep exit presentation separate from logical dismissal so native focus and HTMX cleanup stay immediate.

## Constraints & Gotchas

- Scope dropdown focus traversal and selection to the active menu. The current descendant-wide item query would also include hidden submenu items.
- Treat HTMX removal and snapshot preparation as immediate teardown. Only user dismissal animates. A close or animation completion for an older open cycle cannot hide a popup that has reopened. Native close paths need the same proof as suite button handlers.
- The pinned shadcn `cn-toast` structural skip exists for styles that rely on Base UI-managed absolute stacking and swipe variables. The Trellis grid already has the stack. Retain the skip for that structure and update its rationale to reflect Trellis-owned gestures.
- The maintainer records VoiceOver with Safari, NVDA with Firefox and the Safari pass at release prep on the integrated feature branch before squash.

## Implementation Plan

### Implementation Tasks

- **TI01** The dropdown supports submenu composition and level-local navigation using `packages/trellis_ui/assets/fragments/dropdown-menu.html` and S01 placement.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/menu_tabs_toast_fragments_test.dart test/behaviour_browser_test.dart` – assert legacy rendering and selection together with submenu trigger/panel relations, keyboard and pointer entry, first eligible focus and level-local closure.
  - **SATISFIES**: S01, S02

- **TI02** The four overlays distinguish exit presentation from logical closure.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/overlay_exit_browser_test.dart` – exercise the served gallery in Chrome and Firefox, measure a visible running exit and hidden final state in normal motion, then test immediate hiding with reduced motion. Sample focus and hit testing and exercise native, explicit and Sheet link dismissals.
  - **SATISFIES**: S03, S04

- **TI03** Resuming or tearing down overlays clears transient close work.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/overlay_exit_browser_test.dart test/dialog_browser_test.dart test/behaviour_browser_test.dart` – drive rapid reopen and genuine HTMX swap/history while a submenu or modal popup is open and during exit. Assert fresh state, the nested Escape sequence and existing focus recovery.
  - **SATISFIES**: S05

- **TI04** The port and shipped assets account for the submenu additions and retained toast exception.
  - Retire the submenu slot/hook misses in `packages/trellis_ui/tool/parity-ignore.json` for the parts now implemented. Regenerate the current scan report and slot parity. Preserve the previous tag-transition report and inventory for the upstream revision they describe.
  - **Verify**: `cmd: dart run packages/trellis_ui/tool/port.dart parity && dart run packages/trellis_ui/tool/port.dart check && dart run packages/trellis_ui/tool/embed.dart --check && (cd packages/trellis_ui && dart test test/budget_test.dart test/release_gates_test.dart)` – pinned hooks and slots, rebuilt assets and both existing suite ceilings pass.
  - **SATISFIES**: SC02

- **TI05** Each toast can be swiped independently and keeps its other dismissal paths.
  - Follow the real OOB tests in `packages/trellis_ui/test/toast_browser_test.dart`. Exercise the served gallery with native touch input in Chrome (CDP touchStart/move/end) and Firefox (WebDriver pointer actions with pointerType touch). Verify the browser receives a touch pointer. Register a successful drag and a short or cancelled drag as gesture-specific gate evidence. Only a demonstrated unsupported emulation can use the ADR-012 fallback.
  - **Verify**: `cmd: cd packages/trellis_ui && CI=true dart test test/toast_browser_test.dart test/qualification_gate_test.dart` – require both browser gesture records. Compare toast identities and stack geometry after a rightward swipe removes one toast and after a leftward swipe removes none. Cover scrolling, cancellation and the existing button, timer, live-region and history behaviour.
  - **SATISFIES**: S06, S07

- **TI06** Current gallery and app evidence incorporates the changed interactions and leaves manual results to release prep.
  - Refresh the Dropdown Menu, Dialog, Sheet, Popover and Toast records and applicable composed routes. Rerun Alert Dialog and any other shared-path consumers when their primitive changes. Reset manual entries only for subjects with changed markup or behaviour, since the recorder normally preserves those entries.
  - **Verify**: `cmd: (cd packages/trellis_ui && dart test test/qualification_gate_test.dart test/release_prep_test.dart) && (cd packages/trellis_cli && dart test test/ui_surfaces_gate_test.dart)` – both browser sweeps qualify and reproduce the updated records. Read the changed records to confirm the three manual statuses and cleared evidence.
  - **SATISFIES**: S08, SC03

- **TI07** Existing callers and the documented component contract cover the new behavior.
  - Update relevant component pages and the `trellis_ui` changelog. Include a copyable submenu example and the toast swipe and overlay motion behaviour.
  - **Verify**: `cmd: dart run tool/generate_ui_reference.dart --check && (cd packages/trellis_ui && dart test test/menu_tabs_toast_fragments_test.dart test/dialog_fragments_test.dart)` – generated catalogue and legacy fragment rendering agree. Read the component reference against the served examples.
  - **SATISFIES**: SC01

## Discovered Requirements

- **Submenus must fit the available width.** S01's shared placement sets
  `--available-width` and `--available-height` on `data-trellis-popup` panels. The width cap became concrete
  when S01 tested horizontal placement at a viewport edge. If the panel has a minimum width, limit it to
  `--available-width` so it can shrink before overflowing. Traced from S01/TI05, 2026-11-20.
- **Keep the focus handoff during Popover exit.** S01’s browser review found that Tab could focus a link
  hidden behind an open panel. Keep the next control focused when Tab leaves, restore the trigger on Escape
  or pointer light dismissal, and preserve same-document link navigation. Exit presentation must preserve
  these observed focus paths. Traced from S01/TI06, 2026-11-20.

- **Dismiss through the enhanced Sheet dialog.** S03 found that a server-rendered open dialog leaves normal
  flow without CSS. Sheet now moves the slotted children of its fallback section into a dialog on enhancement.
  Apply exit presentation to that live modal. Link navigation must keep destination focus without bouncing
  through the trigger. Keep node removal and history teardown immediate.
  Traced from S03/TI03, 2026-11-20.
