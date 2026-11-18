# FIS: CSS-only components, layout primitives and overrides

**Plan**: dev/spec/0.14/plan.json
**Story-ID**: S05

## Feature Overview and Goal

**Intent**: Let an app author build forms, data views and page layouts from fragments alone, and let the plan call each of those components qualified, by delivering the 15 CSS-only components and 4 layout primitives through story S01's layout and passing every automated gate item of story S02's harness.

**Expected Outcomes**:

- [OC01] An app author builds forms, data views and page layouts from the 15 CSS-only fragments (the button included) and 4 layout primitives, each rendering native semantic elements with the caller's attributes on the control and no provider class in app templates.
- [OC02] Controls hold the numbers FR4 names: targets of at least 24 px (at least 44 px and 16 px input text under a coarse pointer), destructive text and background at 4.5:1 or more in light and dark, and a visible focus indicator and checked state in forced colours, all through the public styling surface.
- [OC03] Adding the 19 components changes nothing outside suite markup, and a pasted theme block still wins in either link order.
- [OC04] Each of the 19 has a committed gate record showing every automated item passing in Chrome and Firefox under the strict policy, so stories S06 and S07 can build on it and release prep owns only the manual items.


## Required Context

- `dev/spec/0.14/prd.md#fr4-css-only-components-layout-primitives-overrides` and `#fr5-qualification-gate` – the acceptance criteria this story implements; binding.
- `dev/spec/0.14/prd.md#non-functional-requirements` and `#edge-cases` – strict policy, WCAG 2.2 AA, isolation, twice-inserted fragment ids.
- `dev/spec/0.14/s01-porting-pipeline-and-trellis-ui-package.md` – the contracts built on: file layout (Work Areas), template names `trellis-ui/<name>`, gallery pages and shell, `tool/pins.json`, cascade layers and the isolation fixture (Constraints), the button (TI08), the layout-scanning checks (SC01, SC02).
- `dev/spec/0.14/s02-headless-qualification-harness.md` – manifest keys, gate record items (Architecture Decision), touch-target and forced-colour constraints, machine-local browser paths, "never kill browsers by name".
- `dev/spec/0.14/plan.json#sharedDecisions` – "Component layout and gallery" and "Harness input and gate record".
- `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/build-own-cost-map.md#table` – per-component native-element recipe and pitfalls for rows 1-3, 6, 14-18, 21 and L1-L4; the layout primitives are authored from rows L1-L4.
- `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/o6-spike.md#hand-layer` – touch-target layer; § Chrome gates, "Mechanisms found while running the gates" – the 4.02:1 destructive finding.
- Spike starting code, planning repo, `git show spike/trellis-ui-o6-shadcn-port:docs/temp/trellis-ui-o6-shadcn-spike/<path>` (never check it out): `templates/components/field.html` (field, native select, error wiring) and `static/trellis-touch.css`. Examples to port into S01's layout, not to copy.
- `dev/adrs/ADR-014-component-composition-primitives.md` and `packages/trellis/CHANGELOG.md#0130` – `tl:slot` (see § 1; a slot inside a fragment's `tl:each` exposes the loop variable to caller markup, which the table needs; `tl:each` on a caller marker throws), `tl:attrs`, `...rest`.
- `dev/adrs/ADR-012-trellis-ui-contract.md#decision` – public styling surface: shadcn token names and `trellis-<component>[-<part>]` classes.


## Acceptance Scenarios

- **S01 [OC01] Every CSS-only fragment renders native semantic markup, with defaults when invoked bare**
  - **Given** an engine on `CompositeLoader([app loader, suite loader])` and each fragment invoked with no arguments
  - **When** it renders
  - **Then** the root element carries `data-slot` and its `trellis-<component>` hook class, with no `tl:*` attribute left, and the element is: `input` an `<input>`; `textarea` a `<textarea>`; `native-select` a `<select>` of `<option>`s in a wrapper with an `aria-hidden` icon; `checkbox` an `<input type="checkbox">`; `radio` an `<input type="radio">` inside a `<fieldset>` with a `<legend>`; `switch` an `<input type="checkbox" role="switch">`; `badge` a `<span>`; `card` a container whose title is a heading element; `alert` a `<div>` with no implicit role; `separator` an `<hr>` (horizontal) or a `role="separator"` element with `aria-orientation="vertical"`; `table` a `<table>` with `<caption>` and `<th scope="col">` inside a scroll wrapper that is `role="region"`, labelled and `tabindex="0"`; `pagination` a labelled `<nav>` of `<ul>`/`<a>` whose current page has `aria-current="page"` and whose unavailable previous or next is `<span aria-disabled="true">`; `breadcrumb` a `<nav aria-label="Breadcrumb">` with an `<ol>` whose current item has `aria-current="page"` and is not a link, separators hidden from assistive technology; icon-only links and buttons have an accessible name.

- **S02 [OC01] Caller attributes land on the native control**
  - **Given** an app template `<input tl:replace="~{trellis-ui/input :: input}" name="email" type="email" required hx-post="/validate" hx-trigger="change" aria-describedby="email-hint" class="app-x">`, and the same shape for textarea, native select, checkbox, radio and switch with `name`, `value`, `checked`, `disabled`, `aria-*` and `hx-*`
  - **When** each renders
  - **Then** the output is one control (for the select, the `<select>` and not its wrapper) carrying every attribute with valueless booleans preserved, its `class` holding the hook class and `app-x`, and no duplicate of the caller's attributes elsewhere.

- **S03 [OC01] Field wires label, hint and error from its parameters, and two copies keep unique ids**
  - **Given** the field fragment invoked with a control id, a hint, and no error; then with an error message; then twice on one page with different ids
  - **When** it renders
  - **Then** the label's `for` equals the control's id and the hint is referenced by the control's `aria-describedby`; with an error the control has `aria-invalid="true"`, the error text is `role="alert"` and `aria-describedby` lists hint and error; without one the control has neither `aria-invalid` nor the error element; the two-copy page contains no duplicate `id`, and `TemplateValidator` reports no warning for the fragment.

- **S04 [OC01] Table rows and pagination come from app data**
  - **Given** the table fragment given a list of three row maps and a caller slot marker whose cell markup reads the row variable, and the pagination fragment given a server-computed page list with the third page current and an ellipsis
  - **When** they render
  - **Then** the table has a header row and exactly three body rows whose cells hold each row's values; pagination marks only the third page `aria-current="page"` and renders the ellipsis as non-interactive text hidden from assistive technology.

- **S05 [OC01] A value outside the offered set falls back to the default**
  - **Given** badge and alert invoked with a variant they do not offer, and each layout primitive with a gap, width or column size outside its scale
  - **When** they render
  - **Then** the output carries the default variant or scale class and no class without a rule in the stylesheet, and no `style` attribute.

- **S06 [OC01] [runtime] Layout primitives lay out as named, in DOM order**
  - **Given** one gallery page per layout primitive loaded at 390, 768 and 1440 px under the strict policy
  - **When** child geometry is read
  - **Then** stack children are one column separated by its gap; cluster children wrap onto further rows at 390 px without horizontal overflow of the document; grid has more columns at 1440 px than at 390 px, all the same width, with no child narrower than its minimum; a sidebar layout sits beside its content at 1440 px and stacks at 390 px with the side whose DOM position it has (the sidebar first in the DOM is the start side, no parameter flips it); container is centred with its inline size capped at its size step and padded inline at 390 px; for every child, DOM order and visual order agree.

- **S07 [OC02] [runtime] Touch targets hold 24 px and 44 px, inputs use 16 px text on coarse pointers**
  - **Given** every gallery page of the 15 CSS-only components loaded once with a fine pointer and once with an emulated coarse pointer, confirmed by `matchMedia`
  - **When** every interactive element is measured, including checkbox, radio and switch inputs, pagination and breadcrumb links, the button in every variant and size, and the table's scroll region
  - **Then** the smaller side of each is at least 24 px with a fine pointer and at least 44 px with a coarse one, and the computed `font-size` of input, textarea and native select is at least 16 px with a coarse pointer.

- **S08 [OC02] [runtime] Destructive colours meet 4.5:1 in light and dark**
  - **Given** the button, badge, alert and field-error examples in their destructive form, in light mode and with `.dark` on `html`
  - **When** axe runs at WCAG 2.2 A and AA tags
  - **Then** it reports 0 `color-contrast` violations; with the override removed the same run fails naming the destructive button.

- **S09 [OC02] [runtime] Focus and checked state survive forced colours**
  - **Given** the checkbox, radio, switch, input, native select and button pages with forced colours emulated and read back as active
  - **When** each control is focused with the keyboard and, for the three choice controls, checked
  - **Then** the focused control has a non-`none` outline or a border whose computed colour differs from its unfocused state, and each checked control differs from its unchecked twin in a property forced colours keep (border or outline colour, or a system-colour fill).

- **S10 [OC03] [runtime] Isolation and the theme block hold with all 19 components loaded**
  - **Given** story S01's isolation fixture (non-suite elements in light and dark, and a pasted `:root`/`.dark` theme block linked before and after) against the aggregate stylesheet built from all 19 components
  - **When** it runs
  - **Then** every non-suite element has identical standard computed properties with and without the stylesheet, and the pasted `--primary` wins in both orders and modes.

- **S11 [OC04] [runtime] Every component passes every automated gate item in both browsers**
  - **Given** the gallery served with the strict policy and a manifest for each of the 19 pages, with default, hover, focus-visible, active, disabled, invalid (where the component has it), checked (where it has it) and dark states
  - **When** the gate runs in headless Chrome and headless Firefox
  - **Then** each record shows `provenance`, `self-hosting`, `strict-csp`, `semantic-markup`, `htmx-lifecycle`, `keyboard`, `wcag-axe`, `forced-colors`, `responsive`, `zoom`, `reduced-motion`, `touch-target` and `visual` as `pass` for both browsers, 0 violations, the two screen-reader pairs and Safari as `release-prep`, the automated verdict `pass`, and a rerun rewrites every record byte for byte.

- **S12 [OC04] A page without a manifest, or a manifest without a passing record, fails the records test**
  - **Given** the committed manifests and records, then one gallery page added with neither, then one record edited to `fail` on one item
  - **When** the records test runs
  - **Then** it fails naming the page in the first case and the page and item in the second.


## Structural Criteria

- **SC01** The layout primitives' CSS contains no `order`, `row-reverse`, `column-reverse`, `grid-area`, `grid-row`, `grid-column` or `direction` declaration, so none can offer a visual order that differs from DOM order (FR4).
- **SC02** The committed pipeline outputs stay reproducible with the 15 components added: `port.dart check`, `port.dart parity` and `embed.dart --check` exit 0, and every `parity-ignore.json` entry this story adds carries a non-blank reason.
- **SC03** Story S01's layout-scanning checks stay green over this story's fragments, gallery pages and hand CSS: no inline `style`, `<style>`, inline script or `on*` attribute, and `TemplateValidator` clean on every fragment.
- **SC04** `README.md` lists all 19 fragment names with signature, slots and closed scales, since stories S06 and S07 import them.


## Scope & Boundaries

### Work Areas
Paths are relative to the trellis-public root, where the story executes. The 19 components, which the gallery pages (`/components/<name>`), fragments (`trellis-ui/<name>`), manifests and records are all named after: `button`, `input`, `textarea`, `field`, `native-select`, `checkbox`, `radio`, `switch`, `badge`, `card`, `alert`, `table`, `pagination`, `breadcrumb`, `separator`, `stack`, `cluster`, `grid`, `container` (its page also shows `sidebar`).

- `packages/trellis_ui/tool/pins.json` and `tool/parity-ignore.json`, `vendor/`, `generated/` and `lib/src/embedded_assets.g.dart` (regenerated, never hand-edited): the shadcn components `input`, `textarea`, `field`, `label`, `native-select`, `checkbox`, `radio-group`, `switch`, `badge`, `card`, `alert`, `table`, `pagination`, `breadcrumb`, `separator` added to `components`.
- `packages/trellis_ui/assets/fragments/<name>.html` and `assets/css/hand/<name>.css` for the 18 new components (layout primitives are hand CSS only), plus the cross-cutting `assets/css/hand/zz-touch.css`, `zz-contrast.css` and `zz-forced-colors.css`.
- `packages/trellis_ui/gallery/pages/<name>.html` for the 18 new pages; the button page extended where its manifest needs it; the shell's htmx is story S01's and the gate command is story S02's `--serve` (plan.json sharedDecisions).
- `dev/ui-gate/manifests/`, `records/`, `baselines/` for 19 components (locations are story S02's defaults).
- `packages/trellis_ui/test/`: `css_only_components_test.dart`, `layout_primitives_test.dart`, `css_only_browser_test.dart`, `gate_records_test.dart`.
- Docs: `packages/trellis_ui/README.md` (fragment catalogue), `AGENTS.md`, `dev/state/LEARNINGS.md`.

### What We're NOT Doing
- Behaviour components (dialog, dropdown menu, combobox, toast, tabs), any JavaScript, custom elements – story S04. A CSS-only fragment ships no script.
- Declaring a component supported in docs or `CHANGELOG.md` – that needs the manual screen-reader and Safari items too (FR5), so it is release prep and stories S07 and S08. The records here are the evidence.
- The payload (25 KB gzip) and JS-line release gates – story S08 measures them across the suite.
- Docs-site reference pages, the admin example, scaffolds – stories S07 and S06.
- Upstream parts beyond what the 15 components need (`input-group`, field separator-with-text, card `sm`/`image` variants, the alert action slot) – not in the PRD; each slot upstream declares and the fragment omits gets a reasoned `parity-ignore.json` entry (TI01).
- A layout option that reorders (`reverse`, `order`, sidebar side) and arbitrary-value gap or width parameters – FR4 forbids the first, the strict policy forbids the second.
- Changing the shadcn tokens or the generated CSS by hand to reach the contrast numbers – the override is hand CSS against `trellis-*` classes.


## Architecture Decision

**Approach**: Add each component the way story S01 added the button: shadcn components with a `cn-` hook go into `pins.json` and are generated, then a fragment and a gallery page. Where shadcn's markup is Base UI (checkbox, radio, switch) the fragment is a native input and hand CSS restates the vega look on `:checked`, `:focus-visible`, `:disabled` and `[aria-invalid]`, because the generated rules key on Base UI's `data-checked`/`data-unchecked`, which a native input never carries. Layout primitives are hand CSS only, with parameters mapped to closed class scales. The touch layer, contrast override and forced-colours rules are three last-sorting hand files. Each page gets a manifest; story S02's `--serve` runs the gate over story S01's gallery.
**Why this over the floor**: The floor is generated CSS alone. FR4 requires 24/44 px targets, 4.5:1 destructive contrast and four layout primitives that shadcn does not have, and the upstream checkbox, radio and switch rules cannot match a native element. The gate runs through story S02's `--serve` against story S01's gallery, the one command stories S04 and S08 also use.


## Constraints & Gotchas

- **Constraint**: Runs in trellis-public on the 0.14 branch after stories S01 and S02. `fetch` and the compiler download need network; the gate needs Chrome and Firefox with geckodriver (story S02's machine-local paths, `GECKODRIVER`). Never kill browsers by name; other agents run them.
- **Constraint (story S04 follows)**: story S04 runs after this story and builds on its button, input, field, touch layer (`zz-touch.css`), README catalogue table and `gate_records_test.dart`; keep each extensible (alphabetical entries, one table format, per-component test groups). Regenerate `generated/` and `*.g.dart` with `port.dart build` and `embed.dart`; never hand-edit.
- **Constraint (test tiers)**: a test that runs the full gate over real pages carries the `ui-gate` tag, and one that compares a per-OS visual baseline carries `visual`; both are excluded from CI's tiers and run in the release-gate tier on the maintainer's macOS machine (plan.json sharedDecisions "Full-gate tests run locally", ADR-012 § Upstream sync: gates run locally), so a missing Linux baseline or Firefox never fails CI.
- **Constraint (strict policy)**: no `style` attribute, so layout parameters (`gap`, column minimum, container width) map to a closed, named scale of hook classes, never a value written into markup; icons are inline `<svg>` without `style`. htmx injects a `<style>` unless the shell sets `includeIndicatorStyles` false in an `htmx-config` meta before the htmx script and links `/trellis-ui/htmx-indicator.css` (story S03 documents the same trap).
- **Constraint (hand CSS order)**: the bundler concatenates hand CSS in file-name order inside one layer, so the three `zz-` files must sort after every component file to win at equal specificity (`md:text-sm` on inputs would otherwise undo the coarse 16 px). If hand CSS still loses to the generated layer, fix the layer order in S01's bundler, the smallest change, and name it in the report.
- **Constraint (native-drawn controls)**: three traps. (1) The hit box and the painted box differ: the input element itself must measure at least 24/44 px (the harness measures elements), so draw the vega 16 px box and 18.4x32 switch inside the larger box instead of growing the paint. (2) Forced colours drop `box-shadow` (where Tailwind draws rings) and may drop background fills, so the focus ring needs an outline and the checked mark a system-colour fallback (`zz-forced-colors.css`). (3) Which keys change a closed native select differs by platform (arrows open the popup on macOS, unverified here), so its keyboard script uses keys that behave identically in both browsers, chosen by running them.
- **Constraint (gate shape)**: the S02 `keyboard` item has no "not applicable". A non-interactive component (badge, card, alert, separator, stack, cluster, grid, container) declares a script asserting Tab passes through it without stopping. `htmx-lifecycle` runs on every page, so each page has a swappable region that fetches the page itself with `hx-select`, and a boosted link to a second gallery page for the history check.
- **Constraint (contrast scope)**: the 4.5:1 guarantee is for the default shadcn tokens. A pasted theme with a different `--destructive` keeps its own contrast, which is the app's to check.
- **Decision**: the gate subjects are the 19 names in Work Areas, with `container` and `sidebar` sharing one page and record, and `field` covering label, description, error and fieldset/legend – the plan counts "container/sidebar" as one primitive and "field/label" as one component; a separate `sidebar` or `label` page adds a manifest and record each.
- **Decision**: fragment signatures and slot names are the executor's and are listed once in the `README.md` catalogue, which stories S06 and S07 import – the PRD fixes behaviour, not signatures.
- **Decision**: `alert` has no implicit role; the caller passes `role="alert"` or `role="status"` (the gallery shows both), since a live region only announces when it exists before its content arrives.
- **Decision**: the layout primitives' `provenance` notice is the package `LICENSE`, since they are Trellis-authored.
- **Decision**: the dark state is `.dark` set on `html` through the manifest's `eval` escape hatch (a `classList` write is outside the policy).
- **Decision**: visual baselines are recorded on this machine (macOS) as story S02's first-recording references; a Linux recording is not made.


## Implementation Plan

### Implementation Tasks

- **TI01** The 15 shadcn components are vendored, generated and reproducible: `pins.json` lists them, `fetch` and `build` ran, `generated/` and the embedded assets are regenerated, and each orphan structural literal in `report.json` for these components is styled in hand CSS or the dropped part has a reasoned `parity-ignore.json` entry (checkbox/radio indicators, switch thumb and every Base UI part the native fragments replace).
  - **Verify**: `cmd: cd packages/trellis_ui && dart run tool/port.dart check && dart run tool/port.dart parity && dart run tool/embed.dart --check` – exit 0; and `packages/trellis_ui/test/pipeline_generate_test.dart` and `packages/trellis_ui/test/parity_test.dart` still pass (`cmd: cd packages/trellis_ui && dart test test/pipeline_generate_test.dart test/parity_test.dart`).
  - **SATISFIES**: SC02

- **TI02** `input`, `textarea` and `native-select` exist as fragments, hand CSS and gallery pages, following the button's conventions (`assets/fragments/button.html`) and the spike's `field.html` for the select wrapper and icon.
  - **Verify**: `packages/trellis_ui/test/css_only_components_test.dart#text-entry fragments render native elements, defaults and pass attributes through`.
  - **SATISFIES**: S01, S02

- **TI03** `field` exists with label, description, error and fieldset/legend parts whose ids derive from parameters, never literals, and a gallery page whose error state is a swap target.
  - **Verify**: `packages/trellis_ui/test/css_only_components_test.dart#field wires label, hint and error and keeps ids unique when inserted twice` – asserts every clause of S03 including the validator.
  - **SATISFIES**: S03, S01

- **TI04** `checkbox`, `radio` and `switch` exist as native inputs drawn by hand CSS to the vega look from `:checked`, `:focus-visible`, `:disabled` and `[aria-invalid]` (dark included), the input box itself sized per the native-drawn constraint, with gallery pages.
  - **Verify**: `packages/trellis_ui/test/css_only_components_test.dart#choice controls render native inputs, defaults and pass attributes through`.
  - **SATISFIES**: S01, S02

- **TI05** `badge`, `card`, `alert` and `separator` exist with the variants upstream offers, an out-of-set variant falling back to the default, and gallery pages.
  - **Verify**: `packages/trellis_ui/test/css_only_components_test.dart#display fragments render their semantic elements and fall back to the default variant`.
  - **SATISFIES**: S01, S05

- **TI06** `table`, `pagination` and `breadcrumb` exist with the semantic structure of S01 and data-driven bodies of S04, the table in a labelled, focusable scroll wrapper, and gallery pages whose table is wider than 390 px.
  - **Verify**: `packages/trellis_ui/test/css_only_components_test.dart#table, pagination and breadcrumb render their structure from app data`.
  - **SATISFIES**: S01, S04

- **TI07** `stack`, `cluster`, `grid` and `container` (with `sidebar`) exist as hand CSS plus fragments whose parameters select from closed scales, with gallery pages and no reordering option.
  - **Verify**: `packages/trellis_ui/test/layout_primitives_test.dart#out-of-scale values fall back and no style attribute is written` (S05) and `packages/trellis_ui/test/css_only_browser_test.dart#layout primitives lay out in DOM order at 390, 768 and 1440` (S06, using `BrowserProbe` and the gallery server); `cmd: ! git grep -n -E "(^|[^a-z-])(order|row-reverse|column-reverse|grid-area|grid-row|grid-column|direction)[: ]" -- packages/trellis_ui/assets/css/hand/stack.css packages/trellis_ui/assets/css/hand/cluster.css packages/trellis_ui/assets/css/hand/grid.css packages/trellis_ui/assets/css/hand/container.css` – no match.
  - **SATISFIES**: S05, S06, SC01

- **TI08** The touch-target layer (`zz-touch.css`) covers every interactive hook of the 15 components (button and pagination links, input, textarea, native select, checkbox, radio, switch, breadcrumb link, table scroll region): 24 px minimum, 44 px under `(pointer: coarse)`, 16 px input text on coarse pointers; the spike's layer is the starting point.
  - **Verify**: `packages/trellis_ui/test/css_only_browser_test.dart#touch targets hold 24 px and 44 px and coarse inputs use 16 px` – walks every CSS-only gallery page under both pointers, reading `matchMedia` first; mutation check: delete one hook from the layer and watch it go red naming the element.
  - **SATISFIES**: S07

- **TI09** The destructive override (`zz-contrast.css`) lifts destructive button, badge, alert and field-error text and background to 4.5:1 in light and dark by rules that select only destructive-variant `trellis-*` classes; the shadcn tokens stay as they are.
  - **Verify**: `cmd: dart run tool/ui_gate.dart --serve 'dart run packages/trellis_ui/tool/gallery.dart --port 0' button badge alert field` – `wcag-axe` passes in the light and dark states; mutation check: empty `zz-contrast.css` and watch `wcag-axe` fail with `color-contrast` on the destructive button.
  - **SATISFIES**: S08

- **TI10** `zz-forced-colors.css` gives every focusable suite control an outline in forced colours and gives checked checkbox, radio and switch a state forced colours keep.
  - **Verify**: `packages/trellis_ui/test/css_only_browser_test.dart#forced colours keep focus and checked state visible` – emulation read back before measuring; mutation check: delete the file and watch the focus clause go red.
  - **SATISFIES**: S09

- **TI11** Every page has its swappable region and a boosted link over story S01's htmx shell, and a manifest for each of the 19 pages declares states, selectors, semantics assertions, keyboard scripts (native keys per component), htmx region, provenance and, where the harness offers it, `distinct` groups.
  - Follow the key vocabulary of story S02's loader; the shell's htmx is story S01's and the gate command is story S02's `--serve`.
  - **Verify**: `packages/trellis_ui/test/gate_records_test.dart#every gallery page has a loadable manifest` – loads each through story S02's manifest loader; and `cmd: dart run tool/ui_gate.dart --serve 'dart run packages/trellis_ui/tool/gallery.dart --port 0'` runs all manifests (exit status is TI12's).
  - **SATISFIES**: S11

- **TI12** All 19 components pass every automated gate item: the gate command exits 0 in Chrome and Firefox, records and the first `visual` baselines are committed, and each defect the gate finds is fixed in the component, not waived (an `axe` override needs a written reason and none is expected).
  - **Verify**: `cmd: dart run tool/ui_gate.dart --serve 'dart run packages/trellis_ui/tool/gallery.dart --port 0'` – exit 0, run twice, `git diff --quiet -- dev/ui-gate` after the second run; and `packages/trellis_ui/test/gate_records_test.dart#every record passes every automated item in each browser it ran and leaves manual items for release prep` and `#a page without a manifest or a failing record fails` (S12, on a temp copy of the directories).
  - **SATISFIES**: S11, S12

- **TI13** The isolation fixture and theme-block check pass against the aggregate stylesheet with all 19 components.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/isolation_test.dart test/gallery_browser_test.dart test/sources_test.dart` – story S01's tests, unchanged, green (also proves SC03 over the new files); mutation check: add an unscoped `input { margin: 0 }` to one hand file and watch the isolation test go red naming the property.
  - **SATISFIES**: S10, SC03

- **TI14** The package documents what stories S06 and S07 import: `README.md` lists every one of the 19 fragment names with signature, slots and the closed scales; `AGENTS.md` records the hand-file naming rule (`zz-`) and the native-control traps; `dev/state/LEARNINGS.md` gets only the traps found that a frontier model would not already know.
  - **Verify**: `inspect: packages/trellis_ui/README.md` – every one of the 19 names appears with its signature; and `cmd: dart format --output=none --set-exit-if-changed packages/trellis_ui && dart analyze --fatal-infos packages/trellis_ui` – clean.
  - **SATISFIES**: SC04


## Final Validation Checklist

- Fast tier from `KEY_DEVELOPMENT_COMMANDS.md` is green with the new package tests included, the browser tests executed and not skipped, and `git diff --quiet -- test/visual_baselines` exits 0.
- Serve the gallery, capture every new page at 390 and 1440 wide in light and dark with `agent-browser` per `VISUAL-VALIDATION.md`, and read the PNGs: states are distinct, the table scrolls inside its wrapper instead of widening the page, nothing overflows, checkbox/radio/switch look like the vega originals despite the larger hit box, the vega look is recognisable.

## Discovered Requirements

- **Strict-engine pass-through classes.** **Description:** preserve host extension classes and render when the host
  omits `class` under strict mode. **Rationale:** S01 review reproduced `Undefined member: "class"` from reading
  `attrs.class`; ordinary rendering hid the problem. **Interpretation:** keep base/marker classes literal, let
  `tl:attrs` append caller classes, and use `tl:classappend` for computed modifiers. Verify both an omitted class
  and an extension class with a strict engine. This refines fragment authoring without changing the scenarios.
  **Traced from:** S01/TI08. **Date:** 2026-11-17.

- **Measured contrast evidence.** **Description:** S01's independent visual review measured the light destructive
  button at 4.0:1 (`#e7000b` on `#fde6e7`); dark axe had zero violations. **Rationale:** S01 measured the pinned
  upstream button before this story's override. **Interpretation:** this confirms existing TI09, whose mutation
  check must still fail when the override is removed. Evidence: public `.agent_temp/s01/visual-review/report.md`.
  **Traced from:** S01/TI11. **Date:** 2026-11-17.

- **Landed qualification contract.** **Description:** manifests, records and baselines default to
  `dev/ui-gate/{manifests,records,baselines}/`; each `<component>.<os>.json` baseline contains both browser
  captures. **Rationale:** S02 selected and proved this concrete schema. **Interpretation:** follow the UI gate
  section in `dev/guidelines/TESTING-STRATEGY.md`; missing semantics, keyboard or HTMX recipes yield `not-run`,
  so provide meaningful recipes and actual declared-region swaps. Use local `ui-gate` tags for real-page gates;
  fixture tests stay in fast/full. Pass documented `GECKODRIVER` locally so both browser results execute.
  **Traced from:** S02/TI04, TI07, TI11, TI12. **Date:** 2026-11-17.

- **Natural table caller slots.** **Description:** HTML parsing discards `td` inside a generic host before Trellis can collect its marker. **Rationale:** TI06's first render test reproduced map fallback values rather than caller cells. **Interpretation:** invoke the whole table on a natural `table` host with one direct `tbody tl:slot="row"` marker containing a `tr`; the fragment iterates a tbody per row so the marker's contents remain valid HTML and read `row`. Multiple tbody elements are valid row groups and preserve exactly one body row per data item. The README supplies this recipe. **Traced from:** TI06. **Date:** 2026-11-17.

- **Single full-component qualification wrapper.** **Description:** the landed package wrapper is `test/qualification_gate_test.dart`, discovers every canonical component manifest, validates unique logical names and exact partition coverage, and runs three bounded disjoint existing-CLI chunks with both browsers. **Rationale:** S04 TI08 was authored against the placeholder `gate_run_test.dart#records regenerate byte for byte` before the wrapper existed; a second wrapper would duplicate the whole component sweep in the release gate. **Interpretation:** S04 extends the landed wrapper with per-manifest before/after record bytes around the SAME full sweep, retaining manual items; it reuses the current test name and per-component stdout mapping as equivalent proof. S05 retains its separate whole19 exact-byte proof. S08 reuses this wrapper without another full25-component invocation. This preserves coverage while removing duplicate gate work. **Traced from:** parent handover for S04/TI08 and S08. **Date:** 2026-11-17.


- **Archived execution evidence.** **Description:** the completed story worktree is temporary.
  **Rationale:** cleanup removes its historical absolute proof paths. **Interpretation:** resolve public
  `.agent_temp/` evidence under main public
  `.agent_temp/0.14-plan-run/evidence/S05/public-agent-temp/`; the exact returning private plan/FIS are retained in
  `evidence/S05/private-receipt/`, with private scratch in `private-agent-temp/` when present. Preserve original
  proof text as historical, and use this mapping rather than claiming the old worktree still exists.
  **Traced from:** parent integration of commit4cf9e407. **Date:** 2026-11-17.

## Implementation Observations

- Text entry shares its max-width rule in `assets/css/hand/input.css`; no empty `textarea.css` or `alert.css` is added when generated CSS already supplies the component rules. The field exports label/fieldset parts in its one template. Native select owns its inner select slot, and textarea uses a non-rendering fragment wrapper because text-only textarea content cannot contain an inner slot element and fragment roots cannot themselves be slot regions.
- TI01 retains shadcn@4.21.1 and the existing compiler pin. Sixteen upstream inputs cover the button, fifteen selected additions (including field/label and radio-group source names); 19 gallery subjects follow the FIS names. Every reported orphan is styled (native option/optgroup and separator) or explained by the omitted-part parity reasons, including redundant sr-only ellipsis text. Generated output is never hand-edited.
- Required check-blocking harness repairs: reflow previously rejected a table's descendants despite a named, keyboard-focusable scroll wrapper. A new Chrome/Firefox regression failed first with `390/default: table outside horizontal viewport`; clipping now respects reachable auto/scroll ancestors while inaccessible regions, document escape and popup escape fail. Firefox forced-active cleanup previously released a held pointer as a real link activation; a new regression failed with `type 'Null' is not a subtype of type 'Map<dynamic, dynamic>' in type cast`. Cleanup suppresses that synthetic click's default action and handlers, removes suppression when no click emits, and retains subsequent real clicks. No second launcher, emulation workaround or browser-wide termination was added.
- Independent visual review found and recaptured four repairs: suite anchors inherited UA blue in dark mode; text-only pagination Next disappeared under the upstream mobile text rule; an empty card action still triggered the upstream two-column header; native pseudo-elements needed border-box sizing to retain the pinned painted dimensions. Each repair has a failing-first browser regression. Final visual verdict PASS; original findings and fresh evidence remain in public `.agent_temp/s05/visual-review/report.md`.
- Mutation checks reject missing attribute pass-through, field invalid wiring, native checkbox type, badge fallback, table row slot, invalid layout scale, textarea/select slots, stack column layout, cluster wrap, grid column growth, container cap, sidebar wrap, button coarse targets, forced-colour checked paint and global CSS leakage. The isolation fixture now supplies a layered 3px host input margin: a global `input { margin: 0 }` previously matched the UA default and produced no defect; the strengthened fixture observes and names the leaked property. Removing the contrast override fails axe with `color-contrast: .trellis-button-variant-destructive`; the restored override passes.
- No Learnings entry is admitted: the mechanisms above are carried by the changed code, regression tests and catalogue, and do not clear the document's durable-trap bar. No manual screen-reader or Safari qualification is claimed.


- Shared native Enter repair from the parallel scaffold run: Chrome's protocol keyCode/key fields alone did not activate a native button. A new native-key regression observed 0 clicks after two Enter presses before `ChromeDriver.press` supplied carriage-return text on Enter keyDown, then passed in Chrome and Firefox with printable-key behaviour preserved. The story owns the two handed-back paths `tool/ui_gate/driver.dart` and `test/ui_gate_native_key_test.dart`; final fast verification includes the untagged regression.
- ASSUMPTION: the two final complete comparisons run concurrently over immutable sources/baselines, one rewriting canonical records and one rewriting a copied canonical record directory under `.agent_temp/s05/`, preserving manual entries. Compare all 19 record bytes, baseline hashes, and the required canonical `git diff --quiet` after both finish. This avoids shared writes and preserves every item in both browsers; an explicit requirement for sequential canonical rewrites would change the execution order. The plan orchestrator approved this outcome-neutral execution choice on 2026-11-17.

#### DRIFT
- spec-stale: TI05's unqualified upstream-variant wording follows the Scope exclusion of card sm/image variants; card exposes default size only. No scenario assertion changes. | Stale targets: TI05 wording | –

### Verification evidence

- TI01: `cd packages/trellis_ui && dart run tool/port.dart check && dart run tool/port.dart parity && dart run tool/embed.dart --check && dart test test/pipeline_generate_test.dart test/parity_test.dart` -> exit=0; `Regeneration check: 4 files byte-identical`, `Parity vs shadcn@4.21.1: 0 unignored drift, 38 used ignores`, `Embedded check: assets and fragments byte-identical`, `+5: All tests passed!`.
- TI02–TI07: component/scale suites execute the bound selector names from their package directory, following Key Development Commands' package-specific single-test paragraph. Final `css_only_components_test.dart`: 7 passed, `layout_primitives_test.dart`: 1 passed. Strict engines cover omitted/extension classes and native caller attrs; natural textarea/select slot assertions pass.
- TI07/TI08/TI10: `css_only_browser_test.dart` -> exit=0, 7 passed, 0 skipped; layout at 390/768/1440, fine/coarse read-back and targets/text, forced-colour focus/checked paint, link inheritance, mobile pagination text, card header geometry and native painted dimensions.
- TI09: `GECKODRIVER=/Users/tobias/Repos/Libs/trellis/trellis-private/.agent_temp/tools/geckodriver dart run tool/ui_gate.dart --serve 'dart run packages/trellis_ui/tool/gallery.dart --port 0' button badge alert field` -> exit=0; `alert: pass`, `badge: pass`, `button: pass`, `field: pass`. Empty override mutation -> exit=1, `color-contrast: .trellis-button-variant-destructive`; restored override -> exit=0, `pass: [checks completed]`.
- TI11: `dart test test/gate_records_test.dart` from the package -> exit=0, 3 passed; all 19 loadable recipes, both-browser automated records/manual release-prep markers, missing-manifest/missing-record/failing-item negative fixtures.
- TI12 initial recording: the first full run returned exit=1 on the original breadcrumb/pagination defects. Fresh targeted recordings after repairs returned exit=0 for breadcrumb/card/pagination. Current canonical evidence has 19 automated passes, 247 passes per browser, 57 manual release-prep markers and 984 appearance state captures; both final immutable comparisons passed, as recorded below.
- TI13: source/isolation/gallery suites passed with aggregate 19-component CSS. The unscoped input-margin mutant returns exit=1 naming a changed standard property; restored isolation/theme tests return `+2: All tests passed!`.
- TI14: package format check -> exit=0, no changes; all 13 workspace analyses -> `No issues found!`. README catalogue inspected for all 19 subjects plus container/sidebar and field/label aliases, closed scales and caller-data recipes.
- Final checklist fast tier -> exit=0. Packages: 3,428 passed, 1 existing Linux-only watch skip; root: 247 passed, 2 existing no-control skips. `trellis_ui`: 45 passed, 0 failed/skipped. Root driver/native-key/scroll replay: 9 passed, 0 skipped, both engines executed. Browser versions: Chrome 157.0.8103.79, Firefox 157.0, geckodriver 0.37.1.
- Final checklist visual: independent reviewer captured/read every subject at 390/1440 in light/dark plus below-fold, focus, invalid, disabled, checked and forced-colour states. Four findings were repaired under failing-first browser regressions and recaptured to PASS. The story owner also read final dark card/pagination and forced-colour switch images. Evidence: public `.agent_temp/s05/visual-review/report.md`. Existing `test/visual_baselines` diff check -> exit=0.

Reviewed: independent quick code+gap reviewer validated one MEDIUM regex-escaping defect, repaired it under a two-ID aria-labelledby Chrome/Firefox regression, and left no open finding. Independent visual reviewer closed four findings after fresh captures; final verdict PASS. Shared native Enter repair is a bounded failing-first native-button regression handed back by the parallel run and re-executed here.

- Package-local test configuration declares `ui-gate` and `visual`: the first wrapper run proved the root dart_test.yaml is not inherited by a package, producing undeclared-tag warnings. This changes tag metadata only; fast tiers still exclude the local full gate.
- The first two comparison attempts correctly rejected obsolete native-control references left over from before the visual border-box repair (`::before` transform `-9,-9` versus corrected `-8,-8`). Those attempts are retained as failed evidence; only their two owned gallery servers were stopped, allowing drivers to unwind. Checkbox/radio/switch references are refreshed to the independently reviewed16px/32px paint before restarting the full comparisons. No component assertion or tolerance changes.
- TI10 isolated focus mutation: original served aggregate gives focused button `outline: solid, width: 2px`; the same aggregate with only zz-forced-colors bytes removed gives `outline: none, width: 1px` and fails the focus clause. This complements the checked-paint mutation without touching immutable runtime files.

- ASSUMPTION: each complete qualification run schedules three bounded disjoint chunks of sorted manifests through the existing positional CLI arguments, with one owned server per chunk and no product pool/API change. The wrapper validates global logical-name uniqueness and exact partition coverage, awaits every CLI's cleanup, and prints labelled stdout/stderr before exit assertions. The isolated repeat uses the same chunks and separate per-chunk copied record directories. Parent approval on 2026-11-17 replaces only test scheduling; all19 subjects, all13 items, both browsers and two full runs remain required. A requirement for serial scheduling would change this test-only orchestration.
- The previous serial-scheduling pair is retained as superseded interrupted evidence (never counted as pass), per the parent's explicit instruction. No runtime/reference defect prompted that interruption. A partition-omission mutation fails the wrapper's preflight coverage assertion before any browser starts; restored scheduling is exercised by the new complete pair.

- Active-state triage: the bounded pair finished in13.79minutes. All isolated19 components passed; canonical field alone failed Firefox `default/active:primary` with missing native focus paint. A deterministic backgrounding regression showed that :active/activeElement survive while native :focus/:focus-visible paint disappears. The first narrow document-refocus guard passed21 targeted tests but the owner's broader28-test replay exposed an execute/async30000ms timeout in that new regression (27passed/1failed, all7theme baselines passed). The first failed repair was escalated to the parent session/oracle rather than retrying unchanged; logs are preserved under public `.agent_temp/s05/active-triage/` and `active-fix-proof.log`. No baseline/tolerance change is used to absorb this discrepancy.

- Oracle/parent triage separated the regression-fixture timeout from the observed field discrepancy: default window.open could hide the source tab and stop its second animation frame; explicit popup features keep a source window visible but unfocused. Original full-run visibility was not recorded, so no exact original window-state claim is made. Parent strengthened three fresh-profile cases (field/button/anchor), requiring actual blur, no hidden transition, native focus paint and held :active for every target, with a :focus-visible ring only on the text field. The first production document-only guard remained unchanged except a removal-condition comment. Parent's exact broader batch passed30 cases/0skips in1m35, including7 unchanged theme baselines; removing only the active guard failedall3 cases, then source restored byte-for-byte. Evidence: public `.agent_temp/s05-active-timeout/parent-broader-proof.log`, `parent-guard-removal.log`, `parent-static.log` and oracle controlled-tab/popup logs. Complete qualification is replayed against this restored, frozen version.

- TI12 final canonical sweep: `cd packages/trellis_ui && GECKODRIVER=/Users/tobias/Repos/Libs/trellis/trellis-private/.agent_temp/tools/geckodriver dart test test/qualification_gate_test.dart` -> exit=0, `11:46 +1: All tests passed!`; the three labelled CLI chunks name every one of the19 components as `pass`. The concurrent isolated repeat used the same three exact partitions with distinct copied record directories; all three exits were0 and all19 subjects passed. Evidence: public `.agent_temp/s05/final-canonical-verified.log`, `final-repeat-verified-{1,2,3}.log`. The bounded pair completed within the canonical11m46 sweep, versus the prior bounded attempt's13.79min; the earlier sequential attempt was interrupted by authorization before completion, so no completed serial timing comparison is claimed.
- TI12 integrity after both sweeps and again after final fast: `python3 .agent_temp/s05/verify_final_records.py` -> exit=0, `19 records byte-identical; 247 Chrome passes, 247 Firefox passes; 57 manual entries preserved.` and `210 source/test/reference hashes unchanged; git diff --quiet dev/ui-gate/test-visual-baselines/dependencies exit=0.` All six fresh gallery processes were bound to current CSS/JS/indicator bytes and strong ETags before their gate reads, including CSS SHA256 `7b2d197bb5ff3d5161724d076791d147668a9e6c399d74a27cbc8a52e64dbe22`; `verified-asset-identity.log` and `immutable-snapshot-verified.json` retain identity. Only the three native-control references were refreshed after the independently reviewed paint repair; all other repair-target references were audited fresh. No assertion, browser requirement or tolerance was reduced.
- Final exact fast tier from Key Development Commands completed after the latest pair. Package runner totals:3428 passed/1 pre-existing Linux-only file-watcher skip; root `02:43 +247 ~2: All tests passed!` with pre-existing bloom/verdant no-progressive-control skips. `trellis_ui` is `+45: All tests passed!`,0skip. All13 workspace analyzers report `No issues found!`, all format checks report0changes, theme-gallery check reports current, final `Formatted 44 files (0 changed)`. Log: public `.agent_temp/s05/fast-final.log`. The fixture/native tests execute in this tier; the undeclared-tag exit79 smoke was configuration evidence only and is not counted as a passing test. Full tier remains parent-owned under the dispatched `--no-full-tier` contract.
- Shared active-capture proof: `tool/ui_gate/appearance.dart` enables the optional document-focus guard only for Firefox's held-pointer active capture; `tool/visual_baseline.dart` otherwise retains normal/theme digest behavior. It reasserts document focus and restarts a sample after blur without focusing the target or changing keyboard modality. New `test/ui_gate_active_state_test.dart` proves field/button/anchor actual background contention, native focus paint and held-pointer :active, field-only focus-visible ring, and cleanup without a synthetic click. Parent's30-test replay includes all7 unchanged theme baselines; the complete latest six-runner pair independently passed the original field capture. The original full-run visibility was not recorded, and the separate hidden-tab regression-fixture failure is retained rather than misreported as the original cause.

### Chain Attestation

- OC01: S01–S06 are linked through TI02–TI07 to native/default/strict-attribute/field-ID/data-view/closed-scale tests and live390/768/1440 geometry; every advertised fragment and its caller-data recipe ships in the catalogue.
- OC02: S07–S09 are linked through TI08–TI10 to fine24px/coarse44px/16px text, destructive override removal yielding a contrast failure, restored both-browser WCAG passes, and forced-colour focus/checked read-back plus negative mutations.
- OC03: S10 is linked through TI13 to unchanged non-suite standard properties and pasted-theme precedence in both link orders/modes; the global input-margin mutant fails the strengthened host fixture.
- OC04: S11–S12 are linked through TI11–TI12 to19 meaningful manifests, every13 automated item passing in both browsers, a second full sweep yielding exact record bytes,57 retained release-prep manual items, immutable reference/source hashes and missing/failing-record negative fixtures.
- Pre-existing DR strict-engine pass-through classes: native fragments use literal base classes with `tl:attrs` and `tl:classappend`, never missing `attrs.class`; strict omitted-class and extension-class tests execute.
- Pre-existing DR measured destructive contrast: the class-only override preserves tokens, its removal produces the destructive-button color-contrast failure, and both-browser full light/dark qualification passes after restoration.
- Pre-existing DR landed harness schema: canonical manifests/records/baselines ship with one OS baseline containing both browsers, all required semantic/keyboard/real-region HTMX recipes execute, and the package-local ui-gate tag isolates only the full real-component wrapper from fast.

#### DRIFT (completion)
- spec-stale: S04 TI08's placeholder `gate_run_test.dart#records regenerate byte for byte` maps to landed `test/qualification_gate_test.dart#automated qualification remains green in Chrome and Firefox`, whose labelled per-component stdout covers every canonical manifest in both browsers. S05 executed a separate complete exact-byte repeat; S04 extends before/after per-manifest bytes around the SAME wrapper sweep, preserving manual entries; S08 reuses it rather than adding another full25-component invocation. No coverage reduction. | Stale targets: downstream test path/name | –

Reviewed: fresh independent code/gap review fixed one MEDIUM two-ID aria-labelledby regex-escaping finding under a failing-first Chrome/Firefox regression; fresh independent visual review closed four findings with new captures and final PASS. No finding remains open. Parent-authorized native Enter and active-capture repairs carry failing-first native/browser regressions, the latter escalated after its first broader replay failed, and are included in final fast and the latest complete pair.

- Completion receipt: public commit `4cf9e407b644ae1043757239884c644b4de2dc08` on `feat/0.14-s05`,161 own paths recorded in public `.agent_temp/s05/changed-paths.txt`; verified actual root `/Users/tobias/Repos/Libs/trellis/trellis-public/.agent_temp/parallel-0.14/s05/trellis-public`, clean public status. The paired private plan changes only S05 (outside-row bytes match the admission hash), all14 tasks and UTC-minute verification are complete; private metadata remains uncommitted for canonical import.


### Post-integration simplification

S05 merged as e528b3a, then parent exact integrated fast exited0:3450 package passes plus1 known Linux-only skip,248 root passes plus2 known no-control skips,13 clean analyses,45 formatted files unchanged. A fresh simplify-code implementer changed only css_only_components_test.dart and gate_records_test.dart: reuse DOM selections/decoded items and a raw table fixture, plus a failing-first edited-helper tidy accepting S02's four valid manual statuses with string-list evidence. The copied human pass/fail/not-run fixture failed first on three release-prep errors; missing/malformed manual and automated failure cases still fail. All57 canonical manual entries remain release-prep. Final exact fast repeats the same3450/248 counts andknownskips; parent independently reran10 focused cases/0skip and analyzed both files with0issues. Commit afe91c39ebdf653ee1a40325aa6ff88026ad184f (Plan trailer only) carries the two test-file changes. Runtime assets/manifests/references and the complete component qualification inputs are unchanged; the full UI sweep was not redundantly repeated for test-only edits. Reports: public .agent_temp/s05-simplify/report.md, fast-verified.log; parent integration log .agent_temp/0.14-plan-run/fast-after-s05-merge.log.
