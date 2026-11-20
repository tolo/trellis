# Navigation menu

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S05

## Feature Overview and Goal

**Intent**: A public-web author can group site destinations in a header while keeping every link usable with a keyboard and on a page without suite assets.

**Expected Outcomes**:

- [OC01] Readers can open, switch and dismiss navigation panels with a pointer or keyboard.
- [OC02] Site links retain native navigation and current-page semantics with or without enhancement.
- [OC03] The suite can replace an open menu through HTMX and qualify the component under strict CSP.

## Required Context

- `dev/spec/0.15/prd.md#fr5-navigation-menu`
- `dev/spec/0.15/prd.md#non-functional-requirements`
- `dev/spec/0.15/prd.md#edge-cases`
- `dev/spec/0.15/s01-popover-and-shared-positioning.md` for placement and hover timing.
- `dev/PRODUCT.md#proportionality`
- `dev/adrs/ADR-012-trellis-ui-contract.md#porting-pipeline`
- `dev/adrs/ADR-012-trellis-ui-contract.md#htmx-lifecycle`
- `dev/adrs/ADR-012-trellis-ui-contract.md#browser-emulation-fallback`
- `dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate`
- `dev/guidelines/RELEASE-RUNBOOK.md#trellis-ui-release-prep`
- `packages/trellis_ui/tool/pins.json` for the active Base UI source and compiler.

## Acceptance Scenarios

- **S01 [OC01] [runtime] Activating a group opens its panel**
  - **Given** a served Navigation menu with a direct Home link and Guides and Reference groups in a horizontal list where space permits.
  - **When** the reader clicks a closed trigger, presses Enter, Space or Arrow Down on it, or rests the pointer on it past the configured open delay in separate trials.
  - **Then** its native popover opens next to the trigger and the trigger exposes its expanded state. Arrow Down enters the first link. Hover alone leaves focus in place and the panel stays open when the pointer crosses into it. Leaving both closes a pointer-open panel after the close delay if focus is outside it.

- **S02 [OC01] [runtime] A second trigger takes over and Escape returns focus**
  - **Given** the Guides panel is open.
  - **When** the reader focuses Reference or moves the pointer onto it past the open delay, then presses Escape.
  - **Then** Reference replaces Guides as the sole open panel and remains operable after the switch. Escape closes it and leaves focus on Reference without reopening it.

- **S03 [OC02] [runtime] A normal link marks and reaches the current page**
  - **Given** top-level and grouped destination anchors, including a grouped link to the current page under a site path prefix.
  - **When** the reader opens its group and activates a different link with the keyboard.
  - **Then** only the matching anchor had `aria-current="page"` on the original page. Links remain in ordinary Tab order and the browser follows the selected anchor to its destination. A page with no matching link exposes no current-page marker.

- **S04 [OC02] [runtime] Links work before enhancement**
  - **Given** the same server-rendered navigation with JavaScript disabled or with suite asset requests blocked.
  - **When** the reader opens each group and traverses the links with the keyboard.
  - **Then** every direct and grouped destination can be reached as an ordinary link, including the current-page marker when its URL matches.

- **S05 [OC03] [runtime] An open menu cleans up before replacement and history save**
  - **Given** a native popover open in the Navigation menu with CSSOM position and a hover transition pending.
  - **When** HTMX replaces the menu with the same component IDs, or saves it during navigation and restores it on Back.
  - **Then** the old panel closes, temporary state and positioning `style` are absent from replacement or restored markup, and detached triggers and timers leave no active listeners or late UI changes. The new menu responds once to each activation, with zero CSP violations.

- **S06 [OC03] [runtime] Navigation menu qualifies in both browser records**
  - **Given** the served gallery, open and closed appearances, and a manifest covering the ADR-012 automated items.
  - **When** the gate runs in Chrome and Firefox under `script-src 'self'; style-src 'self'`.
  - **Then** CSP violations are zero and each automated item passes under the recorded browser rule. The gate includes forced colours with visible outlines and system colours, both pointer sizes, reflow, zoom, reduced motion and appearance.

## Structural Criteria

- **SC01 [runtime]** The active shadcn Navigation Menu port retains permissive provenance and regenerates the pinned output and embedded assets through the existing no-Node pipeline. Sync hand edits stay within the PRD limits and the package stays within story S01's budgets.
- **SC02** The public reference and package catalogue list the fragment composition. Generated reference metadata derives its support status from the qualification record.

## Scope & Boundaries

### Work Areas

- Pinned Navigation Menu inputs, generated and hand CSS, embedded fragments and small navigation enhancement in `packages/trellis_ui`.
- Served gallery, browser scenarios, manifest, baseline, records and public reference for `navigation-menu`.

### What We're NOT Doing

- Lattice header adoption belongs to story S06. The application action menu and its optional submenu work belong to story S12.

## Architecture Decision

**Approach**: Enhance native disclosures inside a navigation landmark with same-origin light-DOM behaviour, a native popover and the positioning and hover seam from story S01.
**Why this over the floor**: Native disclosures provide the fallback. FR5 also requires delayed hover, switching the active panel, and Escape dismissal with focus restoration.

**Flow**:

- `trellis-ui/navigation-menu :: navigationMenu(label, ...attrs)` accepts a default slot of list items inside a labelled nav. `navigationMenuGroup(id, title, side, align, offset)` yields a list item containing `details` and `summary`, with a default slot for panel links or lists. Group IDs are unique on the page.
- `navigationMenuLink(href, currentUrl, ...attrs)` emits a regular anchor with a default text slot. Callers supply the final destination and current-page URLs in the same path-prefix form. The link compares the two to set `aria-current`.
- Add the popover attribute on enhancement so native disclosure contents stay reachable when the suite fails to load. The wrapper coordinates a single active panel and uses one `hoverIntent()` instance per trigger/panel pair. Use `place()` and `trackPopup()` for placement and cancel pending hover work before snapshot or disconnect.

## Constraints & Gotchas

- A touch activation of a second trigger can produce focus before click. Both target the same open state. Focus on an idle trigger alone must leave a closed menu closed.
- Use ordinary nav and anchor semantics. The action Dropdown Menu's `role="menu"`, roving focus and selection event describe a different interaction.
- The maintainer records VoiceOver with Safari, NVDA with Firefox and the Safari pass at release prep on the integrated feature branch before squash.

## Implementation Plan

### Implementation Tasks

- **TI01** The port reproduces from the active pin within the shared budgets.
  - Follow `packages/trellis_ui/tool/port.dart` and the hand CSS ordering in AGENTS.md. Capture initial adoption separately from a later upstream sync delta.
  - **Verify**: `cmd: dart run packages/trellis_ui/tool/port.dart parity && dart run packages/trellis_ui/tool/port.dart check && dart run packages/trellis_ui/tool/embed.dart --check && cd packages/trellis_ui && dart test test/budget_test.dart test/release_gates_test.dart test/sync_report_test.dart` – slot and class provenance, deterministic generation and embedding, both budgets and the release report's hand-edit limits hold.
  - **SATISFIES**: SC01

- **TI02** The public fragments and enhancement meet the reader and lifecycle contract on the served gallery.
  - Follow `packages/trellis_ui/test/behaviour_browser_test.dart` for a real gallery server. Trigger replacement while the panel remains open, then observe retained old trigger references after swap and let pending timers elapse before checking for late work.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/navigation_menu_browser_test.dart` – run served mixed nav fixtures for S01–S05, including delivery without suite assets and a real swap and history restore under strict CSP.
  - **SATISFIES**: S01, S02, S03, S04, S05

- **TI03** The Navigation menu is an active qualification subject with repeatable browser evidence.
  - Add `navigation-menu` to the release inventory. Keep the three manual entries at `release-prep`. Inspect served-gallery captures and use the existing geometry and accessibility checks.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/gate_records_test.dart test/qualification_gate_test.dart` – release inventory sees the new subject, the gallery replay matches the committed records for Chrome and Firefox, and S06 passes per ADR-012.
  - **SATISFIES**: S06

- **TI04** The reference and catalogue show how to mix top-level links and groups.
  - Include a path-prefixed current-page example and explain the native disclosure fallback. Generate the site data from the qualification record.
  - **Verify**: `cmd: dart run tool/generate_ui_reference.dart --check && cd packages/trellis_ui && dart test test/readme_test.dart` – compare generated metadata and catalogue with the port and record, and read the three fragment signatures in the reference example.
  - **SATISFIES**: SC02

## Discovered Requirements

- **Navigation panels must fit the available width.** S01's shared placement sets
  `--available-width` and `--available-height` on `data-trellis-popup` panels. The width cap became concrete
  when S01 tested horizontal placement at a viewport edge. If the panel has a minimum width, limit it to
  `--available-width` so it can shrink before overflowing. Traced from S01/TI05, 2026-11-20.

- **Shared CSS tokens appear in existing captures.** The component and app gates sample all root custom
  properties. S03's pinned port added two tokens and surfaced the same differences on unrelated components.
  If this port adds root tokens, compare the observed light and dark values from each affected browser
  against the generated CSS. Preserve every existing capture value unless the change is independently
  explained. Traced from S03/TI05, 2026-11-20.

- **Pinned Navigation Menu viewport utilities need a structural exclusion.** The pinned upstream
  activation-direction and easing utilities fail standalone compilation. The corresponding size and
  position animations depend on Base UI's shared viewport. Keep the TSX and Vega paint and use a
  native top-layer panel with the shared placement seam. Traced from TI01, 2026-11-20.

- **Leave the next focused control visible.** At narrow widths a top-layer panel can cover the next focus
  target outside Navigation menu. Close it when focus crosses the landmark boundary and keep focus on its
  destination. Keep the group-switch behavior when focus stays within navigation. Traced from TI03, 2026-11-20.

- **Keep an already-open disclosure usable when the script arrives.** The independent browser review
  opened a group before loading the suite script. On upgrade its links disappeared while the summary
  still announced expanded. Carry open native state into the enhanced panel. Traced from TI02, 2026-11-20.

## Implementation Observations

- The port keeps the pinned Vega paint. Three Base UI structural groups are excluded because
  they depend on a measured viewport or use variants the standalone compiler rejects. Native
  details, popup placement and a summary chevron carry their behavior.
- Enabled Navigation menu in the release inventory at 699 suite-owned JavaScript lines
  and 26,922 gzip bytes. Popover and Tooltip share full-region popup cleanup with Navigation menu.
- The Vega scale utilities register three non-inherited custom properties. Both browser engines
  observed `--tw-scale-x`, `--tw-scale-y` and `--tw-scale-z` as `1` in both skins. Only those
  token entries changed in 36 earlier component and app baselines.
- Visual review caught focus covered by the open panel after Tab and adjacent unstyled links
  without separators. The recheck passed after closing on outside focus and giving the sample
  links native list markup. Code review also reproduced links disappearing when suite JS arrives
  late. A browser test now verifies the open group and its link focus survive upgrade.
- ASSUMPTION: the public shortcode uses page-relative links because it renders before the full
  layout context exists. Revisit if post-Markdown shortcodes receive `site` and `page` objects.
  Both root and prefixed builds mark the intended example link, and the reference explains the
  corresponding prefix-absolute arguments.
- Chrome delivered a new hover on Back when the test cursor stayed over the recreated trigger.
  The history trace confirmed clean restored markup before that new input. The qualification
  setup opens without focus or pointer paint, while native keyboard and pointer interactions have
  their own proofs. Complete catalogue and app-surface replays are pending at plan integration.
- The reference generator previously required every fragment to forward attributes. The fixed-signature
  group leaves its target list empty, while a fragment declaring `...attrs` still needs a receiver.
  A fixture checks both sides of that inventory rule.
