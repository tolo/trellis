# Product Requirements Document: Trellis UI – Tier 1 Slice (0.14)

> **Source**: the 0.14 draft PRD (private planning repo, pruned)
> **Context**: [Linear milestone 0.14](https://linear.app/leafnode/project/trellis-44dd4c9afca7); release sequence in [DECISIONS.md](../../DECISIONS.md) § Still Current (2026-09-02); clarified with the owner 2026-10-16 – 2026-10-19; amended 2026-10-20 and 2026-10-21 with the plan's Step 1 and Preflight answers
> **Related Assets**: [ADR-012 Trellis UI contract](../../adrs/ADR-012-trellis-ui-contract.md) (the decided design: delivery, seed, styling surface, behaviour layer, gates, sync); [ADR-014](../../adrs/ADR-014-component-composition-primitives.md) and the [0.13 PRD](https://linear.app/leafnode/issue/LEA-16) (prerequisite); [ADR-011](../../adrs/ADR-011-htmx-version-policy.md) amendment 2026-10-04 (self-hosted htmx); research 11 (private planning repo: `~/Repos/home/trellis/research/11-trellis-ui-packaging-spike.md`), 12 (private planning repo: `~/Repos/home/trellis/research/12-trellis-ui-csp-spike.md`), 13 (private planning repo: `~/Repos/home/trellis/research/13-trellis-ui-behaviour-layer-spike.md`), 14 (private planning repo: `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/brief.md`) incl. the build-own cost map (private planning repo: `~/Repos/home/trellis/research/14-trellis-ui-seed-reevaluation/build-own-cost-map.md`)


## Executive Summary

- **Problem**: A Trellis app author who wants polished, accessible components today hand-writes them (the todo example carries 417 lines of its own CSS) or adopts a third-party kit that brings Node, a CDN or inline script, and none of the evaluated kits meets Trellis's no-Node, strict-CSP, single-binary constraints (ADR-012 § Context).
- **Vision**: An app author adds `trellis_ui`, composes screens from Trellis fragments and tokens with the shadcn look, and ships one AOT binary under `script-src 'self'; style-src 'self'` with no Node anywhere.
- **Target Users**: Dart developers building admin panels and internal tools (CRUD, forms, tables) and developers building public web apps on Trellis.
- **Success Metrics**: admin example has 0 provider classes and ≤ 50 lines of app CSS; 0 CSP violations under the strict policy across suite, example and all three app scaffolds; a scaffolded UI project renders with 0 manual steps; one upstream sync completes with gates green.

### Capabilities at a Glance
- **FR1: Porting pipeline and sync skill** _(Must / P0)_ – regenerate the suite's CSS from a pinned shadcn tag without Node, and run a reviewed sync.
- **FR2: `trellis_ui` package and delivery** _(Must / P0)_ – a lockstep package embedding fragments and CSS/JS, served same-origin, optionally materialized.
- **FR3: Behaviour components** _(Must / P0)_ – dialog/alert dialog, dropdown menu, combobox, toast, tabs.
- **FR4: CSS-only components, layout primitives, overrides** _(Must / P0)_ – 15 CSS-only components, 4 layout primitives, touch-target layer, contrast override, style isolation.
- **FR5: Qualification gate** _(Must / P0)_ – every FR3/FR4 component passes ADR-012's gate before it is documented as supported.
- **FR6: Strict-CSP scaffolds and UI option** _(Must / P0)_ – all three app scaffolds pass the strict policy; `trellis create` gains a UI option.
- **FR7: Admin example app** _(Must / P0)_ – a new example builds CRUD screens from suite fragments and tokens only.
- **FR8: Component reference docs and docs-site adoption** _(Must / P0)_ – one reference page per qualified component, rendering live suite examples.
- **FR9: Dev reload for CSS/JS** _(Should / P1)_ – the dev server reloads the browser on static CSS/JS changes.
- **FR10: Natural-template preview assets** _(Should / P1)_ – suite assets reach `file://` previews via `static/trellis-ui/`.
- **FR11: Suite components in `trellis_site` themes** _(Could / P2)_ – search combobox, dark/light toggle, code-copy button; TD-021. First to move to 0.15.

### Scope Highlights
- **In scope**: pipeline + one reviewed sync, the 20-component slice + 4 layout primitives, strict-CSP scaffolds with a UI option, admin example, component docs.
- **Out of scope**: Tier 2 recipes (Cally, Tabulator, Uppy) – next minor; public-web extras (sheet/drawer, navigation menu, tooltip, accordion) – 0.15.
- **MVP boundary**: FR1–FR8; FR9–FR10 are small DX stories; FR11 moves to 0.15 first if the release runs long.

### Key Constraints, Assumptions & Dependencies
- *Dependency:* 0.13 composition primitives (`tl:slot`, `tl:attrs`, `...rest`, bare-name `renderFragment`) shipped; Tier 1 authoring starts after they land (ADR-012 § First component slice).
- *Constraint:* no Node/npm in consumer or Trellis toolchains; the pinned Tailwind standalone CLI runs only inside the porting pipeline (ADR-012 § Constraint clarifications).
- *Constraint:* one maintainer (sdk-vision § Proportionality); the gate's manual screen-reader passes re-run only when a component's markup or behaviour changes.
- *Constraint:* the plan executes unattended; every in-plan accessibility, UI and visual check is headless, and the manual screen-reader passes, the Safari pass and the sync-report review happen at release prep (owner, 2026-10-20).


## Problem Definition

### Problem Statement
Trellis renders HTML and swaps it with HTMX, but gives app authors no components. An author building a CRUD screen either hand-writes every control (the todo example: 417 lines of `styles.css`, plus its own dialog wiring) or adopts a kit whose requirements break Trellis's promise: npm builds, CDN scripts, inline handlers that `script-src 'self'` blocks (Basecoat's toast), runtime `<style>` injection that `style-src 'self'` blocks (Vaadin), or Shadow DOM that breaks form and label wiring (ADR-012 § Context, research/12, research/14). If nothing changes, every Trellis app looks hand-rolled or quietly relaxes its CSP, and the "no JavaScript toolchain" positioning does not reach the UI layer.

### Target Users
- **Admin and internal-tool builders** (sdk-vision audience 3): list, filter, sort, page, edit and delete records; need tables, forms, dialogs, menus, toasts.
- **Public web app builders** (sdk-vision audiences 1–2): Dart/Flutter developers expanding to the web and developers leaving JavaScript toolchains; need the same controls with a polished, responsive, touch-friendly look.

### Desired Outcome
An app author depends on `trellis_ui`, composes screens from its fragments, restyles through shadcn tokens and `trellis-*` part classes, and deploys one AOT binary that serves every UI asset same-origin under a strict CSP. Hand-written component CSS/JS in app code is gone; app CSS shrinks to layout and brand tweaks. A new project gets this from `trellis create`. Trellis keeps the look current with shadcn through a reviewed sync rather than hand restyling.

### Evidence & Context
- ADR-012 accepted 2026-10-04 after four spikes; the O6 shadcn port passed 35/35 Chrome and 40/40 Firefox behaviour gates at 14.5 KB gzip with 242 hand-written JS lines, and two syncs cost at most 4 template, 3 CSS lines and one config entry (ADR-012 § Context).
- Safari and VoiceOver have no evidence yet: Safari automation hung in the 2026-10 spikes (ADR-012 § First component slice).
- Upstream vega's destructive button measures 4.02:1 contrast, below AA (ADR-012 § First component slice).
- Current scaffolds load htmx from jsDelivr and allow `'unsafe-inline'` in `scriptSrc` (Shelf, Dart Frog) for an inline CSRF script; `CspBuilder` defaults `styleSrc` to `'self' 'unsafe-inline'`; no strict preset exists; TD-018 (htmx indicator styles under strict CSP) and TD-017 are open.
- The dev loader watches `.html` only; `trellis_dev` sends a reload on template changes only.


## Success Metrics

| Metric | Baseline | Target | How observed |
|--------|----------|--------|--------------|
| App-authored CSS needed for a CRUD screen set | 417 lines (todo example `styles.css`), 0 suite | ≤ 50 lines app CSS, 0 lines app component JS, at 0.14.0 | Line count of the admin example's own static CSS/JS |
| Provider classes or attributes in app templates | n/a | 0 in the admin example and the UI scaffold, at 0.14.0 | Scan for `cn-`, Tailwind utilities, `data-slot` authored in app templates |
| CSP violations under `script-src 'self'; style-src 'self'` | Scaffolds need jsDelivr and `'unsafe-inline'` | 0 across suite pages, admin example and all three app scaffolds, at 0.14.0 | Browser console/report-only capture in the gate and example tests |
| Steps from `trellis create` (UI option) to a rendered component page | unknown (manual today) | 0 manual steps after `dart run`, at 0.14.0 | Scaffold test that creates, runs and loads the example page |
| Upstream sync cost | 2 spike syncs: ≤ 4 template, ≤ 3 hand CSS lines | One sync end-to-end in 0.14 with all local gates green and its report reviewed by the owner at release prep; hand edits within the spike's range | The sync report |
| AOT deployability | research/11 packaging spike | The admin example binary, moved away from the repo and pub cache, serves all suite assets | Release check |


## Scope

### In Scope
- Porting pipeline, local sync gates and sync skill in trellis-public; one sync completed.
- `trellis_ui` package: embedded fragments and CSS/JS, same-origin serving, optional materialization.
- Components with behaviour: dialog (incl. alert dialog), dropdown menu, combobox, toast, tabs.
- CSS-only components: button, input, textarea, field/label, native select, checkbox, radio, switch, badge, card, alert, table, pagination, breadcrumb, separator.
- Layout primitives: stack, cluster, grid, container/sidebar.
- Touch-target layer; destructive-colour contrast override; style isolation from non-suite markup.
- Strict-CSP scaffolds: self-hosted htmx, a strict CSP preset, TD-018 fix, CSRF script as a same-origin file; `trellis create` UI option.
- New admin example app.
- One reference page per qualified component on the docs site, with live examples.
- Dev reload on static CSS/JS changes; `static/trellis-ui/` preview assets.
- Suite components in `trellis_site` themes (FR11), cut first.
- `trellis dev` static-site preview (build, watch, browser reload, root-served); added by the owner on 2026-11-18,
  outside the UI slice. Record it in the Linear PRD at release prep.

### Out of Scope
- Tier 2 recipes (Cally, Tabulator, Uppy, AG Grid fallback) – next minor (roadmap sequence 2026-09-02).
- Sheet/drawer, navigation menu, tooltip, accordion, command palette, rich (custom listbox) select – 0.15 or later.
- A second verified shadcn style – on application request only (ADR-012).
- Registry/ejection, provider packs, CI sync gates – ADR-012 revisit triggers.
- CSS purging interaction (`0.next-css-processing`).
- Per-component bundling – one aggregate CSS/JS bundle (ADR-012 § Neutral).
- Exit animations, submenus, toast stacking/swipe, RTL – not ported in O6; not required in 0.14.

### MVP Boundary
FR1–FR8: a qualified slice an author can adopt from the scaffold or by hand, proven by the admin example and documented. FR9–FR10 ship with it unless time runs out; FR11 moves to 0.15 first.


## Functional Requirements

### User Stories

| ID | Story | Acceptance Criteria | Priority |
|----|-------|---------------------|----------|
| US01 | As an admin-tool builder, I want table, pagination, field, dialog, dropdown and toast fragments, so that I build list/edit/delete screens without writing component CSS or JS | The admin example implements list with filter, sort and paging, edit in a dialog, delete with an alert-dialog confirm, and a result toast, using suite fragments only (FR7) | Must / P0 |
| US02 | As a public web app builder, I want the components to meet touch, zoom and screen-reader expectations, so that my site works on phones and for assistive tech | Every component passes FR5, incl. ≥ 44 px targets under `(pointer: coarse)` | Must / P0 |
| US03 | As a new user, I want `trellis create` to give me a working UI project, so that I start from a page that already uses the suite under strict CSP | FR6 scaffold test passes for all three app scaffolds | Must / P0 |
| US04 | As an app author, I want to restyle the suite with a shadcn theme block and `trellis-*` classes, so that my brand applies without forking managed files | A pasted shadcn theme block changes the admin example's colours and radius with no other edit | Must / P0 |
| US05 | As an app author, I want a reference page per component, so that I know its fragment name, parameters, slots, part classes, tokens and keyboard behaviour | FR8 | Must / P0 |
| US06 | As the maintainer, I want a sync run by a coding agent that ends in a report, so that keeping up with shadcn costs a review, not a restyle | FR1 | Must / P0 |
| US07 | As an app author, I want the browser to reload when I edit my CSS or JS, so that styling iteration matches template iteration | FR9 | Should / P1 |
| US08 | As an app author, I want a template opened from disk to show suite styling and behaviour, so that natural-template previews keep working with components | FR10 | Should / P1 |
| US09 | As a `trellis_site` user, I want themes to offer search, dark/light toggle and code copy from the suite, so that sites get the same qualified components | FR11 | Could / P2 |

### Feature Specifications

#### FR1: Porting pipeline and sync skill
**Description**: Scripts and a project skill in trellis-public that take a pinned shadcn tag (Base UI base, `style-vega.css`, `tailwind.css`, colour tokens, vendored with the MIT notice), rename `cn-` hooks to `trellis-`, compile with the pinned Tailwind standalone CLI, and commit the generated CSS. The sync skill bumps the tag, regenerates, runs the local gates, triages each upstream change, and writes a sync report (ADR-012 § Upstream sync, § Porting pipeline).

**Acceptance Criteria**:
- [ ] When the pipeline runs on the pinned tag, it shall regenerate the committed CSS byte-for-byte (regeneration gate).
- [ ] When a sync runs, the pipeline shall run slot parity, behaviour gates, a per-state appearance check per component, and the regeneration gate locally, and the skill shall write a sync report listing each upstream change as mechanical, hand-layer edit, or new component (port / defer / skip).
- [ ] The appearance check shall compare a computed-style digest per component state (default, hover, focus, open, disabled, as each component has them, extending `tool/visual_baseline.dart`'s capture to forced states), and the sync report shall include a token diff listing every token whose value changed.
- [ ] Before the appearance check is relied on, it shall detect the three regressions only the spike's screenshots caught (the secondary button's hover colour, the `--destructive`/dark token change at shadcn 4.0.0, two overlapping toasts, checked by a two-toast state and the harness's no-overlap check); a state whose regression neither check sees shall get a pixel diff (owner, 2026-10-21).
- [ ] The pipeline shall report structural classes with no `cn-` hook, and every parity-ignore entry shall carry a recorded reason.
- [ ] If the Tailwind CLI binary's checksum does not match the pin, then the pipeline shall stop before generating.
- [ ] If an upstream change renames a hook behind a public `trellis-*` class, then the sync report shall flag it as a breaking change for the changelog.
- [ ] If a sync gate fails, then the sync report shall list the failure, and the sync shall not be committed until each failure is fixed or triaged with a recorded reason.
- [ ] If any upstream change in the sync report is untriaged or any gate failure lacks a recorded reason, then the pipeline's report check shall refuse the sync commit (owner, 2026-10-21).
- [ ] Build, tests and release outside the pipeline shall not invoke the Tailwind CLI or Node.

**Inputs / Outputs**: pinned tag and checksums → generated CSS, updated templates, sync report.
**Priority**: Must / P0

#### FR2: `trellis_ui` package and delivery
**Description**: A publishable package in the lockstep set (ADR-009) whose generated Dart carries fragment templates and CSS/JS as base64 constants with sha256 digests; apps depend on it to render suite fragments and serve its assets same-origin. Optional materialization writes the assets beside the binary, overwriting divergence at startup (ADR-012 § Decision).

**Acceptance Criteria**:
- [ ] When an app depends on `trellis_ui` and wires it into its engine and server, the app shall render suite fragments and serve the suite CSS and JS from its own origin under `/trellis-ui/…`, with no file outside the binary.
- [ ] When materialization is enabled and a materialized file differs from its embedded digest, the runtime shall overwrite it at startup.
- [ ] If materialization is enabled and the target directory cannot be created or written, then startup shall fail with a message naming the path.
- [ ] The suite shall ship as one classic, import-free script and one aggregate stylesheet, plus the htmx indicator stylesheet (FR6).
- [ ] If an app references a suite fragment name that does not exist, then rendering shall fail with the engine's existing `FragmentNotFoundException`.
- [ ] `trellis` core shall not depend on `trellis_ui`; the release script shall version `trellis_ui` with the lockstep set.

**Inputs / Outputs**: app engine/server setup → rendered fragments, same-origin asset responses, optional files on disk.
**Priority**: Must / P0

#### FR3: Behaviour components
**Description**: Dialog (incl. alert dialog), dropdown menu, combobox (HTMX-populated), toast (in-page and out-of-band from one definition, using 0.13 bare-name rendering), and tabs, as fragments wrapped in light-DOM custom elements (`display: contents`) reproducing the Base UI `data-*` contract the vega CSS selects on (ADR-012 § Decision item 3, Tier 1 seed).

**Acceptance Criteria**:
- [ ] Each component shall follow its WAI-ARIA APG pattern's keyboard interaction (dialog focus trap and return, menu-button keys incl. type-ahead, combobox `aria-activedescendant`, tabs roving focus).
- [ ] When a component's markup is swapped in, swapped repeatedly, or restored from HTMX history, it shall initialise and clean up without a forced re-init.
- [ ] When a dialog the server rendered with `open` connects (page load or HTMX swap), it shall open modally via `showModal()`, since a server-rendered `<dialog open>` is otherwise non-modal (research/14 build-own cost map).
- [ ] One toast fragment definition shall render both in-page and as an out-of-band response.
- [ ] If the combobox's HTMX request fails or returns no options, then the combobox shall announce no results and keep the typed value.
- [ ] CSSOM-positioned popups shall drop their `style` attribute before `htmx:beforeSwap` and `htmx:beforeHistorySave`.

**Inputs / Outputs**: fragment parameters, slots, pass-through attributes → server-rendered markup, client behaviour.
**Priority**: Must / P0

#### FR4: CSS-only components, layout primitives, overrides
**Description**: The 15 CSS-only components in Scope, the four layout primitives (authored by Trellis; shadcn has none), the touch-target layer, and a destructive-colour override, all through the public styling surface (shadcn token names, `trellis-<component>[-<part>]` classes).

**Acceptance Criteria**:
- [ ] Each CSS-only component shall render from a fragment with semantic native elements (e.g. `<button>`, `<table>` with `<caption>`/`<th scope>`, `<nav aria-label>` for pagination and breadcrumb).
- [ ] Under `(pointer: coarse)` every interactive control shall measure ≥ 44 px, elsewhere ≥ 24 px, and inputs shall use a 16 px font on coarse pointers.
- [ ] The destructive variant's text and background shall meet 4.5:1 contrast in light and dark modes.
- [ ] When the suite stylesheet loads on a page, markup outside suite components shall render with unchanged computed styles.
- [ ] When an app pastes a shadcn theme block, the suite shall apply its tokens with no other change.
- [ ] If a layout primitive's visual order would differ from DOM order, then the primitive shall not offer that option.

**Inputs / Outputs**: fragment parameters and slots → markup; tokens → styling.
**Priority**: Must / P0

#### FR5: Qualification gate
**Description**: ADR-012's bounded gate per component: permissive provenance, self-hosting, strict CSP, semantic markup, HTMX lifecycle, keyboard, automated WCAG A/AA (axe), screen-reader passes on VoiceOver + Safari and NVDA + Firefox (Windows VM on the maintainer's Mac), forced colours, responsive (390 / 768 / 1440), zoom, reduced motion, touch target, visual. Every automated item runs headless (Chrome over the DevTools protocol, Firefox through geckodriver) inside the unattended plan; the screen-reader passes and the Safari pass are manual and run at release prep (owner, 2026-10-20).

**Acceptance Criteria**:
- [ ] A component shall be listed as supported in docs and the changelog only after every gate item passes, with the result recorded per component.
- [ ] Automated checks (axe, keyboard, emulated forced colours/zoom/reduced motion) shall run headless per release; manual screen-reader passes shall run at release prep and re-run when a component's markup or behaviour changes.
- [ ] Safari shall be covered by a recorded manual pass at release prep; 0.14 adds no Safari automation.
- [ ] If a component fails the gate at release time, then it shall ship undocumented as unsupported or be removed, and the failure shall be recorded as an ADR-012 revisit trigger.
- [ ] If a component the admin example requires (FR7: dialog, dropdown menu, combobox, tabs, toast) fails the gate, then 0.14.0 shall not ship until it passes; the example uses supported components only.

**Inputs / Outputs**: component pages → per-component gate record.
**Priority**: Must / P0

#### FR6: Strict-CSP scaffolds and UI option
**Description**: All three app scaffolds (Shelf, Relic, Dart Frog) meet `script-src 'self'; style-src 'self'`: htmx self-hosted by default with CDN opt-in (ADR-011 amendment 2026-10-04), the inline CSRF script moved to a same-origin file, `htmx.config.includeIndicatorStyles = false` with same-origin indicator CSS (TD-018), and a strict preset in the security-headers builder. `trellis create` gains a `--ui` flag, valid with the htmx (Shelf), relic and dart_frog templates, that adds `trellis_ui` and an example page.

**Acceptance Criteria**:
- [ ] When a project is created with any app scaffold, its pages shall load with 0 CSP violations under the strict preset.
- [ ] When a project is created with the UI option on any of the three app scaffolds, `dart run` shall serve a page rendering suite components with 0 manual steps.
- [ ] The pages of each UI scaffold shall pass the same gate items as FR7's pages (owner, 2026-10-21).
- [ ] The security-headers builder shall offer a strict preset with no `'unsafe-inline'` in `script-src` or `style-src`.
- [ ] If a user opts into CDN htmx, then the generated CSP shall allow exactly that CDN origin.
- [ ] The default (non-UI) scaffold shall keep working without `trellis_ui`.
- [ ] If `--ui` is passed with a template other than htmx, relic or dart_frog, then the CLI shall exit with a usage error naming those three templates.

**Inputs / Outputs**: `trellis create` flags → generated project.
**Priority**: Must / P0

#### FR7: Admin example app
**Description**: A new app under `examples/` (records list such as contacts or inventory) built from suite fragments and tokens only. `todo_app` stays unchanged as the app-conventions baseline.

**Acceptance Criteria**:
- [ ] The example shall implement list with filter, sort and paging (server round-trips via HTMX), edit in a dialog with field validation errors, delete with an alert-dialog confirm, row actions in a dropdown menu, a combobox field, tabs, and a result toast.
- [ ] Its templates shall contain 0 provider classes or attributes, and its own static CSS shall be ≤ 50 lines with 0 lines of component JS.
- [ ] It shall run under the strict CSP preset with 0 violations and build as an AOT binary that serves all assets when moved away from the repo.
- [ ] Its pages shall pass every browser-run FR5 gate item (strict CSP, semantic markup, HTMX lifecycle, keyboard over the page's flows, axe, forced colours, responsive, zoom, reduced motion, touch target; visual only where a page baseline exists), run headless, because composed screens expose problems per-component gates miss, such as focus after an htmx swap (owner, 2026-10-21).
- [ ] If a form submit fails validation, then the dialog shall stay open with errors linked by `aria-describedby` and focus moved to the first error.

**Inputs / Outputs**: in-memory records → pages and fragments.
**Priority**: Must / P0

#### FR8: Component reference docs and docs-site adoption
**Description**: One reference page per qualified component on the docs site, rendering live suite examples; the live examples are the docs site's adoption of the suite. FR8 owns the seam that lets a `trellis_site` build render `trellis_ui` fragments and include its assets; FR11 reuses it. The seam is a generic `trellis_site` hook for extra fragment sources and static assets, so `trellis_site` does not depend on `trellis_ui`; `trellis_cli` depends on `trellis_ui` and plugs it into the hook when a site or theme opts in (owner, 2026-10-20).

**Acceptance Criteria**:
- [ ] Each page shall state the fragment name, parameters, slots, pass-through behaviour, public part classes, tokens used, keyboard interaction, and accessibility notes from the gate record.
- [ ] Each page's fragment signature, slots, part classes and gate results shall be generated from the `trellis_ui` package and its gate records, and a check shall fail when the generated data is stale; pass-through behaviour, tokens used and keyboard interaction are written per page, with token names checked against the shipped stylesheet (owner, 2026-10-21).
- [ ] Each page shall render at least one live example from `trellis_ui`, not a static copy of its markup.
- [ ] When a docs page shows its dark skin (chosen, or `auto` with the OS preferring dark), its live examples shall render in the suite's dark mode, and they shall switch when the shown skin changes (owner, 2026-10-21).
- [ ] A guide shall cover adding `trellis_ui` to an existing app, theming with a shadcn theme block, and the `cn-` → `trellis-` mapping for porting another shadcn style.
- [ ] If a component is not qualified at release, then it shall have no reference page.

**Inputs / Outputs**: `trellis_ui` fragments → docs pages.
**Priority**: Must / P0

#### FR9: Dev reload for CSS/JS
**Description**: In dev mode, changes to the app's static CSS and JS trigger the same browser reload template changes trigger today, in the Shelf and Dart Frog scaffolds. The Relic scaffold has no dev middleware and gets no browser reload in 0.14 (owner, 2026-10-20); the scaffolds work files a tech-debt entry for it.

**Acceptance Criteria**:
- [ ] When a CSS or JS file under the app's static directory changes in dev mode, the dev server shall send a reload to connected browsers within 1 s.
- [ ] The reload client shall load as a same-origin script, so dev-mode pages keep 0 violations under the strict preset.
- [ ] Reload shall work on macOS and Linux (recursive `Directory.watch` is silent on Linux; LEARNINGS).
- [ ] If the static directory does not exist, then dev mode shall start and watch templates only.

**Inputs / Outputs**: file change events → SSE reload.
**Priority**: Should / P1

#### FR10: Natural-template preview assets
**Description**: Suite CSS/JS are written to a gitignored preview folder – `static/trellis-ui/` in the Shelf and Relic scaffolds, `public/trellis-ui/` in Dart Frog's – when dev mode starts (Shelf and Dart Frog; Relic has no dev middleware), and by a command on demand in all three, Relic's only writer (owner, 2026-10-21), so a template opened from disk links them by relative `href`/`src` paired with `tl:href`/`tl:src` pointing at the served `/trellis-ui/…` path (app-conventions intent, research/13).

**Acceptance Criteria**:
- [ ] When dev mode starts in the Shelf or Dart Frog scaffold, the folder shall hold the embedded assets matching their digests.
- [ ] When a template is opened via `file://`, markup in that file carrying `trellis-*` classes shall be styled and suite behaviour that needs no network request shall run (classic script). Suite fragments pulled in by `tl:insert`/`tl:replace` and HTMX requests are outside preview scope.
- [ ] The UI scaffold shall gitignore the folder.
- [ ] If the folder holds a file that differs from its digest, then dev start and the CLI command shall overwrite it.

**Inputs / Outputs**: embedded assets → files in `static/trellis-ui/`.
**Priority**: Should / P1

#### FR11: Suite components in `trellis_site` themes
**Description**: Using the `trellis_site` → `trellis_ui` seam FR8 delivers, themes adopt a search combobox over the `trellis_site` search client (moved into `trellis_site` under TD-021), the reader dark/light toggle in lattice, folio and meadow, and arbor's code-block copy button.

**Acceptance Criteria**:
- [ ] When a theme uses a suite component, the built site shall include the suite assets, and the suite assets shall cause 0 violations under the strict policy. The themes' inline anti-FOUC script (TD-023) stays out of scope.
- [ ] Arbor, folio and lattice shall use one `trellis_site` search client with one hook, replacing their per-theme `search.js` copies.
- [ ] Sites whose theme uses no suite component shall build with no `trellis_ui` assets.
- [ ] If FR11 is cut from 0.14, then FR1–FR10 shall not depend on it.

**Inputs / Outputs**: theme templates → built static site.
**Priority**: Could / P2

### User Flows
1. **New project**: `trellis create --ui` → `dart run` → example page with suite components under strict CSP.
2. **Existing app**: add `trellis_ui` → wire engine and asset serving per the guide → replace hand-written controls with fragments → delete app component CSS.
3. **Theming**: paste a shadcn theme block → override tokens or `trellis-*` classes in an app-first file.
4. **Maintainer sync**: agent runs the sync skill → gates run locally → failures fixed or triaged with a reason → commit with the sync report → owner reviews the report at release prep.
5. **Failure**: a component fails the gate before release (automated in the plan, manual at release prep) → it ships unsupported and undocumented, and the revisit trigger is recorded.

### UI Wireframes
None. The look comes from shadcn's vega style and the docs site's existing layout; no design pass before planning (Decisions Log).


## Non-Functional Requirements

| Category | Requirement | Threshold / Target |
|----------|-------------|--------------------|
| Security | Strict CSP across suite, example, scaffolds | 0 violations under `script-src 'self'; style-src 'self'` |
| Accessibility | WCAG 2.2 AA per component and on composed pages (admin example, UI scaffolds) | axe: 0 violations (headless); SR passes on both matrix pairs, per component (release prep); contrast ≥ 4.5:1 text |
| Performance | Suite payload | ≤ 25 KB gzip for CSS + JS combined (O6: 14.5 KB for 5 components); release gate (owner, 2026-10-20) |
| Isolation | No effect outside suite markup | 0 computed-style changes on non-suite elements of a fixture page |
| Portability | AOT deploy | All assets served from the binary alone |
| Maintainability | Owned JS | ≤ 400 hand-written JS lines for the five behaviour components (O6: 242 for four of them plus field); release gate |
| Browsers | Support | Current Chrome, Firefox, Safari; mobile Safari and Chrome at 390 px |


## Edge Cases

| Scenario | Expected Behavior | Recovery Path |
|----------|-------------------|---------------|
| A suite fragment is inserted twice on one page | No duplicate literal `id`s; ids derive from parameters (LEARNINGS: twice-inserted fragment ids) | Docs state the id parameter rule |
| Browser without CSS anchor positioning | Dropdown and combobox position via the shared CSSOM helper | — |
| An app shadows a managed fragment | Unsupported (ADR-012 override seam); docs say so | Use tokens, part classes, extension classes, composition |
| Materialized folder edited by hand | Overwritten at next start | Edit app-first override files instead |
| Upstream re-implements a component (e.g. toast) | Sync report marks it port / defer / skip; the current component keeps working | Port in a later release |
| HTMX 4 instead of 2 | Indicator config uses `includeIndicatorCSS` | — |
| A release-prep screen-reader or Safari pass fails on a component the admin example needs | 0.14.0 does not ship (FR5) | A standalone fix on the 0.14 branch, then that component's manual pass re-runs (owner, 2026-10-21) |


## Constraints & Assumptions

### Constraints
- No Node/npm in consumer or Trellis toolchains; pinned non-Node binaries only inside the pipeline (ADR-012).
- Provider selectors, attributes, events and types are not public API, except shadcn token names (ADR-012).
- Lockstep versioning; `trellis_ui` releases as 0.14.0 with the set (ADR-009).
- Light DOM only in Tier 1; one classic script (ADR-012).
- Sync gates run locally, no CI gates (ADR-012).
- One maintainer.
- The plan executes unattended: in-plan accessibility, UI and visual checks are headless; committed gate code runs without Node (Dart driving headless Chrome and Firefox), while agents may validate by eye with the tools in trellis-public `AGENTS.md` § UI testing. Manual screen-reader passes, the Safari pass and the sync-report review are release-prep work (owner, 2026-10-20).

### Assumptions
- 0.13 ships ADR-014's syntax unchanged in substance; a change during 0.13 implementation amends FR3/FR4 fragment shapes, not scope.
- Windows 11 ARM in a VM on the maintainer's Mac runs NVDA + Firefox well enough for the gate (owner, 2026-10-19).
- The docs site adopts the suite through FR8's live examples, so FR8 does not depend on FR11 (lattice, the docs-site theme, adopting suite components); FR8 owns the seam (a generic `trellis_site` hook that `trellis_cli` plugs `trellis_ui` into).

### Dependencies

| Dependency | Why It Matters |
|------------|----------------|
| 0.13 composition primitives | Tier 1 authoring and the one-definition toast need slots, spreading, pass-through, bare-name rendering |
| shadcn/ui Base UI base + `style-vega.css` (MIT) | Seed for generated CSS and the `data-*` contract |
| Tailwind standalone CLI (pinned, checksummed) | Pipeline compile step |
| htmx (self-hosted, SRI-pinned) | Lifecycle and scaffolds |
| Windows VM with NVDA + Firefox; Safari and VoiceOver on the maintainer's Mac | FR5 screen-reader and Safari items, at release prep |
| App-conventions todo experiment (during 0.13) | May amend FR10's folder convention |


## Open Questions

- Should date picking become a Tier 1 port of shadcn's Calendar instead of the Cally Tier 2 recipe? shadcn ships Calendar (single and range modes, wrapping React DayPicker) and a Date Picker composed from Popover + Calendar, so a port gets the look from the pipeline but owns the date-grid behaviour. This changes ADR-012's Tier 2 shortlist; decide before the Tier 2 release.
- Can the pipeline drop or scope Tailwind's preflight so suite CSS leaves non-suite markup unchanged (FR4 isolation), given vega's rules on `body`, `:root` and `.dark`? Settled by the pipeline story's first step against FR4's isolation fixture, no separate spike (2026-10-20). FR4 isolation stays a Must: preflight resets the components rely on are scoped to suite elements, and if that proves impossible the run stops for an owner decision rather than relaxing the requirement (owner, 2026-10-21).
- What example page does `trellis create --ui` generate for the Shelf, Relic and Dart Frog scaffolds? Plan.


## Decisions Log

| Decision | Rationale | Alternatives Considered |
|----------|-----------|-------------------------|
| 0.14 = Stage 1 (pipeline) + Stage 2 (Tier 1 slice) | Tier 2 recipes do not depend on the slice; sequence 2026-09-02 (owner, 2026-10-16) | Smaller slice; Stages 1–3 |
| Tier 2 stays, smaller in practice | shadcn has no tree or multi-upload; its data table is a TanStack guide, served for CRUD by server-driven Table + Pagination; date picker routed to an Open Question (owner asked, 2026-10-16) | Drop Tier 2 |
| Both admin and public-web builders are primary users | Owner, 2026-10-16 | Admin only; Trellis's own sites |
| Slice: 5 behaviour + 15 CSS-only components + 4 layout primitives | Covers the CRUD demo; public-web extras to 0.15 (owner, 2026-10-16) | Draft's six; adding sheet, navigation menu, tooltip, accordion |
| Done = CRUD demo + scaffold option + component docs + docs site + theme components | Owner, 2026-10-16 | Subsets |
| Theme components (FR11) in 0.14, first to move to 0.15 | Independent of suite qualification (owner, 2026-10-16) | Out of 0.14; one component only |
| Suite CSS has no effect outside suite markup | Themes, docs site and existing apps keep their base CSS (owner, 2026-10-16) | Opt-in page reset; page-wide preflight |
| Strict CSP for all three app scaffolds | Owner, 2026-10-16 | Relic only; UI scaffold only |
| New admin example; `todo_app` unchanged | Exercises table and pagination; keeps the app-conventions baseline (owner, 2026-10-19) | Convert `todo_app`; both |
| Dev reload on CSS/JS, full reload | Small story; load-bearing for DX (owner, 2026-10-19) | CSS hot-swap; defer |
| Preview assets in gitignored `static/trellis-ui/`, written at dev start and by CLI | App-conventions intent recommendation; the experiment may amend (owner, 2026-10-19) | Wait for experiment; CLI only |
| NVDA pass in a Windows VM on the maintainer's Mac | Owner, 2026-10-19 | Separate machine; hosted service |
| Admin-example components failing the gate block 0.14.0 | The example and its metrics must stand on supported components (owner, 2026-10-19, review note) | Ship with an unsupported-component note |
| FR11 strict-CSP criterion covers suite assets only; TD-023 stays separate | Owner, 2026-10-19, review note | Pull TD-023 into 0.14 |
| No design pass before planning | Look comes from vega and the docs site layout (owner, 2026-10-19) | Wireframe example and reference page first |
| Unattended plan; in-plan checks headless; manual screen-reader, Safari and sync-report review at release prep | Owner wants the plan to run without stops (owner, 2026-10-20, plan Step 1); ADR-012's screen-reader matrix still applies before a support claim | Stop the plan for manual passes per component story or in a final story |
| Sync appearance check = computed-style digest per forced state + token diff | Deterministic, names the changed property, reuses `tool/visual_baseline.dart`; the spike's screenshot-only catches were a hover colour, a token change and two overlapping toasts; a per-state digest and a token diff see the first two, a two-toast state with a no-overlap check the third (planner's inference, not run) (owner, 2026-10-20); proven by replaying the spike's three screenshot-only regressions, with a pixel diff only for a state the digest misses (owner, 2026-10-21) | Pixel diff per state; both |
| Safari covered by a recorded manual pass at release prep | Safari has no headless mode and safaridriver hung in the spikes (owner, 2026-10-20) | Time-boxed safaridriver attempt |
| `trellis_site` gains a generic hook for extra fragment sources and static assets; `trellis_cli` wires `trellis_ui` in | Keeps `trellis_site` standalone (sdk-vision principle 2); the CLI binary grows by about 1.33× the suite's raw (ungzipped) fragments and assets, from base64 (owner, 2026-10-20) | `trellis_site` depends on `trellis_ui`; copy suite files into the site |
| ≤ 50 lines admin-example CSS, ≤ 25 KB gzip suite CSS+JS, ≤ 400 behaviour JS lines are release gates | Scaled from O6 (14.5 KB, 242 lines); a miss blocks 0.14.0 until fixed or the limit is amended (owner, 2026-10-20) | Measured targets only |
| FR9 covers Shelf and Dart Frog; Relic gets no browser reload in 0.14 | Relic's scaffold has no dev middleware; filed as a tech-debt entry with the scaffolds work (owner, 2026-10-20) | All three scaffolds |
| Suite assets served under `/trellis-ui/…` | Mirrors the preview folder (`static/trellis-ui/`, Dart Frog `public/trellis-ui/`), so a static handler serving that folder and the embedded handler answer the same URL (planner's call, owner did not object, 2026-10-20) | A namespaced path such as `/_trellis/ui/` |
| `trellis create --ui` flag | Valid with the htmx (Shelf), relic and dart_frog templates (planner's call, owner did not object, 2026-10-20) | A separate template name per scaffold |
| Reference-page facts generated from the package and gate records, with a staleness check | Pages cannot drift from shipped signatures and part classes; follows the theme-gallery generator precedent (owner, 2026-10-21, plan Preflight) | Hand-typed facts with a page-set test |
| A report check refuses a sync commit while anything is untriaged | FR1's no-commit rule needs a mechanical stop in an unattended run (owner, 2026-10-21) | Skill checklist only |
| Full automated gate also over the admin example and the UI scaffolds | Composed screens expose problems per-component gates miss (owner, 2026-10-21) | CSP-only checks on composed pages |
| Reference-page previews follow the docs skin | Dark-mode readers see dark components (owner, 2026-10-21) | Light previews only |
