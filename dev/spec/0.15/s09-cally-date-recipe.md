# Cally date recipe

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S09

## Feature Overview and Goal

**Intent**: Give authors a reproducible calendar and range recipe that keeps date entry usable under strict CSP and through HTMX navigation.

**Expected Outcomes**

- [OC01] An author can follow the native-first Input reference to vendor the pinned, unaudited picker and apply the HTMX lifecycle to an integration.
- [OC02] An admin reader can save dates through the picker or the native fields and see saved dates after history navigation.
- [OC03] The admin contact form and recipe meet the existing app gate with the same strict policy in Chrome and Firefox.

## Required Context

- `dev/spec/0.15/prd.md#fr8-tier-2-recipe-seam-and-date-recipe`
- `dev/spec/0.15/prd.md#decisions-log`
- `dev/adrs/ADR-012-trellis-ui-contract.md#tier-2-vetting`
- `dev/adrs/ADR-012-trellis-ui-contract.md#htmx-lifecycle`
- `dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate`
- `dev/guidelines/RELEASE-RUNBOOK.md#trellis-ui-release-prep`
- `dev/architecture/system-architecture.md#htmx-fragment-pattern`
- `dev/spec/0.15/s01-popover-and-shared-positioning.md#architecture-decision` for the Popover contract.
- `dev/spec/0.15/s08-native-date-field.md#architecture-decision` for the Input reference anchor.
- [LEA-41](https://linear.app/leafnode/issue/LEA-41/product-requirements-document-trellis-ui-public-web-components-015)

## Acceptance Scenarios

- **S01 [OC01] The Input reference leads from native fields to the recipe**
  - **Given** an author needs a calendar or date range.
  - **When** they read the Date fields section of the Input reference.
  - **Then** they find the native input first, then working examples of single date and two-input range enhancement, the exact Cally version and SHA-256, and the steps to mount, clean up, restore pristine markup and remount around HTMX history. The page states Cally has no audited accessibility programme and that upstream's last recorded screen-reader testing was April 2024.

- **S02 [OC02] [runtime] Single date and range save from the contact dialog**
  - **Given** the admin form arrives in an HTMX swap and the same-origin Cally module has loaded.
  - **When** a reader opens each Popover, selects a single date and a range, then saves.
  - **Then** `2026-11-18`, `2026-11-23` and `2026-11-27` reach the normal form handler as three named date values. Reopening Edit returns all three in server-rendered input attributes and seeds both calendars from those values. With the recipe configured for `sv-SE` and first day `1`, the rendered calendar labels are Swedish and the first weekday is Monday.

- **S03 [OC02] [runtime] Browser Back and Forward remount from saved markup**
  - **Given** a reader has saved the dates from S02, reopened Edit and picked a different date without saving.
  - **When** the reader dismisses the picker, cancels Edit, then activates the list’s sort link and uses Back and Forward. Cancel leaves the closed dialog’s form in the DOM. Exercise two distinct cached list URLs.
  - **Then** cached recipe markup holds the original server-rendered inputs with the saved values, with no mounted Cally DOM, transient popup state or positioning styles. The live dialog recipe left outside the list target remounts after the snapshot. Back and Forward each restore the saved input values and one mounted calendar per field before any new Edit request. Prove each restored recipe from its saved input attributes and mounted elements before another Edit fetch. Through the normal Edit action, confirm that a reader can select a different date exactly once. With the history entry deliberately evicted, the server returns the contact list and a fresh Edit shows all three saved values and a working picker.

- **S04 [OC02,OC03] [runtime] A vendor 404 leaves both modes usable**
  - **Given** the Cally module URL returns HTTP 404 while the real admin app and HTMX load.
  - **When** the reader enters a single date and two range endpoints in the contact form and saves.
  - **Then** the three labelled native controls are usable, the form submits all three values through the same route, and reopening Edit shows the saved values. Calendar-only controls stay hidden.

- **S05 [OC03] [runtime] Date states pass the served admin gate**
  - **Given** the actual admin route uses `script-src 'self'; style-src 'self'`.
  - **When** Chrome and Firefox exercise the date states, including both open calendars and the history journey.
  - **Then** each browser records zero CSP and axe violations. The picked and restored states keep their visible focus targets and fit the admin viewport, and the existing automated app checks continue to qualify.

## Structural Criteria

- **SC01 [runtime]** The example serves Cally 0.9.2's unchanged `package/dist/cally.js` and its MIT notice from app-owned static assets. The served module SHA-256 is `4dcba6a3b8ec63b66ff2fbfc6cf47b7dee1eb4896eac89fe7487d82e28e15870`. The source archive is `https://registry.npmjs.org/cally/-/cally-0.9.2.tgz`, SHA-256 `b09eb28d713b8798eaca028916755230e517766112d1803086bf958bbb292adb`.
- **SC02** The admin footprint check admits only the new pinned asset and its recipe module alongside the existing HTMX asset. Preserve the app CSS limit and all existing strict-clean template checks. Suite source and embedded budgets exclude the recipe.
- **SC03** System Architecture documents the Tier 2 download, app delivery and HTMX lifecycle seam and records the change in its Current through marker. The existing app gate record tracks real browser evidence and resets the three manual items after the contact markup change.

## Scope & Boundaries

### Work Areas

- Admin static assets, base template, and footprint and deployment checks (TI01).
- Existing contact draft, validation, create and edit form, HTTP tests and app recipe module (TI02–TI03).
- Existing admin browser and app qualification harnesses (TI03–TI04).
- Input reference and architecture documentation (TI05).

### What We're NOT Doing

- A suite-owned calendar, generic provider API or shipped lifecycle wrapper. The PRD places the Tier 2 seam in docs and example code.
- New contact routes for calendar or history state. The existing list URLs and Edit fragment supply the history journey.

## Architecture Decision

**Approach**: Enhance optional server-rendered date fields in the existing contact form with S01's Popover and a same-origin app module, using the contact draft to carry values through save, rerender and reopen.
**Why this over the floor**: Story S08's native inputs already handle simple date entry. FR8 adds a calendar and range recipe that must preserve those inputs as the form and fallback.

## Constraints & Gotchas

- Cally's value is a property and the custom element is outside the form submission contract. Seed from the server-rendered inputs on each mount, exchange ISO `YYYY-MM-DD` values, and map a complete range to its two inputs. Preserve them on unrelated contact validation rerenders. Missing optional dates retain the pre-recipe create/edit flow.
- Before HTMX captures history, synchronously tear down enhancements and restore server-rendered recipe markup. Remount still-connected recipe roots after capture as well as roots inserted by HTMX. Use a single mount and cleanup path for initial load, swaps and cache restores. The existing Dialog closes on history save, so prove restored form markup and calendar reopening without requiring the dialog or Popover to stay open.
- The maintainer records VoiceOver with Safari, NVDA with Firefox and the Safari pass at release prep on the integrated feature branch before squash.

## Implementation Plan

### Implementation Tasks

- **TI01** The deployed admin serves the pinned recipe assets from its existing static directory.
  - Vendor the prebuilt module and licence without a Node build. Extend `copyAppFiles` consumers' deployment proof and the exact script inventory in the existing footprint test.
  - **Verify**: `cmd: cd examples/admin_app && dart test test/footprint_test.dart test/aot_test.dart` – unchanged strict policy and footprint rules, correct SHA-256 and same-origin content after moving the compiled binary away from the checkout.
  - **SATISFIES**: SC01, SC02

- **TI02** The existing contact endpoints round-trip native dates in both modes.
  - Extend the `ContactDraft.fromForm` and `_Contacts._form` paths. Validate date input on the server and preserve supplied values when the form returns validation errors.
  - **Verify**: `cmd: cd examples/admin_app && dart test test/contacts_http_test.dart` – POST and PUT persist the named values, an edit GET renders them into native inputs and an unrelated validation rerender preserves them. Cover omitted dates as well.
  - **SATISFIES**: S02, S04

- **TI03** The recipe demonstrates selection, fallback and the full HTMX lifecycle in both browsers.
  - Follow `examples/admin_app/test/admin_browser_test.dart#proveList` and the repository `GateDriver` for Back and Forward, preserving the normal app handler and CSRF. Cancel the reopened editor, then sort the list. On a cache hit, inspect the restored input values, then expose that same retained dialog with native showModal() in the browser harness. Exercise its real calendar and assert one input change before any Edit request. This is the component probe. Separately walk the reader’s normal Edit action and a forced history-cache miss through the production routes. Keep the request log for each path. Observe the cached and still-connected cases separately. Inject only the vendor 404 at the HTTP boundary.
  - **Verify**: `cmd: cd examples/admin_app && dart test test/contact_dates_browser_test.dart` – exercise both registered browsers against the real app with the observable form payload, saved server values and localized dates from S02, lifecycle from S03 and 404 from S04. Require one mount per root and zero CSP reports through the journey.
  - **SATISFIES**: S02, S03, S04, S05

- **TI04** The admin gate audits the contact date states and keeps browser evidence.
  - Extend the existing admin manifest, captures, baseline and record. Include each opened calendar in the CSP, axe, keyboard and layout states. Follow the testing guide's two-browser verdict, and require direct CSP and axe results in both browsers for the recipe. Capture and inspect the actual rendered open and native-fallback states.
  - **Verify**: `cmd: cd packages/trellis_cli && dart test test/ui_surfaces_gate_test.dart` – fresh admin and scaffold checks pass, the calendar results contain zero strict-CSP and axe findings in each browser, and records retain automated evidence with manual outcomes marked `release-prep` for the changed admin surface.
  - **SATISFIES**: S05, SC03

- **TI05** The published recipe and architecture describe the tested path.
  - Append to the S08 anchor in `site/content/docs/ui/components/input.md`. Include the exact hosted asset and pin from SC01 and the two form examples. Update the testing strategy's admin footprint description beside the test change so it describes the app-owned module.
  - **Verify**: `inspect: site/content/docs/ui/components/input.md:22` – check S01 against the admin implementation and SC01, and confirm the referenced architecture section and Current through marker document the same lifecycle and ownership.
  - **SATISFIES**: S01, SC03

## Implementation Observations

- ASSUMPTION: A contact may omit the range. A supplied range needs both endpoints in chronological order, so the native fields and Cally's complete range share one saved representation. Revisit if contact records need open-ended ranges.
- ASSUMPTION: Use the macOS recording host's native digit order for the fallback proof. Chromium's field is year-first on this host and Firefox's default is month-first. Revisit if the baseline host or its browser settings change.
- The app qualification keyboard sequence waits for the Popover close toggle before moving to the next control. Both browsers can return focus asynchronously after native Escape. A close-then-focus control reproduced the earlier opener taking focus back during the transition.
- Responsive and appearance setups open the calendar with a real click. The original Firefox responsive replay could lose the fixture's focused Enter action before opening the panel. The keyboard recipe still exercises Enter on both triggers, Tab into the calendar, selection and focus return. The empty-results and row-menu states check focus before normalizing incidental focus and pointer paint for appearance capture.
- Per the plan runner's revised verification scope, TI04 uses the same recorder and comparison against the changed admin surface in both engines. The seven-surface replay and workspace/release gates run once on the combined branch.
- Visual review passed 41 captures at four widths. P3 tooling note. The older bundled Chrome for Testing 146 intermittently lost the original page during a compound Escape readback. System Chrome 157 and the independent Chrome/Firefox journey confirmed both focus returns and retained Edit. Routing: Note.
