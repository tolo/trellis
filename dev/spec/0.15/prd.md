# Product Requirements Document: Trellis UI – Public-Web Components (0.15)

> **Source**: inline:sha256:37a0e7c91332
> **Context**: Linear project `Trellis`, milestone `0.15`, PRD issue LEA-41. Follows LEA-40 (0.14, Trellis UI Tier 1 slice), whose Out of Scope pencilled these components in for 0.15. Ride-alongs: TD-058, TD-059. LEA-12 closes with the 0.14 release (Decisions Log).
> **Related Assets**: [ADR-012](../../adrs/ADR-012-trellis-ui-contract.md) (Trellis UI contract, tiers, qualification gate), [ADR-015](../../adrs/ADR-015-url-scheme-blocking.md) (URL scheme blocking). Theme appearance references are listed in the [visual validation guide](../../guidelines/VISUAL-VALIDATION.md#references). Research: maintainer's private research repo, canonical: `trellis/research/15-trellis-ui-tier2-refresh/research.md` (2026-11-18).


## Executive Summary

- **Problem**: Trellis UI 0.14 has no popover, tooltip, sheet, accordion or navigation menu, so public-web authors hand-roll them. Our own themes do too: Lattice's sidebar and Meadow's `<details>` menu overlay (27 lines of hand-written theme JS, and a menu that stays open after a link click, TD-031). Date picking has no documented answer at all.
- **Vision**: A public-web author composes app chrome (navigation, side panel, disclosure, hints, a search palette, a date field) from qualified suite components under `script-src 'self'; style-src 'self'`. The docs site and two built-in themes prove it by deleting their hand-rolled widgets.
- **Target Users**: Dart developers building public web apps and sites on Trellis (themes, docs sites, marketing/content apps); secondarily admin-app authors who need a date field.
- **Success Metrics**: hand-rolled nav/menu/sidebar JS in Lattice and Meadow 27 → 0 lines; 0 CSP violations under the strict policy across the gallery, docs site, Lattice and Meadow demo sites and the admin example; 5 new Tier 1 components plus the palette pass every automated gate item in Chrome and Firefox; suite payload ≤ 30,000 bytes gzip.

### Capabilities at a Glance
- **FR1: Popover and shared positioning** _(Must / P0)_ – a qualified Popover, and the positioning and hover-intent layer Tooltip, Navigation menu and the date recipe build on.
- **FR2: Tooltip** _(Must / P0)_ – hover and focus hints on a trigger.
- **FR3: Sheet** _(Must / P0)_ – a modal side panel sliding in from an edge.
- **FR4: Accordion** _(Must / P0)_ – stacked disclosure sections, single or multiple open.
- **FR5: Navigation menu** _(Must / P0)_ – site navigation with dropdown panels that works as plain links without JS.
- **FR6: Theme and docs-site adoption** _(Must / P0)_ – Lattice (docs site) and Meadow replace their hand-rolled sidebar and menu widgets with suite components.
- **FR7: Command palette** _(Should / P1)_ – a keyboard-opened dialog searching the site, adopted on the docs site.
- **FR8: Tier 2 recipe seam and date recipe** _(Should / P1)_ – the HTMX lifecycle seam for vetted widgets, the native date input as the documented baseline, and a Cally recipe for calendar and range picking.
- **FR9: Relic dev reload (TD-058)** _(Should / P1)_ – Relic scaffolds reload the browser on CSS/JS changes like Shelf and Dart Frog.
- **FR10: Site URL scheme opt-out (TD-059)** _(Should / P1)_ – a site maintainer can mark a field in a named source file as a trusted URL in site config.
- **FR11: 0.14 unported behaviour** _(Could / P2)_ – dropdown submenus, exit animations, toast stacking and swipe.

### Scope Highlights
- **In scope**: Popover, Tooltip, Sheet, Accordion, Navigation menu, Command palette; docs-site/Lattice/Meadow adoption; the recipe seam and Cally date recipe; TD-058, TD-059.
- **Out of scope**: a Tier 1 port of shadcn Calendar (rejected, revisit trigger recorded); rich/custom-listbox select (the combobox covers it, ADR-012); Tabulator and upload recipes (0.16); the swipe Drawer; htmx 4.
- **MVP boundary**: FR1–FR6 define the minimum useful feature set. The selected 0.15 release includes FR1–FR11.

### Key Constraints, Assumptions & Dependencies
- *Dependency:* 0.14 is released first; execution starts on `feat/0.15` after it (Product design principle 1).
- *Constraint:* every new or changed component passes ADR-012's qualification gate. Automated items run headless in Chrome and Firefox in-plan; VoiceOver with Safari, NVDA with Firefox and the Safari pass run at release prep.
- *Dependency:* FR10 follows ADR-015's static-site trust declarations.
- *Constraint:* strict CSP (`script-src 'self'; style-src 'self'`), no Node in any toolchain, light-DOM custom elements, popups positioned through the existing CSSOM `place()` rather than CSS anchor positioning.


## Problem Definition

### Problem Statement
0.14 qualified 25 gate subjects aimed at admin and CRUD screens. A public-web page also needs navigation with dropdown panels, an off-canvas side panel on narrow screens, collapsible sections and hover/focus hints, and none of these are in the suite. Authors fill the gap by hand, which is how accessibility and CSP defects get in: our own Meadow theme ships a bare `<details>` overlay that needs 17 lines of theme JS (`themes/meadow/static/js/meadow.js:51-67`) to stop announcing "Open navigation menu" while open and to close on Escape and outside click, and that still does not close when a nav link is clicked (TD-031). Lattice, the docs-site theme, opens and closes its sidebar disclosure by breakpoint in theme JS (`themes/lattice/static/js/lattice.js:65-74`). Date input has no documented path: the suite has no calendar, and ADR-012's Tier 2 date recipe was never written. If nothing changes, each public-web author re-implements these widgets, and the suite's "qualified components" promise covers the admin half of the target users only.

### Target Users
- Dart developers building public web apps and static sites on Trellis who need site chrome (navigation, mobile menu, FAQ/disclosure, hints, search) under a strict CSP without a JS framework.
- Theme authors, including us, maintaining built-in themes that today carry their own widget JS.
- Admin-app authors who need a date or date-range field.

### Desired Outcome
A public-web author builds site chrome from suite fragments and tokens only and gets qualified keyboard, screen-reader and forced-colour behaviour for free. Our docs site (Lattice) and Meadow carry no hand-rolled navigation, menu or sidebar behaviour; the remaining theme JS is theme-specific (skin toggle, headline cycling, clipboard). A date field uses the native input, or a documented Cally recipe where a calendar or range is needed. What remains of the old way: themes keep their visual design; only the widget underneath changes.

### Evidence & Context
- TD-031 (Meadow mobile menu does not close on link click) has been open since 0.11.
- 0.14 S09 already moved Arbor, Folio and Lattice search onto the suite combobox (`packages/trellis_site/CHANGELOG.md:12`), proving theme adoption works.
- Research 2026-11-18 (see Related Assets): shadcn's Calendar wraps react-day-picker rather than Base UI, with 3 `cn-*` rules and 1 `data-slot` (Popover has 6/6), so the porting pipeline generates almost none of its CSS; an owned calendar is an estimated 300–400 JS lines (inferred, not spiked). Cally 0.9.2 (MIT, 12.3 KB gzip) passes the strict CSP, axe, `sv-SE` locale with Monday start and range selection in Chrome and Firefox.
- The shared popup layer (`place()`, `trackPopup`) already exists in `packages/trellis_ui/assets/js/00-base.js:48`.
- The ride-alongs are owner-selected debt with no public-web link: TD-058 leaves Relic apps without the browser reload Shelf and Dart Frog have, and TD-059 leaves a site author no way past ADR-015's scheme check for a deliberate URL. They ride along because each is small and both are open in the Tech Debt backlog.
- At 0.14 the suite had 397 owned JS lines against a 400-line gate and ADR-012's 500–550 estimate for all of Tier 1; the extras alone are estimated at about 600.


## Success Metrics

| Metric | Baseline | Target | How observed |
|--------|----------|--------|--------------|
| Hand-rolled navigation/menu/sidebar behaviour JS in Lattice and Meadow | 27 lines (`lattice.js:65-74`, `meadow.js:51-67`) | 0 lines, at 0.15.0 | Line count of those blocks in the theme JS |
| Known widget defects in built-in themes | TD-031 open | TD-031 closed, at 0.15.0 | Tech Debt backlog |
| Open ride-along debt | TD-058, TD-059 open | Both closed, at 0.15.0 | Tech Debt backlog |
| CSP violations under `script-src 'self'; style-src 'self'` | 0 on qualified 0.14 gallery and app surfaces; the theme tests allow the TD-023 inline skin script | 0 across gallery pages of every new component, the docs site, Lattice and Meadow demo sites, and the admin example with the date recipe, at 0.15.0 | Gate and site browser tests |
| Public-web components passing the automated gate | 0 of Popover, Tooltip, Sheet, Accordion, Navigation menu, Command palette | 6 of 6 in Chrome and Firefox, at 0.15.0; manual items recorded at release prep | `dev/ui-gate/records/` |
| Documented date-picking path | none | Native input baseline plus a Cally recipe used by the admin example under the strict policy, at 0.15.0 | Recipe docs page and admin example test |

All targets apply to the selected twelve-story release.


## Scope

### In Scope
- Tier 1 components: Popover, Tooltip, Sheet (side panel), Accordion, Navigation menu, Command palette, ported from the pinned shadcn tag through the existing pipeline.
- Adoption in the docs site and two built-in themes: Lattice and Meadow.
- Correct the 0.14 Card fragment so omitting its title, description or anonymous body contributes no demo text. A supplied title remains an `h2`. Gallery examples supply their own copy.
- The Tier 2 recipe seam (HTMX swap/history lifecycle for vetted third-party widgets) and one recipe: Cally 0.9.x for calendar and range date picking, vendored by the app, exercised in `examples/admin_app`.
- The native `<input type="date">` documented as the Tier 1 date baseline.
- TD-058 Relic dev reload; TD-059 site URL scheme opt-out (with its own ADR-015 amendment, decided before planning).
- ADR-012 amendments: the refreshed Tier 2 shortlist and pins, the history rule (pristine-markup restore and remount), the date decision with a revisit trigger, the positioning note, and the combined gzip payload budget.
- Could: dropdown submenus, exit animations, toast stacking and swipe.

### Out of Scope
- A Tier 1 port of shadcn Calendar – rejected for 0.15; revisit when shadcn builds Calendar on a Base UI primitive with `cn-*` hooks, or ADR-012's promotion trigger fires.
- Rich (custom listbox) select – the Tier 1 combobox covers it (ADR-012 § Tier 2 vetting).
- Tabulator (grid/tree) and upload (FilePond or Uppy) recipes – 0.16.
- The bottom swipe-to-dismiss Drawer – Sheet covers the side panel; revisit on demand.
- Adoption in Arbor, Folio, Bloom and Verdant – later, on the pattern FR6 proves.
- Offline licence notices for compiled apps are a distribution follow-up. Studio already embeds the published `trellis_ui` files `LICENSE` and `THIRD_PARTY_NOTICES.md` at build time for its `--licenses` command. A generated Dart map could remove that package-directory lookup.
- HTMX 4 migration is a separate decision. The interactive UI gate targets 2.0.10. Document the 4.0.0 remote Combobox error observed in Studio and distinguish it from server-adapter header compatibility (ADR-011).
- RTL – not required, as in 0.14.

### MVP Boundary
FR1–FR6: five qualified public-web components adopted by the docs site and two themes, with the hand-rolled widgets gone. The maintainer selected FR7–FR11 for 0.15 as well, including the Command palette, calendar recipe and overlay interactions.


## Functional Requirements

### User Stories

| ID | Story | Acceptance Criteria | Priority |
|----|-------|---------------------|----------|
| US01 | As a public-web author, I want a popover and tooltip I compose from fragments, so that I can attach panels and hints to triggers without writing positioning JS | FR1, FR2 criteria | Must / P0 |
| US02 | As a public-web author, I want a side sheet, so that my narrow-screen menu traps focus, closes on Escape and on link activation, and announces its state | FR3 criteria | Must / P0 |
| US03 | As a public-web author, I want an accordion, so that FAQ and grouped-navigation sections collapse accessibly | FR4 criteria | Must / P0 |
| US04 | As a public-web author, I want a navigation menu, so that my site header has dropdown panels that stay usable as plain links without JS | FR5 criteria | Must / P0 |
| US05 | As the Trellis maintainer, I want Lattice and Meadow to use the suite, so that our themes stop carrying widget JS and TD-031 is fixed | FR6 criteria | Must / P0 |
| US06 | As a docs-site reader, I want a keyboard shortcut that opens search from anywhere, so that I reach a page without scrolling to the search box | FR7 criteria | Should / P1 |
| US07 | As an app author, I want a documented date field and a calendar/range recipe, so that I add date input without breaking the strict CSP or HTMX history | FR8 criteria | Should / P1 |
| US08 | As a Relic app author, I want browser reload on CSS/JS edits, so that Relic matches the Shelf and Dart Frog dev loop | FR9 criteria | Should / P1 |
| US09 | As a site author, I want to mark a named value as a trusted URL, so that a deliberate bookmarklet or SVG data image renders | FR10 criteria | Should / P1 |

### Feature Specifications

#### FR1: Popover and shared positioning
**Description**: A Popover component (trigger + panel) ported from shadcn's Base UI Popover, and the shared layer FR2, FR5 and FR8 build on: `place()` extended with all four sides, centre alignment and viewport flip/clamp, plus a hover-intent helper (open and close delays) for hover-triggered popups. Panels use the Popover API (`popover` attribute), positioned through CSSOM.

**Acceptance Criteria**:
- [ ] When a reader activates a Popover trigger by click, Enter or Space, the Popover shall open its panel adjacent to the trigger on the requested side and move focus into the panel.
- [ ] While a Popover panel is open, when the reader presses Escape or clicks outside it, the Popover shall close and return focus to the trigger.
- [ ] When a requested side has too little viewport space, the positioning layer shall flip to the opposite side, and if neither fits shall clamp the panel inside the viewport.
- [ ] While a Popover panel is open, when an HTMX swap removes its trigger or the page saves a history snapshot, the Popover shall close and leave no `style` attribute in the snapshot.
- [ ] If JavaScript is unavailable, then the trigger shall remain visible and the panel shall stay hidden, and the reference docs shall tell authors not to make a popover the only path to a navigation target.
- [ ] The Popover shall pass every automated item of ADR-012's qualification gate in Chrome and Firefox with 0 strict-CSP violations.

**Inputs / Outputs**:
- **Inputs**: fragment parameters (side, align, offset), trigger activation, pointer and key events.
- **Outputs**: open/closed state on the panel, inline position set through CSSOM, gate record.

**Priority**: Must / P0

#### FR2: Tooltip
**Description**: A Tooltip ported from shadcn, built on FR1: a short text hint shown on hover and on keyboard focus of its trigger.

**Acceptance Criteria**:
- [ ] When the pointer rests on a trigger past the open delay, or the trigger receives keyboard focus, the Tooltip shall show its text and reference it from the trigger with `aria-describedby`.
- [ ] When the pointer leaves the trigger and tooltip past the close delay, the trigger loses focus, or the reader presses Escape, the Tooltip shall hide.
- [ ] While the pointer moves from the trigger onto the tooltip, the Tooltip shall stay open (WCAG 1.4.13 hoverable).
- [ ] If the trigger is a touch target with no hover, then the Tooltip shall not be the only way to reach its information, and the reference docs shall say so.
- [ ] The Tooltip shall pass every automated gate item in Chrome and Firefox with 0 strict-CSP violations.

**Inputs / Outputs**:
- **Inputs**: trigger element, text, side, delays.
- **Outputs**: visible hint, `aria-describedby` link, gate record.

**Priority**: Must / P0

#### FR3: Sheet
**Description**: A Sheet ported from shadcn: a modal panel sliding in from the top, right, bottom or left, built on the 0.14 dialog behaviour.

**Acceptance Criteria**:
- [ ] When a reader activates a Sheet trigger, the Sheet shall open from its configured side as a modal dialog, trap focus inside it and move focus to its first focusable element or its title.
- [ ] While a Sheet is open, when the reader presses Escape, activates its close control or clicks the backdrop, the Sheet shall close and return focus to the trigger.
- [ ] While a Sheet is open, when the reader activates a link inside it, the Sheet shall close without restoring focus, so the navigation or in-page anchor target takes focus.
- [ ] While the reader prefers reduced motion, the Sheet shall open and close without the slide animation.
- [ ] If an HTMX swap replaces the Sheet's content while it is open, then the Sheet shall stay open with focus inside it.
- [ ] The Sheet shall pass every automated gate item in Chrome and Firefox with 0 strict-CSP violations, including the 24/44 px touch-target layer for its close control.

**Inputs / Outputs**:
- **Inputs**: side, title, content slot, trigger.
- **Outputs**: modal open state, focus movement, gate record.

**Priority**: Must / P0

#### FR4: Accordion
**Description**: An Accordion ported from shadcn's look, built on native `<details>`/`<summary>` (single-open mode through a shared `name`), with JS only mirroring state for styling. Height animation is progressive (Chrome-only `interpolate-size`) and not required.

**Acceptance Criteria**:
- [ ] When a reader activates a section's `<summary>` by click, Enter or Space, the Accordion shall toggle that section, with its expanded state exposed through the native `<details>`/`<summary>` semantics.
- [ ] While the Accordion is in single-open mode, when a reader opens a section, the Accordion shall close the previously open section.
- [ ] If JavaScript is unavailable, then sections shall still open and close natively, single-open mode included.
- [ ] The Accordion shall pass every automated gate item in Chrome and Firefox with 0 strict-CSP violations.

**Inputs / Outputs**:
- **Inputs**: sections (title, content slot, initially open), mode.
- **Outputs**: expanded state per section, gate record.

**Priority**: Must / P0

#### FR5: Navigation menu
**Description**: A Navigation menu ported from shadcn's Base UI Navigation Menu, built on FR1: a horizontal list of links and triggers whose dropdown panels hold further links.

**Acceptance Criteria**:
- [ ] When a reader activates a trigger by click, Enter, Space or Arrow Down, the Navigation menu shall open its panel, and when the reader hovers a trigger past the open delay it shall open that panel.
- [ ] While a panel is open, when the reader presses Escape the Navigation menu shall close it and return focus to its trigger; when focus or the pointer moves to another trigger it shall switch panels.
- [ ] The Navigation menu shall expose the current page with `aria-current="page"` on its link.
- [ ] If JavaScript is unavailable, then every link inside every panel shall still be reachable from the rendered markup.
- [ ] The Navigation menu shall pass every automated gate item in Chrome and Firefox with 0 strict-CSP violations.

**Inputs / Outputs**:
- **Inputs**: menu items (link or trigger with panel content), current URL.
- **Outputs**: open panel state, `aria-current`, gate record.

**Priority**: Must / P0

#### FR6: Theme and docs-site adoption
**Description**: Lattice (the docs-site theme) and Meadow replace their hand-rolled widgets with suite components: Meadow's `<details class="mobile-menu">` overlay becomes a Sheet (its nav is a flat list, so no Navigation menu); Lattice's breakpoint-driven `data-docs-sidebar` disclosure becomes a Sheet on narrow screens, and Lattice's header adopts the Navigation menu with grouped docs sections, which is FR5's real consumer. Suite assets reach the built site as in 0.14 FR11.

**Acceptance Criteria**:
- [ ] When the docs site and the Meadow demo site are built, their output shall render the replaced widgets from suite fragments, and the hand-rolled blocks at `lattice.js:65-74` and `meadow.js:51-67` shall be deleted.
- [ ] While the Meadow menu Sheet is open, when the reader activates a nav link inside it, the Sheet shall close (TD-031).
- [ ] When the docs site is built, Lattice's header shall render the Navigation menu with grouped docs sections.
- [ ] While the Lattice sidebar Sheet is open, when the viewport widens past 700 px, the Sheet shall close and the static sidebar shall show.
- [ ] Lattice's `sidebar` fragment shall keep its name and parameters, so a site overriding it keeps building (Product principle 5).
- [ ] When a built page of either theme is served under the strict policy, the page shall produce 0 CSP violations and 0 axe violations at the breakpoints in `dev/guidelines/VISUAL-VALIDATION.md`.
- [ ] When the visual baselines run, each theme's wide-screen appearance shall match its approved baseline, and any narrow-screen change shall be reviewed and the baseline re-approved.
- [ ] If a site using Lattice or Meadow disables suite assets, then its navigation links shall remain reachable as plain links.

**Inputs / Outputs**:
- **Inputs**: theme layouts, the site menu tree (`${site.menu}`, Lattice's sidebar) and `${theme.nav_links}` (both themes' header and Meadow's mobile menu).
- **Outputs**: built site HTML/CSS/JS, updated visual baselines, TD-031 closed.

**Priority**: Must / P0

#### FR7: Command palette
**Description**: A Command palette ported from shadcn's Command composed with the 0.14 dialog and combobox: a keyboard shortcut opens a dialog with a search input and result list. The docs site wires it to the existing site search index.

**Acceptance Criteria**:
- [ ] When a reader presses Ctrl+K (Cmd+K on macOS) or activates the palette trigger, the Command palette shall open as a modal dialog with focus in its input.
- [ ] On each Trellis docs page with search enabled and an index, one **Search** button in the header shall replace the inline sidebar search box. Other Lattice sites shall keep their inline search by default.
- [ ] While the palette is open, when the reader types, the list shall show matching results, navigable with Arrow Up/Down and chosen with Enter.
- [ ] When the reader presses Escape or chooses a result, the palette shall close and return focus to the previously focused element, or navigate to the chosen page.
- [ ] While the palette is open, when the query matches nothing, the list shall show a "No results" state.
- [ ] If the search index fails to load, then the palette shall show a "Search unavailable" message rather than an empty list.
- [ ] If the build has no search index (search disabled or no qualifying pages), then the docs site shall neither render the palette trigger nor bind the shortcut.
- [ ] If the shortcut is pressed while focus is in an editable field outside the palette, then the palette shall not intercept it.
- [ ] The Command palette shall pass every automated gate item in Chrome and Firefox with 0 strict-CSP violations, and the docs site shall open it with the shortcut.

**Inputs / Outputs**:
- **Inputs**: shortcut key, items (static list or site search index).
- **Outputs**: dialog state, result list, navigation, gate record.

**Priority**: Should / P1

#### FR8: Tier 2 recipe seam and date recipe
**Description**: The documented lifecycle every Tier 2 recipe follows (mount on load and after HTMX swaps; on `htmx:beforeHistorySave` restore a pristine copy of the server markup; remount elements still connected after a history restore), applied in one recipe: Cally 0.9.x for calendar and range picking, vendored by the app (not embedded in `trellis_ui`), composed with the Tier 1 Popover and the native input. The native `<input type="date">` is documented as the Tier 1 baseline; a range field renders start and end native inputs that Cally enhances. The admin example's contact form gains a date field using the recipe.

**Acceptance Criteria**:
- [ ] When an author follows the date docs page, the page shall show the native `<input type="date">` baseline first and the Cally recipe for calendar and range picking, with Cally's exact version and SHA-256 checksum.
- [ ] When a reader picks a date or range in the admin example, the recipe shall write it to a form input that submits with the form.
- [ ] After the reader saves the form, when they navigate away and back through HTMX history, the restored page shall show the saved value in the server markup and a working calendar; an unsaved pick is not required to survive history restore.
- [ ] If the Cally script fails to load, then a single-date field shall accept a date through its native input, and a range field shall accept start and end through its two native inputs.
- [ ] The admin example with the recipe shall produce 0 strict-CSP violations and 0 axe violations in Chrome and Firefox, and the reference docs shall state that Cally has no audited accessibility programme (upstream screen-reader testing last dated April 2024).

**Inputs / Outputs**:
- **Inputs**: vendored Cally bundle, input name, mode (single/range), locale, first day of week.
- **Outputs**: form value, docs page, admin example test.

**Priority**: Should / P1

#### FR9: Relic dev reload (TD-058)
**Description**: Relic scaffolds and `trellis_relic` get the dev middleware and browser reload Shelf and Dart Frog have (0.14 FR9).

**Acceptance Criteria**:
- [ ] While a Relic app created by `trellis create --template relic` runs in dev mode, when a file under `static/` with a `.css` or `.js` extension changes, connected browsers shall reload.
- [ ] If the app runs outside dev mode, then no reload endpoint or script shall be served.
- [ ] The Relic scaffold shall still pass the strict policy with 0 CSP violations.

**Inputs / Outputs**:
- **Inputs**: file changes, dev-mode flag.
- **Outputs**: SSE reload events, TD-058 closed.

**Priority**: Should / P1

#### FR10: Site URL scheme opt-out (TD-059)
**Description**: The site maintainer can grant trust in `trellis_site.yaml` to one named field in one front-matter or site data file, as specified in [ADR-015](../../adrs/ADR-015-url-scheme-blocking.md#static-site-trust-declarations). Content authors cannot grant trust in front matter.

**Acceptance Criteria**:
- [ ] When a site author marks a named value as trusted per the amendment, the built page shall render its `javascript:` or `data:image/svg+xml` URL unchanged.
- [ ] While a value is not marked, including the same field in another source, the build shall keep rendering `about:invalid#trellis-unsafe-url` for script-capable schemes, as today.
- [ ] If a marker names a value that does not exist, then the build shall fail with a `SiteConfigException` naming it.

**Inputs / Outputs**:
- **Inputs**: a `trustedUrls` declaration in `trellis_site.yaml` and the named source file and field.
- **Outputs**: rendered URL attribute, TD-059 closed.

**Priority**: Should / P1

#### FR11: 0.14 unported behaviour
**Description**: The behaviour 0.14 left out: dropdown-menu submenus, exit animations for dialog, sheet, popover and dropdown, and toast stacking with swipe-to-dismiss.

**Acceptance Criteria**:
- [ ] When a reader presses Arrow Right on a dropdown item with a submenu, the dropdown shall open the submenu with focus on its first item, and Arrow Left or Escape shall close it and return focus.
- [ ] While the reader does not prefer reduced motion, when a dialog, sheet, popover or dropdown closes, it shall play its exit animation before becoming hidden; with reduced motion it shall hide immediately.
- [ ] When more than one toast is visible, the toasts shall stack. Swiping right shall dismiss only the touched toast. Swiping left shall leave it visible.
- [ ] Each changed component shall re-pass every automated gate item, and its manual items shall be reset to release prep.

**Inputs / Outputs**:
- **Inputs**: existing component fragments.
- **Outputs**: updated behaviour, refreshed gate records.

**Priority**: Could / P2

### User Flows
1. **Narrow-screen navigation**: a reader on a phone opens the Meadow menu Sheet, tabs to a link, activates it; the Sheet closes and the page navigates.
2. **Docs search by keyboard**: a reader presses Ctrl+K on any docs page, types two terms, arrows to a result, presses Enter and lands on the page.
3. **Date entry**: an admin user opens the contact form, opens the date popover, picks a date, saves; after Back and Forward the value and calendar are intact.
4. **Failure**: the Cally bundle 404s; the field shows the native date input and submits normally.

### UI Wireframes
None: components keep the shadcn look and themes keep their current designs (Decisions Log).


## Non-Functional Requirements

| Category | Requirement | Threshold / Target |
|----------|-------------|--------------------|
| Security | Strict CSP on every surface the release touches | 0 violations under `script-src 'self'; style-src 'self'`; no inline `style` attribute set through `setAttribute` |
| Accessibility | Every new component passes ADR-012's gate | All automated items pass per ADR-012's browser rule (throughout this PRD, "pass in Chrome and Firefox" means one browser passes and every other passes or records `not-run` with a reason); WCAG 2.2 AA; 24/44 px touch targets; forced colours keep outline and system-colour paint |
| Performance | Suite payload | Combined gzip level 9 of the three suite assets ≤ 30,000 bytes (gate raised from 25,000 in `packages/trellis_ui/test/release_gates_test.dart:16`; 20,225 bytes in 0.14) |
| Compatibility | Browser features | Popover API used; CSS anchor positioning, `popover="hint"`, `interestfor` and `<dialog closedby>` not relied on |
| Maintainability | Upstream sync cost | Each new component ports through the pipeline with hand edits within 0.14's sync range (≤ 4 template, ≤ 3 hand CSS lines per sync) |


## Edge Cases

| Scenario | Expected Behavior | Recovery Path |
|----------|-------------------|---------------|
| A Tooltip or Popover open inside an open Sheet | The popup renders above the sheet; Escape closes only the innermost open popup, and a second Escape closes the Sheet | Closing the sheet closes nested popups |
| A popover open when the viewport shrinks below its size | Panel clamps inside the viewport and scrolls internally | Resize or close restores normal placement |
| An HTMX swap replaces a Navigation menu with a panel open | Panel closes; no stale `style` attribute or listener remains | The new menu mounts fresh |
| JS disabled or suite assets blocked | Navigation, sheet content and accordion sections stay reachable as plain links/content | None needed |
| A release-prep manual failure on Popover | Tooltip, Navigation menu and the date recipe depend on it, so it blocks the release like the 0.14 example-required set | Standalone fix, then re-run the manual passes of Popover and its dependents |
| Ctrl+K already bound by the page or browser | Palette shortcut yields to editable fields; a visible trigger always opens it | Use the trigger |


## Constraints & Assumptions

### Constraints
- No Node/npm in consumer or Trellis toolchains; the pinned Tailwind standalone CLI runs only inside the porting pipeline (Product § Proportionality, ADR-012).
- Strict CSP `script-src 'self'; style-src 'self'` everywhere the release touches.
- One maintainer: each new or changed component adds VoiceOver + Safari, NVDA + Firefox and a Safari pass at release prep; the plan executes unattended with headless checks only.
- Lockstep versioning (ADR-009); `## 0.15.0` sections in every package CHANGELOG before the squash.
- Trellis UI hand CSS rules in `AGENTS.md` § trellis_ui hand CSS (touch, contrast and forced-colour files sort last; no geometry transitions).

### Assumptions
- Public-web authors want the shadcn look the suite already carries; no second style is needed (ADR-012).
- The 0.14 pin (`shadcn@4.23.0`) includes all six component sources. Its [Command source](https://github.com/shadcn-ui/ui/blob/96da9cc7f1aa10580a3741664e2a77c721206c00/apps/v4/registry/bases/base/ui/command.tsx) imports `cmdk` and exposes 13 distinct `cn-*` hooks and nine literal slots. FR7 takes its appearance through the porting pipeline and its behaviour from the Trellis dialog and combobox.
- Cally 0.9.x stays maintained through 0.15; its Safari behaviour is unverified until release prep.

### Dependencies

| Dependency | Why It Matters |
|------------|----------------|
| 0.14 released | 0.15 branches from it; FR6 builds on 0.14's theme adoption (S09) |
| ADR-012 amendment | Shortlist, history rule, date decision, positioning note and combined payload budget govern the shipped components |
| ADR-015 amendment (accepted 2026-11-20) | Defines the site-config declaration and the source matching rules for FR10 |
| Cally 0.9.x (MIT) | FR8's recipe; vendored by the app |


## Open Questions

The plan uses Accordion for Lattice's sidebar section groups and Tooltip for its icon-only colour-mode control. The copy button already has a visible label and status text. Meadow's flat mobile navigation uses Sheet.


## Decisions Log

| Decision | Rationale | Alternatives Considered |
|----------|-----------|-------------------------|
| 0.15 centres on public-web components, dogfooded | Public-web authors are half the 0.14 target users and have no chrome components; our themes prove the gap (TD-031) (owner, 2026-11-18) | Admin depth (Tier 2) first; both as equals |
| Proof is the docs site plus Lattice and Meadow | Product principle 6 (dogfooding); builds on 0.14 S09 (owner, 2026-11-18) | A new public-web example; extending the admin example |
| Component set: Popover, Tooltip, Sheet, Accordion, Navigation menu, Command palette; 0.14 unported behaviour as Could | Owner selection 2026-11-18; Popover added as the shared base the research found Tooltip, Navigation menu and the date recipe need | Rich select (dropped, below) |
| Rich select dropped | ADR-012 records that the Tier 1 combobox covers rich select (Tom Select dropped 2026-10-04) (owner, 2026-11-18) | Select-only listbox; multi-select with tags |
| Ride-alongs TD-058 and TD-059 | Owner selection 2026-11-18 | UI only |
| LEA-12 closes with the 0.14 release | 0.14's suite combobox already gives docs search Arrow keys and Escape (`40-combobox.js:82,102`); debounce dropped as unnecessary for an in-memory filter capped at 20 results (`search_client.dart:46`) (owner, 2026-11-19) | Debounce criterion in FR7 |
| Original cut order (superseded 2026-11-21): FR11, then FR8's recipe, then FR7/FR9/FR10; FR1–FR6 are the MVP | One maintainer and per-component manual gate cost (owner, 2026-11-18) | Everything Must; components first |
| Prior estimate of 700 owned JS lines, superseded 2026-11-21 | 397 lines today; research estimates about 600 after the extras (owner, 2026-11-18) | Hard cap at 550; per-component budgets |
| Complete all twelve stories and retire the line-count gate | The Command palette prototype fit the transfer budget. Keep the measured payload and browser gates (owner, 2026-11-21). | Cutting features or compressing source to meet the estimate |
| Payload gate ≤ 30,000 bytes gzip | 0.14 is 20,225 bytes against a 25,000 gate; headroom for six components (owner, 2026-11-18) | – |
| Date picking: native input baseline + Cally 0.9.x recipe; no Tier 1 Calendar port; revisit trigger in ADR-012 | Calendar wraps react-day-picker, 3 `cn-*` hooks, estimated 300–400 owned JS lines and a likely upstream re-implementation; Cally passes CSP, axe, locale and range (research 2026-11-18; owner, 2026-11-18) | Port shadcn Calendar; spike the port first; native input only |
| Only the date recipe is in 0.15; Tabulator and upload in 0.16 | Reuses FR1's Popover; keeps 0.15 on public-web (owner, 2026-11-18) | All three recipes as Could; no Tier 2 in 0.15 |
| Recipes are docs plus a tested admin-example use; no shipped wrapper element | Less owned JS and API surface (owner, 2026-11-18) | Separate example app; a shipped recipe element |
| Sheet means the side panel, not the swipe Drawer | Covers both theme widgets; reuses dialog behaviour (owner, 2026-11-18) | Sheet plus swipe Drawer |
| Popups keep CSSOM `place()` positioning | CSS anchor positioning is not Baseline and has open nested-popover and scroll bugs (research 2026-11-18) | CSS anchor positioning |
| No design pass before planning | Components keep the shadcn look; themes keep their designs; visual baselines catch regressions (owner, 2026-11-18) | Wireframes for theme adoption first |
| A link activated inside a Sheet closes it without restoring focus | Returning focus to the trigger undoes an in-page anchor jump for keyboard and screen-reader users (owner, 2026-11-19) | Always return focus to the trigger |
| Date recipe guarantees the saved value after history restore, not an unsaved pick | The seam restores pristine server markup; keeping unsaved picks needs a spike (owner, 2026-11-19) | Write unsaved picks into the pristine copy |
| A range field is two native inputs Cally enhances | Without Cally both still submit (owner, 2026-11-19) | Single-date recipe only |
| Accordion is built on `<details name>` | Works without JS and carries native expanded semantics (owner, 2026-11-19) | shadcn/APG button + panel |
| Escape closes the innermost open popup first | Predictable nesting for Tooltip/Popover inside Sheet (owner, 2026-11-19) | One Escape closes everything |
| Lattice Sheet closes when widening past 700 px; `sidebar` fragment keeps its name and parameters | Avoids an orphaned modal and keeps overriding sites building (Product principle 5) (owner, 2026-11-19) | Allow a breaking fragment change |
| Lattice's header adopts the Navigation menu | Meadow's nav is flat, so Lattice is FR5's only real consumer (owner, 2026-11-19) | Gallery-only proof; decide in the plan |
| Only the site maintainer grants URL trust, naming a source file and field in `trellis_site.yaml` | Each exception is reviewable and cannot confer trust on the same field in another page. ADR-015 amended before planning (owner, 2026-11-20) | Allow a page author to grant trust in front matter |
| PRD stays uncommitted until `feat/0.15` exists | Committing it on `feat/0.14` would squash it into the 0.14 release | Cut `feat/0.15` from `feat/0.14` now |
