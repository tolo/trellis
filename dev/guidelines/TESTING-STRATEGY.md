# Testing Strategy

What each test level means in this repo, how fixtures are built, and what must be true before a change merges. Commands
live in [KEY_DEVELOPMENT_COMMANDS.md](KEY_DEVELOPMENT_COMMANDS.md) (fast tier, full tier, run one test) and are not
repeated here. CI is `.github/workflows/ci.yml`; its comments explain why each step is shaped as it is. Traps are
collected in [`dev/state/LEARNINGS.md`](../state/LEARNINGS.md) under "Testing" and "Themes & SSG"; known gaps in
[`dev/state/TECH-DEBT-BACKLOG.md`](../state/TECH-DEBT-BACKLOG.md).

Lines marked `ASSUMPTION:` record a decision that needed the repo owner and had no one to ask; each says what would
change it. Read them as proposals until the owner confirms or edits them.


---


## Levels

Level follows the trust boundary a test crosses: filesystem, a spawned process, a socket, a browser, `node`. Static
checks sit below all of them and run first.

| Level | Crosses | Where it lives | Runs |
|---|---|---|---|
| Static | nothing | `dart analyze --fatal-infos`, `dart format`, `tool/generate_theme_gallery.dart --check` | every push (`check` job) |
| Unit | nothing; templates come from `MapLoader`, no real IO | `packages/trellis/test` (51 files), `trellis_css`, parts of `trellis_site` | every push |
| Integration | one boundary: temp dir, in-process HTTP, one socket | adapters, `trellis_site` fixture builds, `trellis_dev`, CLI generator tests | every push |
| Contract (rendered) | `node` or headless Chrome over the DevTools protocol | root `test/`: theme, reflow, search-client, font suites | every push, except `visual` |
| E2E | generated project, `pub get`, spawned servers | `trellis_cli`, files tagged `e2e` (5 files) | `mise run check-full` in CI on `main` and manual dispatch |
| UI qualification | Chrome + Firefox, served component pages | `tool/ui_gate/`; tests tagged `ui-gate` | local release gate only |
| Visual baseline | Chrome plus the host's fonts | `test/visual_baseline_test.dart`, tag `visual` | release gate only |

Static call sites of `test(` per package, as a size indication only (loops generate more): trellis 1283, trellis_site
955, trellis_cli 325, root 166, trellis_shelf 79, trellis_relic 59, trellis_css 54, trellis_dart_frog 51, trellis_dev
36.

### Unit

The default for engine behaviour: parser normalisation, expression evaluation, processors, filters, inheritance,
strict mode. Collaborators are real; the only double is the template source, a `MapLoader` (31 test files) or
`testEngine(templates: {...})` from `package:trellis/testing.dart` (3 files). A test that needs
`FileSystemLoader` moves to integration and uses a temp directory (5 files).

### Integration

One real boundary at a time.

- **Server adapters** (`trellis_shelf`, `trellis_relic`): call the `Handler` in-process with a `Request`, no socket. The
  middleware pipeline is real, the network is not.
- **`trellis_dart_frog`**: a real `serve()` on `InternetAddress.loopbackIPv4` port 0 through
  `test/test_utils.dart` (`withServer`), because dart_frog's handler needs a live `RequestContext`. Its
  `dart_test.yaml` sets `concurrency: 1` so files do not share ports.
- **`trellis_site`**: builds the fixture sites under `packages/trellis_site/test/test_fixtures/` end to end (content,
  Sass through `trellis_css`, shortcodes, feeds, sitemap) and compares to goldens or asserts on the output tree.
- **`trellis_cli`**: generator and command tests run against a per-test `systemTemp` directory, passed to the command
  as `workingDirectory`. Nothing mutates `Directory.current` (TD-009).
- **Real dependency, not a fake, for behaviour that lives at the boundary**: Sass is compiled by the real
  `sass` package, HTML is parsed by the real `package:html`, file watching uses the real filesystem.

### Contract (rendered)

The root `test/` suite asserts invariants over shipped artifacts rather than over Dart units. These are the checks that
caught what green unit suites missed in 0.11 (a 205px dead hero, content pushed off the fold; see LEARNINGS, "A theme
contract test that reads manifests and compiled CSS is a wiring check, not a rendering check").

- `theme_contract_test.dart` is parameterised over `themes/*`, read from disk, so a new theme is covered without
  editing it. `<theme>_theme_contract_test.dart` files hold only what is particular to one theme.
- Layout claims are asserted on rendered geometry (`getBoundingClientRect`, `scrollWidth` against `clientWidth`) via
  `test/browser_reflow_probe.dart`, the repo's CDP client. A CSS substring check is a wiring check and does not count as
  proof of layout.
- `site_reflow_test.dart` holds the docs site to the same reflow contract. `search_client_browser_test.dart` exercises
  shared search in Chrome and Firefox. The older theme toggle harness still runs under system `node`.
- `release_distribution_contract_test.dart` and `docs_preview_script_test.dart` run the release and preview scripts
  against fixture repos with fake binaries first on `PATH`. `link_check_test.dart` covers `tool/link_check.dart` as unit
  and as subprocess.

### E2E

Few and expensive: five files in `packages/trellis_cli/test` tagged `e2e`. They scaffold a project, run `pub get` and
`dart analyze --fatal-infos` inside it, boot the generated server, and hit it over HTTP. `examples_smoke_test.dart`
boots the apps in `examples/`, which have no tests of their own. Servers come from `test/_e2e_server.dart`
(`bootServer`): OS-assigned port, loopback IPv4, retry on a fresh port, server output kept for the failure message.

### Visual baseline

`test/visual_baseline_test.dart` compares a digest of every rendered box and its computed styles per theme and skin to
`test/visual_baselines/<theme>.macos.json`. It is not pixels (reasoning in the header of `tool/visual_baseline.dart`).
Baselines are recorded on macOS; the comparator refuses a platform it has no recording for. CI excludes the `visual` tag
because Chrome and system-font drift on Linux runners moved layout for the themes whose font stacks end in a system
fallback (TD-035); `tool/release.sh` runs the whole root suite with `CI=true`, which is the only place this tier gates.
To change a baseline on purpose, set `UPDATE_VISUAL_BASELINES=1` (optionally `VISUAL_BASELINE_THEMES`) and
review the JSON diff like code; the test refuses to update when `CI=true`.


### UI qualification gate

`tool/ui_gate.dart` drives Chrome through the existing `BrowserProbe` and Firefox through raw WebDriver/BiDi.
No browser download, Node invocation or additional package is part of the harness. Use Firefox 157 and
[geckodriver 0.37.1](https://github.com/mozilla/geckodriver/releases/tag/v0.37.1): extract the macOS
`geckodriver-v0.37.1-macos-aarch64.tar.gz` (Apple Silicon) or `geckodriver-v0.37.1-macos.tar.gz` (Intel), put the
binary on `PATH`, or set `GECKODRIVER` to its absolute path. `FIREFOX_PATH` overrides Firefox discovery;
`CHROME_PATH`/`CHROME_BIN` override Chrome. The tested Mac app paths are discovered automatically. The gate owns
throwaway profiles and OS-assigned HTTP/BiDi ports. Tests may skip absent Firefox locally; the CLI records
`not-run` and exits nonzero instead. Final local verification requires both engines.

A complete fixture recipe is [`test/ui_gate_fixtures/pass.yaml`](../../test/ui_gate_fixtures/pass.yaml). Run it:

```sh
dart run tool/ui_gate.dart --serve 'dart run test/ui_gate_fixtures/server.dart' \
  --records .agent_temp/ui-gate/records --baselines .agent_temp/ui-gate/baselines \
  --record test/ui_gate_fixtures/pass.yaml
```

Use `--base <url>` for an existing server. `--serve` reads `Serving <base-url>` from the command's first stdout
line and stops that process after the run. With no component arguments, every YAML file in `--manifests` runs;
names resolve in that directory, and `.yaml` paths work directly. Defaults are `dev/ui-gate/manifests/`,
`dev/ui-gate/records/` and `dev/ui-gate/baselines/`. `--browsers chrome,firefox` is the default.

The YAML recipe is the component boundary:

- `name` defaults to the filename; `page` is a same-origin absolute path and `root` is its component selector.
- `states` maps names to steps, `elements` maps appearance aliases to selectors, and `keyboard` is a step list.
  Include every applicable interaction, disabled, invalid, checked and dark state. Missing keyboard, semantics
  or HTMX recipes produce `not-run`, rather than a vacuous pass.
- Steps are `focus`, `click`, `hover`, `type`, `press`, `wait` (milliseconds or a true JS expression), `state`,
  `eval`, `axe`, and `expect: {expression: <JS>, equals: <JSON value>}`. Each step has one key. Missing elements
  and failed expectations name the step. Browser execution bypasses page CSP without injecting inline handlers.
- `semantics` contains `{selector, attribute, equals}` or `{expression, equals}` assertions for every state.
  `provenance` lists `{file, license}` notices, relative to the manifest. Allowed licences are MIT, ISC,
  Apache-2.0, BSD-*-Clause and 0BSD. `axe.disable` maps a rule id to a required written reason.
- `htmx` declares `region`, `swap` steps and `navigate` steps; optional `transient` must be absent after history
  restore, and `probe: {steps, expression, equals}` verifies single-fire behavior. `instances` lists selectors
  whose live counts must survive 20 swaps. `distinct` lists selector groups whose visible boxes must not overlap.

The automated items are provenance, self-hosting, strict CSP (including a labelled enforcement control), semantic
markup, HTMX lifecycle, keyboard, WCAG 2.0/2.1/2.2 A/AA axe, forced colours, responsive widths 390/768/1440, zoom
widths 640/320, reduced motion, fine/coarse targets (24/44 px, 16 px input text under coarse), and appearance.
Every emulated condition is read back. An item passes when at least one requested browser passes and every
other requested browser passes or records unsupported emulation with a reason. An unavailable browser, missing
recipe or capture, two unsupported results, or an actual failure blocks qualification. Single-browser CLI runs
are diagnostic. The release and publication checks require records for both browsers.

Each `<component>.json` record has `component`, `automated` (`pass`/`fail`) and ordered `items`. Automated items
carry `status`, per-browser `status`/`evidence`, and an `unsupported` marker where applicable. Manual VoiceOver +
Safari, NVDA + Firefox, and Safari items begin as `release-prep`; existing human-entered values are preserved.
The reference generator requires all three manual passes for a support claim. Records have no timestamps,
ports or host paths and repeated runs are byte-identical.

Appearance uses `<component>.<os>.json` with both browser captures. `--record` is refused under `CI=true` and
still fails clipping, overflow or overlap; the first recording is a reference, not a waiver. The computed-style
fingerprint includes selected elements and forced-state outlines in the same settled frame as geometry. Explicit
forced-focus captures keep actual document/target focus confirmed throughout settling; hidden, disabled and
non-focusable elements are marked inapplicable for that state. Real keyboard and lifecycle checks stay unforced.
`--captures <dir>` also writes `<component>.<browser>.json` snapshots. Sync tools may use `captureAppearance` and
`compareAppearance` in one owned driver run for A/B comparisons; differences name the state, selector/property and
changed token. If emulation becomes unsupported partway through, the gate still compares completed states against
any existing browser baseline. It retains measured differences. Unreadable or malformed baseline evidence makes
an otherwise clean comparison unavailable.
The three spike regressions are replayed by `ui_gate_appearance_test.dart`; all are detected by
styles or box invariants, so no pixel-diff fallback is currently needed.

The local component sweep (`packages/trellis_ui/test/qualification_gate_test.dart`) runs all active manifests in
disjoint CLI chunks and compares freshly written records byte for byte, retaining manual results. The release
policy checks optional failures against their [ADR-012 dispositions](../adrs/ADR-012-trellis-ui-contract.md#optional-component-release-dispositions).
`packages/trellis_cli/test/ui_surfaces_gate_test.dart` launches the actual admin entry point and three generated
`--ui` scaffolds. The same CLI checks the admin list, filter, menu, validation, single-date and range calendars, alert dialog, Summary and toast,
and each scaffold's counter swap and UI dialog, using the seven recipes and records in `dev/ui-gate/apps/`.
The sweep seeds only manual results, checks each fresh record against the same release policy, then compares
its bytes to the committed record.

Release limits are 30,000 bytes for the sum of the three embedded responses gzipped separately at level 9,
700 authored JavaScript lines in the suite (excluding app-owned recipe glue), and 50 authored CSS lines in the admin example. Its exact script inventory is HTMX, the pinned Cally 0.9.2
bundle and the app's date recipe module. The footprint check pins the vendor bytes and checks templates for strict CSP. Run `test/release_gates_test.dart` and `test/budget_test.dart` from `packages/trellis_ui/`, and
`test/footprint_test.dart` from `examples/admin_app/`.

Harness fixture tests are untagged in branch CI and the full tier. A test running the full gate over real component
or app pages carries `ui-gate`; OS-baseline comparisons carry `visual`. Both are excluded from CI's check/E2E tiers and run in
the local `release-gate` tier, preserving ADR-012's local gate decision.


---


## Conventions and fixtures

- **Framework**: `package:test`, one `*_test.dart` per subject under each package's `test/`. Tags are declared per
  package in `dart_test.yaml` where they exist (only `trellis_cli` declares `e2e`) and in a file-level
  `@Tags` (`e2e` in five `trellis_cli` files, `visual` in `test/visual_baseline_test.dart`).
- **Template tests**: use `package:trellis/testing.dart` (`testEngine`, `hasElement`, `elementCount`, `hasAttribute`,
  `expectSnapshot`, fragment helpers). It is a public API shipped to users, so using it here is also the test of it
  (`packages/trellis/test/testing/`).
- **Goldens**: `compareOrCreateGolden` and `expectSnapshot` rewrite the file under
  `TRELLIS_UPDATE_GOLDENS=true`. A golden that does not exist is created locally and the test passes, but fails under
  `CI=true`, so a deleted or uncommitted golden turns CI red; review golden deletions as carefully as edits. Update one file at a time and read the diff.
  Goldens must not depend on the capturing machine: no file mtimes (`packages/trellis_site/test/fixture_mtimes.dart`
  pins them to noon UTC) and no local time zone (fixture dates carry an explicit zone).
- **Filesystem**: tests that write use a fresh `Directory.systemTemp.createTempSync` (about 70 files) and delete it in
  `tearDown`. Tests that build a theme example or `site/` build in a temp copy, never in the tracked tree. A sweep over
  tracked files reads only the extensions it is about, skips dot-entries, and does not follow links (`sweepFiles` in
  `packages/trellis_site/test/theme_sass_sources.dart`, `sassSources` in `test/theme_use_support.dart`).
- **Servers and ports**: bind a concrete `InternetAddress.loopbackIPv4`, never the name `localhost`, and never a fixed
  port. Buffer the server's stdout and stderr into the failure message.
- **Doubles**: allowed at system edges only. The in-repo precedents are a `noSuchMethod` `Stdout` fake injected through
  `IOOverrides.runZoned`, fake binaries on `PATH` for shell-script tests, and `MapLoader` for templates. Our own
  processors, filters and middleware run real. A fake of the real dependency's failure modes (missing directory, parse
  error, port in use) is part of the double, not optional.
- **Environment-gated checks**: a check that needs Chrome or `node` may skip locally, and must call the shared guard
  (`requireChromeInCi`, `requireNodeInCi` or the file-local `_requireNodeInCi`) so the skip becomes a failure when
  `CI=true`. CI installs Node 22 and asserts `google-chrome --version` for this reason. Do not add a skip path without
  the guard.
- **Assertions on CSS and strings**: derive the expected value from the other side of the contract (the script that
  emits a class, the font's own `fvar` axes) and anchor substring matches so a longer token cannot satisfy them. Assert
  presence and absence in the same artifact the assertion reads, and in the form that artifact has (the SSG minifies
  shipped CSS; `TrellisCss.compileSass` output is expanded).


---


## Before-merge bar

1. **Branch CI green** (Key Dev Commands, `branch CI`). It is the `check` job, so a green local run predicts the
   feature-branch CI result. That includes `dart analyze --fatal-infos`, the format check, the gallery check, every
   package suite without `e2e` and `ui-gate`, and the root suite without `visual` and `ui-gate`.
2. **Full tier green when the change can reach an E2E journey.** Feature branches get only `check` in CI; `e2e` runs on
   `main`, so a red E2E would first appear after the squash. Run the `full` tier before merging a change to
   `trellis_cli` templates or generators, server adapters, `trellis_dev`, or anything an example app imports.
3. **Bug fix: a test that fails first.** Write the test, watch it fail with the reported symptom, then fix. The test
   stays as the regression guard. For platform-specific bugs a test on the wrong platform proves nothing (the Linux
   `Directory.watch` gap passes on macOS); show the red on the platform that has the bug or force the code path.
4. **New behaviour: a test at the lowest level that crosses its boundary.** Engine behaviour is a unit test; output
   that a browser lays out is a contract test with a geometry assertion, since a CSS-text assertion stayed green
   through the 0.11 defects.
5. **New or changed contract assertions are mutation-checked once.** Break the thing the assertion protects (revert the
   fix, rename the class, zero the file) and watch it go red, then confirm the mutation actually produced the defect
   before concluding anything. One mutation is not enough for a check with several failure modes; list the ways it can
   break and see that the assertion separates them (LEARNINGS, "One passing mutation does not prove a test
   discriminates"). The repo has no mutation tool; this is done by hand, scoped to the changed files.
6. **Theme CSS or layout changes**: the contract and reflow suites pass, and if the rendered digest moves, the
   `test/visual_baselines/*.macos.json` diff is regenerated on the baseline host and reviewed in the same branch. Theme
   CSS is an input to those baselines.
7. **Release**: `tool/release.sh` runs `dart test` over the root with `CI=true` (including `visual`) on the maintainer's
   macOS host. A release is cut only from a host that has a recording for its platform. See
   [RELEASE-RUNBOOK.md](RELEASE-RUNBOOK.md).
8. **No weakened tests.** A test is not deleted, skipped or loosened to turn a run green. Remove a test only
   together with the surface it covers. A wrong test is rewritten.
9. **Flaky tests are reported, not skipped.** Reproduce first (the trigger is usually shared ports, paths, CWD or time
   zone; run two copies concurrently, or the suite under another `TZ`), then fix the cause. Quarantine needs the
   maintainer's decision and a TD entry.

ASSUMPTION: test-first is required for bug fixes (item 3) and encouraged, not enforced, for new behaviour –
evidence is that no workflow or script in the repo checks for a red-first commit, while LEARNINGS records fixes proven
by a reproducing test (the E2E port collision, made deterministic with two concurrent runs); would change if the owner
wants TDD required for new features.

ASSUMPTION: no coverage gate, on changed lines or overall – CI collects no coverage today and the layout bugs that
escaped were covered lines asserting the wrong thing; would change if the owner wants a changed-lines threshold.

ASSUMPTION: no mutation gate – the repo runs no mutation tool and a full run over `themes/` and the engine would be
slow; item 5 stays a manual, per-change practice. Would change if a Dart mutation tool is adopted.

ASSUMPTION: flaky-test quarantine is approved by the maintainer (repo owner), recorded as a TD entry naming the test and
the suspected trigger, and lasts until the next release; would change if the owner wants another approver or a longer
or shorter window. An agent never quarantines on its own call.

The bar reflects the lockstep release of the publishable packages, the tag workflows' green CI requirement, and
the SDK stage and maintainer scale recorded in [Product](../PRODUCT.md#proportionality).


---


## Gotchas

Each is explained where it was found; this list says where to look.

- **`dart test` at the workspace root runs only root `test/`.** The package suites need `melos exec`. A hand-rolled root
  `dart test` passes while skipping every package suite (ci.yml header comment). KEY_DEVELOPMENT_COMMANDS.md
  `branch CI` and `full` already do both.
- **`dart test --tags=e2e` exits 79 in packages without that tag.** The CLI and admin example have E2E-tagged tests.
  Run that selection in those packages when adding E2E coverage to the local release gate.
- **A local run without Chrome or `node` reports a pass with those assertions unrun.** CI turns the skip into a failure;
  your machine does not. Check the output for skipped tests before calling a theme change verified.
- **Shared worktree red runs are not evidence.** A suite that imports a helper someone is mid-edit on goes red for no
  reason you changed. Re-run before reporting, and check `git status` for an untracked helper that tracked suites
  import.
- **Green in a fresh worktree is not green on a long-lived checkout.** Gitignored build leftovers under
  `themes/*/example/.trellis/` and `.DS_Store` files break naive recursive sweeps (LEARNINGS, "A file sweep that is
  green in a fresh worktree...").
- **Time zone and mtime leaks in goldens** are invisible on the capturing machine. Run `trellis_site` changes under
  `TZ=UTC` and one far-western zone before pushing (LEARNINGS, "Goldens must not bake...").
- **Concurrent agents collide on ports and on the browser.** Confirm a build-specific string from the port you are
  measuring before trusting a reading; `agent-browser close --all` is session-global.
- **Chrome `--dump-dom` ignores `--window-size`**; any viewport-dependent check goes through
  `Emulation.setDeviceMetricsOverride` in `browser_reflow_probe.dart`. A progressive-enhancement check disables script
  execution before navigating instead of waiting for the page's own script to settle.
- **A screenshot or digest compared across Chrome builds has a noise floor** of 4 to 24 percent of pixels. Render old
  and new source in one browser run and compare those two (LEARNINGS, "A screenshot diff needs an A/B control").
- **Linux-only gaps are invisible on macOS.** `Directory.watch(recursive: true)` is a no-op on Linux, so file-watching
  tests prove the Linux path only on Linux CI.
- **Self-derived checks prove consistency, not correctness.** `tool/subset_fonts.py --verify` (run by
  `font-provenance.yml`, deliberately outside the release-gating `ci.yml` because it needs the network) rebuilds from
  the same constants it checks.
