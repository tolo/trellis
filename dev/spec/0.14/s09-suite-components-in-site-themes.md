# FIS: Suite components in site themes

**Plan**: dev/spec/0.14/plan.json
**Story-ID**: S09

## Feature Overview and Goal

**Intent**: Replace the three drifting per-theme search clients (TD-021) with one maintained `trellis_site` client driving the suite combobox, and put the suite's button behind the reader dark/light toggle and arbor's code-copy control, so Trellis's own themes exercise the suite in production and an author gets one search implementation to fix.

**Expected Outcomes**:

- [OC01] A site on arbor, folio or lattice searches its pages through the suite combobox over one `trellis_site` client: typing lists matching pages, selecting one opens it, and an unavailable index leaves no search control.
- [OC02] The reader toggle in lattice, folio and meadow and arbor's code-copy button are suite buttons that behave as before (state, persistence, feedback).
- [OC03] Only the themes that use a suite component ship suite assets, and those assets cause 0 violations under the strict policy.
- [OC04] The adopting themes keep their own palette in light and dark, the adopted controls pass accessibility checks, and the recorded appearance changes only where a control changed.


## Required Context

- `dev/spec/0.14/prd.md#fr11-suite-components-in-trellis_site-themes` – the criteria this story implements; binding. Its seam is the one in `dev/spec/0.14/prd.md#fr8-component-reference-docs-and-docs-site-adoption`.
- `dev/spec/0.14/prd.md#non-functional-requirements` and `#constraints` – strict policy, WCAG 2.2 AA with contrast at least 4.5:1, unattended and headless, no Node in committed test code.
- `dev/spec/0.14/s07-component-reference-docs-and-docs-site-seam.md` – the `SiteSource` hook and the `uses:` list in `theme.yaml` this story consumes (its SC04 says a theme adopts with one line); its Constraints on cascade layers and Lattice's `:root` `--card`/`--radius` and `.prose` collisions; its scenarios S07 and S10 that this story changes (see Constraints).
- `dev/spec/0.14/s04-behaviour-components.md` – combobox signature, `data-value` and hidden-value contract (its scenarios S07 to S09), MutationObserver on the popup, no-results announcement.
- `dev/spec/0.14/s05-css-only-components-layout-primitives-and-overrides.md` – the button fragment, its variants and sizes.
- `dev/spec/0.14/s01-porting-pipeline-and-trellis-ui-package.md` – cascade layers, asset names `trellis-ui/trellis-ui.css`, `trellis-ui.js`, `htmx-indicator.css`, the strict policy of its scenario S11, the theme-block rule (an unlayered `:root` token block wins).
- `dev/spec/0.14/plan.json#sharedDecisions` – "Component layout and gallery".
- `dev/state/TECH-DEBT-BACKLOG.md` – TD-021 (this story closes it), TD-023 (inline anti-FOUC scripts; stays), TD-036.
- `packages/trellis_site/lib/src/search_index_generator.dart`, the four themes' `layouts/base.html`, `static/js/{search,code-enhance,folio,lattice,meadow}.js` – the surfaces that change.
- `dev/guidelines/KEY_DEVELOPMENT_COMMANDS.md` and `TESTING-STRATEGY.md` (before-merge items 4 to 6) – test tiers, mutation check, baseline regeneration; `VISUAL-VALIDATION.md` – capture recipes.


## Acceptance Scenarios

- **S01 [OC01] The client ships beside the index**
  - **Given** a fixture site with `search.enabled: true`, and another with it false
  - **When** each builds
  - **Then** the first output holds `trellis-search.js` in the directory of `search-index.json`, byte-equal to the shipped client, and `staticFileCount` counts both files; the second holds neither

- **S02 [OC01] [runtime] Typing finds pages; Enter and click open one**
  - **Given** the built arbor, folio and lattice examples (lattice built with a `/trellis/` path prefix), loaded with scripts on
  - **When** a query matching several pages is typed, ArrowDown is pressed twice and Enter; and separately a second option is clicked
  - **Then** the combobox popup lists at most 20 options whose pages contain every query term (case-insensitive, over title, summary, content and tags); the input is a suite combobox (`role="combobox"`, `aria-expanded`, `aria-activedescendant` moving while focus stays in the input); Enter and click each navigate to the chosen entry's `url` exactly as indexed (prefix applied once); an Enter with no highlighted option navigates nowhere

- **S03 [OC01] [runtime] No match, empty query, markup in titles**
  - **Given** the arbor example and an index containing a page titled `<img src=x onerror="window.__xss=1">`
  - **When** "zzzz" is typed, then the query is cleared, then whitespace is typed, then the markup-titled page is searched for
  - **Then** the no-match query shows the combobox's empty state, the live region says "No results", and the input keeps "zzzz"; the empty and whitespace queries leave the popup closed with no options; the markup-titled option shows the title as literal text, creates no element, and `window.__xss` stays unset

- **S04 [OC01] [runtime] An unavailable index leaves no control**
  - **Given** the arbor page with its index answering 404, answering 500, malformed JSON, a JSON object instead of an array, unreachable (cross-origin refused), and a shell with no `data-search-index`
  - **When** each page loads
  - **Then** the shell stays `hidden`, the input is `disabled` with `aria-disabled="true"`, and no uncaught error is raised; and with script execution disabled before navigation the shell is `hidden` and the input `disabled` in the served HTML

- **S05 [OC01] Search switched off ships no search markup**
  - **Given** arbor, folio and lattice built with `show_search: false`
  - **When** the pages are read
  - **Then** they hold no `[data-trellis-search]` shell and no script tag for `trellis-search.js`

- **S06 [OC02] [runtime] Toggles still toggle**
  - **Given** the built folio, lattice and meadow examples with an OS scheme of light, then dark, and nothing stored
  - **When** the toggle is clicked, the page reloaded, and a stored value of `light` or `dark` set before load
  - **Then** each theme resolves, applies and persists its skin as before (folio `data-skin` and key `folio-skin`, lattice `data-theme` and key `trellis-theme`, meadow `data-skin` and key `meadow-skin`), its pressed state and accessible name follow the skin, and the toggle element is a suite button (`data-slot="button"`, a `trellis-button` class, its original `data-*-toggle` hook)

- **S07 [OC02] [runtime] Copy button copies and reports**
  - **Given** the built arbor example with the clipboard API stubbed to resolve, then to reject, and absent
  - **When** a code block's copy button is clicked
  - **Then** each button is a suite button; on resolve the code text is written and the label reads "Copied" then reverts after 1.6 s; on reject or absent API it reads "Error" then reverts; the label bar and button stay inside the block's frame at 390 px

- **S08 [OC03] Only adopting themes ship and link the suite**
  - **Given** the six example sites built with the shipped CLI, at root and under `/trellis/`
  - **When** their output trees and pages are read
  - **Then** arbor, folio, lattice and meadow hold `trellis-ui/trellis-ui.css`, `trellis-ui/trellis-ui.js` (bytes `trellis_ui` serves) and link them under the active prefix; bloom and verdant hold no `trellis-ui/` directory and no such link; meadow's pages link the suite once, not per section

- **S09 [OC03] [runtime] Strict policy: 0 violations from the suite**
  - **Given** the four adopting examples served with the strict policy of story S01's scenario S11
  - **When** each is loaded and the adopted controls are exercised (search typed and selected, toggle clicked, copy clicked, popup opened and closed)
  - **Then** the violations seen are exactly the TD-023 allow-list (one inline `script-src-elem` block of the anti-FOUC script in folio, lattice and meadow; none in arbor), and none has a `blockedURI` under `/trellis-ui/` or is a style-attribute block

- **S10 [OC04] [runtime] Controls wear the theme's palette in both skins, and pass axe**
  - **Given** each adopting example in its light and dark skin
  - **When** the computed colours of the toggle or copy button, the combobox input and its open popup are read, and axe (WCAG 2.2 A and AA) runs scoped to the adopted controls
  - **Then** button background and text, input border and popup surface equal the theme's resolved primary, surface, text and border colours for that skin; axe reports 0 violations; a suite button placed outside the controls (in the article body) keeps the suite's default tokens

- **S11 [OC04] [runtime] Reflow holds and the recorded appearance moves only at the controls**
  - **Given** the theme contract and reflow suites and the visual baselines re-recorded for the four adopting themes
  - **When** they run, and old and new baseline nodes are compared by path
  - **Then** the suites pass with the browser tests executed; every added, removed or changed node lies inside an adopted control (the search shell, the toggle, a code bar); `bloom.macos.json` and `verdant.macos.json` are byte-identical to before

- **S12 [OC03] Older tools refuse an adopting theme up front**
  - **Given** the four adopting manifests
  - **When** read
  - **Then** each lists `uses: [trellis_ui]` and `min_trellis_version: 0.14.0`; bloom and verdant list neither


## Structural Criteria

- **SC01** No per-theme search client survives: no `themes/*/static/js/search.js`, no `data-arbor-search` or `data-lattice-search` hook in `themes/`; the only search client source is the one in `packages/trellis_site/lib/src/`.
- **SC02** `trellis_site` and `trellis` still know no suite: no `trellis_ui` in their pubspecs or `packages/trellis_site/lib/`, and the client names no suite class, `data-slot` or part class (ARIA roles, `aria-controls` and the `data-value` option attribute only).
- **SC03** Themes hold no copy of suite markup: the combobox results, the toggle and the copy button come from `trellis-ui/…` fragments (the client and `code-enhance.js` clone a server-rendered `<template>`).
- **SC04** The suite palette bridge is declared on the adopted controls' containers only, never on `:root` or `html`, and the themes add no inline script or style (TD-023's existing scripts excepted).
- **SC05** `trellis_site` gains no change to the `uses` hook: adoption is `theme.yaml` lines and layouts (story S07's SC04).


## Scope & Boundaries

### Work Areas
Paths are relative to the trellis-public root, where the story executes.

- Client: `packages/trellis_site/lib/src/` (new `search_client.dart` holding the script as a raw string, `search_index_generator.dart` writing it), tests `packages/trellis_site/test/search_index_generator_test.dart`.
- Themes arbor, folio, lattice, meadow: `theme.yaml`, `layouts/base.html`, `static/js/` (delete `search.js` in arbor, folio, lattice; edit `code-enhance.js`; toggle scripts only if a hook moves), `sass/` (one bridge partial each, retired search and toggle and copy rules), `VENDORED.md`, `README.md`; bloom and verdant untouched.
- Tests: new `test/search_client_browser_test.dart` and `test/theme_suite_controls_test.dart`; retire `test/search_client_test.dart`, `test/search_client_behavior_test.dart`, `test/search_client_harness.js`; migrate the search, toggle and manifest assertions in `test/{theme,folio_theme,lattice_theme,meadow_theme}_contract_test.dart`; recorded appearance `test/visual_baselines/{arbor,folio,lattice,meadow}.macos.json`, and `themes/*/screenshots/`, `tool/theme_screenshot_digests.json`, `site/static/themes/` only where a control is visible in the committed image.
- Story S07's artifacts that change with lattice adopting: `site/layouts/ui_component.html`, `test/ui_reference_site_test.dart`.
- Docs and records: `AGENTS.md` (client name), `docs/guides/theme-authoring.md`, `site/content/docs/sites/search-and-feeds.md`, `site/content/docs/themes/authoring.md`, `dev/architecture/system-architecture.md` (search client lines, "Current through"), `dev/state/TECH-DEBT-BACKLOG.md` (TD-021 closed, TD-036 re-checked), `dev/state/LEARNINGS.md`, `packages/trellis_site/CHANGELOG.md`, the four themes' changelog or README notes, `tool/visual_baseline.dart` (comment naming `search.js`).

### What We're NOT Doing
- The themes' inline anti-FOUC scripts (TD-023) – out of scope per PRD FR11; the strict-policy check allow-lists them by name.
- One shared toggle script across the three themes – their storage keys and root attributes differ and saved reader choices must survive; the three near-identical scripts stay. NOTICED BUT NOT TOUCHING: merging them is its own tech-debt candidate.
- Lattice's and meadow's home-page "copy install command" buttons – FR11 names arbor's code-block button only.
- Result snippets – the combobox writes the chosen option's text into the input, so options are titles (decision below).
- Server round trips, htmx or `hx-*` in themes; fuzzy or ranked matching; keyboard shortcuts to focus search.
- Per-component suite bundles or a way for a site to drop a theme's `uses` – the aggregate bundle is ADR-012's delivery decision.
- Editing the suite's CSS or components, Lattice's docs-site look beyond the controls, or bloom and verdant.


## Architecture Decision

**Approach**: `trellis_site` embeds one dependency-free client (`trellis-search.js`) and writes it beside `search-index.json`. A theme's search shell (`[data-trellis-search]`, `data-search-index`) holds the suite combobox (input shipped `disabled`) and a `<template data-trellis-search-results>` rendered from the suite's options fragment with one sample option; the client fetches the index, and on input clones that template, fills it with up to 20 matches and replaces the popup's results container, which the combobox already observes (story S04). Selection is read from the combobox's stored hidden value after its own handler ran. The toggle and the copy button become `trellis-ui/button` fragments (the copy button through a `<template>` that `code-enhance.js` clones). Each adopting theme lists `uses: [trellis_ui]` and gains one Sass partial mapping its palette variables onto suite tokens for its controls.
**Why this over the floor**: The floor is leaving three clients and the ad-hoc buttons. TD-021 (decided 2026-10-13) requires one client beside the index, and FR11 requires the combobox, toggle and copy button to be suite components. Cloning a server-rendered template keeps the fragment the only copy of suite markup and the client free of suite names (SC02, SC03). A bridge on the controls rather than `:root` leaves story S07's preview wells untouched.
**Flow**: `search.enabled` build → index + `trellis-search.js` → page loads `trellis-ui.js` and `trellis-search.js` (both `defer`) → client reveals shell once the index parsed → input → match → replace results container → combobox sync → selection → navigate.


## Constraints & Gotchas

- **Constraint (order)**: Runs on the 0.14 branch after stories S04 and S07, and after S05 for the button. Names from their FIS (`SiteSource`, `uses`, fragment signatures in the `trellis_ui` README, `data-value`, the options fragment, `BrowserProbe` violation capture) are the executor's to confirm in landed code; where the code differs, follow it and say so.
- **Constraint (assets are all-or-nothing)**: `uses: [trellis_ui]` copies all three suite files and the layouts link the aggregate CSS and JS (≤ 25 KB gzip combined, a release gate). Every page of an adopting theme pays that; report the added bytes per theme. Link only `trellis-ui.css` and `trellis-ui.js`; no theme uses htmx, so `htmx-indicator.css` is copied but never linked.
- **Constraint (unlayered theme CSS beats the suite)**: Suite styles are layered, theme and site CSS is not, so a theme rule such as `button { … }`, `input { … }`, `ul`, `a` inside the sidebar, or `.prose` reaches suite markup (story S07 met this on Lattice). Audit each adopting theme for such rules around the controls, scope them off the suite elements, and leave a comment naming the cause. Never put the fix in the suite.
- **Constraint (bridge scope)**: Map the theme's variables onto suite tokens (`--primary`, `--primary-foreground`, `--background`, `--foreground`, `--border`, `--input`, `--ring`, `--accent`, `--accent-foreground`, `--popover`, `--popover-foreground`, `--muted-foreground`, `--radius`, `--destructive` only if used) with `var(--theme-variable)` so the dark skin follows with no second block. Story S07's scenario S10 compares previews' custom properties with a bare suite page, so a bridge on `:root` would fail it. Lattice's own `--card` and `--radius` already sit on `:root` and are the same kind of value; leave them.
- **Constraint (story S07 artifacts change)**: With lattice linking the suite on every page, story S07's scenario S07 clause "pages outside `docs/ui/components/` link no suite asset" no longer holds and the reference layout's own suite links duplicate lattice's. Update `site/layouts/ui_component.html` to drop its suite links and `test/ui_reference_site_test.dart` to assert the reference pages link the suite stylesheet and script exactly once and the docs site still builds with no warning in both deploy shapes. Say so in the report; this is a deliberate edit of story S07's tests, not a weakening: every other clause stays.
- **Constraint (no registry, no build)**: A theme with `uses: [trellis_ui]` fails a build whose registry lacks `trellis_ui` (story S07's scenario S04). Tests that build an adopting theme go through the shipped CLI (`tool/visual_baseline.dart#buildExample`); tests that build one through `TrellisSite` directly (`test/theme_gallery_test.dart`, the three theme contract suites) pass the registry story S07's CLI uses or move to `buildExample`. `packages/trellis_site` tests must not build an adopting bundled theme.
- **Constraint (client order)**: `trellis-ui.js` and `trellis-search.js` are both `defer`; either may run first. The client must work if the combobox element upgrades before or after it, and must not assume its own input listener runs before or after the combobox's.
- **Constraint (progressive enhancement)**: The shell ships `hidden`, the input `disabled`, the toggle and copy affordances as today. Measure it by disabling script execution before navigation, not after load (LEARNINGS: the race with the index fetch). Rebuild onto a new port when re-measuring script changes (LEARNINGS: cached script).
- **Constraint (existing assertions carry intent)**: The deleted search tests and the migrated contract assertions protect: index URL read from `data-search-index`, never hardcoded; every failure disables the control; empty query idles; no-match shows an empty state; result URLs used verbatim; no external host in the client; results capped and scrolled; empty state announced. Each reappears as a scenario here or an assertion on the new surface; none is dropped (TESTING-STRATEGY item 8).
- **Constraint (browser tests)**: Use `BrowserProbe`/`StaticSiteServer` and `requireChromeInCi`; arm story S02/S03's violation capture before page scripts; serve the strict policy as a response header (add one optional `headers` parameter to `StaticSiteServer` if it lacks it). Drive interactions with real key events through the probe, and read the clipboard through a stub installed before load. Never kill browsers by name.
- **Constraint (baselines)**: Appearance baselines are macOS-only and regenerate with `UPDATE_VISUAL_BASELINES=1 VISUAL_BASELINE_THEMES=arbor,folio,lattice,meadow dart test test/visual_baseline_test.dart`; the test refuses under `CI=true`. Run it on this host.
- **Constraint (shared files)**: `packages/trellis_site/CHANGELOG.md`, `system-architecture.md` and `LEARNINGS.md` are also edited by stories S03, S06 and S07. Append to the `## 0.14.0` section, keep unrelated lines.
- **Constraint (parallel with story S08)**: S08's sync rewrites suite CSS and every gate record while this story re-records four theme baselines and may touch the combobox. Whichever merges second re-runs `dart test test/visual_baseline_test.dart` on macOS and the combobox's gate before merging. `lattice.js` keeps story S07's line that sets the suite's `dark` class on preview wells.
- **Decision**: the reader toggle adopts the suite `button` fragment and keeps each theme's own script – the suite has no toggle component (shadcn's Toggle is outside the 20) and the three scripts persist under different keys and attributes that saved choices depend on; a `switch` fragment would change role and the contract tests, and a shared script would reset saved skins.
- **Decision**: options show the page title only – the combobox writes the selected option's text into the input, so a title-plus-snippet option would put the snippet in the field; a snippet would need the combobox to take a separate label attribute (a story S04 change).
- **Decision**: matching is arbor's rule for all three themes (every term, case-insensitive, over title, summary, content and tags, at most 20) – lattice matched the whole phrase over three fields; one client needs one rule and the all-terms rule is the stricter-to-read superset for multi-word queries.
- **Decision**: selection navigates by reading the combobox's hidden value after its own handler ran, so the combobox needs no new event – story S04 guarantees the stored value; if the landed combobox does not store `data-value`, add the smallest selection signal to the combobox and re-run its gate record, and report it.
- **Decision**: the client is written as `trellis-search.js` in the directory of the configured index, whenever the index is written – "beside the index" (TD-021); layouts already assume the default `search-index.json` at the asset base. Another name changes the layouts and tests only.
- **Decision**: `uses: [trellis_ui]` is static per theme, so a site that turns off `show_search` and the skin toggle on an adopting theme still ships the assets; arbor always uses the copy button – making `uses` conditional on params needs a hook change story S07 does not make.
- **Decision**: `min_trellis_version` of the four adopting manifests becomes `0.14.0` – an older tool ignores `uses` and then fails on `trellis-ui/…` with a template-not-found error, while `trellis theme add` already refuses a too-new manifest up front.
- **Decision**: committed theme screenshots are recaptured only for a theme whose adopted control is visible in the old image (read both) – they are byte-pinned and public in the gallery, and an unchanged image needs no new pin; the owner reviews any recaptured image at release prep.


## Implementation Plan

### Implementation Tasks

- **TI01** `trellis_site` ships one search client: the script is embedded in the package as a raw string and written as `trellis-search.js` next to the index whenever the index is written, counted in `staticFileCount`; the script is authored to scenarios S02 to S04 (hook, fetch failure disables the control, template clone, textContent only, selection navigates, 20-result cap, all-terms match).
  - Pattern: `search_index_generator.dart#SearchIndexGenerator.writeToOutput`. Port the failure and progressive-enhancement behaviour of `themes/arbor/static/js/search.js`; read its header comment before deleting it.
  - Update existing count assertions that include search-enabled builds.
  - **Verify**: `packages/trellis_site/test/search_index_generator_test.dart#writes the client beside the index and counts it` and `#writes neither file when search is disabled` – bytes equal the shipped constant; `cmd: git grep -n -i -e trellis_ui -e 'data-slot' -e 'trellis-combobox' -- packages/trellis_site/lib; test $? -eq 1` – SC02.
  - **SATISFIES**: S01, SC02

- **TI02** The four adopting themes opt in and link the suite: each `theme.yaml` lists `uses: [trellis_ui]` and `min_trellis_version: 0.14.0`; each `base.html` links `trellis-ui/trellis-ui.css` and `trellis-ui/trellis-ui.js` (`defer`) from the theme's `assetBase`, once per page; bloom and verdant are untouched.
  - Pattern: the existing `assetBase` script tags in `themes/arbor/layouts/base.html`. Contract tests that pin `minTrellisVersion '0.12.0'` (lattice, meadow) and the folio/arbor manifest checks follow.
  - **Verify**: `test/theme_suite_controls_test.dart#only adopting themes ship and link the suite` (six examples, root and `/trellis/`, bytes against `trellis_ui`) and `#manifests list uses and the minimum version`; `cmd: git diff --quiet -- themes/bloom themes/verdant` – the two untouched; `cmd: git diff --quiet -- packages/trellis_site/lib/src/site_config.dart packages/trellis_site/lib/src/theme_manifest.dart packages/trellis_site/lib/src/trellis_site_builder.dart` – adoption left story S07's hook untouched (SC05).
  - **SATISFIES**: S08, S12, SC05

- **TI03** Arbor's search is the suite combobox over the shared client: the shell carries `data-trellis-search`, the combobox fragment (input `disabled`, accessible name "Search documentation") and the results template; the layout loads `trellis-search.js` from the asset base only when `show_search`; `static/js/search.js` and the old result styles are gone; the browser test file replaces the node-harness tests and keeps every scenario they held.
  - Search styling that survives is the shell's placement and width; results styling is the suite's. Resolve TD-036 if its opacity rule disappears with the old input.
  - **Verify**: `test/search_client_browser_test.dart#typing lists matches and Enter or click opens one`, `#no match, empty query and markup in titles`, `#an unavailable index leaves no control`, `#without script the shell is hidden and the input disabled`, `#search off ships no shell or script` – arbor, mutation check: delete the `.catch` that disables the control and the unavailable-index test must go red; `cmd: test ! -e themes/arbor/static/js/search.js && test ! -e test/search_client_harness.js && test ! -e test/search_client_behavior_test.dart && test ! -e test/search_client_test.dart`.
  - **SATISFIES**: S02, S03, S04, S05, SC01, SC03

- **TI04** Folio and lattice use the same shell and client: their per-theme `search.js` copies are deleted, folio's `VENDORED.md` and the hooks `data-arbor-search` and `data-lattice-search` are gone, and their contract tests assert the new surface (shell hidden and input disabled at serve time, results capped and scrollable, empty state announced, `trellis-search.js` at the prefixed URL) in place of the old class-ratchet.
  - Fold the three themes into the parameterised cases of `test/search_client_browser_test.dart` (lattice with `/trellis/`).
  - **Verify**: `test/search_client_browser_test.dart#typing lists matches and Enter or click opens one` over arbor, folio and lattice; `cmd: dart test test/folio_theme_contract_test.dart test/lattice_theme_contract_test.dart` – run output shows browser tests executed, not skipped; `cmd: test ! -e themes/folio/static/js/search.js && test ! -e themes/lattice/static/js/search.js && ! git grep -q -e data-arbor-search -e data-lattice-search -- themes`.
  - **SATISFIES**: S02, S05, SC01

- **TI05** The reader toggle in lattice, folio and meadow is a `trellis-ui/button` fragment (variant and size chosen to match the control's role: text badge in folio, icon in lattice and meadow) with its original `data-*-toggle` hook, `hidden` attribute, label text and `aria-*` unchanged; the theme scripts keep their logic.
  - Pattern: `themes/folio/static/js/folio.js` sets the label with `textContent`, so the fragment's slot content must be plain text or what that script replaces.
  - **Verify**: `test/theme_suite_controls_test.dart#toggle applies, persists and reports its state` (three themes, light and dark OS scheme, stored values) and `#toggle is a suite button`; `cmd: dart test test/meadow_theme_contract_test.dart test/theme_contract_test.dart` – the node toggle harness still passes with its hooks. That harness's `node` calls (`test/theme_use_support.dart`, `test/meadow_theme_contract_test.dart`) predate this story and are legacy; this story adds no Node, and `theme_suite_controls_test.dart` is the proof of record.
  - **SATISFIES**: S06, SC03

- **TI06** Arbor's code-copy control is a suite button: the layout renders one `<template>` holding the `trellis-ui/button` fragment, `code-enhance.js` clones it into each code bar with the "Copy" label and its Copied/Error feedback and timings unchanged, and the old `.code-copy` rules are retired.
  - **Verify**: `test/theme_suite_controls_test.dart#copy button copies, reports success and failure, and fits at 390` (clipboard stub resolve, reject, absent).
  - **SATISFIES**: S07, SC03

- **TI07** Each adopting theme maps its palette onto suite tokens for its controls: one Sass partial per theme declares the bridge on the containers of the search shell, the toggle and the code bar (SC04), the theme rules that reach suite markup are scoped away with a comment, and a suite button in the article body keeps the suite defaults.
  - Verify the mapping by computed colour in a render, not from the Sass; pick `--primary-foreground` so the contrast clears 4.5:1 in both skins.
  - **Verify**: `test/theme_suite_controls_test.dart#controls follow the theme palette in both skins` and `#axe finds no violation in the adopted controls` (vendored axe of story S02 under `tool/ui_gate/vendor/`; mutation check: map `--primary-foreground` to `--primary` in one theme and the contrast case must go red); `cmd: git grep -n -E ':root|^html' -- 'themes/*/sass/_suite*.scss'; test $? -eq 1`.
  - **SATISFIES**: S10, SC04

- **TI08** The strict policy holds on the adopting themes: the four examples load and run their controls with 0 suite-caused violations and exactly the TD-023 allow-list.
  - The allow-list lives in the test with a comment naming TD-023; any other violation fails with its directive, `blockedURI` and sample.
  - **Verify**: `test/theme_suite_controls_test.dart#strict policy: only the TD-023 inline script is blocked` – mutation check: add an inline `<script>` to the arbor layout and the test must go red.
  - **SATISFIES**: S09

- **TI09** Recorded appearance is refreshed deliberately: the four adopting baselines re-recorded; the changed nodes listed by path and confined to the adopted controls; screenshots recaptured and re-pinned only per the decision; bloom and verdant unchanged.
  - Review procedure: diff old and new JSON by node key `k` with a throwaway script in `.agent_temp/`, print added, removed and changed keys per theme and capture, and fail on any key outside an adopted control's subtree (identified by its class in `c`); investigate it as a leak from the suite or a theme rule (see Constraints). Report the counts per theme.
  - **Verify**: `cmd: dart test test/visual_baseline_test.dart` (macOS) – green after re-recording, run output attached; `cmd: git diff --quiet -- test/visual_baselines/bloom.macos.json test/visual_baselines/verdant.macos.json`; `cmd: dart run tool/generate_theme_gallery.dart --check`; `cmd: dart test test/theme_contract_test.dart test/site_reflow_test.dart` – browser tests executed.
  - **SATISFIES**: S11

- **TI10** Story S07's docs-site artifacts match lattice adopting the suite: the reference layout no longer links the suite itself, and its tests assert one link per reference page; the docs site builds in both deploy shapes with no warning and 0 broken links.
  - **Verify**: `cmd: dart test test/ui_reference_site_test.dart test/site_migration_contract_test.dart test/site_reflow_test.dart` – every story S07 scenario still asserted, browser tests executed.
  - **SATISFIES**: S08

- **TI11** Docs and records are current: TD-021 closed (TD-036 closed or reworded), `AGENTS.md`, the theme-authoring guide, the search-and-feeds and theme-authoring site pages, the architecture doc search lines (the "Current through" marker moves only if the whole document is verified), the four themes' `VENDORED.md`/README notes, `tool/visual_baseline.dart`'s comment, a LEARNINGS entry (unlayered theme rules beat the layered suite; a `:root` bridge would break the preview comparison), and `## 0.14.0` bullets in `trellis_site` and the four themes' notes (arbor, folio, lattice, meadow: now require 0.14.0).
  - **Verify**: `cmd: git grep -n -e 'themes/arbor/static/js/search.js' -e 'data-arbor-search' -- AGENTS.md docs site dev; test $? -eq 1`; `cmd: dart run tool/generate_theme_gallery.dart --check`.
  - **SATISFIES**: SC01, S12


## Final Validation Checklist

- Fast tier from `KEY_DEVELOPMENT_COMMANDS.md` green, with the browser tests shown executed, not skipped; plus `dart test test/visual_baseline_test.dart` on the macOS host.
- Per adopting theme, the bytes the suite adds to a page (gzip CSS plus JS) and the whole-site total are reported against the 25 KB gate.
- Build arbor, folio, lattice and meadow examples with `buildExample` per `VISUAL-VALIDATION.md`, capture the home and a docs page at 390 and 1440, light and dark, with the search popup open, and read the PNGs: palette matches the theme, popup inside the viewport, nothing overlaps, copy and toggle buttons legible. Check meadow's and folio's header at 390.
- Run the same checks once under a prefix (`--path-prefix /trellis/`) for lattice, since the docs site ships that way.
- AOT proof is not repeated here; story S07's covers the embedded suite and this story adds no embedded asset beyond one script string.

## Discovered Requirements

- **Canonical user-doc destination.** **Description:** `docs/guides/theme-authoring.md` moved to
  `site/content/docs/themes/authoring.md` in committed public documentation consolidation `8a598ed`. **Rationale:** the FIS predates
  the owner's 2026-11-17 documentation move. **Interpretation:** update the canonical destination and run the
  same documentation checks there; do not recreate `docs/` or mirror the page. Record old Verify paths as
  `spec-stale` drift when executing them against their relocated file. Current `dev/DECISIONS.md` explicitly
  keeps 0.14 execution in this private plan; the planning move applies from 0.15.
  **Traced from:** S02/TI12 integration. **Date:** 2026-11-17.

- **Native keyboard and active-capture proofs.** **Description:** shared GateDriver Enter sends carriage-return text on native Chrome
  keyDown; Firefox active-state appearance restores document focus only, without target.focus or keyboard modality
  forcing. **Rationale:** code-only CDP Enter produced zero native activations, and unfocused held-pointer capture
  lost native focus paint. **Interpretation:** reuse the landed drivers and their regression examples; direct CDP
  keyboard proofs must send native Enter text and assert actual single activation, rather than substituting click.
  A contention fixture uses an explicit popup with a visible source and actual blur: a named tab can hide the
  source and suspend RAF. Preserve native pointer behavior and button/link no-ring expectations. Original full-run
  visibility was not recorded. **Traced from:** S03 keyboard discovery and S05 shared check-blocking repairs.
  **Date:** 2026-11-17.


- **Verified combobox selection contract.** **Description:** selecting a combobox option updates visible text and its hidden value,
  with no selection event emitted. **Rationale:** S04 proves native selection and paired label/ID history.
  **Interpretation:** read the hidden value after the component's native handler, as this FIS already intends;
  do not invent an event dependency or add suite JS absent a failing proof. The current SDK uses397/400 effective
  JS lines. Static options are not filtered by the component; S09's one search client owns matching/results.
  **Traced from:** S04/TI07 and current public catalogue. **Date:** 2026-11-17.


- **Causal hover measurement replay.** **Description:** the landed harness retries only forced Firefox hover snapshots interrupted
  by observed document/window backgrounding, replaying fresh state plus actual hover and failing after3 attempts.
  **Rationale:** real focus loss correctly closes a combobox and can suppress dialog autofocus paint.
  **Interpretation:** reuse the existing capture path; never force target focus/reopen UI or retry generic errors,
  popup closure or visual differences. A genuine in-page dismissal and perpetual interruptions still fail;
  CSP and JS diagnostics survive collect-before-navigation. Native keyboard and HTMX lifecycle stay unforced.
  One new dialog reference corrected five proven foreground focus-paint leaves; no other old state changed.
  **Traced from:** S04/TI08 and driver/active/hover regression controls. **Date:** 2026-11-17.


- **Preview focus isolation is an observed theme collision.** **Description:** S07's independent visual review reproduced Lattice's unlayered global focus rule overriding suite radius and outline on actual modal autofocus, native Tab and combobox. **Rationale:** idle-state comparisons did not exercise focus. **Interpretation:** retain the docs preview's scoped lower-layer restoration and verify adopting controls with real native focus in both skins; an unfocused computed-style comparison cannot establish focused parity. The table scroll wrapper retains its browser focus indicator. Keep the suite default tokens outside adoption containers. **Traced from:** S07/TI08 final independent recapture. **Date:** 2026-11-18.

- **Landed site source and reference contract.** **Description:** S07 ships generic `SiteSource`/`sourceFactories`, ordered site/theme source-name union, source loader below theme/site in both engines, and source asset preflight before output. CLI owns the `trellis_ui` factory. Source-enabled post-Markdown shortcodes receive page-scoped YAML as base context, overridden by explicit string parameters. **Rationale:** the core/site package must remain suite-agnostic and real fragment lists/maps require structured values. **Interpretation:** consume the existing registry and hooks; preserve no-use byte parity, unknown-name/path failures and no-output cleanup. The generated inventory derives signatures, longest-prefix classes and every browser verdict, distinguishes qualified/manual-open from supported, and rejects an unexpected nested reference route. Regenerate `site/data/ui_components.yaml` after SDK signature/slot or qualification changes; preserve all25 real examples and root/prefix proof. The docs preview has scoped token/layer restoration plus an opaque suite background to prevent theme contrast/focus leakage. **Traced from:** S07/TI01–TI10 and independent review. **Date:** 2026-11-18.

- **Search output accounting and the hook fence.** **Description:** the current builder counts one file when `SearchIndexGenerator.writeToOutput` returns true; S09/TI01 requires both index and client counted. TI02's broad whole-file `git diff --quiet` names the same builder only to protect S07's source hook. **Rationale:** the named OC01/TI01 outcome and SC05 no-hook-change constraint are compatible, while a blanket whole-file diff would reject the required unrelated accounting edit. **Interpretation:** make the minimum search-output count change, leave the source-resolution/uses hook unchanged, and prove that hook unchanged with a scoped diff plus the existing source tests. Record the broad whole-file Verify target as spec-stale; do not redesign the source hook or broaden SearchIndexGenerator's public API. **Traced from:** S07 simplification reconnaissance and S09/TI01–TI02. **Date:** 2026-11-18.

- **Reader toggle semantics differ by theme.** **Description:** Folio changes `aria-pressed` and its visible edition text while its accessible name stays "Change color scheme". Lattice exposes the next action through its accessible name and has no `aria-pressed`. Meadow changes both name and pressed state. **Rationale:** S06 describes the three controls collectively, while TI05 and OC02 preserve the existing ARIA and scripts. **Interpretation:** prove each theme's existing accessible state and name directly, including absence of `aria-pressed` where it did not exist. **Traced from:** TI05. **Date:** 2026-11-18.

- **Result template data comes from the theme.** **Description:** Trellis can read list and map values in context but its expression grammar does not construct collection literals. `#lists.isEmpty(null)` already handles the initial no-options state. **Interpretation:** render the prototype from a one-entry YAML list in each adopting search theme's own data directory. The suite options fragment remains the only markup definition. **Traced from:** TI03–TI04. **Date:** 2026-11-18.

## Implementation Observations

#### DRIFT

- spec-stale: the former theme-authoring path was consolidated into `site/content/docs/themes/authoring.md`. | Stale targets: TI11, Work Areas | Canonical destination used.
- spec-stale: TI02's whole-builder diff also selects the search output accounting that TI01 requires. Only the file count and search/asset descriptions changed in that file. | Stale targets: TI02 Verify | Scoped diff and existing site source tests cover SC05.
- spec-stale: `trellis theme add` warns about a newer minimum and then installs. Bloom and Verdant retain their existing 0.12.0 minimum and omit the suite opt-in. | Stale targets: S12 title, S12 Then, minimum-version decision rationale | Preserve existing CLI compatibility handling and assert the four 0.14.0 manifests.
- spec-stale: S07's non-reference asset assertion is superseded by S09's Lattice adoption. | Stale targets: S07 scenario S07 and `test/ui_reference_site_test.dart` asset locality assertion | Each page gets exactly one copy of each linked suite asset. The rest of S07's reference contract stays in force.

#### Implementation readings

- The site generator retains the existing public boolean return. The CLI build counts both newly generated files.
- `trellis-search.js` is reserved as an index basename because sharing its path would overwrite JSON with JavaScript. The output test reproduces the collision before the guard and asserts rejection before either search file is written.
- The architecture update is limited to the SSG and theme sections. Its whole-document coverage marker remains at its existing coverage.
- ASSUMPTION: Meadow's content-page capture uses its bundled About page. A future bundled docs route would replace that target.

#### DRIFT

- spec-stale: Folio's provenance file continues to document the vendored typeface and remaining edition script. | Stale targets: TI04's instruction to remove the whole `VENDORED.md` | TI11's provenance update removes the obsolete search-client provenance and keeps the active entries.

#### Code and gap review

- Fix, high: all four adopters initially failed the existing visible-focus guard with `has 1px none outline`. Scoped 2 px inset outlines use the public theme ring or foreground tokens. The unchanged guard passed 6/6 and the dedicated palette and axe cases passed 2/2 after the repair.
- Fix, medium: an existing incompatible file at the shared client path was overwritten. Reject the collision before writing either search artifact. A byte-identical client is accepted for retries. The package and path-prefix checks passed 127/127 after the red collision proof.
- Fix, medium: the reversed-script fixture could measure before a slow index arrived. It now waits for the browser's actual index decoding. Firefox passed with the real implementation. Removing the upgrade wait in an isolated fixture failed with `Expected: true` and `Actual: <false>`.
- Note, low: Folio provenance discrepancy recorded above.

#### Independent visual review

- Pass with 0 P1, P2 or P3 findings. The reviewer built five deploy variants, read 56 independent browser frames and 12 old/candidate gallery references, and confirmed 16 open popups stayed within the viewport and clear of article content. The review captured 26 native focus states. All frames reported zero document-width overflow and zero font errors. Review evidence lives in the S09 public worktree at `.agent_temp/s09/independent-visual/`.

#### Direct validation details

- Only Folio, Lattice and Meadow displayed an adopted control in their prior public home screenshots. Recaptured and re-pinned those six gallery images. Arbor's old home images and both non-adopters' images remain byte-identical.
- The digest audit compares every node by resolved capture and path. Arbor had 72 additions, 24 removals and 12 changes. Folio had 72, 12 and 18. Lattice had 72, 24 and 36. Meadow had 0, 0 and 18. Each theme had 0 changed nodes outside the adopted controls.
- GZipCodec level 9, measured from each of the four root builds and prefixed Lattice, produced 20,052 B linked CSS/JS and 20,225 B across the three suite artifacts on disk. The CSS, JS and indicator artifacts were 15,179 B, 4,873 B and 173 B compressed. Their raw total was 151,741 B.

#### Post-review browser repairs

- Chrome touch emulation at 390 px found 44 px targets extending beyond the fixed search frames in Arbor and Lattice and the fixed Copy bars in Arbor. Added a rendered regression, grew the two bordered input groups to 46 px for a coarse pointer, and let Arbor's code bars size to their contents under the same media query. The proof passed for all four themes. I read eight light/dark follow-up PNGs covering Arbor search and copy, Lattice search and prefixed Lattice search. The popups fit the viewport and all eight captures report zero horizontal overflow and font errors.
- The existing docs-site live dropdown assertion read after one animation frame and observed `Expected: ['true', 'menuitem', 'undefined']` and `Actual: ['false', null, 'undefined']` in fast. It now awaits the native `toggle` event that updates expanded state and focus. The same expectations passed in the focused browser check.
- The independent visual reviewer recaptured and read those eight touch states from the existing CLI builds. Chrome reported one touch point and a coarse pointer across all frames. All six popups fit the sidebar and Arbor's native touch tap displayed Copied in a contained 44 px button. No P1, P2 or P3 findings, horizontal overflow or font errors. Evidence is in `.agent_temp/s09/independent-visual/capture-coarse.log` and `coarse-shots/` in the S09 public worktree.
- The final-source macOS visual comparator exited 0 with `00:54 +7: All tests passed!`. The structural audit passed against the staged change set.

#### Final proof and commit

- Exact fast tier exited 0. Workspace analysis reported no issues in all 14 jobs, 3,522 package tests passed, and the root runner reported `03:23 +273 ~2: All tests passed!`. Final formatting reported 50 files and 0 changed. The two root skips are no-JavaScript control checks for non-adopters with no control to exercise. The package skip is Linux-only.
- TI05 `dart test test/meadow_theme_contract_test.dart test/theme_contract_test.dart` exited 0, `00:30 +72 ~2: All tests passed!`.
- TI09 `dart test test/theme_contract_test.dart test/site_reflow_test.dart` exited 0, `01:05 +60 ~2: All tests passed!`.
- TI10 `dart test test/ui_reference_site_test.dart test/site_migration_contract_test.dart test/site_reflow_test.dart` exited 0, `01:06 +19: All tests passed!`. Both paths preserve 0 broken links and warning-free builds.
- The verified 82-path product commit is `a9e97f8b1886b116b22e4c935c712637a31c8a00` on `feat/0.14-s09`. The S09 public worktree was clean at that tip. Full combined and release gates belong to the plan run. S08 merges second and owns the combined-source macOS theme and combobox check before merging.

- **Evidence relocation after S09 integration.** **Description:** the owned paired source worktrees and merged branch were removed after verifying hashes for1,679 archived public scratch files and the exact private receipt. **Interpretation:** historical source `.agent_temp` paths resolve under the main checkout `.agent_temp/0.14-plan-run/evidence/S09/public-agent-temp/`; private-return files are in `evidence/S09/private-receipt/`. Parent read the final coarse Arbor Copy and prefixed dark Lattice search captures. **Traced from:** feature `a9e97f8`, integrated `519b075`. **Date:** 2026-11-18.
