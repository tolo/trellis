# FIS: Admin example, UI scaffold option and preview assets

**Plan**: dev/spec/0.14/plan.json
**Story-ID**: S06

## Feature Overview and Goal

**Intent**: Prove that an author can go from `trellis_ui` to a working CRUD app and a working new project without writing component CSS or JS, under the strict policy and as one AOT binary, so the suite's adoption claims (PRD success metrics) rest on a running app and a scaffold, not on a component gallery.

**Expected Outcomes**:

- [OC01] A new records app in `examples/` implements the FR7 screens and interactions from suite fragments and tokens only, with at most 50 lines of its own CSS, no component JS and no provider class in its templates.
- [OC02] That app raises 0 CSP violations under the strict preset across its whole journey, restyles from a pasted shadcn theme block with no other edit, and, compiled and moved away from the repo, serves every suite asset.
- [OC03] `trellis create --ui` on the Shelf, Relic and Dart Frog scaffolds produces a project whose example page renders suite components under the strict policy after only the printed `dart pub get` and run commands; other templates refuse the flag, and scaffolds without it are unchanged.
- [OC04] Suite assets reach each UI scaffold's gitignored preview folder at dev start (Shelf, Dart Frog) and on demand (all three), and a template opened from disk shows suite styling and local behaviour.

## Required Context

- `dev/spec/0.14/prd.md#fr7-admin-example-app` – screens, interactions and limits the example must meet; binding.
- `dev/spec/0.14/prd.md#fr6-strict-csp-scaffolds-and-ui-option` and `#fr10-natural-template-preview-assets` – the `--ui` and preview criteria. `#success-metrics` rows for app CSS, provider classes, violations, steps from `trellis create`, AOT deployability; `#user-stories` US01, US03, US04, US08; `#open-questions` (the example page for `--ui` is settled here).
- `dev/spec/0.14/s01-porting-pipeline-and-trellis-ui-package.md` – package API (loader, framework-neutral `respond` and per-framework glue, `materialize`), README as the home of public names, fragment constraints. It leaves the `bin/` materialize command to this story.
- `dev/spec/0.14/s03-strict-csp-scaffolds-and-dev-reload.md` – `CspBuilder.strict(...)`, `--htmx-cdn`, embedded htmx, files-not-inline scripts, indicator rules in each scaffold's `styles.css`, the CSP-violation helper in `packages/trellis_cli/test/`, the e2e strict groups this story extends.
- `dev/spec/0.14/s04-behaviour-components.md` and `dev/spec/0.14/s05-css-only-components-layout-primitives-and-overrides.md` – the components consumed. Their fragment names, signatures and slots are final only as listed in `packages/trellis_ui/README.md`; read that table, never infer names from these FIS.
- `Linear LEA-19 (app-conventions intent)#constraints` – the preview contract: paired relative `href`/`src` and `tl:href`/`tl:src`, classic script only, placeholder markup under `tl:replace`.
- `dev/guidelines/TESTING-STRATEGY.md#before-merge-bar` and `KEY_DEVELOPMENT_COMMANDS.md` – changes to CLI templates and anything an example imports need the `full` tier; assertions are mutation-checked once.
- `dev/state/LEARNINGS.md` – "twice-inserted fragment ids", "Rebuilding onto the same origin/port serves you the cached script".

## Acceptance Scenarios

Admin example (`E` = `examples/admin_app`):

- **S01 [OC01] [runtime] The list filters, sorts and pages through server round trips**
  - **Given** the seeded contacts (23, page size 8) on the list page
  - **When** text is typed in the filter, a status is chosen, a sortable column header is activated, and page 2 is chosen
  - **Then** each action sends one HTMX request that replaces only the list region (no full navigation), the rows match the query, the sorted header carries `aria-sort`, pagination marks only the current page, and the URL carries `q`, `status`, `sort`, `dir` and `page`; a plain GET of that URL renders the same rows as the swap did; a filter matching nothing shows an empty-state message inside the list region; a page beyond the last, an unknown sort column and a bad status value fall back to the nearest valid value instead of failing.

- **S02 [OC01] [runtime] A contact is created and edited in a dialog, with validation errors in place**
  - **Given** the list page
  - **When** "New contact" is activated, the form is submitted empty, then with a malformed email, then with an email another contact has, then correctly; and the same dialog is opened from a row's menu for an existing contact and saved
  - **Then** the dialog opens modally with the fields pre-filled on edit; each failed submit leaves the dialog open (the same dialog, errors in place), each invalid control has `aria-invalid="true"` and an `aria-describedby` that resolves to its visible error text, and keyboard focus is on the first invalid control; a valid submit removes the dialog, the list shows the saved values, the summary counts change, and a result toast is announced in the live region.

- **S03 [OC01] [runtime] Delete asks for confirmation in an alert dialog**
  - **Given** a row's actions menu
  - **When** Delete is chosen with the keyboard, then Cancel is activated, then Delete is chosen again and confirmed; and separately the only row on the last page is deleted
  - **Then** the menu closes and an alert dialog naming the contact is modal with focus on Cancel; Cancel leaves the record; confirming removes it, announces a toast and updates the summary counts; deleting the last remaining row of the last page shows the previous page, never an empty page.

- **S04 [OC01] [runtime] The company combobox and the summary tab work from the server**
  - **Given** the edit dialog and the page's tab list (Contacts, Summary)
  - **When** "ac" is typed in the company combobox and an option is chosen; a company that is not in the list is typed and submitted; the Summary tab is activated before and after a save
  - **Then** one options request goes out and the chosen option fills the field; the unknown company is a field error of the same kind as S02's; the Summary tab lists the count per status, matching the data, and the same counts update after the save without a reload.

- **S05 [OC02] [runtime] The whole journey raises no CSP violation**
  - **Given** the example served in-process with its real middleware, loaded in headless Chrome
  - **When** S01 to S04 are walked in one session, including opening a row menu before the list is swapped, a browser Back after a filter, and a full reload
  - **Then** every document response carries a `Content-Security-Policy` with no `'unsafe-inline'` and no origin but `'self'`, the pages contain no inline `<script>`, `<style>` or `style` attribute, no `securitypolicyviolation` event fired during the session, and htmx came from the example's own origin.

- **S06 [OC02] [runtime] A pasted theme block restyles the app and nothing else changes**
  - **Given** the example served from a temp copy of its `templates/` and `static/`, once as is and once with a shadcn theme block (`:root` and `.dark` overriding at least `--primary` and `--radius`) appended to its app CSS file
  - **When** the list page loads in light and in dark mode
  - **Then** the primary button's computed background equals the pasted `--primary` and the card and input corner radii equal the pasted `--radius` in the second copy, and differ from them in the first.

- **S07 [OC02] [runtime] The compiled binary serves every suite asset away from the repo**
  - **Given** the example compiled with `dart compile exe`, deployed to a temp directory outside the repo as `bin/server` with its `templates/` and `static/` beside it, no `.dart_tool`, and run from there
  - **When** the list page, `/trellis-ui/trellis-ui.css`, `/trellis-ui/trellis-ui.js`, `/trellis-ui/htmx-indicator.css` and the vendored htmx file are requested, and a contact is created
  - **Then** every request answers 200 and the three suite assets' bytes hash to their embedded digests (S01's `ETag` values); the create succeeds.

- **S08 [OC01] Rejections leave the data alone**
  - **Given** the example's mutation routes
  - **When** an edit or delete names a contact that does not exist, and a POST arrives without a CSRF token
  - **Then** the unknown id answers 404 and renders no dialog, and the tokenless POST answers 403 and changes no record.

Scaffolds (`CLI` = `packages/trellis_cli`):

- **S09 [OC03] The flag is accepted by three templates, refused by the others, and costs the default nothing**
  - **Given** `trellis create demo --ui` for the `htmx` (default), `relic` and `dart_frog` templates, then with `--template blog` and `--template theme`, then each scaffold without `--ui`
  - **When** the commands run
  - **Then** the first three create a project whose `pubspec.yaml` depends on `trellis_ui` at the lockstep constraint (also with `--htmx-cdn`, whose CSP then allows exactly that CDN origin); blog and theme exit with a usage error naming the `htmx`, `relic` and `dart_frog` templates and create no directory; the scaffolds without `--ui` contain no file that mentions `trellis_ui`, and their existing generator and e2e tests pass unchanged.

- **S10 [OC03] [runtime] Each UI scaffold renders the example page under the strict policy with no manual step**
  - **Given** a project generated with `--ui` for each of the three scaffolds, workspace packages substituted for the lockstep constraints, then only `dart pub get` and the run command the CLI printed
  - **When** headless Chrome loads `/ui`, then `/`, and the page's dialog trigger is activated
  - **Then** `dart analyze --fatal-infos` is clean, `/ui` renders suite components (a styled button and badge, a field with its input, a dialog), the suite CSS and JS come from `/trellis-ui/` served by the app, the dialog opens modally, the existing counter page still works, and the session raised 0 `securitypolicyviolation` events with the strict header on every response.

- **S11 [OC04] [runtime] Dev start writes the preview folder and repairs it; Relic writes only on demand**
  - **Given** a `--ui` Shelf project and a Dart Frog project, each with a stale `trellis-ui.css` already in its preview folder (`static/trellis-ui/`, Dart Frog `public/trellis-ui/`), booted with `--dev` and `DEV=true`; and a Relic project booted
  - **When** the servers have started, and separately a Shelf project is booted without `--dev`
  - **Then** the two dev boots leave the folder holding the three suite assets with bytes equal to the embedded digests (the stale file rewritten); the Relic boot and the non-dev boot create no folder.

- **S12 [OC04] The on-demand command writes the same files in all three scaffolds and fails loudly**
  - **Given** a generated `--ui` project of each scaffold and a hand-edited `trellis-ui.js` in its preview folder
  - **When** `dart run trellis_ui:materialize` is run with the scaffold's preview folder as its argument (no argument means `static/trellis-ui`), and once with a target that cannot be created
  - **Then** the folder holds the three assets with embedded-digest bytes (the edited file rewritten), the exit code is 0; the failing target exits non-zero with a message that names that path.

- **S13 [OC04] [runtime] A template opened from disk is styled, and the served page does not use the preview paths**
  - **Given** each `--ui` scaffold after S12's command, its example page template opened over `file://` in headless Chrome; and the same page rendered by the running app
  - **When** the computed style of a `trellis-*` placeholder button is read, and a suite custom element is looked up in `customElements`
  - **Then** the button's background equals the resolved `--primary` rather than the UA default, the custom element is defined (the classic script ran from disk), and the served HTML links `/trellis-ui/trellis-ui.css` and `/trellis-ui/trellis-ui.js` once each with no relative `static/trellis-ui` or `public/trellis-ui` path.

## Structural Criteria

- **SC01** The admin example's templates contain no provider class or attribute and nothing the strict policy blocks: every class token begins `admin-` or `trellis-`, no `cn-` token, no `data-slot`, no inline `<script>`, `<style>`, `style=`, `on*=` or `hx-on` attribute (`hx-on` evaluates script). Proved by a scan of `templates/`.
- **SC02** The example's footprint holds the PRD limits: its own CSS under `static/` is at most 50 lines (non-blank, non-comment, same rule story S04 uses for JS), `static/` holds no authored JS, and the vendored `static/js/htmx.min.js` hashes to `htmxSriHash`, so the htmx pin stays in `htmx_asset.dart` alone.
- **SC03** Generated UI scaffold files carry nothing the strict policy blocks and no provider class: no inline script or style, no `cn-` or `data-slot`, and every class token in the example page is `trellis-*`; each UI scaffold's `.gitignore` lists its preview folder and no non-UI scaffold's does.

## Scope & Boundaries

### Work Areas
Paths are relative to the trellis-public root, where the story executes. `E` = `examples/admin_app`, `CLI` = `packages/trellis_cli`.

- New `E/`: `pubspec.yaml`, `dart_test.yaml` (declares tag `e2e`), `README.md`, `bin/server.dart`, `lib/` (store, query, validation, handler assembly), `templates/`, `static/app.css`, `static/js/htmx.min.js`, `test/`. Registration: root `pubspec.yaml` workspace list, `examples/README.md`, root `README.md` example lists.
- `packages/trellis_ui/bin/materialize.dart` and its README section, plus its CHANGELOG line.
- `CLI`: `create_command.dart` (`--ui`), the three generators and their templates (layout, nav, server or middleware, pubspec, gitignore, one shared example-page body), tests, README, `CHANGELOG.md`, `site/content/docs/packages/trellis_cli.md`.
- `dev/state/LEARNINGS.md` for traps found.

### What We're NOT Doing
- Converting `todo_app` or adding the admin example to `examples_smoke_test.dart`: `todo_app` stays the app-conventions baseline, and the example's own tests boot it.
- Authoring or changing suite components. A defect found while building is fixed in the component under its gate (see Constraints), never worked around in app code.
- A `trellis` CLI subcommand that writes preview assets: the AOT CLI cannot read package assets (ADR-012), and `trellis_cli` gains no `trellis_ui` dependency here (story S07 adds one for sites).
- Preview of suite fragments pulled in by `tl:insert`/`tl:replace` or of HTMX requests: browsers ignore them (FR10 scopes them out); only placeholder markup is styled.
- Browser reload for Relic (story S03 recorded the tech debt), and a materialized preview folder for the admin example (FR10 covers scaffolds).
- Accessibility audits of the example pages – story S08 runs the full gate over the admin example and the `--ui` scaffolds. Focus return after a save that swaps out the open dialog is story S04's dialog behaviour, which this story relies on.
- Releasing, version bumps and the changelog "supported" claim: release prep.

## Architecture Decision

**Approach**: The example is a small Shelf app built the way the Shelf scaffold is, with the suite wired through story S01's glue; its behaviour is server-driven HTMX over suite fragments, so it needs no JS of its own. The `--ui` flag is a generator option beside `htmxCdn`: each generator writes the same files plus a layout that links the suite, a nav entry, an `/ui` route, a pubspec dependency, a gitignore line, and (Shelf, Dart Frog) a dev-start `materialize` call. One shared function writes the example page body; generators differ in the layout path it extends and the relative preview prefix. The on-demand preview command is an executable in `trellis_ui`, run from the app's own dependency.
**Why this over the floor**: The floor is a docs page telling authors to wire `trellis_ui` by hand. The PRD's 0-manual-step metric, FR6 and FR10 rule it out. A `trellis` subcommand for previews is ruled out by ADR-012 (the AOT CLI cannot read package assets); one executable in `trellis_ui` avoids a second asset copy.
**Flow**: `GET /` (page) and `GET /contacts?q&status&sort&dir&page` (HTMX swap) share one query and one list fragment, chosen by `HX-Request`, and push the URL. `GET /contacts/new`, `/contacts/{id}/edit` and `/contacts/{id}/delete` return a dialog or alert dialog fragment rendered `open` into a host element in the layout. `POST /contacts`, `PUT` and `DELETE /contacts/{id}`: invalid input answers 200 with the dialog re-rendered with errors; valid input answers the refreshed list region plus, out of band, an emptied dialog host, the summary panel and a toast (bare-name rendering). `GET /companies?q=` returns the combobox options fragment.

## Constraints & Gotchas

- **Constraint (order and names)**: Executes on the 0.14 branch after stories S01, S03, S04 and S05 are merged. Every `trellis_ui` and S03 name (loader, `respond`, `materialize`, fragment names, `CspBuilder.strict`, test helpers) is read from the landed code and `packages/trellis_ui/README.md`. Where it differs from those FIS, follow the code and say so in the report.
- **Constraint (suite defects)**: The example consumes components that stories S04 and S05 qualified. A defect it exposes (for example a table header that cannot hold a sort control, or a dialog that ignores `autofocus`) is fixed in the component by the smallest change, the component's gate record re-run (never weakened, no manifest edit to turn it green), the README updated, and the change named in the report. The limits (50 CSS lines, 0 JS) are not raised, since a miss means the suite lacks something.
- **Constraint (htmx and status codes)**: htmx 2 swaps only 2xx responses by default, so a validation failure answers 200, not 422.
- **Constraint (focus on first error)**: with no app JS, focus moves by the `autofocus` attribute on the first invalid control of the re-rendered, server-opened dialog (native `showModal()` honours it). Story S04's dialog must not move focus afterwards.
- **Constraint (popups and swaps)**: Row menus sit inside the swapped list region. A menu that was opened carries a CSSOM `style` that htmx's settle step re-applies as an attribute and `style-src` reports; the suite strips it before the swap (story S04). The journey in S05 must open a menu before swapping or this stays invisible.
- **Constraint (CSRF without script)**: `trellisCsrf` accepts the token in the `X-CSRF-Token` header; the layout sets it for every HTMX request with `hx-headers` on `<body>`, from the context's `csrfToken`. No script and no per-form hidden input is needed.
- **Constraint (htmx in the example)**: Under `script-src 'self'` htmx cannot come from a CDN, so `static/js/htmx.min.js` is vendored and its hash checked against the single pin (SC02). The layout sets an `htmx-config` meta with `includeIndicatorStyles` false before the htmx script and links `/trellis-ui/htmx-indicator.css`.
- **Constraint (ids)**: Fragments that take an `id` get one derived from the contact id, so a list of rows never repeats a literal id. The layout's host elements are the app's own and may carry literal ids.
- **Constraint (serving order)**: `respond` is mounted before the static handler in every app, so the embedded bytes answer `/trellis-ui/…` even when a preview folder exists; the folder serves only `file://` previews.
- **Constraint (preview paths)**: Relative preview `href`/`src` are resolved from the template file's own directory (`../../static/trellis-ui/…` for Shelf `templates/layouts` and `templates/pages`, `../static/…` for Relic, `../../public/…` for Dart Frog). A child template's `<head>` is dropped by `tl:extends` (verified: only `tl:define` blocks reach the output), so the example page may carry its own preview-only `<link>` and `<script>` for `file://` without duplicating anything in the rendered page, while the layout carries the paired relative and `tl:href`/`tl:src` links.
- **Constraint (Dart Frog)**: `routes/_middleware.dart` runs only for paths a route matches and `public/` is served outside it. Serve the suite through a catch-all route (so the strict headers apply), confirm by booting, and follow story S01's README glue for the handler.
- **Constraint (shared files, parallel story S07)**: `packages/trellis_ui/README.md` and `CHANGELOG.md` also change in story S07. Add this story's lines as separate sections.
- **Constraint (tests)**: Servers bind `InternetAddress.loopbackIPv4` port 0. Chrome tests call `requireChromeInCi`, import `test/browser_reflow_probe.dart` by relative path, and reuse story S03's violation helper rather than adding a second capture. The scaffold e2e files extend story S03's strict groups and their dependency overrides gain `trellis_ui`.
- **Decision**: The example is `examples/admin_app`, package `trellis_admin_example`, a contacts list (name, email, company, status) seeded with 23 rows at page size 8 – the PRD says "such as contacts or inventory"; another domain or size changes data and fixtures only.
- **Decision**: "serves all assets" (FR7, metric AOT deployability) means the suite's assets come from the binary, and the app's own `templates/` and `static/` are deployed beside it in the `todo_app` layout (`<root>/bin/server`, `<root>/templates`, `<root>/static`) – embedding the app's templates too would need an embedding step this story does not build; the owner wanting it changes TI09 and adds that step.
- **Decision**: The example's vendored `htmx.min.js` does not count as "component JS" or as authored static JS – it is the pinned third-party library, checked by hash; counting its bytes would make the 0-line limit unreachable.
- **Decision**: A validation failure answers 200 with the dialog re-rendered – htmx 2's default swap rule; the owner preferring 422 changes the layout's `htmx-config` `responseHandling` and S02's status expectations only.
- **Decision**: Summary counts refresh through an out-of-band panel in each mutation response – the tabs panels are all in the page, so a stale count is the alternative; a Summary tab that fetches on activation would drop the out-of-band panel.
- **Decision**: The `--ui` example page is a route `/ui` ("Components" in the nav), the counter app stays, and the page shows a button in several variants, a badge, a field with its input, and a dialog with its trigger – the PRD leaves the page to the plan; covering one CSS-only and one behaviour component proves both the stylesheet and the script are served and run.
- **Decision**: UI scaffolds do not link the suite's `htmx-indicator.css`; story S03's rules in each scaffold's `styles.css` cover it, and `test/htmx_indicator_sources_test.dart` keeps the two sources equal.
- **Decision**: The on-demand command is `dart run trellis_ui:materialize [dir]` with `static/trellis-ui` as the default and the scaffold's own folder passed for Dart Frog – PRD FR10 names the folders, not the command; a different spelling changes `bin/`, the README and the printed next steps.
- **Decision**: The example's in-process and Chrome tests live in `E/test/` and run in the fast tier, and only the compile test carries `e2e` – the precedent for browser tests next to the package (story S01) and a slow compile kept out of every push; moving them under `CLI/test/` changes paths only.

## Implementation Plan

### Implementation Tasks

- **TI01** `dart run trellis_ui:materialize [dir]` writes the embedded assets into `dir` (default `static/trellis-ui`) through the package's materialization function, and exits non-zero with the error naming the path when it cannot; the README documents it beside the function.
  - `packages/trellis_ui/bin/materialize.dart` imports only the package's `lib/`; its pubspec dependencies do not change.
  - **Verify**: `packages/trellis_ui/test/materialize_command_test.dart#writes the three assets, rewrites divergent files and fails naming an unwritable path` – runs `dart run bin/materialize.dart <dir>` as a subprocess and compares bytes to the embedded digests.
  - **SATISFIES**: S12

- **TI02** `E` is a workspace member that serves strictly: registered in the root `pubspec.yaml`, `examples/README.md` and the root `README.md`; `bin/server.dart` is thin over a `lib/` function that builds the handler from a root directory; the layout and middleware follow the Architecture Decision and Constraints (strict preset, engine over app loader plus suite loader, CSRF, `respond` before static, self-hosted htmx with config meta, indicator CSS, suite CSS and JS then `app.css`, `hx-headers` CSRF, toast viewport and dialog host); 23 contacts are seeded.
  - Pattern: `packages/trellis_cli/lib/src/templates/server_template.dart#serverTemplate`, the README glue of story S01, `CspBuilder.strict` from story S03.
  - **Verify**: `examples/admin_app/test/contacts_http_test.dart#responses carry the strict policy and the page links the suite, htmx and indicator assets` and `test/htmx_indicator_sources_test.dart#the scaffolds' indicator rules equal the suite's htmx-indicator.css` – policy has no `'unsafe-inline'` and only `'self'` origins on page and fragment responses; the three suite paths and the htmx file answer 200 with script and style content types.
  - **SATISFIES**: S05

- **TI03** The list screen exists: tabs (Contacts, Summary), a filter input and status select, a table with sortable headers and a row-actions dropdown, pagination, an empty state, and the query rules of S01 (bad values fall back); full page and swap share one query and one list fragment.
  - A header cell that cannot hold a sort control is a suite defect (Constraints).
  - **Verify**: `examples/admin_app/test/contacts_http_test.dart#the list filters, sorts and pages, falls back on bad parameters and renders the same rows for a page load and a swap` and `examples/admin_app/test/admin_browser_test.dart#filter, sort and paging swap only the list region` – the second counts requests, checks `aria-sort`, `aria-current` and the pushed URL.
  - **SATISFIES**: S01

- **TI04** Create and edit work in a dialog: the form (field, input, native select, company combobox with its options route) renders open into the host, validates name, email format, unique email and a company from the list, re-renders in place with linked errors and focus on the first invalid control, and on success answers the mutation response set of the Flow (list, emptied host, summary, toast); the Summary panel shows counts per status.
  - **Verify**: `examples/admin_app/test/contacts_http_test.dart#validation re-renders the dialog with linked errors and a valid save answers the full response set`, `examples/admin_app/test/admin_browser_test.dart#create and edit in a dialog with validation errors, focus and toast` and `#company combobox and summary tab` – the browser tests assert every clause of S02 and S04, with the focus and `aria-describedby` reads done on the live DOM.
  - **SATISFIES**: S02, S04

- **TI05** Delete confirms in an alert dialog opened from the row menu, answers the same response set, and the list never lands on an empty page; unknown ids answer 404 without a dialog, and a tokenless mutation is refused.
  - **Verify**: `examples/admin_app/test/admin_browser_test.dart#delete asks for confirmation and never leaves an empty page` and `examples/admin_app/test/contacts_http_test.dart#unknown ids answer 404 and a tokenless mutation answers 403 and changes nothing`.
  - **SATISFIES**: S03, S08

- **TI06** The whole journey is proven clean under the strict policy in Chrome.
  - **Verify**: `examples/admin_app/test/admin_browser_test.dart#the whole journey raises no CSP violation` – one session over S01 to S04 with a row menu opened before a list swap, Back after a filter and a reload; asserts the empty violation list and the page scans of S05; mutation check: add an inline `style` attribute to one template and watch it go red.
  - **SATISFIES**: S05

- **TI07** A pasted theme block restyles the example.
  - **Verify**: `examples/admin_app/test/admin_browser_test.dart#a pasted theme block restyles the app` – boots the handler over a temp copy of `templates/` and `static/`, appends the block to the copy's app CSS, reads the computed primary background and radii in light and dark against an unmodified copy.
  - **SATISFIES**: S06

- **TI08** The example's footprint is guarded: provider-free and policy-clean templates, 50-line CSS, no authored JS, and the vendored htmx file pinned to `htmxSriHash`.
  - **Verify**: `examples/admin_app/test/footprint_test.dart#templates are provider-free and strict-clean` and `#app CSS stays within 50 lines and no authored JS exists`; `packages/trellis_cli/test/htmx_asset_test.dart#admin example htmx matches the pin` – the hash comes from `htmx_asset.dart`; mutation check: append a Tailwind-style class to a template and 51 lines of CSS, and watch each go red naming the file.
  - **SATISFIES**: SC01, SC02

- **TI09** The compiled example serves from outside the repo.
  - **Verify**: `examples/admin_app/test/aot_test.dart#a compiled binary moved away from the repo serves every suite asset` – tagged `e2e`; compiles to a temp directory outside the repo, deploys `templates/` and `static/` beside it, runs from there, checks the digests and a create.
  - **SATISFIES**: S07

- **TI10** `trellis create --ui` and the generator option exist: a flag valid with `htmx`, `relic` and `dart_frog`, refused for the others with a usage error naming the three (before any directory is made); each generator takes `ui` beside `htmxCdn`; one shared function writes the example page body; the Next steps text names `/ui` and the preview command.
  - **Verify**: `packages/trellis_cli/test/create_command_test.dart#--ui` – accepted, refused for blog and theme with no directory left, composes with `--htmx-cdn`; `packages/trellis_cli/test/ui_scaffold_test.dart#default scaffolds mention no trellis_ui` – every file of the three generators run with and without `ui`; `packages/trellis_cli/test/scaffold_pubspec_constraints_test.dart` extended with the three `ui: true` variants.
  - **SATISFIES**: S09

- **TI11** The Shelf UI scaffold is complete: pubspec dependency, layout linking the suite with paired preview paths, nav entry, `/ui` route and handler, `respond` mounted before static, dev-start `materialize` into `static/trellis-ui`, gitignore line.
  - **Verify**: `packages/trellis_cli/test/ui_scaffold_test.dart#shelf ui scaffold files are strict-clean, provider-free and gitignore the preview folder` (SC03); `packages/trellis_cli/test/generated_app_e2e_test.dart#ui scaffold` covering S10, S11 (dev boot, stale file, non-dev boot), S12 (Shelf folder and unwritable target) and S13 for this scaffold.
  - **SATISFIES**: S10, S11, S12, S13, SC03

- **TI12** The Relic UI scaffold is complete on the same terms, with no dev-start write (Relic has no dev middleware): the suite and `/ui` reached by per-route handlers like its `styles.css`, preview folder `static/trellis-ui/`, written only by the command.
  - **Verify**: `packages/trellis_cli/test/ui_scaffold_test.dart#relic ui scaffold files are strict-clean, provider-free and gitignore the preview folder`; `packages/trellis_cli/test/relic_e2e_test.dart#ui scaffold` covering S10, S11 (no folder after boot), S12 and S13 for this scaffold.
  - **SATISFIES**: S10, S11, S12, S13, SC03

- **TI13** The Dart Frog UI scaffold is complete: pubspec dependency, layout, nav, `routes/ui.dart`, the catch-all suite route, dev-start `materialize` into `public/trellis-ui`, gitignore line.
  - **Verify**: `packages/trellis_cli/test/ui_scaffold_test.dart#dart frog ui scaffold files are strict-clean, provider-free and gitignore the preview folder`; `packages/trellis_cli/test/dart_frog_e2e_test.dart#ui scaffold` covering S10, S11 (`DEV=true` boot and stale file), S12 and S13 for this scaffold.
  - **SATISFIES**: S10, S11, S12, S13, SC03

- **TI14** The docs match: `E/README.md` (run, screens, what it proves), `examples/README.md` and root `README.md` lists, `CLI/README.md` and the site CLI page (`--ui`, `--htmx-cdn` together, `dart run trellis_ui:materialize`), `trellis_cli` and `trellis_ui` `## 0.14.0` changelog sections (created if absent), and `dev/state/LEARNINGS.md` with only the traps found that a frontier model would not already know.
  - **Verify**: `cmd: git grep -n -F "trellis_ui:materialize" -- packages/trellis_cli/README.md site/content/docs/packages/trellis_cli.md packages/trellis_ui/README.md` – the command is documented in all three; `cmd: git grep -n -F "admin_app" -- examples/README.md README.md pubspec.yaml` – the example is registered; `cmd: dart format --output=none --set-exit-if-changed examples/admin_app packages/trellis_cli packages/trellis_ui && dart analyze --fatal-infos examples/admin_app packages/trellis_cli packages/trellis_ui` – clean.
  - **SATISFIES**: S09, S12

## Final Validation Checklist

- The `full` tier from `KEY_DEVELOPMENT_COMMANDS.md` is green (CLI templates, generators and an example changed), with Chrome present and the output showing the example's browser tests, the AOT test and the three UI scaffold e2e tests executed, not skipped.
- Serve `examples/admin_app` and capture, with `agent-browser` per `VISUAL-VALIDATION.md`, the list at 390 and 1440 wide, the Summary tab, the edit dialog with errors, the alert dialog and a toast; serve a generated `--ui` project's `/ui` the same way. Read every PNG: the vega look is recognisable, nothing overflows or overlaps, and the table scrolls inside its wrapper at 390.

## Discovered Requirements

- **S01 delivery names and layout.** **Description:** use `TrellisUiLoader`, `trellisUiRespond` and
  `materializeTrellisUi(Directory)` from `package:trellis_ui/trellis_ui.dart`; component sources are under
  `assets/fragments/`, `assets/css/hand/`, `assets/js/`, with `gallery/pages/` examples. **Rationale:** S01 owned
  choosing these names. **Interpretation:** follow `packages/trellis_ui/README.md` engine/framework glue and extend
  the existing layout; do not add another serving or bundling API. **Traced from:** S01/TI07, TI12.
  **Date:** 2026-11-17.

- **Preserve landed scaffold policy and reload.** **Description:** S03 generators take `htmxCdn` (default false),
  self-host HTMX and CSRF assets, disable eval/indicator styles via meta config, and use `CspBuilder.strict`.
  Shelf/Frog call `devMiddleware(..., staticDirectory: staticDir)` (`public` for Frog); its external client is
  `/_dev/reload.js` and static CSS/JS watches cover late directories. **Rationale:** S03 landed before the UI flag.
  **Interpretation:** compose `--ui` with these existing options/assets and preserve strict default/CDN opt-in.
  Materialize preview assets before serving; do not restore inline scripts or add duplicate reload routes.
  Counter IDs now preserve keyboard focus after swaps. Relic browser reload remains recorded as TD-058.
  **Traced from:** S03/TI03, TI04, TI14. **Date:** 2026-11-17.

- **Landed native fragment composition.** **Description:** the landed catalogue is `packages/trellis_ui/README.md`:
  `button(variant, size, ...attrs)` and `input(...attrs)` forward to native controls;
  `field(controlId, label, hint, error, ...attrs)` owns its inner input and forwards attrs there, with separate
  `label(controlId, ...attrs)` and `fieldset(legend, ...attrs)` aliases. Textarea and native-select use inner native
  content slots, so invoke them on natural textarea/select hosts. **Rationale:** S05 proved HTML parser behavior,
  strict attrs, caller classes and accessibility IDs. **Interpretation:** compose with these landed shapes and
  public part classes; follow the README's params/slots/closed scales rather than inventing optional field slots.
  Card has the scoped default size only; sm/image upstream variants remain excluded. Reuse S05's touch layer and
  destructive override, extending only new hooks. **Traced from:** S05/TI02–TI10. **Date:** 2026-11-17.


- **Natural table caller rows.** **Description:** invoke a suite table on a natural table host with one direct
  `tbody tl:slot="row"` marker containing a tr; its contents read `row`, and the fragment iterates valid tbody row
  groups. **Rationale:** a generic div host loses td markup during HTML parsing before Trellis sees the slot.
  **Interpretation:** use the catalogue's caller recipe and verify actual caller cells in rendered output;
  do not substitute map fallback cells or duplicate suite table markup. **Traced from:** S05/TI06.
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


- **Verified behaviour catalogue and opener contract.** **Description:** S04's landed catalogue is authoritative: dialog/alertDialog take
  id, title, description, open and slots; dropdownMenu uses menuItem/menuCheckboxItem/menuSeparator;
  tabs uses tabList/tabTrigger/tabPanel with matching values; toast and toastViewport share one definition;
  combobox takes id, name, placeholder, value, options, displayValue and exposes comboboxOptions.
  **Rationale:** these are the verified fragment signatures, not the earlier FIS placeholders.
  **Interpretation:** follow README parameters/slots and receiver of ...attrs. Dialog data-return-focus names a
  stable opener DOM ID through repeated validation responses, with native autofocus on the first invalid field.
  Combo value is the submitted ID, displayValue its label, options are maps with value/label; the visible input
  gets name=q and hx-get/hx-target/hx-swap/hx-sync through attrs, while name argument names the hidden field.
  Menu/tab disabled uses native disabled through ...attrs, not an omitted positional boolean that erases it.
  **Traced from:** S04/TI03–TI07, TI10 and verified downstream API inventory. **Date:** 2026-11-17.


- **Toast viewport and top-level rendering.** **Description:** toastViewport defaults to DOM ID toaster; an outOfBand toast wrapper
  appends its children there. **Rationale:** the executed component uses toaster, not earlier prototype naming.
  **Interpretation:** place one viewport before any response; render toast by renderFileFragment with its params
  in context and outOfBand=true for OOB, or invoke in-page with false. Use the same fragment, no duplicate markup.
  **Traced from:** S04/TI06. **Date:** 2026-11-17.


- **Causal hover measurement replay.** **Description:** the landed harness retries only forced Firefox hover snapshots interrupted
  by observed document/window backgrounding, replaying fresh state plus actual hover and failing after3 attempts.
  **Rationale:** real focus loss correctly closes a combobox and can suppress dialog autofocus paint.
  **Interpretation:** reuse the existing capture path; never force target focus/reopen UI or retry generic errors,
  popup closure or visual differences. A genuine in-page dismissal and perpetual interruptions still fail;
  CSP and JS diagnostics survive collect-before-navigation. Native keyboard and HTMX lifecycle stay unforced.
  One new dialog reference corrected five proven foreground focus-paint leaves; no other old state changed.
  **Traced from:** S04/TI08 and driver/active/hover regression controls. **Date:** 2026-11-17.


- **Sortable headers use a natural table slot.** **Description:** S05's table had fallback text headers, a row
  slot and a footer slot. Rendering a caller `<thead tl:slot="header">` failed before the fix. **Rationale:**
  TI03 requires interactive sorting controls inside semantic column headers. **Interpretation:** the suite
  declares a `header` slot on its existing `thead`. A caller can supply a natural thead with scope and aria-sort
  on its cells. Default generated headings and the row contract remain covered. S07 derives this slot in the
  reference contract from the suite source. **Traced from:** S06/TI03 and the suite sortable-header regression.
  **Date:** 2026-11-17.

- **Dart Frog serves public files before file-based routes.** **Description:** Dart Frog CLI 1.2.6 generates
  `Cascade().add(createStaticFileHandler()).add(buildRootHandler())`. With the proposed catch-all route and
  a divergent preview CSS file, the 200 asset response arrived without CSP because static serving won.
  **Rationale:** serving embedded assets under strict CSP takes precedence over the proposed routing mechanism.
  **Interpretation:** generate a UI-only custom `main.dart` that handles the entire suite prefix and applies
  security headers before the generated cascade; run materialization in the dev startup `init` hook before
  the route middleware starts file watchers. **Traced from:** S06/TI13 and the scaffold E2E regression.
  **Date:** 2026-11-17.

## Implementation Observations

ASSUMPTION: The admin example was assigned as one disjoint implementation unit while the story owner built scaffolds and preview tooling. The story owner runs its proofs, independent reviews and commit after both units converge. Without separately owned paths or user authorization for parallel execution, the story owner would implement both units in order.

ASSUMPTION: Use a square shadcn theme in the paste test, with a zero radius and distinct light and dark primary colours. Vega scales card and input radii by 1.4 and 0.8 respectively, so a nonzero radius requires scaled expectations or a change to the suite's token contract.

ASSUMPTION: After saving, show the record's sorted page when it matches the active filters, carrying the existing filters forward. Requiring a mutation to preserve the current page even when the saved row moved would change this behavior.

- Table-header rendering needed a suite slot, with the plain text header as fallback. The focused test first reported `TemplateException: Slot marker tl:slot="header" targets a slot fragment "table" does not declare`. This extends the table contract consumed by S07's generated reference data.
- The legacy starter reset is unlayered and therefore overrode suite padding and dialog margin. A Chrome geometry proof reported `scaffold styles preserve suite dialog centering and component padding` as false, then passed with the reset in a lower cascade layer for UI scaffolds.
- The app's validation proof uses native select typeahead on macOS Chrome, where the CDP ArrowDown did not commit a changed selection. The theme check requests reduced motion so it reads the settled token-derived values.

#### DRIFT

- spec-stale: TI13's file-based catch-all gets shadowed by Dart Frog CLI 1.2.6's public-first cascade. The UI-only entrypoint owns the strict suite prefix before that cascade and materializes previews in its dev init hook. The E2E proof puts stale assets and an unrelated file under the prefix. | Stale targets: S06 TI13 and Constraint (Dart Frog) | –
- spec-stale: TI02's indicator equality proof compares the two opacity states and selectors. S01's shipped sheet puts them in a cascade layer and includes a transition, while S03's shared scaffold CSS holds the same visibility states without a transition. | Stale targets: S06 TI02 and Decision (scaffold indicator rules) | –
- spec-stale: S03's landed `htmxConfigMeta` disables injected indicator styles. The scaffold keeps that config and strict policy. The admin layout explicitly disables eval as well. | Stale targets: S06 Discovered Requirement “Preserve landed scaffold policy and reload” | –
- spec-stale: S03 scaffold E2E tests isolate fixed starter ports in generated temporary copies and pass an available test port to Dart Frog; the admin tests use port 0. The new scaffold proofs reuse S03's server boot and readiness mechanism. | Stale targets: S06 Constraint (tests) | –

#### Chain Attestation

- OC01 links list queries and sorting to TI03/S01, create, edit, validation, company and summary to TI04/S02/S04, delete and rejection to TI05/S03/S08, and template and asset footprint to TI08/SC01/SC02.
- OC02 links strict middleware and asset routes to TI02/S05, the full browser journey to TI06/S05, theme tokens to TI07/S06 and the compiled out-of-tree run to TI09/S07.
- OC03 links flag admission and defaults to TI10/S09 and started Shelf, Relic and Dart Frog pages to TI11–TI13/S10.
- OC04 links package materialization to TI01/S12 and startup, digest repair and file preview to TI11–TI13/S11–S13. TI14 verifies the public documentation for the same workflow.
- The S01 names and S03 scaffold policy are exercised by TI01/TI02 and TI10–TI13, including CSP, static reload, asset requests and the existing counters.
- The S05 native control and natural-table recipes are exercised by TI03/TI04. The S04 opener, options, toaster and focus contracts are exercised by TI04–TI06.
- Native keyboard input is exercised by TI03–TI06. The untouched Firefox focus-replay path is exercised by the component qualification wrapper.

#### Review and repair

Reviewed: Fresh independent quick code and gap review found and fixed two medium defects: malformed admin form bodies escaping the handler, including unknown edits that owed 404; and the UI Dart Frog test bypassing the prior CLI bootstrap. No open Fix findings. Filter summary: 2 validated, 0 downgraded, 0 withdrawn.

- The malformed-body regression was red with `Invalid argument(s): Truncated URI` before the decoder boundary
  handled invalid form data. The fixed route returns 404 for unknown edits and 400 for malformed bodies on known
  routes, with unchanged contacts. The existing Dart Frog 1.2.6 setup now runs through one helper for both
  tests. The installed-CLI path ran locally; first-time global activation was checked by inspection.
- Independent visual validation inspected 22 PNGs and accepted the served list, Summary, edit errors, alert,
  toast and generated Components states. Both served pages fit 390/768/1024/1440. The admin table scrolls
  378px within its 294px wrapper while the page stays at scrollX 0. Axe returned zero violations on both
  pages. The reviewer checked the admin's two incomplete rules against its menu references and sort markup.
- The independent review's P3 disk-preview note found a 404px input edge on a 390px viewport. The child
  template now uses the existing scaffold stylesheet on disk and the landed stack/cluster gap classes.
  The fresh file:// capture shows the right input edge at 374px and a 390px document on a 390px viewport.
  All three browser tests cover input reflow, 24px and 8px gaps, the classic script and solitary rendered asset links.
- Final fast first ran red during colour capture. A real Chrome reproduction saw root `--primary: #13588c`,
  no hover, and a running background-colour transition with `oklab(0.205 0 0)` before `rgb(19, 88, 140)`.
  The theme proof now awaits the native transition before reading the same exact expected values. Six
  concurrent tests passed. The changed-colour control remained red with `Actual: ['rgb(255, 0, 0)', '0px', '0px']`.

#### Executed proofs

- TI01 (packages/trellis_ui) dart test "test/materialize_command_test.dart" --plain-name "writes the three assets, rewrites divergent files and fails naming an unwritable path" -> exit=0, 00:10 +1: All tests passed!
- TI02-indicator (.) dart test "test/htmx_indicator_sources_test.dart" --plain-name "the scaffolds' indicator rules equal the suite's htmx-indicator.css" -> exit=0, 00:00 +1: All tests passed!
- TI03-table-slot (packages/trellis_ui) dart test "test/css_only_components_test.dart" --plain-name "a natural table header slot can render a sortable column control" -> exit=0, 00:00 +1: All tests passed!
- TI08-htmx-pin (packages/trellis_cli) dart test "test/htmx_asset_test.dart" --plain-name "admin example htmx matches the pin" -> exit=0, 00:00 +1: All tests passed!
- TI10-create (packages/trellis_cli) dart test "test/create_command_test.dart" --plain-name "--ui" -> exit=0, 00:20 +9: All tests passed!
- TI10-default (packages/trellis_cli) dart test "test/ui_scaffold_test.dart" --plain-name "default scaffolds mention no trellis_ui" -> exit=0, 00:00 +1: All tests passed!
- TI10-lockstep (packages/trellis_cli) dart test "test/scaffold_pubspec_constraints_test.dart" -> exit=0, 00:00 +7: All tests passed!
- TI11-structure (packages/trellis_cli) dart test "test/ui_scaffold_test.dart" --plain-name "shelf ui scaffold files are strict-clean, provider-free and gitignore the preview folder" -> exit=0, 00:00 +1: All tests passed!
- TI12-structure (packages/trellis_cli) dart test "test/ui_scaffold_test.dart" --plain-name "relic ui scaffold files are strict-clean, provider-free and gitignore the preview folder" -> exit=0, 00:00 +1: All tests passed!
- TI13-structure (packages/trellis_cli) dart test "test/ui_scaffold_test.dart" --plain-name "dart frog ui scaffold files are strict-clean, provider-free and gitignore the preview folder" -> exit=0, 00:00 +1: All tests passed!
- TI02-http (examples/admin_app) dart test "test/contacts_http_test.dart" --plain-name "responses carry the strict policy and the page links the suite, htmx and indicator assets" -> exit=0, 00:00 +1: All tests passed!
- TI03-http (examples/admin_app) dart test "test/contacts_http_test.dart" --plain-name "the list filters, sorts and pages, falls back on bad parameters and renders the same rows for a page load and a swap" -> exit=0, 00:00 +1: All tests passed!
- TI04-http (examples/admin_app) dart test "test/contacts_http_test.dart" --plain-name "validation re-renders the dialog with linked errors and a valid save answers the full response set" -> exit=0, 00:00 +1: All tests passed!
- TI03-browser (examples/admin_app) dart test "test/admin_browser_test.dart" --plain-name "filter, sort and paging swap only the list region" -> exit=0, 00:02 +1: All tests passed!
- TI04-crud (examples/admin_app) dart test "test/admin_browser_test.dart" --plain-name "create and edit in a dialog with validation errors, focus and toast" -> exit=0, 00:01 +1: All tests passed!
- TI04-combobox (examples/admin_app) dart test "test/admin_browser_test.dart" --plain-name "company combobox and summary tab" -> exit=0, 00:01 +1: All tests passed!
- TI05-http (examples/admin_app) dart test "test/contacts_http_test.dart" --plain-name "unknown ids answer 404 and a tokenless mutation answers 403 and changes nothing" -> exit=0, 00:00 +1: All tests passed!
- TI05-browser (examples/admin_app) dart test "test/admin_browser_test.dart" --plain-name "delete asks for confirmation and never leaves an empty page" -> exit=0, 00:02 +1: All tests passed!
- TI07 (examples/admin_app) dart test "test/admin_browser_test.dart" --plain-name "a pasted theme block restyles the app" -> exit=0, 00:04 +1: All tests passed!
- TI08-templates (examples/admin_app) dart test "test/footprint_test.dart" --plain-name "templates are provider-free and strict-clean" -> exit=0, 00:00 +1: All tests passed!
- TI08-assets (examples/admin_app) dart test "test/footprint_test.dart" --plain-name "app CSS stays within 50 lines and no authored JS exists" -> exit=0, 00:00 +1: All tests passed!
- TI06 (examples/admin_app) dart test "test/admin_browser_test.dart" --plain-name "the whole journey raises no CSP violation" -> exit=0, 00:05 +1: All tests passed!
- TI09 (examples/admin_app) dart test "test/aot_test.dart" --plain-name "a compiled binary moved away from the repo serves every suite asset" -> exit=0, 00:03 +1: All tests passed!
- geometry (examples/admin_app) dart test "test/admin_browser_test.dart" --plain-name "the contact table scrolls within the page at 390px" -> exit=0, 00:00 +1: All tests passed!
- TI11–TI13 (packages/trellis_cli) dart test test/generated_app_e2e_test.dart test/relic_e2e_test.dart test/dart_frog_e2e_test.dart --plain-name "ui scaffold" -> exit=0, 00:14 +3: All tests passed!
- TI14 git grep found the materialize command in the package and CLI guides and the site CLI doc, and the
  admin app in the workspace and both example indexes. Format checked 159 files with 0 changes. Analysis
  returned `No issues found!`. The diff whitespace check exited 0.
- Scaffold control E2E run without a selector -> exit=0, `00:16 +26: All tests passed!`. A pre/post hash
  comparison covered 77 generated files across the three default generators with and without CDN opt-in.
  The generated Dart Frog production build booted with the exact CDN CSP origin, three embedded asset digests
  and a 404 for a disk-only file. The stale CSS and JS stayed stale on disk.
- Admin package, including AOT and review regression -> exit=0, `00:18 +15: All tests passed!`. The app
  counts 22 owned CSS lines and zero authored JavaScript. Vendored HTMX is SRI-pinned by the CLI test.
- TI06 mutation reported `style-src-attr`. TI08 mutations named `templates/base.html` for an authored
  provider-style class and `static/app.css: 73 lines` for the 50-line cap. Each exited 1 and was restored.
  Six additional CLI/materialization/indicator discrimination mutations exited 1 with their intended failures
  and restored source hashes. The table slot, scaffold dialog geometry, file-preview reflow and gap checks
  each ran red against the original behavior before correction.
- Component qualification wrapper -> exit=0, `16:43 +1: All tests passed!`. It regenerated 25 component
  records byte for byte, covering 325 passes per browser in Chrome and Firefox. The SHA-256 check froze 183
  inputs. Fresh gallery response bodies and ETags matched all three embedded digests. The embed check was
  byte-identical, the porting check reproduced all four generated files, and the 75 human release-prep
  entries were preserved.
- Final visual checklist -> pass. The independent pass covered all requested served states, including
  the 390/1440 lists and scroll containment. The 390px disk-preview recapture was read after the P3 fix.
- Final fast tier -> exit=0, 14 clean analysis targets, 3508 package passes and 1 existing skip,
  root `04:55 +252 ~2: All tests passed!`, and 47 root files formatted without changes. The three skips are the
  existing Linux watch and no-colour-control theme cases. Under the dispatched --no-full-tier run,
  the integration caller runs the combined full and release tiers.

- **Evidence relocation after S06 integration.** **Description:** the owned paired story worktrees and merged branch were removed after byte-for-byte archive verification. **Interpretation:** historical `.agent_temp` evidence paths in the S06 story worktree resolve under the main public checkout `.agent_temp/0.14-plan-run/evidence/S06/public-agent-temp/`; the exact returned private plan/FIS receipt is in `evidence/S06/private-receipt/`. **Traced from:** S06 integration of `153a1e4` at `a0e08b2`. **Date:** 2026-11-18.
