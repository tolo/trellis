# FIS: First upstream sync and full gate run

**Plan**: dev/spec/0.14/plan.json
**Story-ID**: S08

## Feature Overview and Goal

**Intent**: ADR-012 bets that the suite stays current with shadcn at the cost of a reviewed sync, and 0.14.0 may only claim qualified components after one full headless pass, so this story proves the bet once (a real sync, run by an agent from a skill, ending in a validated report) and hands release prep a tree whose automated gates, release limits and open manual items are all recorded.

**Expected Outcomes**:

- [OC01] A coding agent bumps the pinned shadcn tag with one command and gets a deterministic sync report that names every upstream change, every token whose value changed and every removed public `trellis-*` class, with no Node.
- [OC02] A sync cannot be committed with an unclassified change or an unexplained failure, and its appearance check is relied on only after it has detected the three regressions the O6 spike found by screenshot alone.
- [OC03] After the sync, all 25 gate subjects, the admin example and the three UI scaffolds pass every automated gate item in Chrome and Firefox with 0 CSP violations, and the payload, owned-JS and example-CSS release limits are measured and held.
- [OC04] Release prep starts from records whose only open items are the manual ones (screen-reader pairs, Safari, the owner's sync-report review), with a runbook section saying what to do with each result.


## Required Context

- `dev/spec/0.14/prd.md#fr1-porting-pipeline-and-sync-skill` – sync criteria: gates run, per-state appearance check, token diff, replay of the three regressions, report classes, breaking-rename flag, failures fixed or triaged before commit; binding.
- `dev/spec/0.14/prd.md#fr5-qualification-gate`, `#success-metrics` and `#non-functional-requirements` – supported-claim rule, failure handling, sync-cost range, release limits (25 KB gzip, 400 JS lines), strict policy.
- `dev/spec/0.14/prd.md#edge-cases` – a release-prep failure on an example-required component is a standalone fix, then that component's manual pass re-runs.
- `dev/spec/0.14/prd.md#fr6-strict-csp-scaffolds-and-ui-option` and `#fr7-admin-example-app` – the surfaces swept in scenario S07.
- `dev/spec/0.14/plan.json#sharedDecisions` – "Component layout and gallery", "Harness input and gate record", "Gallery shell and gate command": this story runs the one gate command, adds no second wrapper.
- `dev/spec/0.14/s01-porting-pipeline-and-trellis-ui-package.md` – `tool/port.dart` (`fetch`, `build`, `check`, `parity`), `tool/pins.json` incl. `structuralSkip`, `tool/parity-ignore.json`, `tool/embed.dart`, injectable HTTP client, `report.json`, gallery contract (`Serving <base-url>`).
- `dev/spec/0.14/s02-headless-qualification-harness.md` – `tool/ui_gate.dart`, `--serve`, manifests, records, per-OS baselines and recording mode, the per-state capture and token diff, scenario S14's regression replay, machine-local browser paths.
- `dev/spec/0.14/s03-strict-csp-scaffolds-and-dev-reload.md`, `s04-behaviour-components.md` (budget test, six records), `s05-css-only-components-layout-primitives-and-overrides.md` (19 records, run-twice determinism check), `s06-admin-example-ui-scaffold-option-and-preview-assets.md` (admin example, footprint tests, `--ui`), `s07-component-reference-docs-and-docs-site-seam.md` (reference pages keyed on `dev/ui-gate/records/`).
- `dev/adrs/ADR-012-trellis-ui-contract.md#decision` (Upstream sync paragraph), `#porting-pipeline`, `#revisit-triggers` – what the sync must do and where a failed component is recorded.
- `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/o6-stress-sync.md` – method, report columns and the screenshot-only findings; `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/o6-spike.md` – first sync and the two-toast overlap.
- Spike starting code, planning repo, `git show spike/trellis-ui-o6-shadcn-port:docs/temp/trellis-ui-o6-shadcn-spike/<path>` (never check it out): `tool/port.dart` (`diffTags`, `inScope`), `reports/sync-shadcn@4.11.0-to-shadcn@4.21.1.md` (report shape), `pins.json`. Examples to port into S01's layout, not to copy: the spike kept a vendored copy per tag and this repo keeps one.
- `dev/guidelines/KEY_DEVELOPMENT_COMMANDS.md` (fast/full tiers, run-one-test), `TESTING-STRATEGY.md` (levels, fixtures, before-merge bar, "UI qualification gate" section story S02 adds), `RELEASE-RUNBOOK.md` (step 0), `dev/state/LEARNINGS.md` ("A screenshot diff needs an A/B control").


## Acceptance Scenarios

- **S01 [OC01] A fixture sync yields a complete, deterministic report skeleton**
  - **Given** two fixture trees (previous pin, new pin) holding vendored inputs, generated CSS and `report.json`, where between them one TSX line changes, a `cn-` hook behind a public `trellis-*` class disappears, a slot and a `data-*` attribute appear, a component file appears in the upstream listing, `--primary` changes in `:root` and `.dark` while `--radius` does not, and a hook named in `structuralSkip` has a changed upstream rule
  - **When** the report is generated twice
  - **Then** it holds the per-file changed-line counts; one entry per upstream change with an id, a kind (mechanical, hand-layer candidate, new component) and `Triage: pending`; the removed public class flagged `BREAKING` by name; the new component with `port | defer | skip` pending; a token diff listing exactly `--primary` (light and dark, old and new value) and not `--radius`; the `structuralSkip` hook listed for revisit; and both outputs are byte-identical with no timestamp, host path or port

- **S02 [OC01] A tag that cannot be fetched changes nothing**
  - **Given** a fetch client answering 404 for one input of the target tag, and separately a tag that is not of the form `shadcn@X.Y.Z`
  - **When** `port.dart sync` runs with each
  - **Then** it exits non-zero naming the tag (and the file), and `pins.json`, `vendor/`, `generated/` and `sync-reports/` are byte-identical to before

- **S03 [OC02] The report check refuses unresolved triage**
  - **Given** (a) a fresh skeleton, (b) a report with every entry classified but a failed gate whose disposition is blank, (c) a report with a `deferred` disposition and no reason, (d) a report whose hand-edit counts exceed the spike range (4 template lines, 3 hand CSS lines, 1 config entry) with no reason, (e) a fully resolved report whose owner-review line says `release-prep`
  - **When** `port.dart sync --check-report` runs on each
  - **Then** (a) fails listing every pending entry, (b) names the gate, (c) names the entry, (d) names the counter, and (e) exits 0; the owner-review line is the only pending marker accepted

- **S04 [OC02] [runtime] The first sync runs end to end from the skill and lands clean**
  - **Given** the pinned tag from story S01, the newest stable shadcn tag, the committed baselines and records, and story S02's regression replay green
  - **When** the skill is followed: sync, parity, regeneration check, embed, then the harness over every component page with baselines compared
  - **Then** `pins.json` names the new tag and commit; `port.dart check`, `port.dart parity` and `embed.dart --check` exit 0 on the result; every appearance difference the harness reports (component, state, element, property) and every changed token has a report entry resolved as `expected`, `fixed` or `deferred` with a reason; baselines are re-recorded only for `expected` ones and the harness then exits 0; the report states the hand-edit counts against the spike range and passes `--check-report`

- **S05 [OC03] [runtime] The release limits hold and are measured**
  - **Given** the synced tree
  - **When** the limit tests run
  - **Then** the suite's embedded CSS, JS and indicator stylesheet gzip (level 9) to at most 25,000 bytes in total with the measured size in the output; owned behaviour JS is at most 400 lines (story S04's rule); the admin example's own CSS is at most 50 lines with 0 authored JS (story S06's rule); with a 30 KB incompressible comment added to one hand CSS file the payload test goes red naming the size

- **S06 [OC03] [runtime] Every component gate subject qualifies with results from both browsers**
  - **Given** the gallery served under the strict policy and the 25 committed manifests of stories S04 and S05
  - **When** the gate runs in headless Chrome and headless Firefox, twice
  - **Then** every automated item of every record passes under ADR-012’s browser fallback, with both raw results and 0 violations, the screen-reader pairs and Safari are `release-prep`, the command exits 0, and the second run changes no byte under `dev/ui-gate/`

- **S07 [OC03] [runtime] The admin example and the three UI scaffolds pass the same gate**
  - **Given** the admin example served with its real middleware and a `--ui` project of each of the Shelf, Relic and Dart Frog scaffolds generated, installed and booted, each reached through the harness's `--serve` contract
  - **When** the gate runs against each surface's manifest in both browsers: the admin list, empty filter result, open row menu, edit dialog with validation errors, alert dialog, Summary tab and a toast; per scaffold `/` after an htmx counter swap and `/ui` with its dialog open
  - **Then** every automated item passes under ADR-012’s browser fallback with 0 `securitypolicyviolation` events and no third-party request, each surface regenerates the bytes of its checked-in `dev/ui-gate/apps/` record, and the launcher leaves no server process running

- **S08 [OC04] Release prep inherits only manual items, and the runbook says what to do with them**
  - **Given** the final component and surface records and `RELEASE-RUNBOOK.md`
  - **When** they are read
  - **Then** every record lists the two screen-reader pairs and Safari as `release-prep` or a human-entered result; the runbook names those passes, the owner's sync-report review, the standalone-fix-then-rerun rule for an example-required component (dialog, dropdown menu, combobox, tabs, toast), and the ship-unsupported rule with its ADR-012 revisit-trigger entry for any other; and any item this story left `fail` is named in the report and in ADR-012's notes


## Structural Criteria

- **SC01** No Node and no new dependency: no `node`/`npm`/`npx` invocation in the new tools or tests, and no pubspec in the workspace changes.
- **SC02** The skill cannot drift from the tools: every command and path it names exists, and every `port.dart` subcommand it names is in the tool's usage.
- **SC03** The committed sync report is reproducible text: no timestamp, host path or port, so a rerun of its generated part shows only real change.
- **SC04** The committed tree stays regenerable after the sync: `port.dart check`, `port.dart parity` and `embed.dart --check` exit 0, and every parity-ignore entry the sync adds has a non-blank reason.


## Scope & Boundaries

### Work Areas
Paths are relative to the trellis-public root, where the story executes; `P` is `packages/trellis_ui`.

- Sync tooling: `P/tool/port.dart` (`sync`, `sync --check-report`), `P/tool/src/` (report library), `P/sync-reports/` (the committed report, excluded from the published archive through `.pubignore`), tests `P/test/sync_report_test.dart`, `sync_command_test.dart`, `sync_skill_test.dart`.
- Skill: `.claude/skills/trellis-ui-sync/SKILL.md`.
- Sync outputs, regenerated and never hand-merged: `P/tool/pins.json`, `P/vendor/`, `P/generated/`, `P/lib/src/embedded_assets.g.dart`, `P/tool/parity-ignore.json`, any fragment or hand CSS edit the triage needs, re-recorded `dev/ui-gate/baselines/`.
- Release gate: `P/test/release_gates_test.dart` (payload), `P/test/release_prep_test.dart` (records), `tool/serve_ui_surface.dart` (launcher), `dev/ui-gate/apps/{manifests,records,baselines}/`, `packages/trellis_cli/test/ui_surfaces_gate_test.dart`.
- Docs: `dev/guidelines/RELEASE-RUNBOOK.md`, `TESTING-STRATEGY.md`, `KEY_DEVELOPMENT_COMMANDS.md`, `dev/adrs/ADR-012-trellis-ui-contract.md` (Implementation Notes), `dev/state/LEARNINGS.md`, `P/AGENTS.md`, `P/CHANGELOG.md`.

### What We're NOT Doing

- Porting any new upstream component or adopting a new upstream feature (submenus, RTL, translucent menus): the report lists them and this story marks them `defer` or `skip` with a reason. A port is its own story, and an upstream re-implementation of a pinned component (toast) keeps the current one working (PRD edge case).
- The manual screen-reader passes, the Safari pass, the owner's sync-report review and the "supported" claim in docs or `CHANGELOG.md` – release prep (owner, 2026-10-20). This story leaves them recorded as open.
- A second gate wrapper, a CI job or scheduled sync – ADR-012 keeps gates local, and story S02 owns the one gate command.
- Raising or amending a release limit, adding an axe override, editing a manifest or skipping a state to turn a result green. A limit miss is the owner's call.
- A changelog `### Breaking` line for a removed `trellis-*` class: the classes have not been released yet. The skill says later syncs add it.
- Docs-site pages for the app surfaces, and `sdk-package-dag.svg`.


## Architecture Decision

**Approach**: Extend the pipeline that exists. `port.dart sync <tag>` fetches the new tag's inputs, bumps `pins.json`, regenerates through `build`, and writes the mechanical half of the report (input diff, contract deltas, upstream component listing, in-scope rule changes, public-class removals, token diff, `structuralSkip` revisit rows, parity-ignore status), comparing against the committed tree at `HEAD`, not a second vendored copy. `port.dart sync --check-report` validates the agent-triaged report. A project skill orders the gates and the triage. The apps reach the existing gate through a launcher that honours the `Serving <url>` contract of `--serve`. Release limits that no predecessor owns (payload) become a package test; the rest are re-run, not rebuilt.
**Why this over the floor**: The floor is the spike's `diff` command plus a hand-written report and a checklist. FR1 rules it out: the report must list each change by class, the token diff must be exact, and a sync must not commit with an unexplained failure, which only a mechanical check enforces. A GitHub Actions sync job is ruled out by ADR-012 (gates run locally).
**Flow**: `sync <tag>` (report skeleton, pins bumped) → replay precondition (story S02 scenario S14) → `parity` → `check` → `embed.dart` → `ui_gate --serve` over the gallery (visual item compares committed baselines, the diff is the appearance report) → triage in place → re-record baselines for `expected` → `--check-report` → one sync commit. Then limits, component gate, surface gates, runbook and docs.


## Constraints & Gotchas

- **Constraint (order and names)**: Runs last, on the 0.14 branch after stories S04 to S07 are merged. Names from stories S01 to S07 (`port.dart` subcommands, flags of `ui_gate`, record fields, `README.md` catalogue) are read from the landed code; where it differs from those FIS, follow the code and say so in the report. Needs network (GitHub, the pinned Tailwind download), Chrome, Firefox 157 and geckodriver 0.37.1 on `PATH` (`brew install geckodriver`). If the pin is already the newest stable tag there is nothing to sync: stop and report.
- **Constraint (never weaken, bounded fixing)**: A failing item stays `fail` in its record. No waiver, override, manifest edit or skipped state turns it green, and no limit constant moves. A real fix is a hand-layer edit at the cause (fragment, hand CSS, `structuralSkip`, a reasoned parity-ignore entry). A failure that survives two real fix attempts stops the story with the item, evidence and attempts reported. A fix that needs hand-layer JS is reported as an ADR-012 revisit-trigger signal ("two consecutive syncs need hand-layer JS rewrites").
- **Constraint (appearance A/B)**: The `visual` item compares captures made in one browser run per LEARNINGS; the baselines are macOS recordings and re-recording is refused when `CI=true`. Re-record only for an `expected` disposition, after reading the diff. A diff the digest cannot see is story S02's pixel-diff path, not a reason to loosen the compare.
- **Constraint (old side is `HEAD`)**: `sync` reads the previous pin's inputs and generated files from the committed tree (`git show`/`git archive`), so a dirty `vendor/` or `generated/` at start is a reason to stop. Do not add a vendored copy per tag.
- **Constraint (breaking flag)**: A `trellis-*` class selector present in the previous generated or hand CSS and absent from the new is public-surface removal and is flagged `BREAKING` whether or not a replacement hook exists; the agent classifies rename versus removal in triage.
- **Constraint (test doubles)**: `sync` tests use story S01's injectable HTTP client and a stand-in compiler named neutrally, so story S01's search for the real compiler name and for Node in `lib/` and `test/` stays clean. The real compile runs only through `dart run tool/port.dart`.
- **Constraint (surface records live apart)**: Surface manifests, records and baselines go under `dev/ui-gate/apps/`, never `dev/ui-gate/records/`, because story S07 enumerates that directory to decide which components get a reference page and expects 25.
- **Constraint (launcher)**: `tool/serve_ui_surface.dart <admin|shelf|relic|dart_frog>` prints `Serving <base-url>` as its first stdout line and stops every process it started when terminated. Scaffolds are created with the real `trellis create --ui` into a temp directory with workspace packages substituted, installed with `dart pub get`, and booted on an OS-assigned loopback port with retry, as `packages/trellis_cli/test/_e2e_server.dart#bootServer` and story S06's scaffold e2e do. Never kill browsers or servers by name.
- **Constraint (shared files)**: `pins.json`, `generated/`, `embedded_assets.g.dart`, records and baselines were last changed by stories S04 and S05. Regenerate after any conflict, never hand-resolve.
- **Constraint (surface items)**: surfaces run the browser-run gate items (PRD FR7): strict CSP, self-hosting, semantic markup, HTMX lifecycle, keyboard over the page's flows, axe, forced colours, responsive, zoom, reduced motion, touch target, and visual against the surface baselines this story records; `provenance` is a per-component fact; where the harness requires an entry, a surface manifest names the repo `LICENSE`, as story S05 does for layout primitives.
- **Constraint (surface manifests)**: The harness has no "not applicable", so each surface manifest declares a Tab-walk keyboard script over its page and an htmx region (the admin list swap with browser Back, the scaffold counter), as story S05 does for non-interactive components.
- **Constraint (parallel with story S09)**: S09 re-records four theme baselines and may add a selection signal to the combobox while this story's sync rewrites suite CSS and every gate record. Whichever of the two merges second re-runs `dart test test/visual_baseline_test.dart` on macOS and the combobox's gate before merging.
- **Constraint (test tiers)**: a test that runs the full gate over real pages carries the `ui-gate` tag, and one that compares a per-OS visual baseline carries `visual`; both are excluded from CI's tiers and run in the release-gate tier on the maintainer's macOS machine (plan.json sharedDecisions "Full-gate tests run locally", ADR-012 § Upstream sync: gates run locally), so a missing Linux baseline or Firefox never fails CI.
- **Decision**: the sync skill lives at `.claude/skills/trellis-ui-sync/SKILL.md` – trellis-public has no project skill yet, ADR-012 puts the skill in the public repo next to `trellis_ui`, and `.claude/` is tracked; would change if the owner wants a skills directory elsewhere (for example `.agents/skills/`).
- **Decision**: the target tag is the newest stable `shadcn@X.Y.Z` at execution (4.22.1 on 2026-10-21, against a pin assumed to be `shadcn@4.21.1` from the spike) – the PRD names no tag.
- **Decision**: "the three scaffolds" in the full gate are the `--ui` variants (`/` and `/ui`) – the default scaffolds have no suite markup and story S03 already proves their 0 violations.
- **Decision**: hand edits beyond the spike range (4 template lines, 3 hand CSS lines, 1 config entry) are reported with a reason for the owner's release-prep review and do not block the sync – an upstream change size is not the agent's to cap.
- **Decision**: payload counts all three embedded assets (CSS, JS, indicator CSS) at gzip level 9 against 25,000 bytes – the PRD says "CSS + JS combined" and "25 KB"; the stricter reading cannot pass wrongly.


## Implementation Plan

### Implementation Tasks

- **TI01** A report library turns two trees (previous and new inputs, generated CSS, `report.json`, `pins.json`, parity-ignore) into the deterministic report skeleton of scenario S01 and validates a triaged report as scenario S03 describes.
  - Pattern: the spike's `diffTags` and `inScope`; entry ids and `Triage:` / `Disposition:` line grammar are the executor's, documented once in the skill.
  - **Verify**: `packages/trellis_ui/test/sync_report_test.dart#a fixture sync yields entries, breaking flag, token diff and revisit rows, identical twice` and `#check-report rejects pending triage, blank dispositions, reasonless deferrals and unexplained over-range edits` – mutation check: drop the `.dark` block from the token comparison and watch the first go red naming `--primary`.
  - **SATISFIES**: S01, S03, SC03

- **TI02** `port.dart sync <tag>` bumps the pin, fetches, regenerates through `build` and writes the report skeleton to `sync-reports/`; `port.dart sync --check-report <file>` runs the validator; a failed fetch or malformed tag changes nothing.
  - **Verify**: `packages/trellis_ui/test/sync_command_test.dart#sync bumps the pin, regenerates and writes the report` and `#a tag that cannot be fetched changes nothing` – stand-in client and compiler, no network.
  - **SATISFIES**: S02, S03, SC01

- **TI03** The sync skill states preconditions (clean `P`, 0.14 branch, network, browsers), the ordered commands of the Flow with the replay as a hard precondition of the appearance step, the triage vocabulary (mechanical, hand-layer edit, new component; dispositions `expected`, `fixed`, `deferred`), the stop rules of Constraints, the baseline re-record rule, the separate sync commit, and where a breaking class goes later.
  - **Verify**: `packages/trellis_ui/test/sync_skill_test.dart#every command and path the skill names exists` – parses the backticked `dart run`/`dart test` lines and paths.
  - **SATISFIES**: SC02

- **TI04** `tool/serve_ui_surface.dart` serves the admin example and a generated `--ui` project of each scaffold under the harness's `--serve` contract, and each surface has a manifest under `dev/ui-gate/apps/manifests/` covering the states of scenario S07.
  - **Verify**: `packages/trellis_cli/test/ui_surfaces_gate_test.dart#the launcher prints Serving first, serves under the strict policy and stops its server` (`ui-gate`-tagged; asserts the port is free afterwards).
  - **SATISFIES**: S07

- **TI05** The first sync is done by following the skill, and its outputs are in the tree: new pin, regenerated `vendor/`, `generated/` and embedded assets, the triaged report, hand edits only where triage required, baselines re-recorded for `expected` differences, one sync commit.
  - **Verify**: `test/ui_gate_appearance_test.dart#spike regressions` – green before the sync is relied on; `cmd: cd packages/trellis_ui && dart run tool/port.dart check && dart run tool/port.dart parity && dart run tool/embed.dart --check` – exit 0; `cmd: cd packages/trellis_ui && dart run tool/port.dart sync --check-report sync-reports/sync-*.md` – exit 0; `cmd: dart run tool/ui_gate.dart --serve 'dart run packages/trellis_ui/tool/gallery.dart --port 0'` – exit 0. Mutation check once: restore the previous value of one changed token in the served CSS and watch the `visual` item name the token and property.
  - **SATISFIES**: S04, SC04

- **TI06** The release limits are enforced and measured: a payload test over the embedded assets joins story S04's JS budget and story S06's footprint tests.
  - **Verify**: `packages/trellis_ui/test/release_gates_test.dart#suite payload stays within 25,000 bytes gzipped` – prints the size; mutation check: the 30 KB comment of scenario S05; `cmd: cd packages/trellis_ui && dart test test/budget_test.dart`; `cmd: cd examples/admin_app && dart test test/footprint_test.dart`.
  - **SATISFIES**: S05

- **TI07** All 25 component records and baselines are current after the sync, with each defect the gate finds fixed in the component.
  - **Verify**: `cmd: dart run tool/ui_gate.dart --serve 'dart run packages/trellis_ui/tool/gallery.dart --port 0'` – exit 0, run twice with a `shasum` of `dev/ui-gate/` equal between the runs; `cmd: cd packages/trellis_ui && dart test test/gate_records_test.dart test/gate_record_test.dart` – every record passes every automated item in each browser it ran and leaves manual items for release prep.
  - **SATISFIES**: S06

- **TI08** Each of the four surfaces has a passing record and baseline under `dev/ui-gate/apps/`, with each defect found fixed at its source (surface template, scaffold template or suite component, re-running the affected component's gate).
  - **Verify**: `packages/trellis_cli/test/ui_surfaces_gate_test.dart#every surface passes every automated item in both browsers` – runs `tool/ui_gate.dart --serve 'dart run tool/serve_ui_surface.dart <surface>'` per surface with the apps directories, asserts exit 0, the record verdict `pass` and 0 violations; requires Firefox, so it fails rather than skips in the final run.
  - **SATISFIES**: S07

- **TI09** The release-prep handover exists: the runbook's step 0 gains a "Trellis UI release prep" part listing the gate commands to re-run, the manual passes per record, the owner's report review, the standalone-fix rule and the ship-unsupported rule with its ADR-012 entry, which also removes the component's reference page and its `site/data/ui_components.yaml` entry (FR5, FR8); every record holds its manual items open.
  - **Verify**: `packages/trellis_ui/test/release_prep_test.dart#every component and surface record leaves the screen-reader pairs and Safari to release prep` – reads `dev/ui-gate/records/` and `dev/ui-gate/apps/records/`; `inspect: dev/guidelines/RELEASE-RUNBOOK.md` – names VoiceOver with Safari, NVDA with Firefox, the report review and both failure rules.
  - **SATISFIES**: S08

- **TI10** The docs match what shipped: `P/AGENTS.md` (sync section naming the skill), `TESTING-STRATEGY.md` (release limits and surface sweep under the UI gate section), `KEY_DEVELOPMENT_COMMANDS.md` (the sync and release-gate commands), an ADR-012 Implementation Notes entry (first sync: tags, hand-edit counts, hand JS lines, any component left unsupported with its failing item), `P/CHANGELOG.md` (`## 0.14.0` names the pinned shadcn tag), and `LEARNINGS.md` with only the traps found.
  - **Verify**: `cmd: git grep -n -F "trellis-ui-sync" -- packages/trellis_ui/AGENTS.md dev/guidelines/KEY_DEVELOPMENT_COMMANDS.md dev/adrs/ADR-012-trellis-ui-contract.md` – the skill is named in each; `cmd: ! git grep --untracked -n -E "'(node|npm|npx)'" -- packages/trellis_ui/tool packages/trellis_ui/test tool/serve_ui_surface.dart && git diff --quiet -- pubspec.yaml 'packages/*/pubspec.yaml' 'examples/*/pubspec.yaml' && dart format --output=none --set-exit-if-changed packages/trellis_ui packages/trellis_cli tool test && dart analyze --fatal-infos` – SC01 and a clean tree.
  - **SATISFIES**: SC01


## Final Validation Checklist

- The `full` tier from `KEY_DEVELOPMENT_COMMANDS.md` is green (sync changed regenerated assets and example-facing templates), with Chrome and Firefox present and the output showing the browser, surface and Firefox tests executed, not skipped; `git diff --quiet -- test/visual_baselines` exits 0.
- Serve the gallery, capture `/components/button`, `/components/dialog`, `/components/table` and `/components/toast` at 390 and 1440 wide with `agent-browser` per `VISUAL-VALIDATION.md`, and read the PNGs against the report's appearance entries: the vega look holds and every visible change is one the report lists.

## Discovered Requirements

- **Landed qualification contract.** **Description:** manifests, records and baselines default to
  `dev/ui-gate/{manifests,records,baselines}/`; each `<component>.<os>.json` baseline contains both browser
  captures. **Rationale:** S02 selected and proved this concrete schema. **Interpretation:** follow the UI gate
  section in `dev/guidelines/TESTING-STRATEGY.md`; missing semantics, keyboard or HTMX recipes yield `not-run`,
  so provide meaningful recipes and actual declared-region swaps. Use local `ui-gate` tags for real-page gates;
  fixture tests stay in fast/full. Pass documented `GECKODRIVER` locally so both browser results execute.
  **Traced from:** S02/TI04, TI07, TI11, TI12. **Date:** 2026-11-17.

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


- **Measured additive utility-token references.** **Description:** adding component utilities made ten previously absent global Tailwind
  tokens appear without changing old rendered output: --blur-2xl, --blur-xs, --color-black, --container-lg,
  --container-md, --container-xs, --text-lg, --text-lg--line-height, --tracking-widest, --tw-outline-style.
  **Rationale:** root-token maps are part of appearance baselines, including otherwise unused utility tokens.
  **Interpretation:** S04 captured all19 inherited pages in both browsers and proved every prior state and token
  value identical before appending40 measured token entries per file. The auditor rejected geometry drift,
  old-token edits/removals and unapproved additions. Preserve this distinction during sync; no broad reference
  refresh or tolerance change, and investigate every rendered difference. Current combined separate-response
  Dart gzip preflight is20169 bytes, JS397 effective lines; repeat formal release measurements after sync.
  **Traced from:** S04/TI08–TI10 and inherited-reference-audit.log. **Date:** 2026-11-17.


- **Causal hover measurement replay.** **Description:** the landed harness retries only forced Firefox hover snapshots interrupted
  by observed document/window backgrounding, replaying fresh state plus actual hover and failing after3 attempts.
  **Rationale:** real focus loss correctly closes a combobox and can suppress dialog autofocus paint.
  **Interpretation:** reuse the existing capture path; never force target focus/reopen UI or retry generic errors,
  popup closure or visual differences. A genuine in-page dismissal and perpetual interruptions still fail;
  CSP and JS diagnostics survive collect-before-navigation. Native keyboard and HTMX lifecycle stay unforced.
  One new dialog reference corrected five proven foreground focus-paint leaves; no other old state changed.
  **Traced from:** S04/TI08 and driver/active/hover regression controls. **Date:** 2026-11-17.


- **Integrated admin and scaffold proof seams.** **Description:** S06 adds the real admin app and UI-only Dart Frog custom main that serves embedded `/trellis-ui/` assets before the CLI static cascade. **Rationale:** Dart Frog CLI1.2.6 dev/build otherwise serves stale materialized public files first. **Interpretation:** reuse the generated app's actual entrypoint and the existing scaffold E2E harness, including production bootstrap, rather than directly constructing the root handler. Preserve unchanged non-UI/CDN defaults. The admin has22 owned CSS lines,0 authored JS; its table uses the new default-preserving header slot. Malformed forms owe400; unknown edited/deleted IDs owe404 before body parsing. Theme proofs await native transition completion before exact colour assertions, without forcing theme values. Reuse these source tests instead of inventing weaker gates. **Traced from:** S06/TI03–TI13 and independent review. **Date:** 2026-11-18.

- **Landed site source and reference contract.** **Description:** S07 ships generic `SiteSource`/`sourceFactories`, ordered site/theme source-name union, source loader below theme/site in both engines, and source asset preflight before output. CLI owns the `trellis_ui` factory. Source-enabled post-Markdown shortcodes receive page-scoped YAML as base context, overridden by explicit string parameters. **Rationale:** the core/site package must remain suite-agnostic and real fragment lists/maps require structured values. **Interpretation:** consume the existing registry and hooks; preserve no-use byte parity, unknown-name/path failures and no-output cleanup. The generated inventory derives signatures, longest-prefix classes and every browser verdict, distinguishes qualified/manual-open from supported, and rejects an unexpected nested reference route. Regenerate `site/data/ui_components.yaml` after SDK signature/slot or qualification changes; preserve all25 real examples and root/prefix proof. The docs preview has scoped token/layer restoration plus an opaque suite background to prevent theme contrast/focus leakage. **Traced from:** S07/TI01–TI10 and independent review. **Date:** 2026-11-18.

- **Single-vendor provenance migration.** **Description:** the existing suite manifests name the MIT notice under the versioned vendor directory. **Rationale:** a real single-vendor bump removes that old notice path. **Interpretation:** replace only the pin segment in those notice paths before the first synced gate, audit the unchanged recipes and hash the new notice against the peeled upstream commit. **Traced from:** S08/TI05, TI07. **Date:** 2026-11-18.
- **One page per surface recipe.** **Description:** the existing CLI consumes a single page per manifest, and the two UI scaffold routes have distinct gates. **Rationale:** a history step visiting another page does not run every automated item on it. **Interpretation:** qualify seven subjects across the four launched app kinds, with one recipe for each scaffold route and one covering all admin states. **Traced from:** S08/TI04, TI08 and PRD FR6–FR7. **Date:** 2026-11-18.

- **Actual 4.23.0 token baseline.** **Description:** the latest stable annotated tag peels to commit `96da9cc7f1aa10580a3741664e2a77c721206c00`; its pinned neutral input and generated colour/radius declarations equal the previous pin byte for byte. **Rationale:** TI05's literal previous-value mutation assumes a real token delta. **Interpretation:** report zero pinned changes and prove the detector using a scratch alternate light `--primary` baseline on the real gallery, restoring the actual shipped/previous value and requiring the visual item to name that token and its background property. No production asset or canonical baseline carries the alternate value. **Traced from:** S08/TI05. **Date:** 2026-11-18.
- **Composed-page browser applicability.** **Description:** native modal backgrounds remain geometrically visible but cannot receive focus. Firefox's body-based setup also cannot start native Tab inside a pointer-opened one-control modal, and element-origin pointer movement does not prepare nested horizontally scrolled targets. **Rationale:** component-only recipes kept focus within rendered component roots and did not expose these composed-SDK cases. **Interpretation:** use the active modal's focus boundary for forced measurement, start the emulated sequential focus within the modal and restore its tabindex, and reuse nearest-edge pointer preparation before native actions. Preserve actual keyboard/lifecycle behavior and compare all existing states. **Traced from:** S08/TI08. **Date:** 2026-11-18.
- **Release-prep manual failure publication.** **Description:** the public reference inventory and page exclude a component with an explicit failed manual item while preserving its canonical record. **Rationale:** the ship-unsupported procedure must remove the public entry when the owner records a failure. **Interpretation:** omit that component from publication and require page removal, preserving the existing automated-fail diagnostic and manual-open qualification semantics. **Traced from:** S08/TI09 and PRD FR5. **Date:** 2026-11-18.

- **Causal Firefox visual recipe replay.** **Description:** a visible window blur after native End can retain the dropdown's active element while removing its highlight, invalidating a visual state recipe before hover capture. **Rationale:** the landed hover guard arms after recipe setup. **Interpretation:** replay the fresh visual recipe at most three times after a trusted visible blur in the failed attempt with the document still unfocused. Preserve in-page failures, synthetic events, native keyboard/lifecycle behaviour and CSP/JS diagnostics. The original run recorded no blur, so its cause is inferred from the controlled real-gallery transition. **Traced from:** S08/TI07. **Date:** 2026-11-18.

- **Browser emulation fallback (owner re-attestation).** **Description:** The owner confirmed [ADR-012’s browser emulation fallback](../../adrs/ADR-012-trellis-ui-contract.md#browser-emulation-fallback) for every component and app route. **Rationale:** Earlier wording treated every per-browser `not-run` as an item failure. **Interpretation:** Both browsers remain required for the sweeps. Aggregate pass is required for each app route, using fresh records seeded only with manual evidence. **Traced from:** S08/TI07–TI08. **Date:** 2026-11-18.

## Implementation Observations

- Scope and provenance. Public worktree admitted at `4be3c735` on `feat/0.14-s08`. The tooling commit `2f2896b` and the nested-checkout archive repair `8dfa879` precede the real sync so the old inputs were read from a committed 4.21.1 tree. The first real invocation threw `PathNotFoundException: Cannot open file .../candidate/tool/pins.json` before live writes. The fixture moved below the Git root, reproduced the error, then passed after running the named-subtree archive from that root.
- Live upstream check selected stable `shadcn@4.23.0` and independently resolved its annotated reference to commit `96da9cc7f1aa10580a3741664e2a77c721206c00`. The sync fetched 27 inputs. It adds 77 style lines and 19 rules for Code Block and Trace outside the pinned hook set. The generated CSS declarations match before and after comment stripping, the neutral input was byte-identical, and all old generated outputs were compared. The fetched MIT file matches the upstream SHA-256 `1564074e13439397221ffd522e2e504d56561994a23d371aa5e3ad43e4f5423f`. Exactly 21 suite notice paths moved to the new version, with every remaining byte of each recipe audited.
- Three-screenshot replay passed before the first synced appearance verdict. The real pin moved zero colour/radius tokens, so a separate real gallery seed with light `--primary: oklch(0.30 0 0)` recorded in scratch passes. Restoring the shipping value makes a compare run exit 1 explicitly naming `token light --primary oklch(0.30 0 0) -> oklch(20.5% 0 0)` and `default .trellis-button-variant-default backgroundColor`. The scratch baseline is excluded from canonical records and the sync report.
- Three shared checker repairs landed in `7c5e2b6` after actual app reds and fresh browser red/green proofs. Both browsers reproduced the modal-background forced-colour focus failure. Firefox also reproduced separate one-tab-stop focus and offscreen nested pointer errors. Both engines passed the named current focus pair and nested-hover/single-click check. The existing condition, native input and negative controls finished 9/9 under `test/ui_gate_checks_test.dart`.
- The real app launcher reused the generated CLI entries and workspace override/port conventions. TI04 returned 4 real apps, 7 HTTP routes, 12 body/ETag pairs, and 4 released ports. An independent early-TERM probe confirmed cleanup during generated project startup. Initial composed runs found the actual policy directive gap, UI scaffold target/motion gaps and Relic's implicit submit type. The source repairs keep the requested states, real middleware, native shortcuts and all item assertions.
- Explicit failed release-prep manual items now suppress public inventory and reference routes through `b32424a`, while their canonical gate evidence remains. The old S07 automated-fail diagnostics and manual-open compatibility are preserved. The manual-fail fixture first failed missing the `Unexpected reference page: button` error, then passed with all six reference data tests and generated-file freshness.
- Learnings admission. The annotated-tag commits-API detail was already recorded. The nested Git archive and browser traps are attached to the changed source and regression proofs, so no duplicate entry was added.

#### DRIFT

- spec-stale: Owner re-attested the browser fallback in ADR-012. Proofs use the shared item verdict in `packages/trellis_cli/test/ui_surfaces_gate_test.dart#every surface passes every automated item in both browsers` and `packages/trellis_ui/test/qualification_gate_test.dart#automated qualification remains green in Chrome and Firefox` | Stale targets: S08/TI07–TI08 per-browser pass wording | –
- spec-stale: TI05's literal restore-one-changed-token instruction assumes a nonempty diff. The live sync has zero changed tokens. The alternate value is isolated to a real-gallery scratch seed and the restored actual value is checked by the visual item | Stale targets: S08 TI05 mutation phrase | Both the token and a computed property appeared in the red detector output.
- spec-stale: The landed record-unit suite is root `test/ui_gate_record_test.dart` with package `test/gate_records_test.dart` for component qualification | Stale targets: S08 TI07 package `test/gate_record_test.dart` path | Keep the original record and qualification checks.
- spec-stale: The dispatched `--no-full-tier` story runs the exact fast tier while the parent owns final combined full and release-gate | Stale targets: Full-tier checklist ownership | All story-specific browser, AOT, mutation and static proofs remain local to S08.

- spec-stale: S07 S14 requires a failed automated component to remain in internal reference data with `qualified: false`; the sole consumer is its reference page, which must be removed. TI09 drops both the page and inventory key when an explicit manual release-prep failure is recorded | Stale targets: TI09 generic inventory removal wording | Both paths are covered by the reference-data tests and the runbook states the separate owner actions.

### Shared harness repair evidence

- The first provisional pair was stopped after 9 rewritten records per run. The second provisional pair reached 17 each and one Firefox dropdown visual result reported `Bad state: state destructive step 3 expect: Bad state: expected true, actual false`. Both pairs exited 1 after explicit termination of their verified owned process trees. Their outputs and partial records are retained, and source/reference hashes across the second pair were identical.
- On the real synced gallery, native End focuses `menu-alert` with `data-highlighted` while the popover is open. A real visible popup takes window focus and the highlight disappears while the active element and open popover remain. This reproduces the predicate failure with a known cause. The original run's cause remains inferred because that run recorded no focus trace.
- `885e836` adds visual-only replay after trusted visible blur while the failed attempt is still unfocused. The scoped independent pre-freeze review proved an evaluated JS exception could be erased by the broad step wrapper. `b5a9303` limits retry to a false predicate result or an exhausted wait. The direct JS diagnostic is a hard failure even after observed blur. Owner rerun `dart test test/ui_gate_hover_context_test.dart --reporter expanded` -> exit 0, `00:43 +8: All tests passed!`. Controls cover in-page dismissal, synthetic blur, three-attempt exhaustion, actual rendered highlight, and CSP/uncaught JS retention. The earlier successful real dropdown comparison matched the canonical record bytes.
- First app references are promoted from seven captured records and both full browser captures per recipe. The candidate audit checked 182 automated browser-item passes, 228 evaluated appearance states, 21 open app manual entries and exact copied bytes. The package's manual-record assertion passed over 32 subjects.
- Visual checklist owner read 8 actual gallery PNGs and 26 actual app PNGs at 390 and 1440. The two toast boxes remain separate, table overflow stays in its own scroll region, modal autofocus and validation are visible, and all eight app axe audits reported zero violations. Each admin axe snapshot listed two incomplete items. The app reference capture found no clipping or overlap. An auxiliary Dart Frog screenshot attempt exhausted readiness while a second Dart Frog run was active, then the same real source passed after that parallel session finished.

### S09-first integration

- The S08 worktree merged the exact landed S09 commit `519b0754e50f411933578e0fb51fdf9b7b4f5a71` as `196e9b527ca7421ed06bd0aa72d8b9dd7b85351a`. The merge combined both sets of shared hunks and the complete pre/post pending-status files match byte for byte. Regenerated suite outputs and the embedded file have five identical SHA-256 hashes before and after. Parity, embed and reference freshness passed. S08 made no additional theme baseline change relative to the landed S09 tree.

- ASSUMPTION: The independent visual assessment can run alongside the combined qualification sweeps with one isolated owned browser session and server. Observed contention would move it to a separate window. Any visual repair will recheck the affected proof.
- ASSUMPTION: The independent code and gap review can read the complete implementation while qualification runs. The review remains read-only during the source freeze and closes once the executed proof and any repair are available.

### Final combined qualification and sync review

- On the same integrated source and canonical records, two foreground `dart test test/qualification_gate_test.dart --reporter expanded` sweeps exited 0 with `17:02 +1: All tests passed!` and `17:03 +1: All tests passed!`. Each exercised all 25 subjects, including the S09-first integration combobox rerun, and re-created all 25 records byte for byte. The 365-file source list and all 96 files under `dev/ui-gate/` had identical pre/post SHA-256 manifests. The audit found 650 passing browser items, 1,316 measured component appearances and 75 open component manual entries. The live gallery's three asset bodies and strong ETags matched the embedded source.
- The fresh code/gap review found a stale exclusive sync sentinel after a real SIGINT and an unqualified GitHub commit lookup that could also resolve a branch. The scratch cancellation proof exited 1 with `PathExistsException` during retry. The explicit tag-ref fixture initially received `/repos/example/ui/commits/shadcn@1.0.2` instead of the required full path. Commit `efd1550` uses a process-lifetime file lock and fully qualified tag refs. The fixture rejects a second live command, interrupts the first, verifies input/output bytes, and successfully retries. The live qualified tag endpoint returned the already-verified commit. Final fixture/parity/regeneration/embed/report exited 0 with nine tests, zero unignored differences and identical generated bytes.
- The repair changed only the maintainer sync tool among the frozen input list. The running gallery, gate CLI and app launchers do not import that tool. Their bytes and the 96-file gate directory still match the final qualification freeze. Proof logs sit under the isolated public worktree at `.agent_temp/s08/`.

### Independent visual repair

- The independent visual assessment found an offscreen restored keyboard focus target after a saved admin edit at 390 px. Its visible Chrome session and the owner's fresh Chrome and Firefox probe all confirmed the native action at x≈603–697, outside the table's x=48–342 clip after an actual successful save. The permanent regression failed with `the replaced table must reveal the restored focus`.
- The app-only mutation response now uses htmx's existing `focus-scroll:true` option. Both browsers measured the focused Actions button at x≈225–319 and scroll offset 378 after saving. The complete current admin suite passed `00:12 +16: All tests passed!`, including the narrow keyboard regression, exact mutation header, create/edit/delete workflows, HTTP errors, CSRF and the moved standalone AOT binary.
- The same independent reviewer recaptured the exact 390 px native keyboard save and read the visible focus ring beside the success toast. The next Tab moved focus to the second row. Overall visual verdict PASS after one P2 repair, with 47 captures, 34 axe audits, 0 violations, 0 CSP events and no off-origin page resources. The initial gallery table probe ran in a hidden document. A visible context proved Tab focus, ArrowRight to the right edge at offset 282 and Tab onward, with no document overflow. See the isolated public worktree's `.agent_temp/s08-visual-review/assessment.md`.
- The pre-fix exact seven-route comparison exited 0 at `04:19 +1: All tests passed!`. The independent 390 px keyboard flow exposed a state outside its 1440 px appearance digest. That run is retained as pre-fix evidence. The repair changed only the app library and its tests, outside the separately attested component runtime graph.

### Executed proofs

Paths below identify commands by their package or repository working directory. The corresponding logs are under `.agent_temp/s08/` in the isolated public worktree.

- TI01. `dart test test/sync_report_test.dart --reporter expanded` in trellis_ui exited 0, `00:00 +2: All tests passed!`. Removing the dark token block made the expected light and dark `--primary` rows differ from the actual light-only result and exited 1. The restored generator rebuilt the actual live mechanical report twice byte for byte.
- TI02. The four named sync-command fixtures executed in the nine-test canonical package check, exit 0, `00:01 +9: All tests passed!`. They exercised pin/vendor/output installation, protected-byte equality after a 404 or malformed tag, rejection of dirty inputs, concurrent refusal, SIGINT recovery and successful retry.
- TI03. `dart test test/sync_skill_test.dart --reporter expanded` in trellis_ui exited 0, `00:00 +1: All tests passed!`. The skill's frontmatter validator returned `Skill is valid!`.
- TI04. `dart test test/ui_surfaces_gate_test.dart --plain-name 'the launcher prints Serving first, serves under the strict policy and stops its server' --reporter expanded` in trellis_cli exited 0, `00:30 +1: All tests passed!`. Four real app launches served seven routes, reproduced twelve served asset bodies and strong ETags, and released four ports.
- TI05. `dart test test/ui_gate_appearance_test.dart --plain-name 'spike regressions' --reporter expanded` exited 0, `00:51 +1: All tests passed!` before relying on appearance. Live `tool/port.dart sync shadcn@4.23.0` installed 27 fetched inputs from the peeled tag commit. The final root `port.dart check`, `parity`, `embed.dart --check` and `sync --check-report` chain exited 0 with four regenerated byte-identical files, zero unignored differences and `Sync report check: all changes and gate results triaged`. The isolated `--primary` restoration returned exit 1 naming the exact token and the button's computed `backgroundColor`. Two final component passes exercised the CLI in both browsers. Single pin, vendor, generated assets and sync report commit `980ca8338afe03cc15d3d6ca8eedec88a23e80c8`.
- TI06. `dart test test/release_gates_test.dart test/budget_test.dart --reporter expanded` in trellis_ui exited 0, `00:00 +2: All tests passed!`. Gzip level 9 produced 20,225 bytes (CSS 15,179, JS 4,873, indicator 173), and owned JS measured 397 of 400 lines. The scratch 30 KB comment returned exit 1 and named 45,347 bytes. `dart test test/footprint_test.dart test/aot_test.dart --reporter expanded` in admin exited 0, `00:03 +3: All tests passed!`, with 22 authored CSS lines, zero authored JS and the moved binary serving current assets. The final admin suite rechecked the same proofs.
- TI07. Two final `dart test test/qualification_gate_test.dart --reporter expanded` runs in trellis_ui exited 0 at `17:02 +1` and `17:03 +1`. Each reported all 25 subjects passing and 25 records reproduced byte for byte. Pre/post and final SHA-256 manifests match for all 96 files in `dev/ui-gate`. Component/browser-item audit: 650 passes and 75 manual entries. The landed package and gallery record tests exited 0, `00:03 +7`, and root `test/ui_gate_record_test.dart` exited 0, `05:57 +3`. Fresh gallery HTTP assets matched embedded bytes and ETags.
- TI08. `dart test test/ui_surfaces_gate_test.dart --plain-name 'every surface passes every automated item in both browsers' --reporter expanded` in trellis_cli after the visual fix exited 0, `04:37 +1: All tests passed!`. Four batches and seven route subjects passed 182 browser-item checks, with zero CSP violations and seven byte-identical records. The admin narrow save used the existing 1440 px gate reference and the separate 390 px interaction and screenshot proofs.
- TI09. `dart test test/release_prep_test.dart --reporter expanded` in trellis_ui exited 0, `00:00 +1: All tests passed!`, covering 32 records and 96 open manual checks. The runbook names both screen-reader/browser pairs, Safari, the owner's report review and the two failure dispositions. `dart test test/ui_reference_data_test.dart --reporter expanded` and `dart run tool/generate_ui_reference.dart --check` exited 0 with six tests and current reference data.
- TI10. The skill was found in package AGENTS, key commands and ADR-012. The Node invocation and workspace pubspec scans were clear. The required format command reported `Formatted 210 files (0 changed)`, the three late admin files were formatted, and `dart analyze --fatal-infos` reported `No issues found!`. The ADR, handover and changelog name the live tag, measured gates and zero suite hand-edit lines.
- Combined pre-merge check. `dart test test/visual_baseline_test.dart --reporter expanded` exited 0, `00:53 +7: All tests passed!`. The six themes rendered at 390, 768 and 1440 px in light and dark and the S09-relative theme reference diff was quiet. Both combined component sweeps ran the combobox gate, and its sources, recipe, baseline and record hashes match the final tree.
- Visual checklist. The owner read eight requested gallery captures at 390 and 1440 px and inspected the app states. The independent assessment passed after the admin P2 repair, with its 47 read captures, 34 zero-violation axe audits, zero CSP events, and exact targeted keyboard recapture. The full and release-gate tiers are the plan runner's combined proof under `--no-full-tier`.

### Chain attestation

- OC01. S01 and S02 follow from TI01 and TI02's twice-identical report, breaking-class and dual-mode token fixtures, protected-byte failure proof, and real tag installation with a qualified peeled commit.
- OC02. S03 and S04 follow from TI01–TI05's refusal of unresolved reports, current skill paths, actual three-regression replay and visual detector available against the verified live bump.
- OC03. S05–S07 follow from TI04 and TI06–TI08's launcher identity, release measurements, two exact component sweeps and seven real-route comparison after the narrow keyboard repair.
- OC04. S08 follows from TI09 and TI10's 96 typed manual entries, owner report review at release prep, documented failure actions and the generator's two failure paths.
- Landed qualification and the single wrapper are exercised by TI07's 25 unique subjects, both browser keys and every unchanged canonical output byte. TI08 uses the same CLI and recipe contract for each app route.
- Native keyboard and active setup use the real input fixture proofs and the complete component sweeps. The separate 390 px admin probe records native Tab and Enter in both engines, visible focus and a successful response.
- The manual state validator and reference-data fixtures keep human-entered results and the typed status vocabulary. The 32 record comparisons retained all currently open manual fields.
- The paired reference comparison proves the inherited utility-token measurements still agree for all 25 component references. Current SDK signatures and qualification data passed the checked reference generator after the S09 merge.
- The integrated admin and scaffold seams are exercised by TI04's real launchers, TI06's moved AOT binary, and TI08's route matrix. The source edits remain provider-free and strict-policy clean.
- The causal replay regressions cover foreground false conditions, synthetic loss, direct evaluator failure, CSP and JS diagnostics and exhaustion over three attempts. Both final component runs passed on the reviewed harness.
- TI05 and TI07 prove the 21 provenance-only references, the upstream MIT digest and zero actual pinned token changes. TI08's seven routes account for the four app kinds. TI09's manual-failure fixtures prove the reference publication rule.

### Completion check

- The documented fast tier exited 0. Package runs passed 3,532 tests with the existing Linux watcher skip. Root runner returned `03:22 +282 ~2: All tests passed!`; its two existing skips cover themes with no progressive-enhancement controls. All fourteen workspace analyses passed. Final formatting reported `Formatted 51 files (0 changed)`. The release comparisons covered all required browser subjects and executed both engines.
- Final isolated public HEAD `b9eb7e20f560ffb55d7563960e178ab9452a1a2f`, tree `28688fa8905e650a5730eea124bce15113be7744`, clean on `feat/0.14-s08`, contains exact landed S09 beneath the S08 product commits. The list of 118 owned changed or moved paths against S09 is in `.agent_temp/s08/final-owned-paths.tsv`.

Reviewed: Fresh chained quick code and gap review found two sync defects. The repair record `efd1550` resolves the stale interrupted sentinel and ambiguous tag lookup. The reviewer reconciled their red-first and final checks and closed both Fix routes. The S07 automated-failure inventory diagnostic is a spec-stale Note, with the split validated by six reference checks and clarified in the runbook. The separate visual review found one admin keyboard P2, and recaptured its visible focus and toast after the app-only repair. No Fix route remains open.

- **Evidence relocation after S08 integration.** **Description:** the owned paired worktrees and merged branch were removed after copying and hashing3,525 regular evidence files and verifying14 symbolic-link targets. Mutable Finder metadata was separately captured as a byte-verified named snapshot; it is not a test or measurement input. **Interpretation:** historical source `.agent_temp` paths resolve under the main checkout `.agent_temp/0.14-plan-run/evidence/S08/public-agent-temp/`. The exact own return receipt and complete paired bundle are under `evidence/S08/private-receipt/` and `private-bundle-snapshot/`; sibling rows in returned snapshots are historical, while the canonical plan records all nine done. Parent read both fixed admin keyboard-focus PNGs. **Traced from:** feature `b9eb7e2`, integrated `bd8e121`. **Date:** 2026-11-18.

- **Parent final integrated verification.** Public `feat/0.14` HEAD `bd8e121faf15f3e9ea492a481ae7ef0a088a7b86`, tree `28688fa8905e650a5730eea124bce15113be7744`, passed the exact full tier (3572 package +282 root) and exact local release-gate (3535 package +289 root), both exit0. The same3 inherited platform/inapplicable skips remain; no new required proof skipped. Fourteen package analyses, explicit root tool/test analysis, formatting, regeneration/parity/embed/report validation and reference freshness are green. All96 gate-file hashes remain unchanged; canonical32 records hold832 browser-item passes and96 manual release-prep entries. All9 stories/107 declared tasks are verified. S08 simplification found no justified edit. Evidence: public `.agent_temp/0.14-plan-run/summary.md`, final-full.log, final-release-gate.log and final-integration-audit.json. **Date:** 2026-11-18.
