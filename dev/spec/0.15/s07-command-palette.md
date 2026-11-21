# Command palette

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S07

## Feature Overview and Goal

**Intent**: Give docs readers a way to start a search from the page they are reading and give UI authors the same keyboard-driven picker for a local list.

**Expected Outcomes**:

- [OC01] Readers open a labelled modal and select an item or return to their original focus using the keyboard.
- [OC02] The docs site offers search when its build produces an index and distinguishes an unavailable index from an unmatched query.
- [OC03] Maintainers can qualify the new component and retain the inline search contract for existing theme installations.

## Required Context

- `dev/spec/0.15/prd.md#fr7-command-palette`
- `dev/spec/0.15/prd.md#non-functional-requirements`
- `dev/spec/0.15/prd.md#edge-cases`
- `dev/spec/0.15/s06-theme-and-docs-site-adoption.md#architecture-decision`
- `dev/adrs/ADR-012-trellis-ui-contract.md#decision`
- `dev/adrs/ADR-012-trellis-ui-contract.md#porting-pipeline`
- `dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate`
- `dev/guidelines/VISUAL-VALIDATION.md#breakpoints`
- `dev/architecture/system-architecture.md#client-side-search-flow`
- `site/content/docs/sites/search-and-feeds.md#search-index`

## Acceptance Scenarios

- **S01 [OC01] [runtime] A static palette opens, selects and restores focus**
  - **Given** A served UI page has a named palette with local choices, a trigger and a separate focusable link.
  - **When** A reader activates its trigger, filters the choices, moves with Arrow Down and Arrow Up and chooses with Enter, then reopens from the separate link with the shortcut and presses Escape while results are visible.
  - **Then** Each opening creates a modal with focus in its search input. The list tracks the current match and active choice. Selection reports the chosen local value once and closes to the trigger. One Escape closes the reopened modal and restores focus to the link.

- **S02 [OC01,OC02] [runtime] Shortcut and trigger both reach real indexed pages**
  - **Given** The built docs site has an index of real pages and serves beneath the configured prefix. Test both an inner page with a sidebar and a page without one.
  - **When** The reader opens search with Ctrl+K (Cmd+K on macOS), types two terms whose matches span different index fields, uses both arrow keys and presses Enter. In a second trial the reader opens with the visible Search trigger and clicks a result.
  - **Then** Each page has exactly one Search button in its header. On the inner page it replaces the inline sidebar search box. Both entry points open the same modal with focus in its input. The results match both terms up to the existing 20-result cap, and each choice navigates to its indexed URL with the prefix applied once.

- **S03 [OC01] [runtime] An editing surface or existing binding keeps its shortcut**
  - **Given** Focus is in an editable input, textarea or nested contenteditable target outside the palette, or the page has already handled the key event.
  - **When** The reader presses the palette shortcut.
  - **Then** The palette stays closed and does not cancel the editable field's event. The visible trigger still opens it.

- **S04 [OC02] [runtime] Empty matches and an unavailable index have different messages**
  - **Given** One build serves a valid index and a second trial requests that build's index through a 404, failed fetch or invalid payload.
  - **When** The reader opens the palette and enters a nonmatching query in the valid build, then opens the palette in each failure trial.
  - **Then** The valid build announces and displays “No results”. A failed request or parse leaves a dismissible palette that announces and displays “Search unavailable”, with no stale results or selectable placeholder.

- **S05 [OC02] [runtime] A build without eligible search emits no palette entry point**
  - **Given** A docs build disables index generation or its pages are all excluded by the index's eligibility rules. In another build the theme's existing `show_search` is off.
  - **When** The reader loads an emitted page and presses the shortcut.
  - **Then** The page has no Search trigger or palette shortcut handler. In the no-index builds the emitted HTML does not link to an index or search client. Rebuilding over old output does not advertise a stale index.

- **S06 [OC03] [runtime] The current inline consumers keep working**
  - **Given** Arbor, Folio and a standalone Lattice installation use their existing sidebar search.
  - **When** Their builds load the shared client and a reader filters, selects or encounters an unavailable index.
  - **Then** The inline shells use their current commands, result limit, navigation and failure behavior. They have no palette shortcut or trigger.

## Structural Criteria

- **SC01 [runtime]** The pinned Command styling travels through the existing no-Node port, parity and embed checks. The runtime uses suite Dialog and Combobox behavior and a shared local matching path. Suite size and sync hand-edit limits stay within the PRD ceilings.
- **SC02 [runtime]** The real gallery qualifies Command palette under every applicable ADR-012 automated item in Chrome and Firefox. The served docs journey stays clean under strict CSP in both browsers, including the keyboard, trigger and failed-fetch states.
- **SC03 [runtime]** Narrow and wide captures preserve the S06 navigation layout and show the compact docs Search trigger and palette without overflow. Only changed theme fixture recordings receive a scoped candidate baseline diff for feature-branch approval.
- **SC04** The reference and catalogue document the public composition, shortcut and results and derive support from the existing qualification records. Site and architecture docs explain build-time availability and the docs integration.

## Scope & Boundaries

### Work Areas

- Trellis UI Command port, composed fragment, shared selection and local matching, gallery, gate inventory and records.
- Search index preparation and shared client in `trellis_site`, Lattice and docs-site integration, and served browser contracts.
- Component/reference documentation, Lattice appearance evidence, architecture and affected changelogs.

### What We're NOT Doing

- Action registries, hotkey customization menus and extra search providers are outside FR7.
- Story S06 owns the navigation layout and base theme adoption. Existing inline search on other installations retains its public markup and behavior.

## Architecture Decision

**Approach**: Compose the pinned Command appearance with Trellis Dialog and Combobox. Prepare one optional search result before HTML and emit its assets through the existing generator after rendering.
**Why this over the floor**: The inline sidebar Combobox only works on pages that show the sidebar. FR7 requires a global shortcut and visible way to reach the same index from other docs pages.
**Flow**: `trellis-ui/command-palette :: commandPalette(id, title, placeholder, options, shortcut)` accepts a `trigger` slot and the existing Combobox option shape `{label, value}`. `shortcut` is an optional key letter. Use the actual triggering element or previously focused node as the Dialog opener. Reuse Combobox navigation and option rendering for local and indexed choices. The site client supplies the indexed match text and navigates on selection. Derive optional `site.search` index and client URLs from the same generator eligibility and configured output used at emission. A docs-site setting in existing `site.params` selects one header trigger and palette in Lattice when `theme.show_search` and `site.search` are both present.

## Constraints & Gotchas

- The previous Combobox consumes Escape while its list is open. Give the active Command palette's dismissal precedence within its own modal and leave standalone Escape behavior intact. A handled key, an editable target, an active different modal, or repeated keydown must not open another surface.
- Normalize configured search paths and append the serving prefix once. A nested output emits the client alongside the JSON. Availability is a fact about this build, even if an older file still exists or the newly emitted asset later fails to load.
- Docs markup must carry one palette per page, including home and UI-reference layouts. HTMX swap/history must unwind open state and shortcut registration. The deferred search client can run before the suite upgrades; test both delivery orders. Keep index labels text-only.
- The maintainer records VoiceOver with Safari, NVDA with Firefox and the Safari pass at release prep on the integrated feature branch before squash. Present any S07 visual changes with the S06 baseline evidence.

## Implementation Plan

### Implementation Tasks

- **TI01** The in-repo port and composed palette are reproducible from the active pin.
  - Follow the existing Dialog and Combobox fragments. Use the pinned `command.tsx` for style and slot provenance and record composition differences in the port inventory.
  - **Verify**: `cmd: dart run packages/trellis_ui/tool/port.dart parity && dart run packages/trellis_ui/tool/port.dart check && dart run packages/trellis_ui/tool/embed.dart --check && (cd packages/trellis_ui && dart test test/release_gates_test.dart test/embed_test.dart)` – regenerated source, recorded parity and final compressed payload agree with SC01.
  - **SATISFIES**: SC01

- **TI02** The static palette uses the suite's modal focus, keyboard and local-result behaviors.
  - **Verify**: `cmd: cd packages/trellis_ui && CI=true dart test test/command_palette_browser_test.dart` – exercise S01 and S03 using real focus, pointer and key actions. Cover a pending results popup on Escape, one selection, independent palette IDs and one shortcut registration after HTMX replacement. Also exercise the unchanged Dialog and Combobox paths through their active gate recipes.
  - **SATISFIES**: S01, S03, SC01

- **TI03** One search decision drives the render context and emitted assets.
  - Derive it from the actual `SearchIndexGenerator` rule after front matter and draft policy, and carry the decision through HTML rendering to the existing emission. Preserve the existing generator entry points and the legacy client contract.
  - **Verify**: `cmd: cd packages/trellis_site && dart test test/search_index_generator_test.dart` – build enabled, disabled, no qualifying pages and rebuild cases. Check context versus emitted JSON/client, nested configured output beneath a prefix, and the existing exclusion and draft cases.
  - **SATISFIES**: S05, S06

- **TI04** Served docs readers and inline theme consumers use the shared client successfully.
  - Extend `test/search_client_browser_test.dart` through the real site build and serving path. Extend the existing driver transport narrowly for modifier down/up where needed. Browser actions should exercise the platform shortcut before the application calls `preventDefault`.
  - **Verify**: `cmd: CI=true dart test test/search_client_browser_test.dart test/theme_suite_controls_test.dart` – on both docs layouts assert one header Search button opens the same palette as the shortcut, and zero sidebar search boxes. Exercise focus restoration, navigation, omission, untouched key events, distinct no-match and load-error messages, strict CSP, script readiness and inline theme consumers in both browsers. Build the actual docs routes at root and a subpath with custom index output. Inject load failures at the response boundary.
  - **SATISFIES**: S02, S03, S04, S05, S06, SC02

- **TI05** The Command palette qualifies with a reproducible gallery record.
  - Register the gallery page, checklist manifest, baseline and release inventory. Use the existing re-run path for affected Dialog and Combobox records if their markup or behavior changes. Keep manual results at `release-prep` for new or changed subjects.
  - **Verify**: `cmd: cd packages/trellis_ui && CI=true dart test test/qualification_gate_test.dart` – regenerate all active browser records with passing Command interaction, semantic, axe, CSP, HTMX, appearance and other applicable gate items in the existing browser verdict.
  - **SATISFIES**: SC02

- **TI06** The served docs layout retains usable controls at the documented widths.
  - Capture and view narrow and wide docs PNGs with the modal closed, with results and with no matches. Check light and dark skins. Preserve S06’s wide evidence before generating any scoped candidate. Compare the standalone theme to that reference and present any intentional docs layout change in separate before/after captures.
  - **Verify**: `cmd: CI=true dart test test/site_reflow_test.dart test/visual_baseline_test.dart` – the built docs do not overflow or crowd the command input, header trigger or navigation. The macOS comparison retains S06's unaffected theme baselines.
  - **SATISFIES**: SC03

- **TI07** The published reference and architecture agree with the shipped palette.
  - Document static and indexed use, `show_search`, keyboard, failure and omission behavior. Update the search pipeline and docs-site flow in system architecture and advance Current through. Append the component and site build outcomes to the corresponding 0.15.0 changelogs.
  - **Verify**: `cmd: dart run tool/generate_ui_reference.dart --check` – the Command fragment and reference agree with inventory and recorded support. Read the examples and pipeline description against S01–S06.
  - **SATISFIES**: SC04

## Discovered Requirements

- **Shared CSS tokens appear in existing captures.** The component and app gates sample all root custom
  properties. S03's pinned port added two tokens and surfaced the same differences on unrelated components.
  If this port adds root tokens, compare the observed light and dark values from each affected browser
  against the generated CSS. Preserve every existing capture value unless the change is independently
  explained. Traced from S03/TI05, 2026-11-20.

- **Measure the composed palette against the integrated suite.** S05 shipped on the feature branch at
  699 of 700 owned JavaScript lines and 26,922 of 30,000 gzip bytes. Its scale utilities already register
  the three neutral scale properties. The reference generator accepts fixed-signature fragments without an
  attribute target. Traced from S05/TI01 and TI04, 2026-11-20.

- **Keep the docs search trigger reachable with the narrow header closed.** Lattice has one header
  Navigation menu in a responsive Sheet. Place the independent Search trigger outside that Sheet. Preserve
  S06's inline Tab handoff and the standalone sidebar search shell. Compare the palette and header with
  S06's wide and dark baselines. The Sheet fix brings the suite to 700 lines and 26,931 gzip bytes.
  Traced from S06/TI01, TI04 and TI06, 2026-11-20.

## Implementation Observations

- ASSUMPTION: `site.params.search_palette: true` opts Lattice into the header picker. A theme that needs
  this picker in another location can compose the public fragment and provide its own layout.
- ASSUMPTION: The first valid palette shortcut on a page handles that key. Give multiple palettes distinct
  letters when each needs an independent shortcut. Revisit if a caller needs explicit shortcut ownership.
- The composed picker keeps matches below its input and scrolls them within the viewport gap. The ready
  index provides up to 20 choices. At a 320×500 viewport, the original flip covered the close button.
- A trusted Firefox window blur fired `focusout` with the query still active and `relatedTarget` null.
  Keep the active palette results through that window transition. A true focus departure still closes them.
- The indexed launcher and shortcut become available together when the search client mounts. A held index
  response shows loading status. HTTP failures, disconnected sockets and invalid payloads show unavailable status.
- TI05's complete catalogue sweep and the full workspace and app suites remain plan-final verification.
  The story replays the focused Command palette, Dialog and Combobox records. Safari and assistive-technology
  manual entries remain at release prep.
