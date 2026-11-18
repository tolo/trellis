# S02 – Headless Qualification Harness

**Plan**: dev/spec/0.14/plan.json
**Story-ID**: S02

## Feature Overview and Goal

**Intent**: ADR-012 allows no Tier 1 component to be called supported until it passes a bounded gate, and the 0.14 plan runs unattended, so the automated half of that gate must be one committed, Node-free command that any component page can be pointed at.

**Expected Outcomes**:

- [OC01] One command drives a served component page through every automated FR5 item in headless Chrome and headless Firefox, and a page that breaks an item fails that item by name with the evidence.
- [OC02] Each component gets a deterministic gate record listing every FR5 item with its result and evidence, with the screen-reader and Safari items marked for release prep and never set by the tool, so later stories can write, read and complete records without parsing anything else.
- [OC03] Appearance regressions that behaviour checks cannot see (the three the O6 spike found only by screenshot) are caught by a per-state computed-style capture, which a sync can also run before and after a change.

## Required Context

- `dev/spec/0.14/prd.md#fr5-qualification-gate` – the item list, headless/manual split, per-component record, failure rules; binding.
- `dev/spec/0.14/prd.md#non-functional-requirements` and `#constraints` – strict policy `script-src 'self'; style-src 'self'`, WCAG 2.2 AA, 390/768/1440, unattended plan, committed gate code without Node.
- `dev/spec/0.14/plan.json#sharedDecisions` – "Harness input and gate record": the harness takes a base URL, page paths and per-component interaction scripts, never package internals; stories S04, S05, S07 and S08 consume the record.
- `dev/adrs/ADR-012-trellis-ui-contract.md#decision` (qualification gate and sync paragraphs) and `#htmx-lifecycle` – gate items; the appearance check exists because behaviour gates "do not see" skipped-hook breakage.
- `../trellis-private/docs/research/14-trellis-ui-seed-reevaluation/o6-spike.md` – "Chrome gates" table and "Mechanisms found while running the gates" (htmx settle versus `style-src-attr`, the two-toast overlap); the checks to generalise.
- `../trellis-private/docs/research/14-trellis-ui-seed-reevaluation/o6-stress-sync.md#gates-and-screenshots-across-the-window` – the screenshot-only findings scenario S14 replays.
- `../trellis-private/docs/research/12-trellis-ui-csp-spike.md#mechanism--what-strict-csp-actually-governs` – CSSOM writes and constructed stylesheets pass the policy; `<style>` elements and style attributes do not.
- `test/browser_reflow_probe.dart#BrowserProbe` – the repo's only CDP client; `StaticSiteServer` and `requireChromeInCi` live beside it.
- `tool/visual_baseline.dart` – `digestScript`, `Capture`, `compareCaptures`, `scanClipping`: the digest this story extends.
- `dev/guidelines/TESTING-STRATEGY.md#conventions-and-fixtures` and `KEY_DEVELOPMENT_COMMANDS.md` – CI guard convention, loopback port 0, run-one-test row.
- `dev/state/LEARNINGS.md` – "A screenshot diff needs an A/B control"; "Rebuilding onto the same origin/port serves you the cached script".
- Spike starting code, read-only through `git show spike/trellis-ui-o6-shadcn-port:docs/temp/trellis-ui-o6-shadcn-spike/<path>` in the planning repo (never check it out): `tool/check.dart` (Chrome checks, APG walks), `tool/webdriver.dart` (raw W3C WebDriver and BiDi for Firefox), `tool/pixdiff.dart` (PNG decoder), `static/instrument.js` (instance counting), `static/vendor/axe.min.js`, `static/vendor/htmx.min.js` with licences. Its component-specific walks are examples of the scripts S04 and S05 will write, not code to copy.

## Acceptance Scenarios

- **S01 [OC01] [runtime] A conforming page passes every automated item in both browsers**
  - **Given** the passing fixture page and manifest, served with the strict policy
  - **When** the gate runs against it in Chrome and in Firefox
  - **Then** every automated item reports `pass` per browser with evidence, the strict-policy control confirms the policy was enforced, and the process exits 0

- **S02 [OC01] [runtime] Policy violations are caught at load and at interaction, in both browsers**
  - **Given** fixtures that (a) ship an inline script, (b) ship a `style` attribute in markup, (c) call `setAttribute('style', …)` after a scripted interaction
  - **When** the gate runs each
  - **Then** `strict-csp` fails, naming the directive and the source for each, including the load-time ones (a listener installed after load would miss (a) and (b))

- **S03 [OC01] [runtime] A page without the strict policy cannot pass `strict-csp`**
  - **Given** the passing fixture served with no `Content-Security-Policy`, and again with `'unsafe-inline'` in `script-src`
  - **When** the gate runs
  - **Then** `strict-csp` fails because the policy under test is not the strict one, instead of reporting 0 violations

- **S04 [OC01] [runtime] A third-party request fails `self-hosting`**
  - **Given** a fixture that requests an asset from another origin (blocked or not)
  - **When** the gate runs
  - **Then** `self-hosting` fails naming the URL; the passing fixture's requests are all same-origin

- **S05 [OC01] [runtime] Accessibility and semantic failures are found in the state where they occur**
  - **Given** a fixture whose control is unlabelled only after a scripted interaction, and a manifest `semantics` assertion on a role/attribute the markup lacks
  - **When** the gate runs
  - **Then** `wcag-axe` fails naming the axe rule id and the state, and `semantic-markup` fails naming the assertion; the passing fixture has 0 violations at WCAG 2.0/2.1/2.2 A and AA tags in every declared state

- **S06 [OC01] [runtime] Keyboard scripts run identically in both browsers and fail precisely**
  - **Given** a passing walk (arrows, Home/End, Escape returning focus, Tab leaving) and a fixture that breaks one step
  - **When** the gate runs
  - **Then** the broken fixture fails `keyboard` naming the step, the expected and the actual value; a script step whose element does not exist fails instead of being skipped

- **S07 [OC01] [runtime] HTMX swap and history lifecycle defects are found**
  - **Given** a passing fixture and failing twins that (a) re-initialise on swap so a document listener count grows, (b) double-fire a handler after a swap, (c) leave a transient popup or toast in the history snapshot
  - **When** the gate performs 20 swaps of the manifest's region, then a boosted navigation with back, forward and back
  - **Then** each twin fails `htmx-lifecycle` naming the measurement (listener counts, instance counts, single-fire probe, stale transient UI); the passing fixture's instance counts and listener counts are unchanged and its keyboard script still passes afterwards

- **S08 [OC01] [runtime] Forced colours, reduced motion, responsive widths and zoom each fail on their own defect**
  - **Given** twins that (a) draw the focus ring with `box-shadow` only, (b) keep a transform animation under `prefers-reduced-motion: reduce`, (c) overflow the document at 390 px, (d) overflow only at 320 px, (e) open a popup partly outside the viewport
  - **When** the gate runs with the condition emulated and read back as active
  - **Then** (a) fails `forced-colors`, (b) `reduced-motion`, (c) `responsive` naming the width, (d) `zoom`, (e) `responsive`; the passing fixture passes all four, with its keyboard script re-run at each width

- **S09 [OC01] [runtime] Touch targets are measured under a coarse pointer**
  - **Given** a control 30 px tall, a control 20 px tall, and a passing page with 44 px controls
  - **When** the gate measures interactive elements, including those in popups opened by the manifest's states
  - **Then** the 20 px control fails the fine-pointer minimum (24 px), the 30 px control fails the coarse-pointer minimum (44 px), the passing page passes both, and `(pointer: coarse)` is confirmed true before measuring

- **S10 [OC01] [runtime] A condition that did not take effect never produces a pass**
  - **Given** Firefox or geckodriver missing, or a browser that does not report an emulated condition back through `matchMedia`
  - **When** the gate is asked to run it
  - **Then** the affected item is `not-run` with the reason (never `pass`), and the command exits non-zero

- **S11 [OC02] Record shape, manual items and determinism**
  - **Given** a component run, with and without an existing record that holds human-entered results
  - **When** the gate writes the record twice
  - **Then** the record lists every FR5 item (provenance, self-hosting, strict CSP, semantic markup, HTMX lifecycle, keyboard, WCAG axe, both screen-reader pairs, Safari, forced colours, responsive, zoom, reduced motion, touch target, visual) with `status` (`pass`, `fail`, `not-run`, `release-prep`), per-browser results and evidence, and a record-level automated verdict; the two screen-reader pairs and Safari are `release-prep` when absent and an existing value is kept as is; the two writes are byte-identical

- **S12 [OC02] A failing item is recorded, not hidden**
  - **Given** a fixture that fails `touch-target`
  - **When** the record is written
  - **Then** that item is `fail` with its evidence, the automated verdict is `fail`, and the exit code is non-zero

- **S13 [OC01] A new component is gated by data alone**
  - **Given** a second fixture component whose manifest names a base URL path, states, selectors and scripts
  - **When** the gate runs against it
  - **Then** it is gated with no change to harness code, and a manifest with an unknown key, missing page or bad selector fails with the field named before any browser starts

- **S14 [OC03] [runtime] The three screenshot-only regressions are caught by name**
  - **Given** the spike's regressions replayed from its generated CSS (reduced to the rules the fixture page uses): the secondary button's hover colour change, the destructive and dark token values changing at one shadcn tag, and two toasts landing on each other (the unsynced stacking CSS)
  - **When** the before and after captures are compared, and the unchanged control pair is compared
  - **Then** each regression is reported with its state, element and property (hover background; the token or its rendered use; overlapping boxes), the control pair reports nothing, and any regression the computed-style digest cannot see is caught by a pixel diff on that state

- **S15 [OC03] [runtime] Forced states and tokens are part of the capture, under the strict policy**
  - **Given** the passing fixture served with the strict policy
  - **When** its appearance is captured
  - **Then** the capture holds the default, hover, focus-visible, active, disabled and dark states of each manifest-listed element plus the resolved token table (custom properties declared on `:root` and `.dark`), a token change is reported as a token diff, and the capture produced 0 policy violations

## Structural Criteria

- **SC01** No Node and no new dependency: no `node`/`npm`/`npx` invocation in the new code, and no pubspec in the workspace changes.
- **SC02** Vendored inputs (axe-core 4.10.2, the fixture htmx 2.0.10) are checksummed in one file beside them with their licence notices, and a test recomputes the digests.
- **SC03** One CDP client: `BrowserProbe` is extended additively and no second DevTools launcher exists; the theme baselines, reflow and contract suites still pass and `test/visual_baselines/` is unchanged.
- **SC04** Measurement never causes the violations it counts: nothing the harness adds to a page is a `<style>` element, a `style` attribute, an inline handler or a `setAttribute('style', …)` call.
- **SC05** The harness knows no component package: no reference to `trellis_ui` in `tool/ui_gate*` or `test/ui_gate*`; its inputs are a base URL (given, or printed by a `--serve` command) and manifest/record/baseline paths.
- **SC06** Records, captures and baselines are deterministic: no timestamps, host paths or ports, so a rerun is byte-identical and a commit shows only real change.

## Scope & Boundaries

### Work Areas

Paths in Work Areas, Verify lines and Constraints are relative to the trellis-public root, where the story executes.

- `tool/ui_gate.dart` and `tool/ui_gate/` – CLI, `GateDriver` interface, Chrome and Firefox drivers, manifest loader, the checks, appearance capture and compare, record writer; `tool/ui_gate/vendor/` – axe-core, checksums and notices.
- `test/browser_reflow_probe.dart` – additive: input, listeners, console/request/violation capture, emulation, response headers on `StaticSiteServer`.
- `tool/visual_baseline.dart` – only if the digest's animation freeze must change to run under the strict policy (see Constraints).
- `test/ui_gate_*_test.dart` and `test/ui_gate_fixtures/` – passing and failing fixture pages, manifests, the regression pairs, the vendored fixture htmx.
- `dev/guidelines/TESTING-STRATEGY.md`, `KEY_DEVELOPMENT_COMMANDS.md`, `dev/state/LEARNINGS.md` – the gate's place in the levels table, its command, the traps found.

### What We're NOT Doing

- Real component manifests, records and baselines – stories S04 and S05 write them against story S01's gallery; the button's belongs to story S05. This story ships fixtures only.
- Screen-reader and Safari checks – manual at release prep (FR5); the tool only emits `release-prep` markers. No Safari/WebKit driver.
- The sync skill, sync report and the full gate run – story S08; this story supplies the capture/compare it calls.
- A CI job – ADR-012 keeps gates local. The new root tests join the existing tiers like the other rendered contract tests, except that a test comparing a per-OS baseline carries the `visual` tag; this story registers the `ui-gate` tag (for full-gate runs over real pages, stories S04, S05, S08) beside `visual` in the test configuration and `KEY_DEVELOPMENT_COMMANDS.md`'s release-gate tier.
- Downloading browsers or geckodriver – located through environment or `PATH`, pinned version recorded in the docs.
- A general screenshot-diff facility – pixel diff exists only for a state the digest provably misses (scenario S14).
- Axe rule exceptions beyond a manifest `axe` override that requires a written reason; upstream's 4.02:1 destructive contrast is a failure for the component to fix (story S05), not an informational note.

## Architecture Decision

**Approach**: A root `tool/ui_gate/` Dart library. Checks are written once against a `GateDriver` interface with two drivers: Chrome through the extended `BrowserProbe` (raw DevTools protocol), Firefox through raw W3C WebDriver plus BiDi over `dart:io` (as the spike's `tool/webdriver.dart`). Per-component data is a YAML manifest (page path, named states reached by declarative steps, selectors, keyboard scripts with expectations, HTMX region/swap/navigation, provenance notices). Output is one JSON record per component, plus appearance captures. Record items, in this order: `provenance`, `self-hosting`, `strict-csp`, `semantic-markup`, `htmx-lifecycle`, `keyboard`, `wcag-axe`, `forced-colors`, `responsive`, `zoom`, `reduced-motion`, `touch-target`, `visual`, and the manual `screen-reader-voiceover-safari`, `screen-reader-nvda-firefox`, `safari`.
**Why this over the floor**: the floor is the repo's probe and digest as they are. They have no keyboard or pointer input, listener counts, console/violation/request capture, forced states, or Firefox, all of which FR5 requires. `package:puppeteer` (the spike) is rejected: it adds a dependency and a second Chrome lifecycle where `BrowserProbe` already carries the profile, shutdown and CI-guard lessons.
**Flow**: manifest → driver opens base URL + page with the strict-policy control and request/violation capture armed before page scripts → per-item checks reach declared states by replaying their steps from a fresh load → results fold into the record; appearance capture and compare run separately and feed the `visual` item.

## Constraints & Gotchas

- **Constraint**: `digestScript` freezes animation by appending a `<style>` element. Under `style-src 'self'` that is blocked and reported, so the capture would both fail to freeze and add a violation – Workaround: freeze through a constructed stylesheet in `adoptedStyleSheets` (outside the policy per research/12), keeping the theme baselines byte-identical, or give the capture its own freeze.
- **Constraint**: violation, request and instance-count capture must be armed before page scripts run: Chrome `Page.addScriptToEvaluateOnNewDocument`, Firefox a BiDi preload script. Instance counting follows the spike's `instrument.js` (wrap `customElements.define`), injected by the harness so components carry no counting code. Axe and all measurement go through DevTools/WebDriver script execution, which the policy does not govern.
- **Constraint (shared with story S03)**: story S03 runs in parallel and also adds `securitypolicyviolation` capture and response headers on `StaticSiteServer` to `test/browser_reflow_probe.dart` (plan.json sharedDecisions "CSP violation capture in the browser probe"). If story S03's capture is already on the branch, extend it instead of adding a second; otherwise keep TI02's additions in self-contained, additive blocks so the later merge keeps one capture.
- **Constraint**: an emulated condition (coarse pointer, forced colours, reduced motion, viewport) is trusted only after `matchMedia`/the viewport reads it back; otherwise the item is `not-run`. Firefox's desktop window will not go below about 500 CSS px, so its narrow viewports use BiDi `browsingContext.setViewport`; its coarse pointer and forced colours need preferences in a separate session, as the spike did for the pointer.
- **Constraint**: the zoom item is viewport emulation at 640 and 320 CSS px (200% and 400% of a 1280 px window), plus the reflow and keyboard checks at those widths.
- **Constraint**: axe runs scoped to the manifest's component root, so page-level rules (landmarks, h1) stay the gallery's concern; the rule tags are WCAG 2.0, 2.1 and 2.2 A and AA.
- **Constraint**: forced colours drop `box-shadow`, which is how Tailwind rings are drawn; a focus indicator that is only a shadow disappears, so `forced-colors` requires an outline- or border-based indicator.
- **Constraint**: the `visual` item follows the theme-baseline precedent: baselines are per OS (`<component>.<os>.json`), a missing recording for this OS fails rather than skips, and the first recording is the reference, so on that run the item rests on the invariant sweeps (clipped content via `scanClipping`, overflow, manifest `distinct` selector groups that must not overlap, which catches two toasts on each other). Recording is refused when `CI=true`.
- **Constraint**: the Firefox tests skip locally when geckodriver or Firefox is absent and do not use the fail-in-CI guard, because CI installs Chrome only; the CLI never skips, it reports `not-run` and exits non-zero (scenario S10).
- **Constraint**: never kill browsers by name or `close --all`; other agents run browsers here. Own only the processes the harness started, each with a throwaway profile and an OS-assigned loopback port.
- **Machine-local**: Chrome at `/Applications/Google Chrome.app`, Firefox 157 at `/Applications/Firefox.app`, geckodriver 0.37.1 at `/Users/tobias/Repos/Libs/trellis/trellis-private/.agent_temp/tools/geckodriver` (pass it as `GECKODRIVER`).
- **Decision**: the harness lives in the root `tool/ui_gate/` rather than inside `packages/trellis_ui` – story S01 is authored in parallel and the shared decision keeps the harness independent of package internals.
- **Decision**: default locations are `dev/ui-gate/manifests/`, `dev/ui-gate/records/` and `dev/ui-gate/baselines/`, each overridable by flag, created by the first writer – the package is not published with gate files.
- **Decision**: an item that a browser cannot emulate (checked by read-back) runs in the other browser only, and the record states the browser set and the reason; the item passes when every browser that can run it passes.
- **Decision**: `provenance` is automated as manifest-declared notice files that must exist and name an allowed licence (MIT, ISC, Apache-2.0, BSD-*, 0BSD); it cannot judge licence truth.
- **Decision**: manifests are YAML with a declarative step vocabulary (focus, click, hover, type, press, wait, expect, axe, state) and a JS-expression `eval`/`expect` escape hatch, identical in both browsers.
- **Decision**: the first recorded `visual` baseline is the reference (no external vega screenshot reference).

## Implementation Plan

### Implementation Tasks

- **TI01** Vendored axe-core 4.10.2 and the fixture htmx 2.0.10 sit under `tool/ui_gate/vendor/` and `test/ui_gate_fixtures/` with their notices (MPL-2.0, 0BSD), copied from the spike's `static/vendor/` and checksummed in one file.
  - **Verify**: `test/ui_gate_driver_test.dart#vendored inputs` – recomputed sha256 matches the recorded value, each notice exists, and the axe banner reads 4.10.2.
  - **SATISFIES**: SC02

- **TI02** `BrowserProbe` can drive a gate run: keyboard and pointer input, hover and focus, listener counts (`DOMDebugger`), page-script preloading, console/request/`securitypolicyviolation` capture, forced colours, reduced motion, coarse pointer and viewport emulation, response headers, multiple navigations including back/forward; `StaticSiteServer` accepts response headers. Additive only.
  - Follow `BrowserProbe._send` and `forceFocusVisible` for the call style.
  - **Verify**: `test/ui_gate_driver_test.dart#chrome driver` – each capability observed on a small page (key reaches a focused input, coarse pointer reads back, a blocked inline script is captured with directive and source, listener count changes on `addEventListener`); `cmd: dart test test/theme_contract_test.dart test/site_reflow_test.dart && test "$(git grep --untracked -l -e '--remote-debugging-port' -- tool test packages | wc -l)" -eq 1` – existing users unchanged and one DevTools launcher remains.
  - **SATISFIES**: S02, SC03

- **TI03** A Firefox driver with the same `GateDriver` surface runs headless through geckodriver, using BiDi for viewport and preload scripts, the preference session for coarse pointer and forced colours, and `matchMedia` read-back for each.
  - Pattern: the spike's `tool/webdriver.dart`; locate the binary via `GECKODRIVER`, then `PATH`.
  - **Verify**: `test/ui_gate_driver_test.dart#firefox driver` – the same capability probes as TI02, skipped locally when Firefox or geckodriver is absent.
  - **SATISFIES**: S02, S10

- **TI04** The manifest loader validates a YAML manifest (page path, states, selectors, scripts, htmx region, provenance, `distinct` groups, optional `axe` overrides each with a reason) and rejects unknown keys, a missing page and an invalid selector with the field named, before any browser starts.
  - **Verify**: `test/ui_gate_record_test.dart#manifest` – valid manifest loads; three malformed ones each fail naming the field.
  - **SATISFIES**: S13

- **TI05** `strict-csp` and `self-hosting` run over the whole page session (load, every state, every swap): the policy control confirms the strict policy is the one served and enforced, violations carry directive and source, and any cross-origin request is named.
  - **Verify**: `test/ui_gate_checks_test.dart#csp and self-hosting` – scenarios S01–S04 fixtures in Chrome and Firefox; the passing fixture shows 0 violations.
  - **SATISFIES**: S01, S02, S03, S04, SC04

- **TI06** `semantic-markup`, `wcag-axe` and `keyboard` run per declared state and script: axe scoped to the component root at WCAG A/AA tags, manifest semantics assertions, and the step runner with precise failure messages.
  - **Verify**: `test/ui_gate_checks_test.dart#axe, semantics and keyboard` – scenarios S05 and S06 fixtures, both browsers.
  - **SATISFIES**: S05, S06

- **TI07** `htmx-lifecycle` performs 20 swaps and a boosted navigation with back/forward/back, comparing listener counts, instance counts (preloaded wrapper plus manifest `instances` selectors), a single-fire probe, and stale transient UI in the restored page, then re-runs the keyboard script.
  - **Verify**: `test/ui_gate_checks_test.dart#htmx lifecycle` – S07 passing fixture and three failing twins, both browsers; each twin fails on its own measurement.
  - **SATISFIES**: S07

- **TI08** `forced-colors`, `reduced-motion`, `responsive` (390/768/1440), `zoom` (640/320) and `touch-target` (24 px fine, 44 px coarse, including popups opened by states) run with their conditions read back; an unconfirmed condition yields `not-run`.
  - **Verify**: `test/ui_gate_checks_test.dart#conditions and touch targets` – scenarios S08, S09 and the unconfirmed-condition case of S10, with a failing twin per defect.
  - **SATISFIES**: S08, S09, S10

- **TI09** Appearance capture records, per manifest element and state (default, hover, focus-visible, active, disabled, dark via DevTools forced pseudo-states and emulated scheme), the digest from `digestScript`, the resolved token table and the invariant sweeps; compare reports per state, element and property, with a token diff; the `visual` item is built on it and baselines are recorded per OS.
  - Pattern: `visual_baseline.dart#compareCaptures` and `scanClipping`; the freeze constraint above applies.
  - **Verify**: `test/ui_gate_appearance_test.dart#state capture` – scenario S15 on the passing fixture under the strict policy; `cmd: dart test test/visual_baseline_test.dart` – the digest change left the theme baselines passing (macOS).
  - **SATISFIES**: S15, SC03, SC04

- **TI10** The spike's three screenshot-only regressions are replayed as fixture pairs with an unchanged control pair, each detected by name; any state the digest misses gets a pixel diff (PNG decoding with `dart:io` zlib, after the spike's `tool/pixdiff.dart`; A/B in one browser run per LEARNINGS) wired into compare.
  - **Verify**: `test/ui_gate_appearance_test.dart#spike regressions` – per regression the reported state, element and property (or the pixel-diff region), and an empty report for the control.
  - **SATISFIES**: S14

- **TI11** `dart run tool/ui_gate.dart` takes a base URL, or `--serve '<command>'`, which starts that command, reads the base URL from its first stdout line (`Serving <url>`, story S01's gallery contract) and stops it after the run, plus component names or manifest paths and browser selection; runs every check; writes or updates the record; prints a summary; exits non-zero on any `fail` or `not-run`. Records are deterministic and keep human-entered manual items.
  - **Verify**: `test/ui_gate_record_test.dart#record and cli` – scenarios S11, S12 and S13 through the CLI against fixture servers, one started through `--serve`, including the byte-identical double write and a pre-filled manual item surviving a rerun.
  - **SATISFIES**: S10, S11, S12, S13, SC06

- **TI12** The harness is documented where contributors look: a levels-table row and a short "UI qualification gate" section in `TESTING-STRATEGY.md` (what it covers, manifest and record locations, geckodriver pin and how to obtain it, the local-only gate), the command in `KEY_DEVELOPMENT_COMMANDS.md`, and Learnings entries for the traps this story found.
  - **Verify**: `cmd: ! git grep --untracked -n -E "'(node|npm|npx)'|trellis_ui" -- 'tool/ui_gate*' 'test/ui_gate*.dart' && git diff --quiet -- pubspec.yaml 'packages/*/pubspec.yaml' 'examples/*/pubspec.yaml' && dart format --output=none --set-exit-if-changed tool test && dart analyze --fatal-infos` – no Node call, no package reference, no pubspec change, clean; `inspect: dev/guidelines/TESTING-STRATEGY.md` – the gate section names every command and path the tests use.
  - **SATISFIES**: SC01, SC05

## Final Validation Checklist

- The fast tier from `KEY_DEVELOPMENT_COMMANDS.md` is green with the new root tests included, `git diff --quiet -- test/visual_baselines` exits 0, and the run output shows the Firefox tests executed, not skipped, on this machine.
- Each automated item has a failing fixture twin that differs from its passing twin only in the defect (the mutation check of `TESTING-STRATEGY.md`, item 5).

## Implementation Observations

- S02 execution verified on 2026-11-17. The implementation stays in root `tool/ui_gate/`; Chrome extends the existing `BrowserProbe`, and Firefox uses raw WebDriver/BiDi. No Node invocation, dependency or package reference was added. The first recording is one `<component>.<os>.json` baseline holding both browser captures; optional captures remain per browser. Recipes, records and baselines default to `dev/ui-gate/{manifests,records,baselines}/`.
- Conservative reading: absent semantic, keyboard or HTMX recipes report `not-run` instead of vacuous success. A requested condition must read back; unsupported conditions are recorded per browser, while already observed failures survive an unsupported later condition. Root controls participate in target and forced-colour checks. The declared HTMX region is confirmed from the actual after-settle target across all 20 swaps.
- The three spike regressions are all detected by computed state/style/token/geometry comparison, with the unchanged A/B control empty in both engines. No pixel decoder was warranted. Selected styles participate in the same settle fingerprint as geometry; a 24-frame outline-only mutation proved why a second protocol read was insufficient.
- Firefox can retain `activeElement` while `document.hasFocus()`, `:focus` and `:focus-visible` are false. Standard BiDi activation is required before native input. Explicit forced-focus assertions and measurements share one bounded helper that reasserts the owned document/target and confirms document, target and visible focus in the measurement task. Its three consumers are pseudo readback, appearance settling and AFTER forced-colours paint; declarative keyboard/input and BEFORE paint stay unforced. Deterministic background-before-input, first-RAF readback, mid-settle and mid-paint regressions precede their repairs. The final replay survived concurrent Chrome capture; the bounded control completed 867 captures in 3 minutes.
- Geckodriver HTTP and BiDi ports both use OS-assigned port 0. A concurrent-session regression failed first with the default BiDi port collision. Final proofs explicitly set the documented geckodriver 0.37.1 path and executed Firefox 157 and Chrome 157 without an S02 skip.
- Additive canonical CSP API for S03: `BrowserProbe.captureSecurityPolicyViolations()`, `securityPolicyViolations()` and `cspViolationPreload`, plus `StaticSiteServer.serve(..., headers: ...)`. Controls are separated from page violations. S03 must reuse these rather than introduce a second listener.
- Integration for S04/S05/S08: use the documented manifest schema, canonical baseline containing both browsers and ordered record items. Missing recipes and failed/unavailable checks cannot qualify a component. Real-page gates use the local `ui-gate` tag and release-gate tier; fixture proofs remain untagged in fast/full. S07's user docs destination is now `site/content/docs/` under the owner's committed docs migration.
- Independent code/gap review fixed two MEDIUM defects under failing-first browser regressions: interactive root controls were excluded from scans, and a later unsupported condition erased an earlier failure. Independent visual review read 37 captures and four WCAG 2.2 AA audits (0 violations, 0 incomplete); no visual finding. A later three-line pseudo-readback migration removed the last separate focus assertion under its own deterministic red/green regression.
- Check-blocking tidy: `packages/trellis/test/cache_test.dart` now warms the same source cache synchronously in `close() stops cache invalidation`. An initial-file event delivered between asynchronous warmups reproduced `Expected: <1> / Actual: <0>` before close; a raw page-file event after close retains the original hit/miss/size contract. All post-close assertions remain, and no loader/engine implementation changed.
- Verification: fast tier exits 0 with 3410 package passes plus one existing Linux-only watcher skip, 238 root passes plus two existing no-control skips, 13 clean analyses and all format/gallery checks. TI01–TI12 exact proofs pass. Existing theme visual baselines pass 7/7 and remain unchanged; compatibility passes 60 with its same two skips. Evidence: public `.agent_temp/s02/final-evidence.md`, `final-fast-portable.log`, `final-proofs/summary.log`, `final-portable-cli.log`, `code-review/review.md`, `visual-review/report.md`. No S02 proof was skipped.
- Learnings admission: no new entry added. The traps above are carried by implementation comments and permanent regressions, so duplicating them would fail that document's header bar. No dependency/version or user-facing package behaviour changed, so no package CHANGELOG entry was added.
- Shared tree: verification used public HEAD `1c409b6` after the owner's four committed documentation/governance rounds. Those commits and the parent's uncommitted SVG redraw are preserved and excluded from S02 attribution. Private metadata is intentionally uncommitted.
- NOTICED BUT NOT TOUCHING: the existing probe's SIGKILL shutdown can leave its own macOS crashpad handler holding stderr open in a standalone Dart script. The bounded Chrome controller had no browser/socket remaining, but exited only after its proven-owned handler was terminated (paired-pipe `lsof` evidence). This needs browser child-process lifecycle ownership rather than an S02 check workaround; parent owns between-story triage. No required S02 gate failed on it.

- Final checklist repair: the CLI now has an isolated disallowed-licence twin that requires only `provenance` to fail while every other automated item passes. Red/green real-CLI probes also proved and repaired host-path leakage in invalid notice labels and a non-executable geckodriver `ProcessException`. Failure records retain basename/licence or executable basename/OS message. Permanent no-host-root assertions cover both, and the reviewer independently inspected these deltas with no finding.

Chain Attestation:

- OC01: S01–S10 and S13 are implemented by TI02–TI08/TI11 and verified in real Chrome/Firefox fixture twins, including policy enforcement, requests, state accessibility, keyboard, swap/history lifecycle, conditions, targets, unavailable runs and manifest validation.
- OC02: S11–S12 are implemented by TI11; the final CLI proof verifies ordered deterministic writes, manual-item preservation, failed-item recording, server ownership and data-only second-component reuse.
- OC03: S14–S15 are implemented by TI09–TI10; the final proofs verify forced states and resolved tokens under strict policy, atomic settling, all three historical regressions and an empty unchanged control.

- **Post-integration shutdown resolution.** The earlier crashpad shutdown observation was repaired in public commit `4be75f5`. `BrowserProbe` owns and cancels its output readers, requests graceful `Browser.close`, falls back after5 seconds, and cleans partial launch resources. Three real-Chrome regressions failed first (inherited output writers blocked VM exit; failed launch leaked a browser; stopped-browser close exceeded10 seconds), then passed. Removing reader cancellation reproduced the exit failure. The standalone56-capture controller then exited0 autonomously without manual process cleanup. Parent compatibility checks passed60 plus the same2 existing skips, Chrome driver passed1, analysis reported0 issues. Evidence is public `.agent_temp/chrome-shutdown/` and `.agent_temp/s02/crashpad-observation.md`. This closes the historical NOTICED BUT NOT TOUCHING item above. Date2026-11-18; original repair evidence2026-11-17.
