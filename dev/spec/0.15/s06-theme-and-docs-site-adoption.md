# Theme and docs-site adoption

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S06

## Feature Overview and Goal

**Intent**: Make the built-in themes prove that suite components can replace bespoke widget behavior in real navigation while retaining each theme's visual design.

**Expected Outcomes**:

- [OC01] Readers can navigate the docs and Meadow on narrow and wide screens, including when scripts or suite assets are unavailable.
- [OC02] Theme authors keep their existing Lattice sidebar overrides and shipped theme appearance.
- [OC03] Maintainers can ship the adopted themes under strict CSP with browser evidence and the lockstep release record.

## Required Context

- `dev/spec/0.15/prd.md#fr6-theme-and-docs-site-adoption`
- `dev/spec/0.15/prd.md#open-questions`
- `dev/spec/0.15/prd.md#edge-cases`
- `dev/spec/0.15/prd.md#constraints`
- `dev/spec/0.15/s01-popover-and-shared-positioning.md#architecture-decision`
- `dev/spec/0.15/s02-tooltip.md#architecture-decision`
- `dev/spec/0.15/s03-sheet.md#architecture-decision`
- `dev/spec/0.15/s04-accordion.md#architecture-decision`
- `dev/spec/0.15/s05-navigation-menu.md#architecture-decision`
- `dev/adrs/ADR-012-trellis-ui-contract.md#decision`
- `dev/adrs/ADR-009-package-versioning-strategy.md#decision`
- `dev/guidelines/TESTING-STRATEGY.md#contract-rendered`
- `dev/guidelines/VISUAL-VALIDATION.md#breakpoints`
- `dev/guidelines/RELEASE-RUNBOOK.md#0-on-the-feature-branch--before-asking-for-a-merge`
- `dev/architecture/system-architecture.md#lattice-docs-theme-themeslattice`

## Acceptance Scenarios

- **S01 [OC01] [runtime] Meadow's flat mobile menu closes on navigation**
  - **Given** A reader opens the suite Sheet in the built Meadow demo at 390 px.
  - **When** The reader tabs to a link and activates it.
  - **Then** The Sheet closes and the reader reaches the page or fragment destination. A same-page link moves focus to its target without bouncing through the trigger. Repeat at a subpath with an anchor link that points back to the home page. In a separate trial open the mobile Sheet at 839 px, widen to 841 px and focus a visible desktop link. There is no active modal, and narrowing again starts closed.

- **S02 [OC01,OC02] [runtime] Lattice sidebar switches from modal to static at 701 px**
  - **Given** The docs sidebar Sheet is open at 700 px on a page with grouped sections.
  - **When** The reader widens to 701 px and then narrows again.
  - **Then** The modal closes at 701 px, the same sidebar content is visible in its static position, and the narrow view returns closed. The reader can open or close a sidebar group via Accordion and follow its destination directly. The current branch is readable when the sidebar first appears.

- **S03 [OC01] [runtime] Lattice header groups docs destinations and keeps direct links**
  - **Given** The built Lattice site has `theme.nav_links` for a docs section with children and for an external destination.
  - **When** A reader opens the header Navigation menu and follows a section link.
  - **Then** The menu offers the section landing page and descendant links, exposes the current page with `aria-current="page"`, and navigates within the serving prefix. On the real docs build a package page occurs once across the header panels, under Packages, and exactly one header link is current. The configured Themes link to `/docs/themes/gallery/` also occurs once and receives the sole current marker on that page. On a page outside the represented destinations no header link is current. The external link stays a direct anchor. A configured link without a matching group also stays a direct anchor.

- **S04 [OC01] [runtime] Lattice's colour control has a supplementary hint**
  - **Given** Automatic skin selection exposes the icon-only colour-mode button.
  - **When** A reader focuses or hovers it, then activates it.
  - **Then** Tooltip describes the control, its independent accessible name and skin switching still work, and keyboard activation toggles the skin once.

- **S05 [OC01] [runtime] Navigation survives missing enhancement**
  - **Given** The built docs site and both theme demos are served first with JS disabled, then with suite script blocked while CSS loads, and then with both suite assets blocked.
  - **When** A reader explores each theme's narrow navigation using the keyboard.
  - **Then** Plain links to every menu and sidebar destination remain reachable through native markup, including links in the Lattice groups and Meadow anchors. The wide layouts continue to expose their navigation links.

- **S06 [OC02] [runtime] A Lattice consumer keeps its argument-free `sidebar` override**
  - **Given** A consumer site provides a Lattice layout override using the existing `sidebar` fragment name and argument list.
  - **When** The CLI builds a page that invokes the fragment by its existing name.
  - **Then** The page publishes the override's content under the same layout lookup rules. The docs gallery and UI component reference still resolve their explicit theme sidebar.

- **S07 [OC03] [runtime] Real builds are clean under strict CSP and axe**
  - **Given** The CLI builds the docs site, Lattice demo and Meadow demo, including their home pages and representative inner pages.
  - **When** The served builds use `script-src 'self'; style-src 'self'` and a browser visits them at 390, 768, 1024 and 1440 px in light and dark, including the opened navigation states at their active widths and either side of their changed breakpoints.
  - **Then** There are zero CSP violations and zero axe violations. Same-origin suite assets load and the pages have no horizontal overflow. Saved skin choice and toggle work, the Lattice vine keeps its origins, and the Meadow confidence meter remains proportional to its configured value.

- **S08 [OC01,OC03] [runtime] A Sheet dismisses nested suite popups in order**
  - **Given** A served composed fixture has a real Tooltip or Popover open above an open Sheet under the strict policy.
  - **When** The reader presses Escape twice, then reopens both layers and dismisses the Sheet directly.
  - **Then** The first Escape dismisses only the popup and the second dismisses the Sheet. Direct dismissal also closes the nested popup. Geometry and hit testing show the open popup above its Sheet, and the fixture records zero CSP violations for each component variant.

- **S09 [OC02] [runtime] Wide appearance matches the approved theme baseline**
  - **Given** The prior macOS recordings for Lattice and Meadow and fresh captures of the built themes.
  - **When** The comparator and screenshot review compare their wide layouts in light and dark and capture the new narrow interaction.
  - **Then** The wide layouts preserve approved paint and geometry even where the fragment changes node identities. The narrow layout's candidate baseline diff and captures show the intended menu/sidebar change and make any other visual difference identifiable before approval.

## Structural Criteria

- **SC01 [runtime]** Lattice and Meadow render the suite fragments from the existing source registration and emit the same-origin suite files once per build at root and `/trellis/`. The theme-owned navigation/sidebar JS in the two PRD blocks and the superseded callers of their DOM hooks are removed.
- **SC02** The two theme manifests advertise the SDK version carrying their required fragments. The 0.15.0 changelog sections exist for all nine packages and describe the work that has landed.
- **SC03** TD-031 is resolved with the real Meadow anchor-navigation regression proof. TD-023 tracks its remaining Folio scope. The architecture record describes this delivery and its theme consumers.

## Scope & Boundaries

### Work Areas

- `themes/lattice`, `themes/meadow` and `site` composition, manifest compatibility, navigation styles and strict-CSP fixes.
- Root rendered theme contracts, real browser probes and scoped visual baselines.
- Nine lockstep changelog headings, TD-031, TD-023 and the theme adoption sections of system architecture.

### What We're NOT Doing

- Story S07 owns the Command palette and changes to how docs search is launched. The existing sidebar search client, ID and `show_search` setting serve this story.
- Arbor and Folio keep their existing suite controls and CSP assertions. Any remaining TD-023 debt stays recorded against the affected theme.

## Architecture Decision

**Approach**: Compose the suite fragments through the existing theme source registration and use the theme Sass layers for visual integration.
**Why this over the floor**: Keeping the two current widgets would retain the theme JavaScript FR6 retires and leave Meadow's anchor-dismissal defect. The suite also supplies Lattice's required grouped header behavior.
**Flow**: Use S03's `sheet(id, side, title, inlineAbove)` with one `content` instance. Pass `700` for Lattice’s sidebar and `840` for Meadow’s mobile navigation. When Meadow hides the mobile wrapper above 840 px, it must release modality and leave one visible desktop link set. Preserve distinct `trigger` and `content` slots for both. In Lattice, keep configured header links in order and match section links with children against `site.menu` in the same path-prefix form as `page.url`. Give each destination to its nearest configured section in the menu tree. Emit the landing link once in that group, and reserve a more specific configured branch or direct link for its own header entry. Compose the sidebar section groups through S04's multiple-open Accordion with the existing branches initially open. Keep sidebar landing links separate from their disclosure summaries. Use the existing colour-mode button as S02's focusable `trigger` slot.

## Constraints & Gotchas

- The narrow Meadow menu still follows the theme's 840 px breakpoint. Measure across 839/841 there and apply the documented Lattice breakpoint pairs where layout changes. Build and serve actual docs, Lattice and Meadow outputs. `site/layouts/gallery.html` and `site/layouts/ui_component.html` render the theme's `sidebar` explicitly, while Lattice's standard list/single layouts use the unqualified lookup.
- Extend the existing served controls checks. Migrate the old Lattice sidebar and Meadow menu assumptions in Sass and their test stubs to browser behavior while retaining the skin, clipboard and search coverage. The current TD-023 exemption in `test/theme_suite_controls_test.dart` is per theme. The two adopting themes require zero exceptions, and Folio retains its current one.
- CSP must catch load-time reports, including the two inline skin initializers and the home pages' inline vine transform origins and confidence width. Preserve early skin application using same-origin resources. Keep the vine origins in CSS and carry the meter value through semantic markup and strict-CSP-safe styling.
- The unattended story delivers the prior-wide comparison, narrow screenshots and candidate baseline diff. The maintainer reads them and approves intentional narrow changes on the feature branch before squash (root visual-baseline test and release runbook).

## Implementation Plan

### Implementation Tasks

- **TI01** Lattice renders one responsive sidebar and a grouped header from the real suite fragments.
  - **Verify**: `cmd: CI=true dart test test/lattice_theme_contract_test.dart test/theme_suite_controls_test.dart` – exercise the open narrow → inline wide → closed narrow sequence, Accordion, unique destinations and a single current link across the Docs/Sites/Packages panels and exact direct Themes link under both prefixes, external links, the colour hint and toggle, and the existing layout override. Cover the docs-only theme fragment consumers on their built routes.
  - **SATISFIES**: S02, S03, S04, S06

- **TI02** Meadow's mobile Sheet closes on actual link activation.
  - **Verify**: `cmd: CI=true dart test test/meadow_theme_contract_test.dart test/theme_suite_controls_test.dart` – build Meadow and follow both a same-page anchor and a link to another page in the browser. Assert the closed Sheet, URL, destination focus and absence of a trigger-focus event. Cover the prefixed home-anchor case and the 839→841→839 resize while the menu was open, including desktop focusability.
  - **SATISFIES**: S01

- **TI03** Served builds keep suite delivery and plain navigation across both prefixes.
  - **Verify**: `cmd: CI=true dart test test/theme_suite_controls_test.dart` – assert component markers and shipped suite bytes under both prefixes, verify removal of the two superseded JS blocks/hooks, and exercise the actual script-disabled and asset-blocked link paths, rather than treating DOM presence as keyboard reachability.
  - **SATISFIES**: S05, SC01

- **TI04** The docs and two demos pass strict-policy and layout checks in existing browser harnesses.
  - **Verify**: `cmd: CI=true dart test test/theme_suite_controls_test.dart test/site_reflow_test.dart` – arm CSP logging before requests, capture violation and axe arrays, measure overflow, exercise skin and the home-page visual values, and assert the covered widths, skins, pages and open states in S07. Retain unchanged Folio checks and exercise the adopted routes in Chrome and Firefox under ADR-012's emulation rule.
  - **SATISFIES**: S07

- **TI05** Real composed Sheet, Tooltip and Popover pass registered interaction checks.
  - **Verify**: `cmd: CI=true dart test test/theme_suite_controls_test.dart --plain-name 'suite popups nest inside a Sheet'` – serve the fixture using actual embedded fragments and assert top-layer hit testing, both Escape steps, direct dismissal and the CSP observations in Chrome and Firefox.
  - **SATISFIES**: S08

- **TI06** The existing visual baseline comparison distinguishes authored narrow changes from wide regressions.
  - Preserve the 0.14 recordings from `git show v0.14.0:test/visual_baselines/lattice.macos.json` and its Meadow counterpart. Before recording candidates, compare the wide light/dark captures and geometry against that reference at 768 and 1440, retaining PNGs and explaining any node-identity-only differences. Generate candidates on macOS with `UPDATE_VISUAL_BASELINES=1 VISUAL_BASELINE_THEMES=lattice,meadow dart test test/visual_baseline_test.dart` outside CI. Review the 390 px differences independently.
  - **Verify**: `cmd: CI=true VISUAL_BASELINE_THEMES=lattice,meadow dart test test/visual_baseline_test.dart` – compare complete light/dark matrices with the candidate recording, and retain the prior-wide comparison and viewed PNGs captured before any re-record. If the macOS recorder changes either theme's file, it exits nonzero by design. Fix wide visual differences before proposing the diff and rerun the comparison in check mode.
  - **SATISFIES**: S09

- **TI07** Theme compatibility metadata and lockstep changelogs match shipped capabilities.
  - **Verify**: `cmd: dart test test/theme_suite_controls_test.dart --plain-name 'manifests list uses and the minimum version' && for f in packages/*/CHANGELOG.md; do git grep -Fqx '## 0.15.0' -- "$f" || exit 1; done` – Lattice and Meadow require 0.15.0, each package has its heading, and changelog review applies the runbook's exact note wherever this release has no functional change yet. Later stories replace that note when they add a functional outcome.
  - **SATISFIES**: SC02

- **TI08** The debt and architecture records reflect the shipped navigation and CSP behavior.
  - **Verify**: `inspect: dev/state/TECH-DEBT-BACKLOG.md:34` – TD-031 is under Resolved with the serving/keyboard proof from TI02, TD-023 names Folio as the outstanding theme, and the Lattice and Meadow adoption is recorded in system architecture with its Current through marker advanced.
  - **SATISFIES**: SC03

## Discovered Requirements

- **Preserve the Sheet navigation landmark in fallback and modal views.** S03 found that putting the slot on
  the list itself dropped its wrapper. Put the theme's navigation or list inside
  `<tl:block tl:slot="content">`. The server emits a labelled section in normal flow, then Sheet enhancement
  moves its children into the dialog. Keep the same links through the breakpoint and asset-loss cases.
  Traced from S03/TI03 and TI06, 2026-11-20.
