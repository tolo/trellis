# S03 – Strict-CSP Scaffolds and CSS/JS Dev Reload

**Plan**: dev/spec/0.14/plan.json
**Story-ID**: S03

## Feature Overview and Goal

**Intent**: A project from any app scaffold cannot be served under `script-src 'self'; style-src 'self'` today (jsDelivr
htmx, an inline CSRF script, htmx's injected indicator `<style>`, an injected inline reload script), so the strict
policy the Trellis UI suite is screened against is unusable by exactly the apps that would adopt the suite, and dev
mode ignores the CSS/JS an author edits most.

**Expected Outcomes**:

- [OC01] Every page of a project created from the Shelf, Relic or Dart Frog scaffold loads, and keeps working through
  its htmx interactions, with 0 CSP violations under the strict policy, with htmx served from the app's own origin.
- [OC02] An author who opts into CDN htmx gets a CSP that allows exactly that CDN origin and nothing wider.
- [OC03] App authors can ask the security-headers builders (Shelf's, which Dart Frog reuses, and Relic's) for a strict
  policy without writing the directives by hand.
- [OC04] In dev mode the Shelf and Dart Frog scaffolds reload the browser when the app's static CSS or JS changes, with
  the reload client a same-origin script so dev pages stay at 0 violations; Relic's missing browser reload is recorded
  as tech debt.

## Required Context

- `dev/spec/0.14/prd.md#fr6-strict-csp-scaffolds-and-ui-option` and `#fr9-dev-reload-for-cssjs` – the acceptance
  criteria this story implements (the `--ui` criteria are story S06's). `#edge-cases` (HTMX 4 row) and `#constraints`
  (unattended plan: every in-plan browser check is headless, committed test code runs without Node).
- `dev/adrs/ADR-011-htmx-version-policy.md#amendment-2026-10-04-scaffolds-self-host-htmx-cdn-opt-in` –
  self-hosted by default, opt-in CLI flag keeps the SRI-pinned CDN tag, `htmx_asset.dart` stays the single pin.
- `~/Repos/home/trellis/research/12-trellis-ui-csp-spike.md` § Mechanism – which style paths a strict policy blocks (`<style>`
  elements and `style=""` markup; CSSOM writes pass), the basis for the htmx indicator finding in TD-018.
- `dev/state/TECH-DEBT-BACKLOG.md` rows TD-017 and TD-018 – the two items this story closes.
- `dev/state/LEARNINGS.md#file-watching-dev-mode` – Linux watches one directory at a time; the
  loader already carries the traps.
- `packages/trellis_cli/lib/src/templates/htmx_asset.dart` – the pin (`htmxVersion`, `htmxSriHash`,
  `htmxScriptTag`).
- `packages/trellis_shelf/lib/src/security_headers_middleware.dart#CspBuilder` and its near-identical
  twin `packages/trellis_relic/lib/src/security_headers_middleware.dart#CspBuilder`.
- `packages/trellis_dev/lib/src/dev_middleware.dart#devMiddleware`,
  `live_reload_handler.dart#liveReloadHandler`, and `packages/trellis/lib/src/loaders/file_loader.dart#FileSystemLoader`
  (`changes`, recursive/Linux watching).
- `test/browser_reflow_probe.dart#BrowserProbe` – the repo's headless Chrome over raw DevTools; it
  has no CSP-violation capture.
- `dev/guidelines/TESTING-STRATEGY.md#before-merge-bar` and `KEY_DEVELOPMENT_COMMANDS.md` – the
  `full` tier is required for changes to CLI templates, server adapters and `trellis_dev`; item 5 (mutation-check new
  assertions) applies to the violation capture.

## Acceptance Scenarios

- **S01 [OC01] [runtime] Shelf scaffold loads cleanly under the strict policy**
  - **Given** a project generated from the default (`htmx`) template and booted
  - **When** headless Chrome loads `/` and `/about`
  - **Then** each response's `Content-Security-Policy` has no `'unsafe-inline'` in `script-src` or `style-src` and
    allows no origin but `'self'`, htmx is defined (loaded from the app's own origin), and the page raised 0
    `securitypolicyviolation` events.

- **S02 [OC01] [runtime] Relic scaffold loads cleanly under the strict policy**
  - **Given** a project generated from the `relic` template and booted
  - **When** headless Chrome loads `/` and `/about`
  - **Then** the same three outcomes as scenario S01.

- **S03 [OC01] [runtime] Dart Frog scaffold loads cleanly under the strict policy**
  - **Given** a project generated from the `dart_frog` template and booted
  - **When** headless Chrome loads `/` and `/about`
  - **Then** the same three outcomes as scenario S01.

- **S04 [OC01] [runtime] htmx interactions stay clean and keep working**
  - **Given** the index page of each scaffold, loaded in headless Chrome
  - **When** the counter increment button is clicked, then the About nav link, then browser back
  - **Then** the counter changes through a same-origin htmx request that the server accepts (in the Shelf and Dart
    Frog scaffolds this proves the CSRF header is still attached by the same-origin script, since a missing header is
    a 403), no `<style>` element exists in the document, and the whole sequence raised 0 violations.

- **S05 [OC01] The self-hosted htmx file is the pinned release**
  - **Given** a default project of each scaffold
  - **When** its htmx file is read from the generated project and the layout is parsed
  - **Then** the file's SHA-384 equals `htmxSriHash`, the layout loads it from a same-origin path and contains no
    `cdn.jsdelivr.net`, and it sets `includeIndicatorStyles` to false through a `htmx-config` meta before the htmx
    script.

- **S06 [OC02] CDN opt-in allows exactly the CDN origin**
  - **Given** a project generated with the CDN opt-in flag, for each of the three scaffolds
  - **When** the layout and server/middleware source are read
  - **Then** the layout carries the SRI-pinned CDN `<script>` (`htmxScriptTag`), no local htmx file is written, and the
    generated CSP's `script-src` is `'self'` plus the origin of `htmxCdnUrl` and nothing else, with no
    `'unsafe-inline'`.

- **S07 [OC02] The CDN flag is rejected where htmx is not scaffolded**
  - **Given** `trellis create demo --template blog --htmx-cdn` (and `--template theme`)
  - **When** the command runs
  - **Then** it exits with a usage error naming the `htmx`, `relic` and `dart_frog` templates, and creates nothing.

- **S08 [OC03] Strict preset in both builders, defaults untouched**
  - **Given** the Shelf and Relic `CspBuilder`
  - **When** the strict preset is built bare, with an extra `connect-src`, and with a CDN `script-src`
  - **Then** the output has no `'unsafe-inline'`, has `style-src 'self'`, carries the caller's extra directives, is
    identical across the two packages for identical arguments, and a plain `CspBuilder().build()` is byte-for-byte what
    it is today (`style-src 'self' 'unsafe-inline'`).

- **S09 [OC04] [runtime] Static CSS or JS edits reload Shelf scaffold browsers within 1 s**
  - **Given** a project booted in dev mode (`--dev`) with a client connected to the SSE reload endpoint
  - **When** a `.css` file, then a `.js` file under `static/` is rewritten
  - **Then** each write delivers an `event: reload` frame within 1 s.

- **S10 [OC04] [runtime] Static CSS or JS edits reload Dart Frog scaffold browsers within 1 s**
  - **Given** a Dart Frog project booted with `DEV=true` and a client connected to the SSE reload endpoint
  - **When** a `.css` file, then a `.js` file under `public/` is rewritten
  - **Then** each write delivers an `event: reload` frame within 1 s.

- **S11 [OC04] [runtime] Dev-mode pages stay at 0 violations and really reload**
  - **Given** the Shelf scaffold in dev mode, loaded in headless Chrome under the strict header
  - **When** the page is loaded and then `static/styles.css` is rewritten
  - **Then** the served HTML has no inline `<script>` body (the reload client is a `<script src>` to a same-origin
    path that answers with a JavaScript content type), the page navigated again after the write, and the load raised 0
    violations.

- **S12 [OC04] Negative paths: unrelated files and a missing static directory**
  - **Given** `devMiddleware` with a static directory
  - **When** a file that is neither `.css` nor `.js` changes there; and separately when the static directory does not
    exist
  - **Then** the first sends no reload frame; the second starts without error and still reloads on template changes.

- **S13 [OC04] Nested and late-created static directories are watched**
  - **Given** `devMiddleware` watching a static directory
  - **When** a `.js` file is written in a subdirectory that was created after the middleware started
  - **Then** a reload frame arrives (the Linux per-directory path, which CI's ubuntu `check` job exercises).

## Structural Criteria

- **SC01** No file any of the three generators writes (default and CDN variants) contains an inline `<script>` body, a
  `<style>` element, a `style=` attribute, an `on*=` handler attribute, or `'unsafe-inline'`.
- **SC02** The htmx version and hash are defined once (`htmx_asset.dart`); the embedded bytes are verified against that
  hash by a test, so a version bump that forgets the bytes fails.
- **SC03** The violation capture is proven to detect: under the strict header a fixture page with an inline script, an
  inline `style=""` and a `<style>` element yields a violation for each directive, so "0 violations" is a measurement.
- **SC04** TD-017 and TD-018 are in `Resolved` (TD-017 with the real class name, `CspBuilder` /
  `trellisSecurityHeaders`, not the nonexistent `SecurityHeadersMiddleware`), and an open entry records Relic's missing
  browser reload.
- **SC05** The user-facing docs name the strict preset, what breaks under it, the CDN flag, and the `trellis_dev`
  changes; no doc still says scaffolds load htmx from a CDN by default or allow `'unsafe-inline'`.

## Scope & Boundaries

### Work Areas

- `trellis_shelf` and `trellis_relic` security-headers builders (strict preset) – TI01.
- `trellis_cli`: shared assets in `templates/htmx_asset.dart` (+ embedded source), the three scaffold generators and
  templates, `create` command flag – TI02, TI05–TI08.
- `trellis_dev`: reload client delivery and static-directory watching – TI03, TI04.
- Test infrastructure: violation capture in `test/browser_reflow_probe.dart`, a shared e2e helper, three e2e files –
  TI09–TI12.
- Tech-debt backlog, docs, READMEs, site package pages, architecture doc, changelogs – TI13, TI14.

### What We're NOT Doing

- `trellis create --ui` and anything `trellis_ui` – story S06. Generators take only the new CDN option; S06 adds its
  own.
- Changing `CspBuilder()` defaults or adding nonce/hash support – the permissive default is deliberate (TD-017); the
  preset is opt-in.
- The example apps (`examples/*`, `todo_app` included) – not scaffolds; they keep their CDN tags and CSP, and the
  example-pin tests in `htmx_asset_test.dart` stay.
- Blog/theme templates, themes' anti-FOUC inline script (TD-023), HTMX 4 migration, `htmx.config.allowEval` – out of
  PRD scope.
- A browser reload for Relic – recorded as tech debt only (owner, 2026-10-20).
- The qualification harness (story S02): this story adds only the violation capture its own proof needs.
- A new runtime dependency (`package:watcher` considered and rejected, see Architecture Decision).

## Architecture Decision

**Approach**: The scaffolds run only in the strict mode. The generator writes htmx, the CSRF listener and the reload
client as same-origin files; asset text and pins live as constants in `htmx_asset.dart` beside the existing pin; the
CDN path is an opt-in generator option; `trellis_dev` serves the reload client from its own route and watches the
static directory with one `FileSystemLoader` per extension (`.css`, `.js`), merged into the existing reload stream.
**Why this over the floor**: Leaving the scaffolds as they are fails FR6's "0 violations" outright. Reusing
`FileSystemLoader` as the watch primitive (floor: extend what exists) carries the Linux per-directory watching and its
tests (LEARNINGS, TD-013) instead of a second implementation or a new `watcher` dependency.

## Constraints & Gotchas

- **Constraint**: `X-Content-Type-Options: nosniff` is on every response, so each script (htmx, CSRF, reload client)
  must be served with a JavaScript content type or Chrome refuses it – static handlers do this by extension; Relic's
  hand-written routes and the reload route need it set explicitly.
- **Constraint**: htmx reads `htmx-config` from the page at init, so the meta must precede the htmx script. The key is
  `includeIndicatorStyles` (HTMX 4 renamed it `includeIndicatorCSS`; the guide's HTMX 4 section says so). The indicator
  rules (`.htmx-indicator` opacity states) ship in each scaffold's own `styles.css` from one shared constant.
- **Constraint**: Dart Frog's `routes/_middleware.dart` may only run for paths that match a route, and `public/` is
  served outside it. Boot a Dart Frog scaffold and confirm `/_dev/reload` and the reload script path are answered
  (today's SSE route is untested there); if not, the scaffold gains explicit routes for them.
- **Constraint**: macOS-green says nothing about the Linux watch path (TESTING-STRATEGY, Gotchas). Reuse the loader's
  mechanism so CI's ubuntu `check` job is the proof; do not re-implement recursion.
- **Constraint**: A violation listener must exist before the page's scripts run (register it for new documents through
  the DevTools protocol), and only `securitypolicyviolation` events count: a 404 favicon is a console error, not a
  violation.
- **Constraint**: Story S02 (`s02-headless-qualification-harness.md`) also adds violation capture to
  `test/browser_reflow_probe.dart`, and the two stories can run in parallel. If S02's capture is already on the branch,
  TI09 reuses it and adds only the helper and positive control; otherwise keep the addition one self-contained, additive
  block. S02's capture is the one kept: if this story merges after S02, it deletes its own block and uses S02's (plan.json
  sharedDecisions).
- **Constraint**: Code, paths and `cmd:` Verify lines are relative to the `trellis-public` root. Package tests run from
  there with the test form; e2e files need Chrome (the shared guard
  `requireChromeInCi` makes a missing Chrome fail in CI) and run only in the `full` tier and CI's `e2e` job on `main`.
- **Decision**: the strict preset is spelled `CspBuilder.strict(...)` – the PRD requires a "strict preset" without naming the API; the owner's preferred spelling would change it.
- **Decision**: the CDN opt-in flag is `trellis create --htmx-cdn` – ADR-011 requires "an opt-in CLI flag" without naming it; another name changes only TI08 and the docs.
- **Decision**: the pinned htmx bytes are embedded in the CLI source (`htmx_source.dart`) rather than downloaded at `create` time – the AOT CLI cannot read package assets (ADR-012) and create-time download would need network; the owner preferring a download changes TI02 and the generators.
- **Decision**: static-directory watching reuses `FileSystemLoader` per extension instead of adding `package:watcher` – avoids a new dependency in a published package; a loader that cannot serve as a pure file watcher in practice switches TI04 to `package:watcher`.
- **Decision**: the middleware serves the client through the new `liveReloadClientScript()`, and `liveReloadScript()` keeps its inline output for existing manual setups – sdk-vision Design Principle 5 (backward compatible) rules out repurposing it.
- **Decision**: the "within 1 s" criterion is asserted as the SSE `reload` frame arriving within 1 s of the file write, not as full page reload time – the PRD words it as "send a reload"; S11 separately proves the page reloads.
- **Decision**: the violation capture is added to `test/browser_reflow_probe.dart` and the strict-CSP checks join the three existing e2e files (CI `e2e` job on `main`, plus the `full` tier) – avoids a second DevTools client and a second scaffold boot; S02 landing an equivalent capture first replaces TI09's addition.
- **Decision**: the indicator stylesheet is the rules appended to each scaffold's `styles.css`, not a separate file – the PRD asks for "same-origin indicator CSS"; a separate file is a one-line layout change.

## Implementation Plan

### Implementation Tasks

- **TI01** Shelf's and Relic's `CspBuilder` each offer a strict preset; Dart Frog gets it through its Shelf re-export;
  `CspBuilder()` output unchanged.
  - Spelling: a `CspBuilder.strict(...)` named constructor taking the same override parameters that make sense
    (script/connect/font sources, `custom`). The two twin files stay textually parallel.
  - **Verify**: `packages/trellis_shelf/test/security_headers_middleware_test.dart#CspBuilder.strict` and
    `packages/trellis_relic/test/security_headers_middleware_test.dart#CspBuilder.strict` – both assert the same
    expected strings (twin parity) and the unchanged default.
  - **SATISFIES**: S08

- **TI02** `htmx_asset.dart` holds everything the scaffolds share: the embedded pinned htmx source, the CSRF listener
  source, the indicator CSS, the `htmx-config` meta tag, and the CDN origin derived from `htmxCdnUrl`.
  - Obtain the bytes from `htmxCdnUrl` at the pinned version and keep them in a sibling source file
    (`templates/htmx_source.dart`, raw string; verified ASCII, no `'''`, 51,238 bytes for 2.0.10). Extend the file's
    bump instructions to say the bytes are regenerated too. `crypto` is added to `trellis_cli`'s `dev_dependencies`
    only (already resolved in the workspace).
  - **Verify**: `packages/trellis_cli/test/htmx_asset_test.dart#embedded htmx` – SHA-384 of the embedded bytes equals
    `htmxSriHash`; the CSRF source registers both the HTMX 2 and HTMX 4 event shapes (`htmx:configRequest`,
    `htmx:config:request`) as the current inline script does.
  - **SATISFIES**: S05, SC02

- **TI03** `devMiddleware` delivers the reload client as a same-origin script: it answers `scriptPath` (default
  `/_dev/reload.js`) with the client JavaScript and injects `<script src="…"></script>` before `</body>`, never an
  inline body.
  - A new `liveReloadClientScript({ssePath})` returns the bare client JavaScript the script path serves; the existing
    `liveReloadScript({ssePath})` keeps its output and is documented as incompatible with a strict policy (sdk-vision
    Design Principle 5: no breaking API change). Its existing tests stay; the injection tests change.
  - **Verify**: `packages/trellis_dev/test/dev_middleware_test.dart#reload client` – injected HTML contains the `src`
    tag and no inline script body; the script path answers 200 with a JavaScript content type and the client text;
    custom `ssePath`/`scriptPath` are honoured.
  - **SATISFIES**: S11

- **TI04** `devMiddleware` takes an optional static directory and sends the same reload event when a `.css` or `.js`
  file under it changes, recursively, including directories created later; a missing directory is skipped.
  - Pattern: `file_loader.dart#FileSystemLoader.changes` (one loader per extension, merged privately); keep
    `liveReloadHandler(loader)` source-compatible.
  - **Verify**: `packages/trellis_dev/test/dev_middleware_test.dart#static reload` – an SSE client receives a frame
    within 1 s of a `.css` write and of a `.js` write; none for a `.txt` write; a `.js` write in a subdirectory made
    after start reloads; a nonexistent directory starts cleanly and template changes still reload.
  - **SATISFIES**: S09, S12, S13

- **TI05** The Shelf scaffold is strict by default: layout loads `/js/htmx.min.js` and `/js/csrf.js` (both written under
  `static/js/`), sets the `htmx-config` meta, carries no inline script; `styles.css` includes the indicator rules;
  `server.dart` uses the strict preset (CDN origin added to `script-src` only under the opt-in), drops `ws:` from
  `connect-src`, and passes the static directory to `devMiddleware`.
  - The generator takes `htmxCdn` (default false); under it the layout keeps `htmxScriptTag` and no htmx file is
    written. Existing layout tests that pin the CDN tag move to the CDN variant.
  - **Verify**: `packages/trellis_cli/test/project_generator_test.dart#strict CSP scaffold` – S05 and S06 assertions for
    this scaffold, the SC01 sweep over every written file in both variants, and `unsafe-inline` absent from
    `server.dart`.
  - **SATISFIES**: S05, S06, SC01

- **TI06** The Relic scaffold is strict by default on the same terms (no CSRF script exists there): htmx written to
  `static/js/htmx.min.js` and served with a JavaScript content type, strict preset, indicator rules, `htmx-config`
  meta, `htmxCdn` option.
  - Relic has no static handler (relic 1.2.0): extend the existing per-file route pattern for `styles.css`.
  - **Verify**: `packages/trellis_cli/test/relic_project_generator_test.dart#strict CSP scaffold` – as TI05.
  - **SATISFIES**: S05, S06, SC01

- **TI07** The Dart Frog scaffold is strict by default: files under `public/js/`, strict preset, indicator rules,
  `htmx-config` meta, `htmxCdn` option, `public/` passed to `devMiddleware`; dev reload endpoints reachable per the
  Dart Frog gotcha above.
  - **Verify**: `packages/trellis_cli/test/dart_frog_project_generator_test.dart#strict CSP scaffold` – as TI05.
  - **SATISFIES**: S05, S06, SC01

- **TI08** `trellis create` accepts the CDN opt-in flag (name: `--htmx-cdn`) for the `htmx`, `relic` and `dart_frog`
  templates and passes it to the generators; with `blog` or `theme` it is a usage error naming those three templates.
  - **Verify**: `packages/trellis_cli/test/create_command_test.dart#htmx-cdn` – flag reaches each generator (CDN tag
    present, no local htmx file); rejection leaves no project directory.
  - **SATISFIES**: S06, S07

- **TI09** `BrowserProbe` can report the CSP violations (directive, blocked URI) raised since a navigation, with the
  listener installed before page scripts; a thin helper in `packages/trellis_cli/test/` lets the e2e files drive a
  page (load, click, wait for htmx settle) and read violations.
  - **Verify**: `test/csp_probe_test.dart#csp violation capture` – a fixture page served under the strict header with an
    inline script, a `style=""` attribute and a `<style>` element yields one violation per directive involved; a clean
    page yields none. Mutation-check once by serving the clean page's header without `style-src` and watching the
    positive control still fail on the right reason.
  - **SATISFIES**: SC03

- **TI10** The Shelf e2e proves S01, S04, S05, S09 and S11 against the booted scaffold (dev-mode server for S09/S11).
  - **Verify**: `packages/trellis_cli/test/generated_app_e2e_test.dart#strict CSP` and `#dev reload` – assertions as in
    those scenarios, S09's frame timing measured from the file write.
  - **SATISFIES**: S01, S04, S09, S11

- **TI11** The Relic e2e proves S02 and S04.
  - **Verify**: `packages/trellis_cli/test/relic_e2e_test.dart#strict CSP`
  - **SATISFIES**: S02, S04

- **TI12** The Dart Frog e2e proves S03, S04 and S10 (server booted with `DEV=true`).
  - **Verify**: `packages/trellis_cli/test/dart_frog_e2e_test.dart#strict CSP` and `#dev reload`
  - **SATISFIES**: S03, S04, S10

- **TI13** `dev/state/TECH-DEBT-BACKLOG.md`: TD-017 and TD-018 move to Resolved (TD-017 corrected to the real class
  name, resolution naming the strict preset and `--htmx-cdn`); a new open entry (next free TD id) records that Relic
  has no dev middleware, hence no browser reload, citing PRD FR9.
  - **Verify**: `cmd: ! git grep -n -F "SecurityHeadersMiddleware" -- dev/state/TECH-DEBT-BACKLOG.md` – the wrong class
    name is gone (the resolution text does not repeat it); `inspect: dev/state/TECH-DEBT-BACKLOG.md` – TD-017 and TD-018
    under Resolved, the Relic entry under Open Items.
  - **SATISFIES**: SC04

- **TI14** Docs and changelogs describe the shipped behaviour: `docs/guides/framework-integration.md` (security-headers
  table and a "what breaks under the strict preset" passage; section 5.5's HTMX 4 steps for a self-hosted file and the
  `includeIndicatorCSS` key), the shelf/relic/dart_frog/cli/dev READMEs and their `site/content/docs/packages/*.md`
  pages, `dev/architecture/system-architecture.md` (the HTMX scaffold sentence and the dev-reload diagram; leave the
  stale "Current through" marker unless the whole document is verified), the ADR-011 amendment's "Not covered" sentence
  (one dated line that the scaffolds now meet it), and a `## 0.14.0` section in the changelogs of `trellis_cli`,
  `trellis_dev`, `trellis_shelf`, `trellis_relic` and `trellis_dart_frog` (create the heading if absent; `trellis_dev`'s
  `liveReloadClientScript` under `### Added`).
  - **Verify**: `cmd: ! git grep -n -F "The jsdelivr URL pattern is unchanged" -- docs/guides/framework-integration.md` –
    the stale "scaffolded CSP allow-list still applies" step is gone; `cmd: git grep -n -F "CspBuilder.strict" -- docs/guides/framework-integration.md`
    and `cmd: git grep -n -F "htmx-cdn" -- docs/guides/framework-integration.md packages/trellis_cli/README.md site/content/docs/packages/trellis_cli.md`
    – the preset and the flag are documented.
  - **SATISFIES**: SC05

## Final Validation Checklist

- `full` tier from KEY_DEVELOPMENT_COMMANDS.md green (CLI templates, server adapters and `trellis_dev` all changed),
  with Chrome present so no browser assertion is skipped; `dart test test/csp_probe_test.dart` included.

## Discovered Requirements

- **Canonical user-doc destination.** **Description:** `docs/guides/framework-integration.md` moved to
  `site/content/docs/packages/framework-integration.md` in committed public documentation consolidation `8a598ed`. **Rationale:** the FIS predates
  the owner's 2026-11-17 documentation move. **Interpretation:** update the canonical destination and run the
  same documentation checks there; do not recreate `docs/` or mirror the page. Record old Verify paths as
  `spec-stale` drift when executing them against their relocated file. Current `dev/DECISIONS.md` explicitly
  keeps 0.14 execution in this private plan; the planning move applies from 0.15.
  **Traced from:** S02/TI12 integration. **Date:** 2026-11-17.

- **Canonical pre-script CSP capture.** **Description:** S02 landed `BrowserProbe.captureSecurityPolicyViolations()`,
  `securityPolicyViolations()`, `cspViolationPreload`, and `StaticSiteServer.serve(..., headers: ...)`.
  **Rationale:** S02 completed first on the shared branch. **Interpretation:** reuse these additive APIs under
  the plan's shared decision; do not add a second listener/block. Keep this story's strict-policy scaffold proofs.
  **Traced from:** S02/TI02. **Date:** 2026-11-17.

- **Flush SSE connection before edits.** **Description:** real HTTP clients wait indefinitely for SSE response headers until the first body bytes, even with Shelf buffering disabled. **Rationale:** TI10/TI12's first live SSE proofs timed out waiting for a connection before any file write. **Interpretation:** send an SSE comment on connection; it flushes headers without dispatching a reload and lets clients prove connection readiness before timing writes. Keep reload event payloads unchanged. **Traced from:** TI10, TI12. **Date:** 2026-11-17.

- **Native Enter activation carries text.** **Description:** Chrome CDP's keyDown Enter event needs `text: '\r'` to activate a native button; the existing shared gate driver omits it. **Rationale:** an actual-keyboard regression added for the counter-focus repair did not increment until the text field was supplied. Isolating fields retained focus/documentFocus but count stayed 0 without text, while text without code passed. **Interpretation:** S03's thin browser helper dispatches native Enter with carriage-return text and proves repeated activation; the integration caller routes the shared driver's equivalent repair before dependent keyboard qualification. **Traced from:** TI10/TI11/TI12 focus repair. **Date:** 2026-11-17.

- **Retained execution evidence.** **Description:** public evidence is retained under
  `.agent_temp/0.14-plan-run/evidence/S03/public-agent-temp/` in the public checkout; the exact private receipt
  is beside it under `private-receipt/`. **Rationale:** temporary paired worktrees are removed after integration.
  **Interpretation:** command paths in proof output are historical worktree paths; inspect the retained logs and
  captures, and the integrated public commits for source. The later simplification passed full fast and 23 E2Es;
  parent independently passed 77 generator and 15 dev-middleware tests before its integration.
  **Traced from:** S03/TI14 integration. **Date:** 2026-11-17.

## Implementation Observations

ASSUMPTION: SC01's markup sweep inspects every generated HTML artifact; the pinned vendor JavaScript's inert `<style>` string is allowed because the required htmx bytes contain it. Browser proofs enforce that no such style is inserted. A requirement to remove inert strings would require changing the pinned bytes and contradict S05/SC02.

#### DRIFT
- spec-stale: TI14 commands target the relocated canonical `site/content/docs/packages/framework-integration.md` | Stale targets: `docs/guides/framework-integration.md` | –
- spec-stale: TI06's Relic 1.2 wording predates the committed Relic 2.0 upgrade already in base 630ee53; preserve 2.0 and extend its existing per-file route | Stale targets: TI06 Relic version note | –
- spec-stale: TI09 reuses S02's canonical CSP capture and header-serving API, adding only its helper and positive control | Stale targets: Required Context probe paragraph | –


### Required accessibility audit tidy
The served Shelf/Relic/Dart Frog Home pages each reported `color-contrast` on `.counter-hint` (3.36:1) and `footer > p` (3.54:1). A browser regression assertion failed first with `Actual: ['color-contrast: .counter-hint, footer > p']`; all three stylesheet templates now use `#666` for those two text roles. This is the minimum fix to the required WCAG 2.2 AA gate, preserving layout and interaction.


### Chain Attestation

- OC01: TI02/TI05–TI07/TI09–TI12 close S01–S05 with pinned-byte checks and actual strict-policy Home/About loads, counter updates with explicit CSRF-header observation, SPA navigation/back, no style elements, and zero CSP events across all three scaffolds.
- OC02: TI05–TI08 close S06/S07 with default/CDN generator assertions for all three templates and command-level acceptance/rejection checks, including no directory after rejection.
- OC03: TI01 closes S08 with identical strict expected strings in both adapters, caller overrides, and byte-for-byte unchanged plain defaults.
- OC04: TI03/TI04/TI10/TI12 close S09–S13 with actual SSE frames within 1 s, a real browser reload after a CSS write, unrelated/missing/nested-directory cases, and same-origin JavaScript delivery; TI13 records Relic's missing reload as TD-058.
- Canonical-doc discovery: TI14 edits and checks `site/content/docs/packages/framework-integration.md`; no legacy docs tree was recreated.
- Canonical-capture discovery: TI09 uses S02's pre-script capture methods and StaticSiteServer header support, proven by a positive fixture with all three inline-blocking directives and a clean navigation resetting capture.

### Executed proofs

All task targets below ran from the assigned public root. Every task-specific browser assertion ran with Chrome present and zero skips.

```text
TI01-Shelf: dart test "packages/trellis_shelf/test/security_headers_middleware_test.dart" --plain-name "CspBuilder.strict" -> exit=0, 00:00 +2: All tests passed!
TI01-Relic: dart test "packages/trellis_relic/test/security_headers_middleware_test.dart" --plain-name "CspBuilder.strict" -> exit=0, 00:00 +2: All tests passed!
TI02: dart test "packages/trellis_cli/test/htmx_asset_test.dart" --plain-name "embedded htmx" -> exit=0, 00:00 +1: All tests passed!
TI03: dart test "packages/trellis_dev/test/dev_middleware_test.dart" --plain-name "reload client" -> exit=0, 00:00 +2: All tests passed!
TI04: dart test "packages/trellis_dev/test/dev_middleware_test.dart" --plain-name "static reload" -> exit=0, 00:01 +5: All tests passed!
TI05: dart test "packages/trellis_cli/test/project_generator_test.dart" --plain-name "strict CSP scaffold" -> exit=0, 00:00 +2: All tests passed!
TI06: dart test "packages/trellis_cli/test/relic_project_generator_test.dart" --plain-name "strict CSP scaffold" -> exit=0, 00:00 +2: All tests passed!
TI07: dart test "packages/trellis_cli/test/dart_frog_project_generator_test.dart" --plain-name "strict CSP scaffold" -> exit=0, 00:00 +2: All tests passed!
TI08: dart test "packages/trellis_cli/test/create_command_test.dart" --plain-name "htmx-cdn" -> exit=0, 00:00 +5: All tests passed!
TI09: dart test "test/csp_probe_test.dart" --plain-name "csp violation capture" -> exit=0, 00:00 +1: All tests passed!
TI10-strict: dart test "packages/trellis_cli/test/generated_app_e2e_test.dart" --plain-name "strict CSP" -> exit=0, 00:03 +1: All tests passed!
TI10-reload: dart test "packages/trellis_cli/test/generated_app_e2e_test.dart" --plain-name "dev reload" -> exit=0, 00:03 +2: All tests passed!
TI11: dart test "packages/trellis_cli/test/relic_e2e_test.dart" --plain-name "strict CSP" -> exit=0, 00:03 +1: All tests passed!
TI12-strict: dart test "packages/trellis_cli/test/dart_frog_e2e_test.dart" --plain-name "strict CSP" -> exit=0, 00:04 +1: All tests passed!
TI12-reload: dart test "packages/trellis_cli/test/dart_frog_e2e_test.dart" --plain-name "dev reload" -> exit=0, 00:03 +1: All tests passed!
TI13-name: ! git grep -n -F "SecurityHeadersMiddleware" -- dev/state/TECH-DEBT-BACKLOG.md -> exit=0, no stale matches
TI14-old-step: ! git grep -n -F "The jsdelivr URL pattern is unchanged" -- site/content/docs/packages/framework-integration.md -> exit=0, no stale matches
TI14-preset: git grep -n -F "CspBuilder.strict" -- site/content/docs/packages/framework-integration.md -> exit=0, 4 matching documentation lines
TI14-flag: git grep -n -F "htmx-cdn" -- site/content/docs/packages/framework-integration.md packages/trellis_cli/README.md site/content/docs/packages/trellis_cli.md -> exit=0, 6 matching documentation lines
TI13-inspect: TD-017 and TD-018 are after Resolved; TD-058 is under Open Items; wrong class name absent.
```

Fast tier: gallery check, all 13-package analyze/format checks, and all 9-package non-E2E suites exited 0. The core suite's one existing Linux-only unwatchable-directory case is skipped on macOS. The first root invocation passed 227 with 17 skips because GECKODRIVER was scoped only to the first shell command; that evidence is superseded by the corrected exported-environment root run: `dart test --exclude-tags=visual --exclude-tags=ui-gate -> exit=0, 03:24 +242 ~2: All tests passed!`. The two remaining root skips are Bloom/Verdant's existing no-progressive-enhancement-control cases. Root formatting checked 42 files with 0 changed.

Final checklist: `--no-full-tier` delegates the final full/release tiers to the integration caller. All three complete scaffold E2E files ran here: `00:05 +23: All tests passed!`, 0 failures/0 skips. The changed-surface focused run passed 175 with 0 failures/0 skips; after the contrast tidy the three generator files re-ran 77 with 0 failures/0 skips, and the full E2E files re-ran 23 with 0 failures/0 skips. `dart analyze --fatal-infos` reports `No issues found!`.

Mutation checks: nine changed-behavior mutations each exited 1 for the intended failure: relaxed strict styles, altered embedded htmx bytes, disabled CSS watcher, disabled JS watcher, enabled htmx indicator injection, removed style policy from the positive control, removed the CSRF event listener, wrong Relic JS MIME, and removed missing-directory guard. Restored implementations were rechecked green. Detailed logs are under the assigned public `.agent_temp/s03/` (not committed).

Tidies: removed stale file-count prose from the three generator methods; alphabetized Dart imports in the edited dev middleware; migrated old CDN/inline-script assertions to the new default while retaining explicit CDN pin tests; fixed the required-audit hint/footer contrast in all three stylesheet templates. No new Learnings entry meets its admission rule.

Independent code/gap review: fresh reviewer, 0 validated findings, no edits. Independently ran static reload 5, Shelf strict preset 2, CSP control 1; all passed without skips.


### Independent visual review

Routing: PASS, 0 P1/P2 findings. A fresh reviewer read 106 PNGs across Home, increment, About, Back, keyboard and end regions at 390/768/1024/1440. All 48 state/viewport combinations had no overflow, missing styles, overlap or clipped controls. All 12 WCAG 2.2 AA audits reported 0 violations and 0 incomplete checks. Report: assigned public `.agent_temp/s03/visual-review/visual-review.md`.

Routing: Note (P3), existing counter-swap focus refinement. Keyboard increment replaces the focused button and leaves focus on BODY; next Tab goes to the footer. Locations: `packages/trellis_cli/lib/src/templates/index_page_template.dart:31`, `templates/dart_frog/dart_frog_index_page_template.dart:30`, `templates/relic/relic_index_page_template.dart:29`. The unchanged index templates lack stable button IDs. This remains outside the dispatch's touched-file tidy scope; preserve focus on the equivalent control and verify repeated keyboard activation if addressed in a later scaffold change.

Discoveries for S06: preserve the new `htmxCdn` option and self-hosted script/config/indicator setup when adding the UI option. Static CSS/JS dev reload already watches the full static/public tree, including new subdirectories. Dev reload paths are reachable in Dart Frog without explicit routes (proved at runtime). No Relic dependency migration is needed; 2.0 is already in the base. TD-058 is the new Relic reload debt ID.


### Objective focus repair round

The original visual P3 note is now **fixed**, with explicit authorization to extend the tidy to the three unchanged index templates. Initial and replacement counter fragments carry stable `counter-increment`, `counter-decrement`, and `counter-reset` IDs. No app JavaScript or focus workaround was added. A native-keyboard regression failed first on each scaffold with `Expected: true`, `Actual: <false>`, `Counter swap preserves the keyboard control for repeated activation`. It now asserts focus after each of two Enter activations and verifies both counter updates.

Reverification: all three complete E2E files -> exit=0, `00:05 +23: All tests passed!`, 0 failures/0 skips; generator/command/pin suite -> exit=0, `00:03 +117: All tests passed!`, 0 failures/0 skips; `dart analyze --fatal-infos` -> exit=0, `No issues found!`; touched format check -> exit=0, `Formatted 4 files (0 changed)`.

Repair visual validation: captured and read 18 viewport PNGs, three apps × 390/1440 × counts 0/1/2. Every image retains the visible blue outline around + after both keyboard swaps; card edges, controls and hint remain contained without overlap or horizontal overflow. Native activeElement stays `counter-increment`, `:focus-visible` is true in all 18 snapshots, and CSP events remain empty. Evidence: assigned public `.agent_temp/s03/focus-repair/records.json` and its PNGs. Independent code/gap and full visual reviews remain the original reviews; this small objective repair was recaptured and checked by the implementer per dispatch, without a second review slot.
