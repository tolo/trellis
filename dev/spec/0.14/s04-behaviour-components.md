# FIS: Behaviour components

**Plan**: dev/spec/0.14/plan.json
**Story-ID**: S04

## Feature Overview and Goal

**Intent**: Give app authors the interactive controls an admin screen needs (dialog, alert dialog, dropdown menu, combobox, toast, tabs) as fragments whose behaviour survives HTMX swaps and history under the strict policy, each proven by the headless gate, so the admin example (story S06) and the reference docs (story S07) stand on components that passed.

**Expected Outcomes**:

- [OC01] An author renders each component through the app's engine and operates it by keyboard to its WAI-ARIA APG pattern.
- [OC02] Markup swapped in, swapped repeatedly or restored from HTMX history initialises and cleans up with no forced re-init and 0 violations under `script-src 'self'; style-src 'self'`.
- [OC03] Server-driven states behave: a server-rendered `open` dialog is modal, one toast definition serves both in-page and out-of-band responses, and a combobox with no options or a failed request announces no results and keeps what was typed.
- [OC04] Each of the six components passes every automated gate item in Chrome and Firefox and has a committed gate record; owned JS stays within 400 lines and the suite still leaves non-suite markup untouched.


## Required Context

- `dev/spec/0.14/prd.md#fr3-behaviour-components` – the acceptance criteria this story implements; binding.
- `dev/spec/0.14/prd.md#fr5-qualification-gate` and `#non-functional-requirements` – every automated item, per-component record, 400-line owned-JS gate, strict policy.
- `dev/spec/0.14/prd.md#edge-cases` – twice-inserted fragment ids, browsers without CSS anchor positioning.
- `dev/spec/0.14/s01-porting-pipeline-and-trellis-ui-package.md` – the layout, pipeline commands, gallery and bundler this story extends: component files under `packages/trellis_ui/assets/`, template names `trellis-ui/<component>`, `/components/<name>` pages, `tool/pins.json`. It leaves `00-base.js` to this story.
- `dev/spec/0.14/s02-headless-qualification-harness.md` – `tool/ui_gate.dart`, YAML manifests, gate records under `dev/ui-gate/`, the step vocabulary and the manifest hooks (`distinct` groups, `instances` selectors, stale-transient-UI selectors) this story writes data for.
- `~/Repos/home/trellis/research/13-trellis-ui-behaviour-layer-spike.md#conventions-this-fixes-for-tier-1-authoring` – `display: contents` wrapper, delegated events, live getters, one classic script.
- `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/o6-spike.md` – "Mechanisms found while running the gates" (htmx settle versus `style-src-attr`) and "Choices worth reviewing" (focus model, popovers, toast, combobox).
- `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/build-own-cost-map.md` – row 7 (dialog: `showModal()` on connect) and "Shared helper anchor".
- `dev/adrs/ADR-012-trellis-ui-contract.md#decision` and `#htmx-lifecycle` – the Base UI `data-*` contract and the `style` attribute rule.
- `dev/adrs/ADR-014-component-composition-primitives.md#decision` and `packages/trellis/CHANGELOG.md#0130` – `tl:slot`, `tl:attrs`, `...rest`, bare-name `renderFragment`.
- Starting code, read with `git show spike/trellis-ui-o6-shadcn-port:docs/temp/trellis-ui-o6-shadcn-spike/<path>` in the planning repo (never check it out): `ui/js/00-base.js`, `10-dropdown-menu.js`, `20-tabs.js`, `30-toast.js`, `40-combobox.js`, `templates/components/{dropdown-menu,tabs,toast,toast-oob,combobox}.html`, `static/trellis-hand.css`, `static/trellis-touch.css`, `pins.json` (`structuralSkip`). The README there says do not merge it. Dialog and alert dialog are new.


## Acceptance Scenarios

- **S01 [OC01] [runtime] Dialog opens modally, traps focus and returns it**
  - **Given** the gallery dialog page: a closed dialog with trigger, title, description, a body with two inputs and a footer with two buttons
  - **When** the trigger is activated by click, and separately by Enter; then Tab and Shift+Tab are pressed past the ends; then Escape; then the dialog is reopened and its backdrop clicked, and a click lands inside its content
  - **Then** the dialog matches `:modal` with `data-open` set, `aria-labelledby` and `aria-describedby` resolve to the title and description, focus is inside it, Tab and Shift+Tab cycle within it and the rest of the page is inert; Escape closes it and focus returns to the trigger; a backdrop click closes it, a click inside does not

- **S02 [OC02,OC03] [runtime] A server-rendered open dialog is modal on connect and never restored open**
  - **Given** a dialog fragment rendered with `open`, present at page load, and the same fragment returned by an HTMX request swapped into a container twice in a row, the second replacing the first
  - **When** each one connects, and then a boosted navigation away from the page is followed by Back
  - **Then** after each connection exactly one dialog matches `:modal`, focus is inside it and the page behind is inert; the history snapshot held the dialog closed, so the restored page shows it closed

- **S03 [OC01] [runtime] Alert dialog requires an answer**
  - **Given** the gallery alert-dialog page: trigger, title, description, a Cancel button and a caller-supplied action button
  - **When** it is opened, its backdrop is clicked, Escape is pressed, and it is reopened and the action activated
  - **Then** it has role `alertdialog` with an accessible name and description, shows no close (X) button, focus starts on Cancel, the backdrop click does not close it, Escape closes it and returns focus to the trigger, and activating the action runs the action button's own behaviour and closes the dialog

- **S04 [OC03] [runtime] A menu item opens a server-rendered alert dialog**
  - **Given** a dropdown menu item whose `hx-get` returns an alert dialog fragment rendered open into a container
  - **When** the item is activated by keyboard (Enter), then Escape is pressed in the dialog
  - **Then** the menu closes, the alert dialog is modal with focus on Cancel, and after Escape focus is back on the menu's trigger

- **S05 [OC01] [runtime] Dropdown menu follows the APG menu-button keys**
  - **Given** the gallery menu page: a trigger and a menu with items, a disabled item, a separator, a checkbox item and a destructive item
  - **When** the trigger gets Enter, Space or ArrowDown, and separately ArrowUp; then ArrowDown/ArrowUp past the ends, Home, End, a typed letter, Escape, Tab, and Enter on an item
  - **Then** the menu opens with the first item focused (the last for ArrowUp); arrows wrap and skip the disabled item; Home/End jump; a typed letter focuses the next item whose text starts with it; Escape closes it and focuses the trigger; Tab closes it; Enter on an item emits one `tl-select`, runs the item's own `hx-*` request and closes the menu, while a checkbox item toggles `aria-checked` and `data-checked` and stays open; the trigger's `aria-expanded` mirrors the state

- **S06 [OC01] [runtime] Tabs use roving focus and manual activation**
  - **Given** the gallery tabs page, horizontal and vertical, one tab disabled
  - **When** ArrowLeft/ArrowRight (ArrowUp/ArrowDown when vertical), Home, End, Enter and Space are pressed on a tab, a tab is clicked, and Tab leaves the tab list
  - **Then** exactly one tab has `tabindex="0"`; arrows move focus with wrap and skip the disabled tab without activating; Enter, Space or click activates (`aria-selected`, `data-active`, panel `hidden`); Tab moves to the active panel; with scripts off the first panel is visible

- **S07 [OC01] [runtime] Combobox follows the APG combobox-with-listbox keys**
  - **Given** the gallery combobox page backed by an HTMX options endpoint
  - **When** "ap" is typed, then ArrowDown, ArrowUp, Enter, and separately Escape, Home, End and Tab
  - **Then** after the debounce one request goes out and the popup opens with the options; the input is `role="combobox"` with `aria-expanded` and `aria-controls`; ArrowDown/ArrowUp move `aria-activedescendant` while focus stays in the input; Enter selects; Escape closes; Home and End remain text-cursor keys; Tab and focus loss close the popup; the live region announces the result count

- **S08 [OC01] [runtime] Selecting stores the value and editing clears it**
  - **Given** a combobox with a visible text input and a hidden value input
  - **When** an option is selected, then a character is typed into the text input
  - **Then** after selection the input shows the option's label and the hidden input its value; after the edit the hidden input is empty

- **S09 [OC03] [runtime] No options or a failed request announces no results**
  - **Given** the combobox with typed text "ap", and an endpoint that in turn returns an empty list, returns HTTP 500, and is unreachable
  - **When** each response (or failure) arrives
  - **Then** the live region announces "No results", the empty state shows, no option from an earlier response remains, the popup stays operable with Escape, the input still holds "ap", and no script error is raised

- **S10 [OC03] One toast definition renders in-page and out-of-band**
  - **Given** the package's fragment sources and an engine over them
  - **When** the toast is invoked with `tl:replace` inside a page, and rendered top-level by bare name with its parameters in the render context for an HTMX response
  - **Then** `tl:fragment` declares the toast exactly once; both outputs carry the same toast element (type, title, description, duration, `role="alert"` only for the error type); the top-level output sits inside one wrapper that carries the out-of-band swap attribute targeting the toast viewport, and the in-page output has no such wrapper

- **S11 [OC03] [runtime] An out-of-band toast joins the live region and behaves**
  - **Given** a page whose viewport (`role="region"`, `aria-live="polite"`) exists before any toast, and an HTMX request returning the out-of-band toast
  - **When** the request is made twice, a toast is hovered, another is focused, a third is closed with its button, and the rest wait out their duration
  - **Then** each toast is appended inside the viewport without the wrapper, the two do not overlap, the timer of a hovered or focused toast does not run out until it is left, the close button removes the toast, a toast of duration 0 stays until dismissed, and a toast is gone from the history snapshot

- **S12 [OC02] [runtime] Popup `style` attributes never reach htmx**
  - **Given** a menu opened and closed once (so the popup carries CSSOM-written `style`), and a second page state with the menu open
  - **When** `htmx:beforeSwap` is dispatched, and separately `htmx:beforeHistorySave`
  - **Then** the closed popup has no `style` attribute after `beforeSwap`, and no popup has one after `beforeHistorySave`; an htmx swap of the menu's region then raises 0 `style-src-attr` violations

- **S13 [OC02] [runtime] Popups position without CSS anchor positioning**
  - **Given** the menu and the combobox with their anchors near the bottom edge of a 390 px-wide viewport, and another near the right edge
  - **When** each popup opens, and the viewport is resized with it open
  - **Then** the popup lies fully inside the viewport, flips above the anchor when there is no room below (`data-side="top"`), keeps its minimum width at the anchor's, and follows the anchor after the resize

- **S14 [OC02] A fragment inserted twice keeps unique ids and resolving references**
  - **Given** a page that invokes each id-bearing component twice with different `id` arguments
  - **When** it renders
  - **Then** no `id` repeats, and every `aria-labelledby`, `aria-describedby`, `aria-controls`, `for` and `popovertarget` value resolves to an element on the page

- **S15 [OC02,OC04] [runtime] Every component qualifies with results from both browsers**
  - **Given** the gallery serving the six component pages under the strict policy and each component's manifest
  - **When** the gate runs against each in Chrome and in Firefox
  - **Then** every automated item passes under ADR-012’s browser fallback, including `htmx-lifecycle` (20 swaps and a boosted back/forward with unchanged listener and instance counts), `strict-csp` (0 violations) and `touch-target`, and the command exits 0

- **S16 [OC04] Each component has a committed, current gate record**
  - **Given** the six committed records
  - **When** the gate rewrites them
  - **Then** each lists every FR5 item, the observed results and evidence from both browsers, the aggregate automated items `pass` under ADR-012’s browser fallback, the two screen-reader pairs and Safari `release-prep`, and the rewrite is byte-identical to the committed file

- **S17 [OC04] [runtime] The suite still leaves non-suite markup untouched**
  - **Given** story S01's isolation fixture with a non-suite `dialog`, a non-suite `[popover]` element and a `tl-` prefixed unknown element added
  - **When** it loads with and without the aggregate stylesheet carrying all six components, light and dark
  - **Then** every non-suite element has identical standard computed properties in both loads


## Structural Criteria

- **SC01** Owned hand-written JS in `assets/js/` stays within 400 lines, counting non-blank, non-comment lines (the PRD's release gate, rule from research/13), shipped as one classic script with no `import`/`export`.
- **SC02** No owned JS writes a `style` attribute (`setAttribute('style'`), creates a `<style>` element, or sets an inline handler; positioning goes through CSSOM properties only (research/12).
- **SC03** The pipeline stays regenerable: `generated/` and `lib/src/embedded_assets.g.dart` match their sources after the new components, and every added parity-ignore entry carries a reason.
- **SC04** The gallery's htmx copy (2.0.10) is a checksummed vendored file with its licence notice beside it, and `gallery/` stays out of the published archive.
- **SC05** `packages/trellis_ui/README.md` lists every public fragment of the six components once, with parameters, slots and where `...attrs` lands, and that table matches `assets/fragments/` (stories S06 and S07 import from it).


## Scope & Boundaries

### Work Areas

Paths in Work Areas, Verify lines and Constraints are relative to the trellis-public root. `P` below is `packages/trellis_ui`.

- Pipeline inputs: `P/tool/pins.json` (`components`, `structuralSkip`), `P/tool/parity-ignore.json`, `P/vendor/` (shadcn inputs for the added components, Lucide icons with licence), `P/THIRD_PARTY_NOTICES.md`, regenerated `P/generated/` and `P/lib/src/embedded_assets.g.dart`.
- Fragments: `P/assets/fragments/{dialog,alert-dialog,dropdown-menu,tabs,toast,combobox}.html`.
- Hand CSS: `P/assets/css/hand/00-base.css` (extended) and one file per component; touch rules for this story's own hooks extend story S05's landed `zz-touch.css`; S05's `button.css`, `input.css` and field files are used as landed, not edited.
- Behaviour: `P/assets/js/00-base.js` and one `NN-<component>.js` per behaviour element.
- Gallery: shell and `/demo/` endpoints in `P/tool/gallery.dart` and `P/tool/src/`, `P/gallery/pages/<six>.html` (the shell's self-hosted htmx is story S01's).
- Gate data: `dev/ui-gate/manifests/`, `records/`, `baselines/` (six each, the locations story S02 defaults to).
- Tests in `P/test/`: `behaviour_fragments_test.dart`, `behaviour_browser_test.dart`, `gate_manifest_test.dart`, `gate_run_test.dart`, `budget_test.dart`; story S05's `gate_records_test.dart` extended; extended `isolation_test.dart` and `sources_test.dart`.
- Docs: `P/README.md`, `P/AGENTS.md`, `dev/state/LEARNINGS.md`.

### What We're NOT Doing

- Changelog or docs "supported" claims, the screen-reader and Safari passes, the full-suite payload (25 KB gzip) measurement – story S08 and release prep. The records here leave those items `release-prep`.
- The touch-target layer, the destructive-colour contrast override and the CSS-only components – story S05, which lands before this story; this story only adds its own hooks to S05's touch layer.
- The admin example's dialog form, validation focus and row actions – story S06; this story proves the components compose (scenario S04), not the screens.
- Reference pages and live docs examples – story S07.
- Submenus, radio items, chips, toast swipe and stacking runtime, exit animations, RTL (PRD out of scope); body scroll lock behind a dialog (not required, and a `body` rule would blur the isolation guarantee).
- A CSS anchor-positioning code path – one positioning path measured in all browsers is enough (decision below).
- Shipping the gallery's `/demo/` endpoints or its htmx copy in the package archive.


## Architecture Decision

**Approach**: Port the spike's behaviour layer into story S01's layout and complete it: one fragment file, one hand CSS file, one `tl-*` light-DOM element (own JS file on the shared `00-base.js`), one gallery page, one manifest and one record per component. Conventions every fragment follows: invoked with `tl:replace`; `id` is the first parameter wherever ids are needed and every id and ARIA reference derives from it; `...attrs` lands on the interactive element (README table names it per component); slots are `trigger`, `footer` and the anonymous body; Base UI state attributes are set by JS with `toggleAttribute`; popups use the Popover API (`auto` for the menu, `manual` for the combobox) positioned by one shared `place()`, dialogs the native `<dialog>`. Compound parts (menu items, tab triggers and panels) are sibling fragments in the component's file; they read the parent's `id` because slot content is processed in the fragment's scope (ADR-014 § Decision).

The six components are pinned in `pins.json` together with the hooks their markup composes (`input-group`, `input`, `label`); story S05 already lists some of the same names, so add only the missing ones (the list is a set).


## Constraints & Gotchas

- **Constraint (order)**: The story starts after stories S01, S02 and S05 are merged; it builds on S05's button, input, field, touch layer, README catalogue format and `gate_records_test.dart`. Names used here (`tool/port.dart`, `tool/embed.dart`, `tool/gallery.dart`, `tool/ui_gate.dart`, `dev/ui-gate/…`) come from their FIS; where the landed code differs, follow the code and say so in the report. Gate flags are the ones in `TESTING-STRATEGY.md` § UI qualification gate.
- **Constraint (never weaken)**: A gate item that fails stays `fail` in the record. No manifest edit, axe override or skipped state turns a failure green. If a component cannot pass an automated item after a real fix, stop and report it: the admin example needs dialog, dropdown menu, combobox, tabs and toast, and PRD FR5 blocks 0.14.0 on any of them failing.
- **Constraint (popups and htmx)**: htmx's settle step copies a replaced element's old attributes with `setAttribute`, so a popup that was ever opened carries a CSSOM `style` that `style-src 'self'` then reports. A manifest must open and close each popup before its swap region is swapped, or the defect stays invisible to `htmx-lifecycle` and `strict-csp`.
- **Constraint (dialogs)**: A server-rendered `<dialog open>` is non-modal; the element must drop `open` and call `showModal()` on connect. `showModal()` sets `open`, so a history snapshot taken while a dialog is open would restore it open; the base's history hook closes it first. Vega styles the overlay hook on an element, while a native dialog's overlay is `::backdrop`; the overlay declarations are copied to `::backdrop` in the dialog's hand CSS and the unused overlay hook gets a reasoned parity-ignore entry.
- **Constraint (toast OOB)**: htmx inserts the children, not the element, of an out-of-band element whose swap style is not `outerHTML` (spike `toast-oob.html` wraps `<tl-toast>` for this reason). The shared definition therefore needs a wrapper that exists only in the out-of-band rendering, and `tl:remove="tag"` on a root now processes the children it keeps (0.13). The viewport lives once in the page layout, outside every swapped region, because a live region must exist before content enters it.
- **Constraint (toast stacking)**: Upstream toast CSS stacks toasts with variables only Base UI's runtime sets, so two toasts land on each other. `pins.json` `structuralSkip` for `cn-toast` (spike) skips the generated structural classes and the hand CSS stacks them; if story S01 dropped the key when porting `port.dart`, restore it with its reason. Revisit at every sync.
- **Constraint (destructive contrast)**: Upstream's destructive-on-tint pair measures 4.02:1. Gallery buttons use the default and outline variants, since the override is story S05's. The menu's destructive item is this story's: its `data-highlighted` state is a manifest state, and if it fails axe the fix is a local rule in `dropdown-menu.css` with a comment naming story S05's override as what replaces it.
- **Constraint (generated files)**: after adding to `pins.json` and `parity-ignore.json`, regenerate `generated/` and `embedded_assets.g.dart` with `port.dart build` and `embed.dart`; never edit them by hand. The README table keeps story S05's format, and `readme_test.dart` covers S05's rows as landed.
- **Constraint (popup style)**: before `htmx:beforeSwap`, a popup inside the region being swapped is closed and its `style` dropped, while an open popup whose own content swaps (combobox results) keeps its `style`; before `htmx:beforeHistorySave` every popup drops it (ADR-012 § HTMX lifecycle; the open-popup case is why FR3's "popups" reads as popups being swapped out).
- **Constraint (test tiers)**: a test that runs the full gate over real pages carries the `ui-gate` tag, and one that compares a per-OS visual baseline carries `visual`; both are excluded from CI's tiers and run in the release-gate tier on the maintainer's macOS machine (plan.json sharedDecisions "Full-gate tests run locally", ADR-012 § Upstream sync: gates run locally), so a missing Linux baseline or Firefox never fails CI.
- **Constraint (isolation)**: Dialog, popover and listbox elements have UA styles that tempt page-wide resets. Every reset is scoped to suite elements and in a cascade layer (story S01's rule); scenario S17 is the check.
- **Constraint (fragments)**: Story S01's fragment constraints apply (no literal `id`, no asset URL, `TemplateValidator` clean, no inline style/script).
- **Constraint (browsers)**: Firefox runs through geckodriver as in story S02 (machine-local path in its FIS); run only browsers the harness started. Prefer APIs both browsers ship (`<dialog>`, `popover`, `showModal`, `showPopover`) over newer invoker commands.
- **Decision**: alert dialog is gated as a component of its own (fragment file, gallery page, manifest, record) – its dismissal and focus rules differ and PRD FR5 records per component; a single `dialog` record would drop one page, manifest and record.
- **Decision**: fragment names, parameters and slots follow the conventions in Architecture Decision and are final here, listed once in the README table – an owner preference for other names changes README, fragments and tests only.
- **Decision**: `place()` is the only positioning path, with no CSS anchor-positioning branch – the PRD requires the helper wherever anchor positioning is missing and one path is measured in every browser; native anchor positioning would add a second path and a feature test.
- **Decision**: typing into a combobox after a selection clears the hidden value (scenario S08's second half) – PRD FR3 only requires keeping the typed value, and a stale id submitted with different text is a defect; delete that clause if unwanted.
- **Decision**: a toast's `data-duration` is milliseconds, defaults to 5000 as in the spike, and 0 means it stays until dismissed – PRD FR3 names no timing; WCAG 2.2.1 is met by pausing on hover and focus.
- **Decision**: announcements are fixed English strings ("No results", "N results available") as in the spike – no i18n requirement exists in the PRD; a localisation need turns them into parameters.
- **Decision**: the `/demo/` endpoints are gallery-only – the gallery shell's htmx and indicator settings are story S01's (plan.json sharedDecisions "Gallery shell and gate command"); an app-facing demo endpoint would need its own story.
- **Decision**: the owned-JS line rule is non-blank, non-comment-only lines (research/13); a stricter count (e.g. after minification) would change the budget test only.
- **Decision**: touch rules for this story's hooks extend story S05's `zz-touch.css`, which lands first; S05's component files are used as landed.
- **Decision**: package tests run the gate in Chrome always and in Firefox when geckodriver and Firefox exist, and carry the `ui-gate` tag, so they run in the release-gate tier on macOS where the `visual` baselines live, never in CI (Constraint (test tiers)).


## Implementation Plan

### Implementation Tasks

- **TI01** The pipeline knows the six components: `pins.json` lists `dialog`, `alert-dialog`, `dropdown-menu`, `tabs`, `toast`, `combobox` and the composed `input-group`, `input`, `label`; `port.dart fetch` has vendored their inputs; the Lucide icons the fragments inline are vendored with the ISC licence and the Feather MIT notice in `THIRD_PARTY_NOTICES.md` (story S01 requires both once an icon is vendored); `cn-toast` is structurally skipped; each parity gap the Trellis markup keeps has a reasoned ignore entry; `generated/` is rebuilt.
  - Run `fetch` and `build` with network; if the Tailwind download fails, stop and report.
  - **Verify**: `cmd: cd packages/trellis_ui && dart run tool/port.dart check && dart run tool/port.dart parity && dart run tool/embed.dart --check` – regeneration is byte-identical, the embedded set matches its sources, and no gap lacks a reasoned entry; and `packages/trellis_ui/test/sources_test.dart#every vendored input carries its licence and the pinned commit` – green with Lucide and Feather present.
  - **SATISFIES**: SC03

- **TI02** The gallery can host HTMX demos: story S01's shell (self-hosted htmx 2.0.10, strict-clean config, `htmx-indicator.css`) gains mounted `/demo/` routes (handlers added per component by the tasks below); its htmx copy and licence notice are checksummed beside it, and no second htmx copy is added (plan.json sharedDecisions "Gallery shell and gate command").
  - **Verify**: `packages/trellis_ui/test/sources_test.dart#gallery htmx matches its recorded checksum and notice` and `cmd: cd packages/trellis_ui && dart test test/gallery_test.dart test/gallery_browser_test.dart` – story S01's gallery tests stay green (button page still 0 violations) with the new shell.
  - **SATISFIES**: SC04

- **TI03** The dropdown menu and the shared base exist: `00-base.js` holds the element base class (listeners added on connect and removed on disconnect, `style` stripped from closed popups before `htmx:beforeSwap` and from all popups before `htmx:beforeHistorySave`, a per-element history hook) and `place()` (CSSOM `top`/`left`, flip above, clamp to the viewport, `--anchor-width`, `--available-height`, `--transform-origin`, `data-side`/`data-align`); `00-base.css` carries `display: contents` for the `tl-*` tags, the popover reset and `trellis-sr-only`; the menu has fragment (trigger and anonymous slots, item fragments taking `...attrs`), JS, CSS, gallery page, manifest, and a destructive-item highlighted state.
  - Pattern: spike `ui/js/00-base.js` and `10-dropdown-menu.js`; DOM focus moves to the item (roving) and `data-highlighted` mirrors it.
  - **Verify**: `packages/trellis_ui/test/behaviour_fragments_test.dart#dropdown menu renders its contract markup and passes attributes to items`, `packages/trellis_ui/test/behaviour_browser_test.dart#popup style attributes are dropped before swap and history save` and `#popups stay inside the viewport and follow their anchor` (menu and, once it exists, combobox), `packages/trellis_ui/test/gate_manifest_test.dart#dropdown-menu keyboard script walks every key of the menu pattern` – the required keys are listed in the test (Enter, Space, ArrowDown, ArrowUp, Home, End, a printable character, Escape, Tab), and `packages/trellis_ui/test/gate_run_test.dart#dropdown-menu passes every automated gate item` – covers the keyboard walk and the lifecycle. Mutation checks: remove the Home handler and watch `keyboard` name the step; remove the style stripping and watch `strict-csp` report `style-src-attr`.
  - **SATISFIES**: S05, S12, S13

- **TI04** Dialog and alert dialog exist as two components: fragments (`trigger`, `footer` and anonymous slots, title and description from parameters, close button on the dialog only, Cancel and an action slot on the alert dialog), one `tl-dialog` element (modal on connect when rendered `open`, closes itself in the history hook, backdrop-click dismissal for `dialog` only, Cancel/action/close buttons close, and an open dialog removed by an htmx swap returns focus to its opener when that is still connected, as story S06's save flow needs, FR3's focus return), hand CSS including `::backdrop`, gallery pages (including a `/demo/` endpoint returning an open dialog, and a menu item on the menu page that fetches the alert dialog), manifests.
  - Pattern: build-own-cost-map row 7; `tl-dropdown-menu` for the element shape.
  - **Verify**: `packages/trellis_ui/test/behaviour_browser_test.dart#dialog opens modally, traps focus, returns it and dismisses on Escape and backdrop`, `#an open dialog removed by a swap returns focus to its opener`, `#a server-rendered open dialog is modal on load and after a swap and is closed in history`, `#alert dialog focuses Cancel and ignores backdrop clicks`, `#a menu item opens a server-rendered alert dialog`; `packages/trellis_ui/test/behaviour_fragments_test.dart#dialog and alert dialog render their contract markup`; `packages/trellis_ui/test/gate_run_test.dart#dialog passes every automated gate item` and `#alert-dialog passes every automated gate item`. Mutation check: drop the `showModal()` on connect and watch the server-open test go red.
  - **SATISFIES**: S01, S02, S03, S04

- **TI05** Tabs exist: fragment (sibling `trigger` and `panel` fragments; the parent `id` and each tab's value derive every id and `aria-controls`; non-active panels carry `hidden`; vertical option), `tl-tabs` with roving focus and manual activation, CSS, page, manifest.
  - Pattern: spike `20-tabs.js`.
  - **Verify**: `packages/trellis_ui/test/behaviour_fragments_test.dart#tabs render roving tabindex, linked ids and hidden inactive panels`, `packages/trellis_ui/test/gate_manifest_test.dart#tabs keyboard script walks every key of the tabs pattern` (ArrowLeft, ArrowRight, ArrowUp and ArrowDown on the vertical page, Home, End, Enter, Space, Tab), `packages/trellis_ui/test/gate_run_test.dart#tabs passes every automated gate item`.
  - **SATISFIES**: S06

- **TI06** Toast exists: one `toast` definition (type, title, description, duration, an out-of-band flag, `...attrs`), a viewport fragment for the page layout, `tl-toast` (timer, pause on hover and focus, close, removal in the history hook), hand CSS that stacks toasts without overlap, a `/demo/` endpoint returning the out-of-band rendering by bare name, page, manifest with a `distinct` group over the toasts and the toasts named as transient UI.
  - Pattern: spike `30-toast.js`, `toast.html`, `toast-oob.html`.
  - **Verify**: `packages/trellis_ui/test/behaviour_fragments_test.dart#toast renders in-page and out-of-band from one definition` – counts the `tl:fragment="toast` declarations across the fragment files, and compares both renderings; `packages/trellis_ui/test/behaviour_browser_test.dart#an out-of-band toast joins the live region and behaves`; `packages/trellis_ui/test/gate_run_test.dart#toast passes every automated gate item`. Mutation check: remove the `structuralSkip` entry and watch the `distinct` sweep fail.
  - **SATISFIES**: S10, S11

- **TI07** The combobox exists: fragment (`id`, `name`, placeholder, value; `...attrs` on the text input so the app puts `hx-get` there; hidden value input; status region), an options fragment rendered top-level by bare name from the context (also used inline for initial options), `tl-combobox` with the failure path (`htmx:responseError` and `htmx:sendError` empty the listbox and announce "No results"), CSS, a `/demo/options` endpoint (matches, none, HTTP 500, abort), page, manifest.
  - Pattern: spike `40-combobox.js`; popup observed with a `MutationObserver` because htmx replaces the results container.
  - **Verify**: `packages/trellis_ui/test/behaviour_fragments_test.dart#combobox options render by bare name from the context`, `packages/trellis_ui/test/behaviour_browser_test.dart#combobox selection stores the value and editing clears it` and `#combobox with no options or a failed request announces no results and keeps the typed text` (empty, 500 and unreachable), `packages/trellis_ui/test/gate_manifest_test.dart#combobox keyboard script walks every key of the combobox pattern` (typed text, ArrowDown, ArrowUp, Enter, Escape, Home, End, Tab), `packages/trellis_ui/test/behaviour_browser_test.dart#popups stay inside the viewport and follow their anchor` – now covering the combobox case of S13, `packages/trellis_ui/test/gate_run_test.dart#combobox passes every automated gate item`.
  - **SATISFIES**: S07, S08, S09, S13

- **TI08** The six gate records are committed and current: each has `dev/ui-gate/records/<component>.json` and a baseline for this OS recorded on the first run, the screen-reader and Safari items `release-prep`, and a test reads them.
  - Record baselines with the harness's recording mode (refused when `CI=true`); review each baseline for the invariant sweeps' result before committing.
  - **Verify**: `packages/trellis_ui/test/gate_records_test.dart#every behaviour component has a complete passing record` – lists FR5 items, automated items `pass` in both browsers, manual items `release-prep` or human-entered; `packages/trellis_ui/test/gate_run_test.dart#records regenerate byte for byte` – reruns the gate and compares; and `cmd: cd packages/trellis_ui && dart test test/gate_run_test.dart` – run output shows Firefox executed, not skipped.
  - **SATISFIES**: S15, S16

- **TI09** Cross-cutting invariants hold: story S01's isolation fixture covers the extra non-suite elements and passes with all six components; every id-bearing fragment renders twice cleanly; owned JS stays within budget and classic; no owned JS writes `style` attributes.
  - **Verify**: `packages/trellis_ui/test/isolation_test.dart#non-suite elements keep their computed styles with the suite stylesheet loaded` – fixture extended with `dialog`, `[popover]` and an unknown `tl-` element; `packages/trellis_ui/test/behaviour_fragments_test.dart#fragments inserted twice keep unique ids and resolving references`; `packages/trellis_ui/test/budget_test.dart#owned behaviour JS stays within the release gate` (story S08 reuses it); `cmd: git grep -n -E "setAttribute\(['\"]style|createElement\(['\"]style|\.on[a-z]+ *=" -- packages/trellis_ui/assets/js; test $? -eq 1` – SC02. Mutation check: restore a page-wide `dialog` reset and watch the isolation test name the property.
  - **SATISFIES**: S14, S17, SC01, SC02

- **TI10** The package documents the six: the README table (fragment, parameters, slots, where `...attrs` lands, state attributes the CSS selects on, the `id` rule), the `AGENTS.md` conventions for behaviour elements (base class, `place()`, history hook, the popup-and-swap manifest rule), and LEARNINGS entries for the traps found.
  - **Verify**: `packages/trellis_ui/test/readme_test.dart#the component table lists every public fragment of the six components` – compares table rows with `assets/fragments/`.
  - **SATISFIES**: SC05


## Final Validation Checklist

- The fast tier from `KEY_DEVELOPMENT_COMMANDS.md` is green with the new package tests included, and the run output shows the browser tests (Chrome and Firefox) executed, not skipped. `dart run tool/port.dart check`, `dart run tool/port.dart parity` and `dart run tool/embed.dart --check` exit 0 from `packages/trellis_ui`.
- Serve the gallery, open each of the six pages in the states the manifests walk (dialog open, menu open, combobox with options, two toasts) at 390 and 1440 wide with `agent-browser` per `VISUAL-VALIDATION.md`, and read the PNGs: the vega look is recognisable, popups sit inside the viewport, nothing overlaps.

## Discovered Requirements

- **Strict-engine pass-through classes.** **Description:** preserve host extension classes and render when the host
  omits `class` under strict mode. **Rationale:** S01 review reproduced `Undefined member: "class"` from reading
  `attrs.class`; ordinary rendering hid the problem. **Interpretation:** keep base/marker classes literal, let
  `tl:attrs` append caller classes, and use `tl:classappend` for computed modifiers. Verify both an omitted class
  and an extension class with a strict engine. This refines fragment authoring without changing the scenarios.
  **Traced from:** S01/TI08. **Date:** 2026-11-17.

- **Landed qualification contract.** **Description:** manifests, records and baselines default to
  `dev/ui-gate/{manifests,records,baselines}/`; each `<component>.<os>.json` baseline contains both browser
  captures. **Rationale:** S02 selected and proved this concrete schema. **Interpretation:** follow the UI gate
  section in `dev/guidelines/TESTING-STRATEGY.md`; missing semantics, keyboard or HTMX recipes yield `not-run`,
  so provide meaningful recipes and actual declared-region swaps. Use local `ui-gate` tags for real-page gates;
  fixture tests stay in fast/full. Pass documented `GECKODRIVER` locally so both browser results execute.
  **Traced from:** S02/TI04, TI07, TI11, TI12. **Date:** 2026-11-17.

- **Disabled menu navigation confirmed.** **Description:** arrow navigation skips disabled menu items as S05
  of this FIS specifies. **Rationale:** APG's menu guidance instead keeps disabled items focusable, so the
  preparation lookup surfaced a choice before implementation. **Interpretation:** the owner explicitly chose
  "Follow S04: skip disabled items" on 2026-11-17; keep this scenario and document the actual interaction in
  the component reference. Do not change its assertions to the alternate APG behavior.
  **Traced from:** S03/TI14 integration preparation and owner clarification. **Date:** 2026-11-17.

- **Landed native fragment composition.** **Description:** the landed catalogue is `packages/trellis_ui/README.md`:
  `button(variant, size, ...attrs)` and `input(...attrs)` forward to native controls;
  `field(controlId, label, hint, error, ...attrs)` owns its inner input and forwards attrs there, with separate
  `label(controlId, ...attrs)` and `fieldset(legend, ...attrs)` aliases. Textarea and native-select use inner native
  content slots, so invoke them on natural textarea/select hosts. **Rationale:** S05 proved HTML parser behavior,
  strict attrs, caller classes and accessibility IDs. **Interpretation:** compose with these landed shapes and
  public part classes; follow the README's params/slots/closed scales rather than inventing optional field slots.
  Card has the scoped default size only; sm/image upstream variants remain excluded. Reuse S05's touch layer and
  destructive override, extending only new hooks. **Traced from:** S05/TI02–TI10. **Date:** 2026-11-17.


- **Single full-component qualification wrapper.** **Description:** the landed package full-component test is
  `test/qualification_gate_test.dart`, which discovers all canonical manifests, validates unique logical names and
  exact partition coverage, and runs three disjoint existing-CLI chunks with both browsers. **Rationale:** the
  FIS placeholder `gate_run_test.dart` predates this wrapper; adding another duplicates the full component sweep.
  **Interpretation:** reuse the landed wrapper and map old test paths/names to its labelled per-component results
  as spec-stale equivalent proof. S04 adds per-manifest before/after record-byte assertions around that SAME
  sweep, retaining manual entries; S08 reuses it for all25 components. Keep every automated item and both browsers,
  one source/reference freeze, separate outputs for concurrent repeats, and fresh server asset-byte/ETag identity.
  No manifest, baseline tolerance or assertion is weakened. **Traced from:** S05/TI11–TI12 and final handover.
  **Date:** 2026-11-17.


- **Native keyboard and active-capture proofs.** **Description:** shared GateDriver Enter sends carriage-return text on native Chrome
  keyDown; Firefox active-state appearance restores document focus only, without target.focus or keyboard modality
  forcing. **Rationale:** code-only CDP Enter produced zero native activations, and unfocused held-pointer capture
  lost native focus paint. **Interpretation:** reuse the landed drivers and their regression examples; direct CDP
  keyboard proofs must send native Enter text and assert actual single activation, rather than substituting click.
  A contention fixture uses an explicit popup with a visible source and actual blur: a named tab can hide the
  source and suspend RAF. Preserve native pointer behavior and button/link no-ring expectations. Original full-run
  visibility was not recorded. **Traced from:** S03 keyboard discovery and S05 shared check-blocking repairs.
  **Date:** 2026-11-17.


- **Retained manual record statuses.** **Description:** S02's item schema permits pass, fail, not-run and
  release-prep with string-list evidence, and automated rewrites preserve human-entered manual items.
  **Rationale:** S05's shared record-test helper initially rejected legitimate human values; a copied-record test
  failed before its minimal correction during simplification. **Interpretation:** extend the landed helper rather
  than requiring every manual status to remain release-prep. Missing/malformed entries still fail validation;
  automated browser verdicts must still pass, and a valid manual record is not a claim of support or release
  approval. Real canonical manual entries remain owner-controlled. **Traced from:** S05 integration tidy and
  S02/S11; S04/TI08. **Date:** 2026-11-17.

- **Combobox values across history.** **Description:** the visible text and submitted value must remain paired
  when HTMX restores a selected combobox. **Rationale:** Chrome serializes a hidden input's value assignment
  into its attribute but keeps a text input assignment only in live form state. The selected display was blank
  on Back while the old hidden ID was still submitted. **Interpretation:** serialize the current visible value
  before the history snapshot while closing the popup. Keep the existing selection and editing proof and extend
  it through real boosted Back. **Traced from:** TI07/TI08 and the fresh gap review. **Date:** 2026-11-17.

- **Only options for the current query are selectable.** **Description:** while the combobox awaits an
  HTMX response for new text, options from its previous response cannot be chosen. **Rationale:** a real
  Chrome run selected the old Apple result after typing unmatched text before the debounce finished.
  **Interpretation:** close and clear old options on an HTMX-driven edit and reopen on the response when
  the user is still searching. Preserve static inline choices in a combobox without an HTMX source.
  **Traced from:** TI07/S07–S09 and the fresh gap review. **Date:** 2026-11-17.

- **Appearance token additions travel with the suite stylesheet.** **Description:** the gate records computed
  root tokens in both themes for each component. Adding components made Tailwind emit ten new utility tokens,
  so inherited CSS-only references require the observed additive token keys as well. **Rationale:** the old
  button reference failed only on those additions in both browsers. **Interpretation:** for S08 and later
  syncs compare all inherited states and existing token values first. Add new keys only from the corresponding
  live browser capture, and take any other difference through the normal review and requalification path.
  **Traced from:** TI01/TI08. **Date:** 2026-11-17.



- **Archived execution evidence.** **Description:** the source worktree was temporary.
  **Rationale:** cleanup removes historical absolute proof paths. **Interpretation:** resolve public .agent_temp
  evidence under main public .agent_temp/0.14-plan-run/evidence/S04/public-agent-temp/; exact returning private
  plan/FIS are in evidence/S04/private-receipt/. Preserve historical proof text and use this map rather than
  claiming the removed source root exists. **Traced from:** parent merge816de71 of feature254c639. **Date:** 2026-11-17.

- **Browser emulation fallback (owner re-attestation).** **Description:** The owner confirmed [ADR-012’s browser emulation fallback](../../adrs/ADR-012-trellis-ui-contract.md#browser-emulation-fallback) for every component and app route. **Rationale:** Earlier wording treated every per-browser `not-run` as an item failure. **Interpretation:** TI08’s per-browser pass means the aggregate passes with both raw results retained. **Traced from:** S04/TI08. **Date:** 2026-11-18.

## Implementation Observations

ASSUMPTION: The owner's parallelism request authorizes concurrent implementation of disjoint component files.
Shared API and vendoring were pinned first; one writer built and embedded the combined source, and the whole
story still uses fresh independent reviews and one full qualification wrapper. Sequential authoring would be
required if a task changed the same source or depended on another task's output.

#### DRIFT

- spec-stale: Owner re-attested the browser fallback in ADR-012. Proofs use the shared item verdict in `packages/trellis_ui/test/qualification_gate_test.dart#automated qualification remains green in Chrome and Firefox` and `packages/trellis_ui/test/gate_records_test.dart` | Stale targets: S04/TI08 per-browser pass wording | –
- spec-stale: TI03–TI08 name `gate_run_test.dart`; `test/qualification_gate_test.dart` discovers every manifest,
  runs disjoint dual-browser chunks and compares record bytes in those same runs | Stale targets: TI03–TI08 Verify | –
- spec-stale: dialog and menu/tabs/toast focused tests use per-component suites rather than the shared proposed
  files; the named Verify selectors are unchanged | Stale targets: TI03–TI06 Verify paths | –

#### Repair and proof details

- Chrome 157.0.8103.79 can leave an empty `style` attribute when CSSOM has written it and
  `removeAttribute('style')` is called before reading it. A paired browser experiment showed the empty
  attribute with direct removal and no attribute after the presence read. Both real popup gates initially
  reported `style-src-attr source=/static/htmx.min.js blocked=inline line=1` on history. The repair keeps the
  read-and-remove path for the owned popovers and preserves an open combobox while only its results swap.
- Native Tab could leave a Chrome modal for browser chrome at the last control. The dialog wraps both Tab
  boundaries while retaining native focus selection and `autofocus` within the dialog.
- Firefox rejected forced pointer actions on hidden controls. The harness verifies geometry and visibility
  before explicit forced appearance actions, preserving missing selector failures and genuine input checks.
- Independent code/gap review found the mismatched visible/hidden combobox history state, stale options during
  a pending query, and an unpinned gallery htmx licence. All three had failing tests before repair.
- Independent visual review found one P3: the closed dialog page's two demo openers touched.
  The existing gallery row now gives a 16 px gap at 390 and 1440 px. Final open and closed captures were read.
- The gallery uses native `disabled` through `...attrs` for menu items and tab triggers. Strict render probes
  show that an omitted boolean argument would otherwise erase the host attribute. Arrow navigation skips
  disabled items as the owner specified.
- S06 can use `data-return-focus` on the rendered dialog host to keep a stable opener through repeated
  validation responses. Native `autofocus` selects the error field. The component catalogue records the
  actual signatures, including combobox `displayValue` for a submitted ID distinct from its label, for S06/S07.
- The initial frozen whole-gallery run passed 23 pages and caught Firefox foreground loss during forced hover in
  the dialog and combobox. A visible external popup reproduced both the input focusout and consequent combobox
  dismissal. The harness replays the exact state and native hover up to twice after an observed external blur.
  A focused in-page popup dismissal still fails appearance comparison, three interruptions fail the capture,
  and the blur listener is removed. A separate strict-policy probe retained the original CSP and JavaScript
  diagnostics through a replay. The only corrected new reference was the dialog's Firefox `open/hover:save`
  state, with five focus-paint differences and every other value identical. The initial reference and both
  frozen run logs are retained.
- Final verification exited 0 with `25 component records regenerated byte for byte` and
  `16:36 +1: All tests passed!`. The 25 pages each passed 13 automated items in both browsers.
  The final fast tier passed 3,475 package and 251 root tests with the three pre-existing platform/fixture skips.
  Public commit `254c639faddde7800dbd516c64415304eee4fbd4` contains 115 story paths. All 279 source and
  reference hashes matched before and after the final sweep.


### Post-integration simplification

Feature254c639 merged as816de71. Parent exact integrated fast exited0:3475 package tests and251 root tests, the1Linux-onlywatcher and2no-controltheme skips unchanged,13 analyses clean/46 formatted files unchanged. Fresh simplify-code pass changed only gate_manifest_test.dart: retain its existing whereType<String> projection in the return type and reuse the same RegExp.hasMatch predicate. No assertion, recipe, SDK runtime, reference or record changed. The pass repeated exact fast with the same green counts; parent independently ran the three manifest-keyboard contract tests with0skips and analyzer0issues. Refactor b9bd795 carries the one test-file change with Plan trailer only. Reports: public .agent_temp/s04-simplify/report.md, fast.log; parent .agent_temp/0.14-plan-run/fast-after-s04-merge.log.
