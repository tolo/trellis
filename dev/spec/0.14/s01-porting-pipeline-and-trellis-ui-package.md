# FIS: Porting pipeline and trellis_ui package

**Plan**: dev/spec/0.14/plan.json
**Story-ID**: S01

## Feature Overview and Goal

**Intent**: Give Trellis a no-Node way to regenerate the shadcn look as committed CSS, and deliver it to apps as one lockstep package, so every later component story adds a component instead of re-deciding how the suite is built, isolated, embedded, served and shown.

**Expected Outcomes**:

- [OC01] A maintainer regenerates the suite stylesheet from a pinned shadcn tag with no Node, and the pipeline refuses an unverified compiler, drifted output and unexplained divergence from upstream.
- [OC02] Loading the suite stylesheet never changes how markup outside suite components looks, and an app's pasted theme block wins over the suite's tokens whatever the link order.
- [OC03] An app that depends on `trellis_ui` renders the button through its own engine and serves the suite from its own origin under `script-src 'self'; style-src 'self'` with 0 violations, on Shelf, Relic and Dart Frog.
- [OC04] `trellis_ui` releases with the lockstep set.
- [OC05] A later story adds a component by dropping files into one layout and sees it in the gallery and in the checks that scan the layout.


## Required Context

- `dev/spec/0.14/prd.md#fr1-porting-pipeline-and-sync-skill` – gate behaviours this story owns: regeneration gate, compiler checksum stop, structural-class report, reasoned parity-ignore, no Node outside the pipeline. The sync skill, appearance check and sync report belong to S02 and S08.
- `dev/spec/0.14/prd.md#fr2-trellis_ui-package-and-delivery` – package, serving, materialization, three assets, lockstep.
- `dev/spec/0.14/prd.md#fr4-css-only-components-layout-primitives-overrides` – the isolation and theme-block criteria; the semantic-markup criterion binds the button fragment.
- `dev/spec/0.14/prd.md#open-questions` – the preflight question this story settles first; the owner's ruling is that isolation stays a Must.
- `dev/spec/0.14/prd.md#constraints` and `#edge-cases` – no Node, unattended headless checks, twice-inserted fragment ids, hand-edited materialized folder.
- `dev/adrs/ADR-012-trellis-ui-contract.md#porting-pipeline` and `#delivery-packaging-spike-resolved-2026-08-18` – pinned inputs, `@apply` cannot apply `group/*` or `peer/*` markers, base64 not string literals, aggregate bundle.
- `~/Repos/home/trellis/research/11-trellis-ui-packaging-spike.md` – measured delivery: tree-shaking, 1.33x, ETag from compile-time digest, why a CLI-vendored bundle was rejected.
- `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/o6-spike.md` and `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/shadcn-porting.md` – what the spike pipeline did and where it was unverified (§4 no-Node build).
- `packages/trellis/CHANGELOG.md#0130` – `tl:slot`, `tl:attrs`, the `...rest` parameter and bare-name `renderFragment`, which the button fragment is written with.
- Starting code, local trellis-private branch `spike/trellis-ui-o6-shadcn-port`, read with `git show spike/trellis-ui-o6-shadcn-port:docs/temp/trellis-ui-o6-shadcn-spike/<path>` (never check it out): `tool/port.dart`, `tool/src/tsx_scan.dart`, `tool/parity.dart`, `tool/bundle.dart`, `bin/server.dart`, `parity-ignore.json`, `pins.json`, `static/trellis-hand.css`, `vendor/`. The spike's README says do not merge it: port the code, add what it lacked (tests, gates, isolation, checksum), do not copy its layout.


## Acceptance Scenarios

- **S01 [OC01] Pinned tag regenerates the committed CSS byte for byte**
  - **Given** the pinned shadcn inputs vendored and the pinned Tailwind CLI verified
  - **When** the regeneration gate runs
  - **Then** it regenerates `entry.css`, `trellis.css`, `trellis.min.css` and `report.json` into a temp directory, finds each byte-identical to the committed file and exits 0; with one byte of `generated/trellis.css` edited it exits non-zero naming that file.

- **S02 [OC01] A compiler that does not match its pin stops the build before generating**
  - **Given** a compiler file whose sha256 differs from the pin for its platform, or a platform with no pin
  - **When** `build` runs with it
  - **Then** it exits non-zero, names the expected and actual digest (or the unpinned platform), and creates or modifies nothing under `generated/`.

- **S03 [OC01] Structural classes without a hook are reported**
  - **Given** vendored component source with a class literal that carries no `cn-` hook
  - **When** the pipeline generates
  - **Then** `report.json` lists that literal with its file, line and slot, and the generated CSS does not contain it.

- **S04 [OC01] Divergence from upstream needs a reason**
  - **Given** a fragment missing a `data-slot` the upstream component declares
  - **When** `port.dart parity` runs
  - **Then** it exits non-zero naming the slot; the same gap passes only with a parity-ignore entry that has a non-blank reason, and an entry without one fails the gate by name.

- **S05 [OC02] [runtime] Suite CSS leaves non-suite markup untouched**
  - **Given** a fixture page of plain elements outside any suite markup (html, body, h1 to h6, p, a, ul, ol, button, input, select, textarea, table, img, pre, code, hr, fieldset) and one suite button
  - **When** Chrome loads it with and without the aggregate stylesheet, in light mode and with `.dark` on `html`
  - **Then** every non-suite element has identical standard computed properties in both loads (custom properties are excluded: shadcn tokens on `:root` and `.dark` are the public surface).

- **S06 [OC02] [runtime] A pasted theme block wins in either link order**
  - **Given** a stylesheet with an unlayered `:root { --primary: … }` and `.dark { --primary: … }` block, linked once before and once after the suite stylesheet
  - **When** the page with the default button loads, light and dark
  - **Then** the button's computed background is the pasted value in both orders and both modes.

- **S07 [OC03] The button renders through the app's engine**
  - **Given** an engine on `CompositeLoader([app loader, suite loader])` and an app template `<button tl:replace="~{trellis-ui/button :: button('destructive', 'sm')}" type="submit" hx-post="/save" disabled>Save</button>`
  - **When** it renders
  - **Then** the output is one `<button>` with `data-slot="button"`, classes `trellis-button trellis-button-variant-destructive trellis-button-size-sm`, `type="submit"`, `hx-post="/save"`, a valueless `disabled`, the text "Save", and no `tl:*` attribute; invoked with no arguments it carries `variant-default` and `size-default`; and every variant and size the fragment offers has a rule in the generated CSS.

- **S08 [OC03] Unknown suite names fail with the engine's own exceptions**
  - **Given** the same engine
  - **When** a template inserts `trellis-ui/button :: nonexistent`, and another `trellis-ui/nonexistent :: button`
  - **Then** the first throws `FragmentNotFoundException` and the second `TemplateNotFoundException`.

- **S09 [OC03] Assets are served same-origin with validators**
  - **Given** an app on Shelf, on Relic and on Dart Frog, each with the documented handler glue
  - **When** it receives `GET /trellis-ui/trellis-ui.css`, `/trellis-ui/trellis-ui.js` and `/trellis-ui/htmx-indicator.css`, then the same requests with `If-None-Match` set to the returned `ETag`, then `/trellis-ui/nope.css`, then `/other.css`
  - **Then** the first three return 200 with bytes whose sha256 equals the embedded digest, `text/css; charset=utf-8` or `text/javascript; charset=utf-8`, and a strong `ETag` equal to that digest; the conditional requests return 304 with an empty body; the unknown suite path and the path outside the prefix are not answered by the suite, so the app's own 404 or routing applies.

- **S10 [OC03] Materialization overwrites divergence and fails loudly**
  - **Given** a directory holding a stale `trellis-ui.css` and a hand-edited `trellis-ui.js`, a directory that does not exist, and a path that cannot be created or written
  - **When** materialization runs against each
  - **Then** divergent files are rewritten to the embedded bytes, files already equal are not rewritten, the missing directory is created, and the unwritable target throws an error whose message contains that path.

- **S11 [OC03] [runtime] The gallery's button page loads under the strict policy with 0 violations**
  - **Given** the gallery server answering every response with `default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'`
  - **When** Chrome loads `/components/button`
  - **Then** the suite CSS and JS arrive from `/trellis-ui/`, no `securitypolicyviolation` event fires, every variant and size is on the page, the default button's computed background equals the resolved `--primary`, and its computed `box-sizing` is `border-box` (the suite's own reset still reaches suite elements).

- **S12 [OC05] A new gallery page appears without code changes**
  - **Given** a gallery pages directory holding the button page and a second page file
  - **When** the index `/` is requested
  - **Then** it links `/components/button` and the second page, and requesting the second page renders it under the same policy.

- **S13 [OC04] A lockstep release requires a trellis_ui changelog section**
  - **Given** the release-script fixture with every publishable package's changelog at `## 9.8.7` except `trellis_ui`
  - **When** `tool/release.sh 9.8.7` runs
  - **Then** it refuses, naming `trellis_ui`; with the section present it proceeds like the other packages.


## Structural Criteria

- **SC01** No fragment, gallery page or hand asset contains an inline `style` attribute, a `<style>` element, an inline `<script>` or an `on*` handler attribute, because the strict policy blocks each; the check scans the layout directories, so later stories are covered without editing it.
- **SC02** Every fragment under `assets/fragments/` passes `TemplateValidator` with no errors or warnings (this covers literal ids on parameterised fragments, PRD edge case "inserted twice").
- **SC03** Every publishable package under `packages/` is listed in every release registry (workspace `pubspec.yaml`, `tool/version_lockstep.sh`, `tool/release.sh`, `tool/verify_release.sh`, `.github/workflows/publish.yml`), and `packages/trellis/pubspec.yaml` does not depend on `trellis_ui`.
- **SC04** Each `vendor/` source directory carries its licence, `THIRD_PARTY_NOTICES.md` names shadcn/ui (MIT), Tailwind CSS (MIT) and tw-animate-css (MIT), plus Lucide (ISC) and Feather (MIT) once any icon is vendored, and the shipped stylesheet keeps the Tailwind and shadcn banners.
- **SC05** No file under `packages/trellis_ui/test/` or `lib/` starts the Tailwind binary or Node; the compile step runs only through `dart run tool/port.dart`.


## Scope & Boundaries

### Work Areas
Paths in Work Areas, Verify lines and Constraints are relative to the trellis-public root, where the story executes.

- New package `packages/trellis_ui/`: `pubspec.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, `AGENTS.md`, `.pubignore`, `analysis_options.yaml`.
- Layout every component story uses: `assets/fragments/<component>.html` (template `trellis-ui/<component>`), `assets/css/hand/00-base.css` then `<component>.css`, `assets/css/htmx-indicator.css`, `assets/js/<NN>-<name>.js`, `gallery/pages/<component>.html`, `gallery/static/`, `vendor/`, `generated/`.
- Pipeline: `tool/pins.json`, `tool/parity-ignore.json`, `tool/port.dart`, `tool/embed.dart`, `tool/src/` (TSX scan, bundle, pipeline root).
- Gallery: `tool/gallery.dart` (Shelf server, exact strict policy, `/`, `/components/<name>`, `/trellis-ui/…`, `/static/…`).
- Runtime: `lib/trellis_ui.dart` and `lib/src/` including the generated `embedded_assets.g.dart`.
- Tests: `packages/trellis_ui/test/`; the release fixture and a registry guard in root `test/release_distribution_contract_test.dart`.
- Registration sites: root `pubspec.yaml`, the three release scripts, `publish.yml`, root `README.md` and `llms.txt` package tables, `AGENTS.md` package table, `dev/architecture/system-architecture.md`.

### What We're NOT Doing
- Qualification of the button, its gate record and its touch-target and contrast layers – story S05. The button here proves the pipeline only.
- Any behaviour component and the `00-base.js` helpers – story S04. The shipped script is the bundler's output over zero files plus whatever S04 adds.
- Sync commands (`diff`, sync report), the sync skill, the appearance check – stories S02 and S08.
- A framework adapter API inside `trellis_shelf`, `trellis_relic` or `trellis_dart_frog`, or a `bin/` materialize command – the first would make those packages depend on `trellis_ui` (or the reverse on three frameworks), the second is story S06's preview-assets command.
- Self-hosted htmx, strict-CSP scaffolds, `CspBuilder` strict preset – story S03. The gallery writes its policy as a literal.
- Updating `sdk-package-dag.svg`: its source diagram lives in the private repo and is redrawn at release prep.


## Architecture Decision

**Approach**: Productionise the O6 spike as `packages/trellis_ui`: a Dart pipeline (vendored pinned inputs, TSX scan, Tailwind standalone compile of theme + utilities layers only, scoped resets) commits `generated/`; a bundler plus `tool/embed.dart` turn sources and generated CSS into base64 constants with sha256 digests; a framework-neutral runtime exposes a `TemplateLoader` for `trellis-ui/<component>`, a `respond(path, ifNoneMatch)` function returning status, headers and bytes (or null when the path is not the suite's), and synchronous materialization. Each framework mounts `respond` with a handler of about five lines, shown in the README and proven by one test per framework.
**Why this over the floor**: The floor is leaving the spike as scripts. FR1 needs a byte-for-byte gate and a checksum stop, FR2 an embedded lockstep package, FR4 isolation, none of which the spike has. Neutral `respond` plus glue is the floor for framework support: an adapter inside each integration package would make it depend on `trellis_ui`, and adapters inside `trellis_ui` would make it depend on Shelf, Relic and Dart Frog (ADR-012: depends toward core).
**Flow**: `vendor/` + `tool/pins.json` → `port.dart build` → `generated/` → `embed.dart` (bundles `generated/trellis.min.css` + `assets/css/hand/*.css` into `trellis-ui.css`, `assets/js/*.js` into `trellis-ui.js` as one IIFE, plus `htmx-indicator.css` and the fragments) → `lib/src/embedded_assets.g.dart` → loader, `respond`, `materialize` → gallery and app handlers.


## Constraints & Gotchas

- **Constraint**: The story runs on the 0.14 branch cut after 0.13 merges, since the button uses `tl:slot`, `tl:attrs` and `...rest`. `fetch` and the first compiler download need network; every test in `test/` runs offline and without the compiler.
- **Constraint (isolation, stops the story)**: TI02 comes before every later task. If the fixture of S05 cannot pass with resets scoped to suite elements, stop, leave the branch as is and report the finding for an owner decision. Do not relax S05, drop the fixture, ship page-wide resets or opt-in page resets.
- **Constraint (cascade layers)**: Every suite declaration (tokens, scoped resets, components, hand CSS) lives in a cascade layer, so unlayered app CSS wins whatever the link order (S06). Hand CSS in `assets/css/hand/` is wrapped in a layer by the bundler, not by each author.
- **Constraint (fragments)**: Suite fragments are invoked with `tl:replace`; a `...rest` spread on a fragment root is invisible under `tl:insert` (LEARNINGS). They carry no literal `id` and no asset URL, so the docs site's `/trellis/` prefix (story S07) cannot break them.
- **Constraint (generated files)**: Nothing in `generated/` or `*.g.dart` is edited by hand. The generated Dart must be stable under `dart format` and `dart analyze --fatal-infos`, both CI gates.
- **Constraint (package contents)**: `.pubignore` keeps `vendor/`, `tool/`, `gallery/`, `assets/` and `generated/` out of the published archive; `THIRD_PARTY_NOTICES.md` ships.
- **Constraint (version)**: The package version and its `trellis:` constraint equal the lockstep version in `packages/trellis/pubspec.yaml` at execution time; the release script rewrites them.
- **Decision**: the Tailwind standalone CLI stays at the spike's v4.3.3, pinned with per-platform sha256 for macOS arm64/x64 and Linux x64/arm64, downloaded on demand into a gitignored `.tools/`; Windows runs no pipeline – the PRD names no version or platform; a newer pin or Windows support changes `tool/pins.json` and the platform table only.
- **Decision**: the regeneration gate's Tailwind compile runs only as `dart run tool/port.dart check` on the maintainer's machine, while the Tailwind-free half (entry stylesheet, bundle, embedded Dart) is a fast-tier test – FR1 says tests never invoke Tailwind and ADR-012 has no CI sync gates; a CI step that downloads the pinned compiler would move the compile half into CI.
- **Decision**: custom properties are excluded from S05's computed-style comparison, and unlayered shadcn tokens on `:root` and `.dark` in an app are allowed to change them – FR4 says "unchanged computed styles" without defining the property set, and the tokens are the public surface; counting custom properties would forbid the theme block itself.
- **Decision**: `htmx-indicator.css` ships as a third embedded asset, hand-written from the rules the pinned htmx 2.0.10 injects (`grep htmx-indicator` in its source), outside the aggregate stylesheet so apps may link it alone – FR2 names it and S03 builds its own copy for non-UI scaffolds; S06 decides whether UI scaffolds link this one.
- **Decision**: "suite fragment name that does not exist" (FR2) is read as both cases of S08, the fragment name inside a known template (`FragmentNotFoundException`) and an unknown template (`TemplateNotFoundException`), since the engine already throws each – the loader adds no exception type; a single required type would need a loader-level wrapper.
- **Decision**: the browser contract tests live in `packages/trellis_ui/test/` and import `test/browser_reflow_probe.dart` by relative path, not in root `test/` – the root workspace package has no dependency on `shelf` or `trellis_ui`, and that file imports only `dart:*`; a root test would need those dependencies added there.
- **Decision**: only `button` is in `pins.json` `components`; S04 and S05 add their components there and run `fetch` – S01's proof is the button, and the generated CSS scopes to the listed components' hooks.


## Implementation Plan

### Implementation Tasks

- **TI01** `packages/trellis_ui` exists as a workspace member and a lockstep package: scaffolded like `packages/trellis_dev`, listed in every registry of SC03, in the release fixture of `release_distribution_contract_test.dart`, and in the README, `llms.txt`, `AGENTS.md` and architecture tables; `trellis` core does not depend on it.
  - Search case-insensitively for `trellis_relic` (hidden `.github/` included) and map every match to a task or an exclusion; `sdk-package-dag.svg` is the documented exclusion.
  - **Verify**: `test/release_distribution_contract_test.dart#every publishable package is listed in each release registry` – derives the package list from `packages/*/pubspec.yaml` without `publish_to: none`; and `test/release_distribution_contract_test.dart#release refuses without a trellis_ui changelog section` – the fixture's `omitChangelog: 'trellis_ui'` case names the package.
  - **SATISFIES**: S13, SC03

- **TI02** Preflight isolation is settled before anything else is built: the spike's `tool/port.dart` and `tsx_scan.dart` are ported into `tool/`, the button inputs and the pinned compiler are in place, the entry stylesheet imports Tailwind's theme and utilities layers without `preflight.css`, the resets suite elements need are scoped to suite elements in `assets/css/hand/00-base.css`, and tokens plus all suite CSS sit in cascade layers.
  - Reads the stylesheet through a minimal `tool/src/bundle.dart` (generated min CSS + hand CSS in file-name order, layered) that TI06 extends.
  - **Verify**: `packages/trellis_ui/test/isolation_test.dart#non-suite elements keep their computed styles with the suite stylesheet loaded` and `packages/trellis_ui/test/isolation_test.dart#a theme block wins in either link order` – the fixture covers the element list of S05 and both modes, using `BrowserProbe` and `StaticSiteServer`; mutation check: restore `preflight.css` and watch the first go red naming the property.
  - **SATISFIES**: S05, S06

- **TI03** The compiler pin and vendored inputs are verified before use: `tool/pins.json` carries the shadcn tag and commit (`shadcn@4.21.1`, the spike's last verified tag, which stories S04 and S05 keep, so story S08 has a real upstream sync to run), base, style, base colour, component list, tw-animate and Lucide versions, per-platform compiler digests, and the spike's `structuralSkip` map (per-hook generated rules skipped with a reason because they assume a runtime Trellis lacks, such as Base UI toast stacking; empty for the button, used by S04, revisited each sync); `port.dart fetch` vendors inputs with their licences (injectable HTTP client) and `build` downloads and verifies the compiler.
  - **Verify**: `packages/trellis_ui/test/pipeline_generate_test.dart#a compiler that does not match its pin stops the build before generating` – asserts digest text, an unpinned platform case, and an untouched `generated/`, with fixture compilers named neutrally (SC05's search must stay clean); and `packages/trellis_ui/test/sources_test.dart#every vendored input carries its licence and the pinned commit` – covers SC04, including the banner in the shipped stylesheet.
  - **SATISFIES**: S02, SC04

- **TI04** The pipeline's output is committed and gated: `port.dart build` writes `generated/entry.css`, `trellis.css`, `trellis.min.css` and `report.json` from the vendored inputs, and `port.dart check` regenerates them to a temp directory and fails on any byte difference, naming the file.
  - **Verify**: `packages/trellis_ui/test/pipeline_generate_test.dart#entry.css regenerates byte for byte from the vendored inputs` – the Tailwind-free half; and `cmd: dart run tool/port.dart check` from `packages/trellis_ui` – exit 0, then exit non-zero after editing one byte of `generated/trellis.css` (restore it).
  - **SATISFIES**: S01

- **TI05** Divergence from upstream is visible: `report.json` lists structural class literals with no `cn-` hook, and `port.dart parity` compares the fragments' `data-slot` values, hooks and `group/*`/`peer/*` markers with the vendored TSX, honouring `tool/parity-ignore.json` entries and failing on a blank reason or an uncovered gap.
  - Port `parity.dart` and its entry shape from the spike; ignore entries that match nothing are reported, not failed.
  - **Verify**: `packages/trellis_ui/test/pipeline_generate_test.dart#structural classes without a hook are reported` and `packages/trellis_ui/test/parity_test.dart#a missing slot fails unless an ignore entry with a reason covers it` – the latter also covers the blank-reason failure.
  - **SATISFIES**: S03, S04

- **TI06** Sources become one embedded set: `tool/embed.dart` bundles the stylesheet and one classic script (files in name order inside a single IIFE; any file containing `import`/`export` module syntax fails the bundle) and writes `lib/src/embedded_assets.g.dart` with base64 constants and sha256 digests for `trellis-ui.css`, `trellis-ui.js`, `htmx-indicator.css` and every fragment; `--check` fails on byte difference.
  - **Verify**: `packages/trellis_ui/test/embed_test.dart#embedded assets regenerate byte for byte from the sources and generated CSS` and `packages/trellis_ui/test/embed_test.dart#the bundle orders scripts by name and rejects module syntax` – the second runs on a fixture directory, since the shipped script has no behaviour files yet.
  - **SATISFIES**: S01, S09

- **TI07** The runtime serves and renders the embedded set: a `TemplateLoader` resolves `trellis-ui/<component>` (with or without `.html`) and throws `TemplateNotFoundException` otherwise; `respond` answers only paths under `/trellis-ui/` that exist, with content type, strong ETag and 304 on a matching `If-None-Match`; materialization writes missing or divergent files and throws with the path on failure.
  - Public names are the executor's; list them once in the README, since stories S06 and S07 import them.
  - **Verify**: `packages/trellis_ui/test/trellis_ui_test.dart#unknown suite names fail with the engine exceptions`, `#respond serves bytes, content type and ETag and answers 304`, `#respond ignores paths outside the suite`, `#materialize overwrites divergent files, creates the directory and names the path on failure`.
  - **SATISFIES**: S08, S09, S10

- **TI08** The button is the first suite fragment, in the layout later stories copy: `assets/fragments/button.html` defines `button(variant, size, ...attrs)` with an anonymous slot, `data-slot`, hook classes and `group/button` marker as in the upstream component, defaults `default`/`default`, and a natural-template fallback; `tool/pins.json` lists only `button`.
  - Pattern: the spike's `templates/components/field.html` for markup conventions, `ADR-014` for the primitives.
  - **Verify**: `packages/trellis_ui/test/button_test.dart#the button renders variants, sizes, slot content and pass-through attributes` and `packages/trellis_ui/test/button_test.dart#every offered variant and size has a generated rule` – the offered set is read from the upstream `cva` hooks in `report.json`, not typed into the test; and `packages/trellis_ui/test/sources_test.dart#strict-CSP-clean sources and clean fragments` – scans `assets/`, `gallery/` and runs `TemplateValidator` over every fragment.
  - **SATISFIES**: S07, SC01, SC02

- **TI09** The gallery serves one page per component under the strict policy: `tool/gallery.dart` starts a Shelf server (port argument, 0 for ephemeral), mounts `respond` at `/trellis-ui/`, serves `gallery/static/` (including a same-origin `csp-watch.js` that records `securitypolicyviolation` events), lists `gallery/pages/*.html` at `/` and renders each at `/components/<name>` through a shared page shell that loads self-hosted htmx 2.0.10 (`gallery/static/htmx.min.js` with its notice, SHA-384 equal to the CLI's `htmxSriHash`) after an `htmx-config` meta setting `allowEval: false` and `includeIndicatorStyles: false`, and links `/trellis-ui/htmx-indicator.css`; on start the server prints `Serving <base-url>` as its first stdout line, which story S02's `--serve` reads; it resolves `gallery/`, `assets/` and the embedded set from the package root, not the working directory, since stories S05 and S08 start it from the repo root as `dart run packages/trellis_ui/tool/gallery.dart --port 0`; the button page shows every variant and size, a disabled button and one with `hx-*` pass-through.
  - **Verify**: `packages/trellis_ui/test/gallery_test.dart#the index lists every page file and each page renders under the exact policy header` – builds the server over a temp pages directory with two pages; `#the shell loads self-hosted htmx with indicator styles off`; `#the first stdout line names the base URL`.
  - **SATISFIES**: S12

- **TI10** Each framework serves the suite: README shows the handler glue for Shelf, Relic and Dart Frog, and a test per framework mounts exactly that glue on the real framework.
  - Dart Frog follows `packages/trellis_dart_frog/test/test_utils.dart#withServer` (real server, loopback, port 0); Shelf and Relic call the handler in-process.
  - **Verify**: `packages/trellis_ui/test/serving_shelf_test.dart#serves the suite assets with validators`, `packages/trellis_ui/test/serving_relic_test.dart#serves the suite assets with validators`, `packages/trellis_ui/test/serving_dart_frog_test.dart#serves the suite assets with validators` – each asserts every clause of S09.
  - **SATISFIES**: S09

- **TI11** The gallery proves the strict-policy claim in Chrome: the button page loads with 0 violations and a styled button.
  - **Verify**: `packages/trellis_ui/test/gallery_browser_test.dart#the button page loads under the strict policy with no violations` – guarded with `requireChromeInCi`; asserts the violation list is empty, the computed background equals the resolved `--primary` and `box-sizing` is `border-box`; mutation check: add an inline `style` attribute to the page and watch it go red.
  - **SATISFIES**: S11

- **TI12** The package explains itself and the architecture docs match: `README.md` (install, engine and server wiring for the three frameworks, public names, materialization, how to add a component to the layout), `AGENTS.md` (commands, layout rule, the fragment constraints above, no hand edits to generated files), `CHANGELOG.md` `## 0.14.0` entry, `dev/architecture/system-architecture.md` package map (its "Current through" marker moves only if the whole document is verified in this story, per the project's architecture-doc rule), and ADR-012 Implementation Notes § Porting pipeline recording what replaced Tailwind's preflight and the compiler pin.
  - **Verify**: `cmd: git grep -n -e "tailwindcss-" -e "'node'" -- packages/trellis_ui/lib packages/trellis_ui/test; test $? -eq 1` – nothing in `lib/` or `test/` starts the compiler or Node; and `inspect: dev/architecture/system-architecture.md` – the package map shows `trellis_ui`; the marker at line 5 is unchanged unless the whole document was verified.
  - **SATISFIES**: SC05


## Final Validation Checklist

- Fast tier from `KEY_DEVELOPMENT_COMMANDS.md` is green, and the run shows the browser tests executed, not skipped.
- `dart run tool/port.dart check` and `dart run tool/embed.dart --check` from `packages/trellis_ui` exit 0 on the committed tree.
- `dart pub publish --dry-run` in `packages/trellis_ui` lists `lib/`, `README.md`, `CHANGELOG.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md` and none of `vendor/`, `tool/`, `gallery/`, `assets/`, `generated/` (read the file list; a dirty-tree warning is not a failure).
- Serve the gallery, capture `/components/button` at 390 and 1440 wide with `agent-browser` per `VISUAL-VALIDATION.md`, and read the PNGs: variants and sizes are distinct, nothing overflows, the shadcn vega look is recognisable.

## Discovered Requirements

- **Strict-engine pass-through classes.** **Description:** suite fragments must preserve host extension classes and
  render when the host omits `class` on a strict engine. **Rationale:** initial S01 markup read `attrs.class`, which
  throws for a missing map member under strict mode; ordinary rendering did not expose it. **Interpretation:** keep
  base/marker classes literal, let `tl:attrs` append caller classes, and use `tl:classappend` for computed modifiers;
  do not read an optional map member just to preserve a class. This applies to S04/S05 fragment authors.
  **Traced from:** TI08. **Date:** 2026-11-17.

## Implementation Observations

- TI08 pass-through tidy: the initial button overwrote the host's extension class when computing variant classes.
  `button_test.dart` first failed with `Expected: contains 'app-save'`; the fragment now retains that class alongside
  its managed hooks. Defaults use `tl:with` because fragment parameter declarations do not parse default values.
- TI09 visual-review repair: the Refresh example fetched a full shell into `main`. A Chrome regression test first
  failed with `Expected: <1>, Actual: <2>` main elements. `hx-select="main > *"` now swaps only the response's
  content, and the test exercises two consecutive refreshes with one header/main and no CSP violations.
- Visual validation: the independent review captured/read 14 light/dark, focus, hover and refresh images at
  390/768/1024/1440. The light destructive variant has axe contrast 4.0:1 (`#e7000b` on `#fde6e7`), below 4.5:1;
  Routing: Note for S05's explicitly assigned contrast layer and button qualification. Dark axe has 0 violations.
  S01 makes no support/qualification claim. Evidence: public `.agent_temp/s01/visual-review/report.md` and axe JSONs.
- Packaging: the manifest remains at SDK 0.13.0 by lockstep contract. The 0.14.0 changelog identifies that development
  base, so `dart pub publish --dry-run` reports only its allowed dirty-tree warning; its archive excludes source,
  tooling, gallery, generated CSS and compiler cache directories. The story does not publish.
- Baseline fast tier: package suites 3,407 passed, 1 Linux-only watch test skipped on macOS; root 216 passed,
  2 existing no-control cases marked skipped (bloom/verdant). All 24 initial trellis_ui tests, including Chrome,
  executed. The complete tier reruns after the visual-review repair; final results are recorded below.
- TI06 code-review repairs: the import-free gate now scans executable template interpolation, including nested
  templates; it previously hid `${import(...)}` as inert string text. The classic bundler separates source files
  with a semicolon, preventing ASI from joining adjacent expressions. Both regressions failed before the repair;
  `embed_test.dart` now exercises a real Chrome execution for statement boundaries.
- TI08 code-review repair: a strict-engine test first threw `Undefined member: "class"` when the caller had no
  extension class. The `tl:classappend` pattern above replaces the earlier `attrs.class` workaround and retains
  extension classes in strict and lenient engines. All generated Dart was regenerated through `tool/embed.dart`.
- Final verification after all review repairs: fast tier exit 0, 3,410 package tests passed with 1 existing Linux-only
  watch skip on macOS; root 216 passed with 2 existing no-control skips. trellis_ui: 27 passed, 0 failed/skipped;
  all 13 analyses clean, format checks unchanged. All 26 FIS/repair proof selectors had passed; the final tier
  reran the repaired selectors plus strict-engine/script-boundary regressions. Regeneration: 4 byte-identical files;
  embed byte check and parity (0 drift) pass. Final 390/1440 captures were recaptured/read after class repair.
Reviewed: independent quick code review fixed strict-engine class access, template-interpolation module detection and script boundaries; independent visual review fixed/rechecked Refresh shell nesting. No open S01 finding; destructive contrast is a Note for S05.
- Public commit: `aa3d58a`. Working tree clean. Committed-tree `dart pub publish --dry-run` exits 0 without
  warnings; regeneration again reports 4 byte-identical files and embed --check passes. The private plan/FIS
  execution-state/tail updates remain uncommitted because those files were foreign/untracked at admission.
