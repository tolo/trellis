# FIS: Component reference docs and docs-site seam

**Plan**: dev/spec/0.14/plan.json
**Story-ID**: S07

## Feature Overview and Goal

**Intent**: Let an app author learn each qualified suite component from a reference page whose example is the real fragment, and give every `trellis_site` build a generic way to pull in extra fragment sources and static assets, so the docs site shows the suite without `trellis_site` depending on it and story S09 reuses the same hook for themes.

**Expected Outcomes**:

- [OC01] A site whose config or theme names a source builds with that source's fragments available to layouts and shortcodes and its assets in the output; a site naming none builds exactly as before; `trellis_site` knows no suite.
- [OC02] The docs site publishes, under `/trellis/` and at the root, one reference page per component whose automated gate items all pass, each rendering a live `trellis_ui` example and stating its fragment name, parameters, slots, pass-through target, part classes, tokens, keyboard interaction and accessibility notes with the gate record's results.
- [OC03] One guide shows an author how to add `trellis_ui` to an existing app, theme it with a shadcn theme block and map `cn-` to `trellis-` when porting another style.
- [OC04] The pages stay true as components change: facts are generated from fragments, stylesheets and gate records, and a record that stops passing removes its page or fails a test.


## Required Context

- `dev/spec/0.14/prd.md#fr8-component-reference-docs-and-docs-site-adoption` – the criteria this story implements, including the seam's shape (owner, 2026-10-20); binding.
- `dev/spec/0.14/prd.md#fr5-qualification-gate` – a component is "supported" only when every item passes; automated items run in the plan, screen-reader and Safari items at release prep.
- `dev/spec/0.14/prd.md#constraints` and `#edge-cases` – unattended, headless checks, no Node, twice-inserted fragment ids.
- `dev/spec/0.14/s01-porting-pipeline-and-trellis-ui-package.md` – package API (loader, `respond`, materialize, public names in its README), template names `trellis-ui/<component>`, fragment constraints (no literal `id`, no asset URL), cascade-layer rule, isolation guarantee.
- `dev/spec/0.14/s04-behaviour-components.md` and `dev/spec/0.14/s05-css-only-components-layout-primitives-and-overrides.md` – the 25 gate subjects (six behaviour, 19 CSS-only and layout), fragment signatures in the package README catalogue, the `id`-first parameter rule.
- `dev/spec/0.14/s02-headless-qualification-harness.md` – gate record shape under `dev/ui-gate/records/<component>.json`: items, per-browser results, record-level automated verdict.
- `dev/spec/0.14/plan.json#sharedDecisions` – "Component layout and gallery" and "Harness input and gate record".
- `dev/adrs/ADR-012-trellis-ui-contract.md#delivery-packaging-spike-resolved-2026-08-18` and `dev/DECISIONS.md` "Trellis UI delivery" – the CLI-managed vendored bundle is rejected for app delivery; see Constraints.
- `packages/trellis_site/lib/src/trellis_site_builder.dart`, `packages/trellis_site/lib/src/shortcode_processor.dart` and `packages/trellis_cli/lib/src/commands/build_command.dart` – the three places the hook touches (`_runPipeline`, `ShortcodeProcessor`, `BuildCommand`).
- `tool/generate_theme_gallery.dart` and `test/site_migration_contract_test.dart` – precedent for a committed, checked, generated `site/data` file and for building `site/` in both deploy shapes.


## Acceptance Scenarios

- **S01 [OC01] A named source's templates and assets reach the build**
  - **Given** a site whose `trellis_site.yaml` has `uses: [acme]`, a registered source `acme` offering template `acme/badge` (a fragment) and asset `acme/badge.css`, a layout invoking `~{acme/badge :: badge('new')}`, and a post-Markdown shortcode invoking the same
  - **When** the site builds
  - **Then** the layout output and the shortcode output both contain the rendered fragment, `output/acme/badge.css` holds the source's bytes, the shortcode raised no warning, and `BuildResult.staticFileCount` counts the asset

- **S02 [OC01] Site and theme can both name a source; it is written once**
  - **Given** the same source, named only in the theme's `theme.yaml`, then only in the site config, then in both
  - **When** each builds
  - **Then** every build has the fragment and the asset, and the both-named build neither fails nor writes the asset twice

- **S03 [OC01] A source nobody names changes nothing**
  - **Given** a registry holding `acme` whose factory counts its calls, and a site with no `uses`
  - **When** it builds
  - **Then** the factory was never called, the output tree is byte-identical to a build given no registry, there is no `acme/` directory, and a layout invoking `acme/badge` fails as it did before with the engine's `TemplateNotFoundException`

- **S04 [OC01] Bad names and paths fail the build and leave no output**
  - **Given** a site with `uses: [nope]`; another whose two sources claim the same asset path; another whose source offers asset path `../escape.txt`, and one offering `/abs.txt`; another with `uses: acme` (not a list)
  - **When** each builds
  - **Then** each fails with a message naming the key and the registered names (unknown name), both source names and the path (clash), the path (escape), or the key and expected shape (not a list), and leaves no output directory behind

- **S05 [OC01] Site and theme win over a source**
  - **Given** a source template and a site (and separately a theme) template with the same name, and a source asset and a site static file with the same output path
  - **When** the site builds
  - **Then** the site or theme template renders, and the site static file's bytes are in the output

- **S06 [OC01] The CLI plugs `trellis_ui` in, under a path prefix**
  - **Given** a temp site with `uses: [trellis_ui]` and a layout that invokes `~{trellis-ui/button :: button('destructive')}` and links `/trellis-ui/trellis-ui.css`
  - **When** `trellis build` runs, once without and once with `--path-prefix /trellis/`, and once on the same site without `uses`
  - **Then** the page holds `data-slot="button"` markup; `trellis-ui/trellis-ui.css`, `trellis-ui/trellis-ui.js` and `trellis-ui/htmx-indicator.css` exist at those unprefixed output paths with the bytes `trellis_ui` serves; the prefixed build links `/trellis/trellis-ui/trellis-ui.css`; the build without `uses` has no `trellis-ui/` directory and its layout fails with `TemplateNotFoundException`; `uses: [nope]` exits 1 naming `trellis_ui` as the registered name

- **S07 [OC02] [runtime] The docs site has one reference page per qualified record, in both deploy shapes**
  - **Given** the committed gate records and the docs site built root-served and with `pathPrefix: /trellis/`
  - **When** the output trees are listed and checked with `tool/link_check.dart`
  - **Then** `docs/ui/components/<component>/index.html` exists for exactly the records whose automated verdict is pass (25 when all pass), each page links the suite stylesheet and script under the active prefix with the files at unprefixed output paths, pages outside `docs/ui/components/` link no suite asset, the link check reports 0 broken in both shapes, and the build prints no warning

- **S08 [OC02] Each page states its facts from the sources**
  - **Given** a built page and the generated `site/data/ui_components.yaml`
  - **When** its text is read
  - **Then** it names every fragment of its component as `trellis-ui/<component> :: <signature>` with parameters, slots, the element that receives pass-through attributes and the public part classes exactly as the data holds them; a gate section lists every record item with its status and browsers, saying "supported" only when every item (the manual ones included) is `pass` and otherwise naming the pending manual items; headings for tokens, keyboard interaction and accessibility notes are present; and every token it lists exists in the shipped stylesheet

- **S09 [OC02] [runtime] Live examples operate**
  - **Given** the root-served build loaded in Chrome with scripts on, and no htmx on the page
  - **When** the dialog example's trigger is activated, the dropdown menu's, and a second tab of the tabs example
  - **Then** the dialog matches `:modal` with focus inside, the menu's trigger reports `aria-expanded="true"` with an item focused, the second panel is visible and the first hidden, the button example's computed background equals its resolved `--primary`, and the console holds no error

- **S10 [OC02] [runtime] The docs page leaves each preview as the suite renders it**
  - **Given** every built reference page, loaded under a light and a dark docs skin (`prefers-color-scheme`), and a bare page holding the same preview HTML with only the suite stylesheet and script, carrying the suite's `dark` class when the docs skin is dark, its body given the preview's inherited font and colour
  - **When** the non-inherited computed properties of every element with a `trellis-` class (display, padding, margin, border widths, styles and colours, radius, background colour, shadow, opacity, text decoration, list style, gap) and every custom property the suite stylesheet declares on `:root` are read in both
  - **Then** they are equal; a difference is reported with page, element path and property

- **S11 [OC02] The example shown is the example rendered**
  - **Given** a page and its shortcode template
  - **When** the suite-fragment invocations in the template are compared with the fenced code on the page
  - **Then** each invocation appears, whitespace-normalised, in a fence, and the page calls its shortcode in the post-Markdown form for exactly its own component

- **S12 [OC02] [runtime] Reference pages do not overflow narrow viewports**
  - **Given** the docs reflow sweep over both deploy shapes
  - **When** it measures every built page, the 25 new ones included
  - **Then** none overflows at the narrow widths or just above the site's breakpoints (the table example scrolls inside its own region)

- **S13 [OC03] The guide's wiring is the README's, and its mapping names real classes**
  - **Given** the guide page and the `trellis_ui` README
  - **When** their Shelf, Relic and Dart Frog wiring snippets and the guide's `trellis-*` class names are read
  - **Then** each snippet equals the README's (whitespace-normalised), each named class exists in the shipped stylesheet, and the guide covers adding the package, the theme-block procedure and the `cn-` to `trellis-` rule

- **S14 [OC04] A record that stops passing removes its page**
  - **Given** a fixture project root holding two gate records and their fragments, one with an automated verdict of `fail`
  - **When** the reference data is generated, and the page-set check runs with a page present for the failing one
  - **Then** the data marks it not qualified and the check fails naming that page as unexpected; with the page deleted it passes

- **S15 [OC04] Stale generated data is caught**
  - **Given** the committed `site/data/ui_components.yaml`, then one fragment signature edited without regenerating
  - **When** the freshness check runs
  - **Then** it passes on the committed tree and fails after the edit, naming the regeneration command; two generations are byte-identical


## Structural Criteria

- **SC01** `trellis` core and `trellis_site` know no suite: no `trellis_ui` in `packages/trellis/pubspec.yaml`, `packages/trellis_site/pubspec.yaml` or `packages/trellis_site/lib/`, and `trellis_ui` does not depend on `trellis_site` (ADR-012: depends toward core).
- **SC02** `packages/trellis_cli/pubspec.yaml` is the only manifest that gains a dependency, `trellis_ui` at the lockstep constraint, and the release registry tests stay green with the new edge.
- **SC03** The generator is deterministic and reads only committed inputs: no timestamp, absolute path or environment value in `site/data/ui_components.yaml`, and no Node or network call.
- **SC04** The shipped hook has no per-source code: adding story S09's theme use means one `uses` line in a `theme.yaml`, with no change to `trellis_site`.


## Scope & Boundaries

### Work Areas
Paths are relative to the trellis-public root, where the story executes.

- Hook: `packages/trellis_site/lib/src/` (a source type, `site_config.dart`, `theme_manifest.dart`, `trellis_site_builder.dart`, `shortcode_processor.dart`), exported from `trellis_site.dart`; tests `packages/trellis_site/test/site_sources_test.dart`.
- CLI wiring: `packages/trellis_cli/pubspec.yaml`, `lib/src/commands/build_command.dart`; test `packages/trellis_cli/test/build_ui_test.dart`; `packages/trellis_ui/lib` only if its public API cannot list the embedded assets (smallest read-only accessor, added to its README).
- Generator: `tool/generate_ui_reference.dart`, committed `site/data/ui_components.yaml`, `test/ui_reference_data_test.dart`.
- Docs site: `site/trellis_site.yaml` (`uses`), `site/layouts/ui_component.html`, `site/layouts/shortcodes/ui_<component>.html` (25), `site/static/ui-reference.css`, `site/content/docs/ui/` (`_index.md`, `guide.md`, `components/_index.md`, 25 component pages), `site/content/docs/packages/_index.md` and `trellis_site.md`/`trellis_cli.md` mentions; test `test/ui_reference_site_test.dart`.
- Docs and records: `packages/trellis_site/README.md`, `docs/guides/theme-authoring.md` (manifest key), `dev/architecture/system-architecture.md`, `dev/adrs/ADR-012-trellis-ui-contract.md` Implementation Notes, `dev/guidelines/VISUAL-VALIDATION.md` (routes), `dev/state/LEARNINGS.md`, `packages/trellis_site/CHANGELOG.md` and `packages/trellis_cli/CHANGELOG.md` (`## 0.14.0`), `tool/serve_docs.sh` and `test/docs_preview_script_test.dart`.

### What We're NOT Doing
- Themes adopting suite components, the shared search client, `theme.yaml` `uses` lines in bundled themes – story S09. This story only makes that a one-line change (SC04).
- Declaring any component supported in `CHANGELOG.md` or running the manual screen-reader and Safari passes – story S08 and release prep. Pages show the record's manual items as pending until a human enters them.
- Server round trips on the docs site: no htmx, no `hx-*` request in an example. Behaviour that needs an endpoint (combobox filtering, out-of-band toast) is described in prose and fenced as static code.
- A docs-site strict CSP, the themes' inline skin script (TD-023), or changes to the Lattice theme or the suite's CSS: collisions are fixed in the site's own stylesheet.
- A component playground, copy-to-clipboard.
- A nav-bar entry: the sidebar tree builds from the content section, `nav_links` stays.


## Architecture Decision

**Approach**: `trellis_site` gains a `SiteSource` (a template loader plus an output-relative asset map) and takes a registry of source factories by name; `trellis_site.yaml` and `theme.yaml` list `uses:` names, only named factories are called, and the page engine, the shortcode engine and the static-copy step all consume the result. `trellis_cli` registers `trellis_ui`. Reference pages are Markdown with a post-Markdown shortcode per component under one site layout; fragment, part-class and gate facts come from `tool/generate_ui_reference.dart` into `site/data/ui_components.yaml` (precedent: the theme gallery), and tokens, keyboard and accessibility prose are authored per page.
**Why this over the floor**: The floor is copying suite files into `site/static/` and showing markup as code. FR8 rules it out: examples must render from `trellis_ui`, `trellis_site` must not depend on it, and a page may exist only for a qualified component, which hand-typed facts cannot track. Hand-typing the fragment facts per page is the second floor; the generator costs one script and removes the drift FR8's "from the gate record" invites.
**Flow**: `uses` (site ∪ theme) → registry factories → `SiteSource` → [page engine loader after site and theme, shortcode engine loader, static copy before theme and site] → pages; generator: records + fragments + stylesheets → `site/data/ui_components.yaml` → layout.


## Constraints & Gotchas

- **Constraint (order)**: Runs on the 0.14 branch after stories S01, S04 and S05. Names from their FIS (`respond`, the loader, README catalogue, record fields, `dev/ui-gate/records/`) are the executor's to confirm in the landed code; where code differs, follow it and say so.
- **Constraint (two engines)**: `ShortcodeProcessor` builds its own `Trellis` over `FileSystemLoader(siteDir)`, separate from the page generator's. A source reaching only the page engine makes every shortcode fail, and the processor swallows that into a `BuildWarning` and leaves the raw tag, so a page still builds. Pass the source loader to both; the tests assert no warning.
- **Constraint (sync loading)**: Cross-file `tl:replace` resolves with `loadSync`, so a source's loader must implement it (a `CompositeLoader` skips a loader answering `null`).
- **Constraint (post-Markdown shortcodes only)**: Use `<!-- tl:ui_<name> -->`. A `{{% … %}}` shortcode is replaced before Markdown runs, and rendered HTML with a blank line or a four-space indent inside turns into paragraphs and code blocks.
- **Constraint (`BuildCommand` copies config by hand)**: `build_command.dart` rebuilds `SiteConfig` field by field, so a new config field silently disappears on the CLI path unless threaded. Scenario S06 covers it.
- **Constraint (path prefix)**: After rendering, `applyPathPrefixToLinks` prefixes root-absolute double-quoted `href`/`src`, except inside `<pre>`/`<code>`; files are written unprefixed. The layout follows the Lattice `assetBase` pattern (`site.pathPrefix`), never a hard-coded `/trellis/`, and example markup never links a suite asset.
- **Constraint (docs CSS beats the suite)**: Suite styles sit in cascade layers (story S01), so the docs site's unlayered CSS wins. Lattice declares `--card` and `--radius` on `:root`, which override the suite's tokens of the same name, and its `.prose table`, `.prose a`, `.prose ul` rules reach suite markup inside page content. S10 is the check; fix in `site/static/ui-reference.css` scoped to the preview well (re-declare colliding tokens there, shield the rest), with a comment naming the cause. Do not touch Lattice or the suite. Story S09 meets the same collisions in theme layouts.
- **Constraint (static site)**: No server and no htmx. The suite's classic script must run without htmx (S09 asserts no console error). Example `id` arguments differ per example on a page (story S04's `id`-first rule).
- **Constraint (layout head)**: Load suite CSS and JS only on reference pages, from a site layout that extends `theme:layouts/base.html` and fills `head-extra` inside a `tl:block` (a bare `<link tl:define>` contributes nothing; see `site/layouts/gallery.html`).
- **Constraint (ADR-012 and Decisions)**: ADR-012 and `dev/DECISIONS.md` reject a CLI-managed vendored bundle as the way apps get the suite. This story embeds the suite in the CLI for site builds only, as PRD FR8 decided (owner, 2026-10-20); the CLI binary grows about 1.33x the suite's raw bytes. Add one clarifying sentence to ADR-012's Implementation Notes so the two do not read as contradictory; reconciliation of the Decisions row is the owner's.
- **Constraint (shared files)**: `packages/trellis_cli/pubspec.yaml`, `CHANGELOG.md` files and `system-architecture.md` are also edited by stories S03 and S06. Append to the `## 0.14.0` section, creating it if absent, and keep unrelated lines.
- **Constraint (browsers)**: Browser tests use `BrowserProbe`/`StaticSiteServer` from `test/browser_reflow_probe.dart` and `requireChromeInCi`; drive interactions with in-page `click()` and event dispatch, and use story S02's console and violation capture on the probe if it landed. Never kill browsers by name.
- **Decision**: the opt-in is a `uses:` list of source names in `trellis_site.yaml` and `theme.yaml`, resolved against a name-to-factory registry passed to `TrellisSite` – the PRD says "when a site or theme opts in" without a syntax; another key name or a CLI flag changes the parsing and docs only.
- **Decision**: a source's templates rank below the site's and theme's, its assets are written before theme and site static files, and two sources claiming one asset path fail the build – a silent override is the failure the hook should not add; first-wins merging would change S04 and S05.
- **Decision**: previews follow the shown docs skin, `auto` included – `lattice.js` sets the suite's `dark` class on preview wells whenever the page shows dark (owner, 2026-10-21).
- **Decision**: a page exists for every gate record whose record-level automated verdict is `pass` (25: `alert-dialog` has its own page, `container` covers `sidebar`) and says "supported" only when every item including the manual ones is `pass` – FR8 asks for pages per "qualified" component while FR5 reserves "supported" for release prep.
- **Decision**: tokens, keyboard interaction and accessibility prose are written per page and only the tokens are cross-checked (existence in the stylesheet) – deriving them mechanically from manifests and CSS yields poor prose; a derived list would change S08.
- **Decision**: generated data freshness is enforced by a root test in the fast tier and `tool/serve_docs.sh` regenerates it, with no new CI or deploy-workflow step – the theme gallery's extra `--check` step exists to order a workflow test.
- **Decision**: the guide copies the README's wiring snippets and a test keeps them equal – the README is the one source whose snippets story S01 proves; linking out to GitHub instead would drop the copy and S13's first clause.


## Implementation Plan

### Implementation Tasks

- **TI01** `trellis_site` has a source type and parses `uses`: a `SiteSource` carries a `TemplateLoader` and an asset map keyed by output-relative POSIX path; `SiteConfig.uses` and `ThemeManifest.uses` are lists of names matching `[a-z][a-z0-9_]*`, absent meaning empty, any other shape raising the existing config/manifest exception naming the key.
  - Pattern: `site_config.dart#ThemeConfig.fromYaml` for error style; dartdoc states the rank and clash rules of the decisions.
  - **Verify**: `packages/trellis_site/test/site_sources_test.dart#uses parses from site config and theme manifest and rejects other shapes` – list, missing, scalar, nested list, bad name.
  - **SATISFIES**: S04

- **TI02** A build honours the sources its site or theme names: `TrellisSite` takes the registry, resolves `uses` (site ∪ theme manifest), calls only named factories, feeds the page engine (after site and theme), the shortcode engine, and the static copy (before theme and site), validates names and asset paths, and counts asset files in `staticFileCount`; a failure leaves no output.
  - Callers keep compiling: the registry is optional (`ShortcodeProcessor`, `TrellisSite`, 17 test files and the theme contract suites construct without it).
  - **Verify**: `packages/trellis_site/test/site_sources_test.dart#a named source reaches layouts, shortcodes and the output`, `#site and theme naming one source write its asset once`, `#a source nobody names is never built and changes nothing`, `#bad names and paths fail the build and leave no output`, `#site and theme win over a source`; and `cmd: cd packages/trellis_site && dart test` – existing suites unchanged. Mutation check: pass the loader to the page engine only and watch the shortcode assertion go red.
  - **SATISFIES**: S01, S02, S03, S04, S05, SC04

- **TI03** `trellis_cli` depends on `trellis_ui` and registers it as source `trellis_ui` (its loader and all embedded assets under `trellis-ui/`), and `BuildCommand` threads `uses` into the config it rebuilds.
  - If story S01's public API does not list the embedded assets, add the smallest read-only accessor to `trellis_ui` and list it in its README.
  - **Verify**: `packages/trellis_cli/test/build_ui_test.dart#build with uses: trellis_ui renders suite fragments and ships its assets`, `#a path prefix reaches suite links while files stay unprefixed`, `#without uses the output has no trellis-ui directory`, `#an unknown name exits 1 naming the registered names` – bytes compared with what `trellis_ui` serves; and `cmd: git grep -n trellis_ui -- packages/trellis/pubspec.yaml packages/trellis_site/pubspec.yaml packages/trellis_site/lib; test $? -eq 1` – nothing links the other way; and `cmd: dart test test/release_distribution_contract_test.dart` – registries accept the new edge.
  - **SATISFIES**: S06, SC01, SC02

- **TI04** Reference data is generated and checked: `tool/generate_ui_reference.dart [--check] [project-root]` writes `site/data/ui_components.yaml` with, per gate record: name, qualified, supported, items with status and browsers, fragments (name, signature, parameters, slots, tag receiving pass-through attributes) from `packages/trellis_ui/assets/fragments/<component>.html`, and public part classes from the generated and hand stylesheets (each `trellis-*` class belongs to the component whose name is its longest matching prefix, so `alert` does not take `alert-dialog`'s).
  - Pattern: `tool/generate_theme_gallery.dart` (header, `--check`, exception type, library class so tests build a fixture root).
  - **Verify**: `test/ui_reference_data_test.dart#committed data matches its sources and regenerates byte for byte`, `#a failing record is not qualified and a stale file names the regeneration command`, `#part classes go to the longest matching component name`.
  - **SATISFIES**: S14, S15, SC03

- **TI05** The docs site renders reference pages: `site/trellis_site.yaml` has `uses: [trellis_ui]`; `layouts/ui_component.html` extends the theme base, links suite CSS and JS plus `ui-reference.css` on these pages only, honours the path prefix, renders the generated fragment and gate facts and the page content; `ui-reference.css` shields the preview well from Lattice's rules, and `lattice.js` sets the suite's `dark` class on every preview well whenever the page shows its dark skin (chosen, or `auto` with the OS preferring dark), on load, on toggle and on an OS scheme change, so previews follow the shown skin; `docs/ui/_index.md` and `components/_index.md` list the pages; the button page and its shortcode are the pilot.
  - Verify the colliding-token and `.prose` effects in a browser before writing the fix (`--card`, `--radius`, `.prose table`).
  - **Verify**: `test/ui_reference_site_test.dart#each page states its fragments, slots, attribute target, part classes and gate results from the generated data` and `#each page's live example source appears in its page` over the pages present; `cmd: dart test test/site_migration_contract_test.dart` – link check and no warnings in both shapes.
  - **SATISFIES**: S08, S11

- **TI06** The 18 other CSS-only and layout components have pages (input, textarea, field, native-select, checkbox, radio, switch, badge, card, alert, table, pagination, breadcrumb, separator, stack, cluster, grid, container): front matter with `component`, `tokens`; the post-Markdown shortcode and its template; fenced source matching it; keyboard and accessibility sections (non-interactive components say Tab passes through).
  - **Verify**: `test/ui_reference_site_test.dart#each page states its fragments, slots, attribute target, part classes and gate results from the generated data`, `#each page's live example source appears in its page` and `#tokens a page lists exist in the shipped stylesheet` – green over the larger set.
  - **SATISFIES**: S08, S11

- **TI07** The six behaviour components have pages (dialog, alert-dialog, dropdown-menu, tabs, toast, combobox), whose examples run statically: inline initial combobox options, a toast of duration 0, no `hx-*`; prose and static fences describe the server round trips; the keyboard section lists the APG keys the story S04 manifests walk.
  - **Verify**: `test/ui_reference_site_test.dart#one reference page per qualified record in each deploy shape` – builds both shapes, compares the page set with the generated data, checks suite links per prefix and that other pages link none.
  - **SATISFIES**: S07, S08, S11

- **TI08** The browser contracts hold on the built site: examples operate, the docs page leaves previews as the suite renders them, nothing overflows.
  - **Verify**: `test/ui_reference_site_test.dart#live examples operate` and `#the docs page leaves each preview as the suite renders it` (light and dark docs skin; mutation check: delete the token re-declaration and watch the named property go red); `cmd: dart test test/site_reflow_test.dart` – run output shows the browser tests executed, not skipped.
  - **SATISFIES**: S09, S10, S12

- **TI09** The guide exists: `docs/ui/guide.md` covers adding `trellis_ui` to an existing app (dependency, engine loader, asset serving for Shelf, Relic and Dart Frog, materialization), theming with a shadcn theme block (pasted block, either link order, the contrast guarantee being for default tokens), and the `cn-` to `trellis-` rule for porting another style, and states that shadowing a managed fragment is unsupported (PRD Edge Cases) with tokens, part classes, extension classes and composition as the override seam, linked from the section index and `docs/packages/_index.md`.
  - **Verify**: `test/ui_reference_site_test.dart#the guide's wiring equals the README's and its classes exist`.
  - **SATISFIES**: S13

- **TI10** The seam and pages are documented and kept current: `trellis_site` README, its package page and `theme-authoring.md` describe `uses` and `SiteSource`; the `trellis_cli` page notes the embedded suite; architecture doc package map, dependency graph and build pipeline step (the "Current through" marker moves only if the whole document is verified); ADR-012 sentence; VISUAL-VALIDATION routes; LEARNINGS entries (two engines swallow a missing loader into a warning; Lattice token and `.prose` collisions); `## 0.14.0` changelog bullets in `trellis_site` and `trellis_cli`; `tool/serve_docs.sh` runs the generator before the build and its script test expects it.
  - **Verify**: `cmd: dart test test/docs_preview_script_test.dart` – expected command log includes the generator; `cmd: git grep -n -E "trellis_cli.*trellis_ui" -- dev/architecture/system-architecture.md` – the package map and graph show the new edge (exit 0).
  - **SATISFIES**: S15, SC04


## Final Validation Checklist

- Fast tier from `KEY_DEVELOPMENT_COMMANDS.md` is green and the run shows the browser tests executed, not skipped.
- AOT proof: `dart compile exe packages/trellis_cli/bin/trellis.dart -o .agent_temp/trellis-aot`, copy the binary outside the repo, run it from `site/` with `build --output <temp dir>`, and confirm `trellis-ui/trellis-ui.css` and a reference page are in the output. Report the binary size before and after.
- Root-served build of `site/`, capture `/docs/ui/components/button/`, `/dialog/`, `/table/` and `/combobox/` at 390 and 1440 wide with `agent-browser` per `VISUAL-VALIDATION.md`, and read the PNGs: previews look like the gallery's, nothing overflows, facts and gate sections are legible.

## Discovered Requirements

- **S01 delivery names and layout.** **Description:** use `TrellisUiLoader`, `trellisUiRespond` and
  `materializeTrellisUi(Directory)` from `package:trellis_ui/trellis_ui.dart`; component sources are under
  `assets/fragments/`, `assets/css/hand/`, `assets/js/`, with `gallery/pages/` examples. **Rationale:** S01 owned
  choosing these names. **Interpretation:** follow `packages/trellis_ui/README.md` engine/framework glue and extend
  the existing layout; do not add another serving or bundling API. **Traced from:** S01/TI07, TI12.
  **Date:** 2026-11-17.

- **Canonical user-doc destination.** **Description:** `docs/guides/theme-authoring.md` moved to
  `site/content/docs/themes/authoring.md` in committed public documentation consolidation `8a598ed`. **Rationale:** the FIS predates
  the owner's 2026-11-17 documentation move. **Interpretation:** update the canonical destination and run the
  same documentation checks there; do not recreate `docs/` or mirror the page. Record old Verify paths as
  `spec-stale` drift when executing them against their relocated file. Current `dev/DECISIONS.md` explicitly
  keeps 0.14 execution in this private plan; the planning move applies from 0.15.
  **Traced from:** S02/TI12 integration. **Date:** 2026-11-17.

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


- **Retained manual record statuses.** **Description:** S02's item schema permits pass, fail, not-run and
  release-prep with string-list evidence, and automated rewrites preserve human-entered manual items.
  **Rationale:** S05's shared record-test helper initially rejected legitimate human values; a copied-record test
  failed before its minimal correction during simplification. **Interpretation:** extend the landed helper rather
  than requiring every manual status to remain release-prep. Missing/malformed entries still fail validation;
  automated browser verdicts must still pass, and a valid manual record is not a claim of support or release
  approval. Real canonical manual entries remain owner-controlled. **Traced from:** S05 integration tidy and
  S02/S11; S04/TI08. **Date:** 2026-11-17.


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

- **Table header slot integration.** **Description:** S06 adds a named `header` slot to the table's
  `thead` for caller-owned sorting controls while preserving the default headings. **Rationale:** an admin
  sorting fixture exposed the missing slot during concurrent execution. **Interpretation:** generate the
  slot inventory directly from the fragments in each tree. Regenerate and verify the reference data on the
  combined tree after both changes land. The static table preview uses the default headings and the existing
  caller-owned row slot. **Traced from:** S06 admin table and S07/TI04, TI06. **Date:** 2026-11-17.

- **Structured input for live shortcodes.** **Description:** table rows, breadcrumbs, pagination and
  combobox options require actual list/map values. **Rationale:** the landed expression engine has
  no collection literals, and post-Markdown shortcode parameters were strings only. **Interpretation:**
  builds that opt into sources provide page front matter as the post-Markdown shortcode's base context.
  Explicit shortcode parameters override it. A build with no source names retains its existing lookup
  and output. Store example data in the page's authored YAML and pass it to the actual fragments.
  **Traced from:** S07/TI02, TI06, TI07. **Date:** 2026-11-17.

## Implementation Observations

- `SiteSource` stays in `trellis_site`. The CLI maps the read-only `trellisUiAssetPaths` inventory to
  bytes from `trellisUiRespond`; apps and the CLI share one package payload. Post-Markdown's new optional
  context takes per-page front matter only on source builds. The no-source fixture compares the entire
  output tree byte for byte.
- The reference generator uses the existing CSS bundling order and records all conditional pass-through
  receivers. Separator forwards to either `<hr>` or `<div>`; the layout identifies each selector hook.
  Longest component prefixes own part classes. Fragment-root aliases supply unclaimed hooks such as
  `trellis-sidebar`, `trellis-label`, and `trellis-toaster`.
- Existing documentation illustrated pre-Markdown shortcodes with literal tags in fences. Creating the
  site shortcode directory made those samples resolve and emit three warnings. The docs encode the first
  brace only and the existing migration test checks the rendered text in both deploy shapes. Remove the
  encoding when the pre-Markdown pass distinguishes fenced samples.
- Lattice's declarations affect `--radius-md` through `--radius`, and its global link color reaches breadcrumb
  and pagination parts. Chrome measured both collisions. The preview scopes the three token declarations
  and reverts the unlayered link and prose table properties to the suite cascade.
- The System Architecture update names the 0.14 source pipeline locally. The document's existing broader
  `Current through` verification scope remains the declared scope.

#### DRIFT

- spec-stale: ThemeConfig YAML parsing lives in its own file | Stale targets: TI01 `site_config.dart#ThemeConfig.fromYaml` | `site_sources_test.dart` proves the same parser outcomes.
- spec-stale: The canonical user docs were consolidated under `site/content/docs/` | Stale targets: TI09 `docs/ui/guide.md` and TI10 `docs/guides/theme-authoring.md` | The guide proof and root/prefix link checks run on the canonical paths.
- spec-stale: Use the landed fragment signatures, conditional receivers and published names | Stale targets: earlier component placeholders in the 0.14 context bundle | Reference generation reads actual fragments, CSS and gate records; the site tests verify every rendered fact, class, token and live example.

#### Code and gap review

- Fix, high. A transparent preview let the Lattice background pattern lower Table caption contrast.
  The well now uses the suite's resolved `--background`. The strengthened parity proof observed
  `rgba(0, 0, 0, 0)` before the fix and passed across all 25 pages in both skins after it.
- Fix, medium. Source assets that claimed a file and its descendant passed preflight and then
  raised `FileSystemException ... Not a directory` during copy. The builder rejects either owner
  order before output creation and names both sources and paths.
- Fix, low. The reference route proof truncated nested paths to their first segment. The old
  comparison accepted an injected `button/extra/index.html`; the repaired proof retains the
  full reference route and rejects it.

#### Visual review

- Fix, P2. Lattice's global keyboard focus rule reached dialog, combobox and table previews.
  The real modal autofocus and native Tab proof found a 2px radius and inset outline where identical
  suite markup had an 8px radius and its own shadow ring. The site stylesheet now reverts only those
  preview focus properties to the lower layers. The native table region retains its browser focus outline.
- Fix, P3. The Button listing card displayed literal `&quot;`. Rephrased the authored summary and added
  a real index check for readable card text and the exact qualified links in both builds.
- Note, P3. The dialog title inherits the effect of Lattice's heading rule. The independently captured
  font and line-height variation falls outside the computed properties named by S10.
- Note, P3. The Lattice contents list uses Markdown headings. Generated Fragment API and Gate results
  remain reachable by scrolling and have named anchors.

The independent targeted recapture passed both fixes. It matched all 24 focused-state comparisons
against suite markup, verified visible native table focus and 98px within-region keyboard scrolling,
and found readable Button text in all four listing checks.


- **Evidence relocation after S07 integration.** **Description:** the owned paired worktrees and merged branch were removed after archive hash verification. **Interpretation:** historical source-worktree `.agent_temp` evidence resolves under the main public checkout `.agent_temp/0.14-plan-run/evidence/S07/public-agent-temp/`; the exact private return receipt is in `evidence/S07/private-receipt/`. Only the documented throwaway AOT pinned-tree checkout was omitted from the archive, with its binary sizes/results retained in the verification receipt. The integrated data was regenerated for S06's header slot and showed exactly that one slot-list addition. **Traced from:** S07 feature `e0ebe4f`, merge `4180058`. **Date:** 2026-11-18.
