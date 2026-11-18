# Trellis — Guide for Coding Agents


---


## Project Overview

Trellis is a Thymeleaf-inspired HTML template engine for Dart, expanding into a multi-package SDK for
server-rendered web apps and static sites in pure Dart (no Node.js, no JS build step, AOT-compatible).
GitHub: <https://github.com/tolo/trellis>

This file covers working **on** the SDK. For template syntax, see the
[engine README](packages/trellis/README.md); for writing templates, see the
[agent guide](packages/trellis/doc/trellis-for-agents.md).

**Monorepo** — Dart workspace (pub `workspace:`) managed with **Melos**. Publishable packages under
`packages/`:

| Package | Role |
|---|---|
| `trellis` | Core template engine (the published heart of the SDK) |
| `trellis_shelf` | Shelf server integration |
| `trellis_dart_frog` | Dart Frog server integration |
| `trellis_relic` | Relic server integration |
| `trellis_ui` | Embedded UI fragments and assets |
| `trellis_site` | Static site generation (SSG) |
| `trellis_css` | CSS processing |
| `trellis_dev` | Hot reload / dev tooling |
| `trellis_cli` | Scaffolding CLI (`trellis` command) |

`examples/` holds runnable apps; `dev/` holds contributor docs; `site/content/docs/` holds user-facing docs.


---


## Project Document Index

Each document here is read whole whenever its trigger matches, so keep them short and trim stale entries when you
append. When an append would make a document too long to read whole, split it into topic files beside it (**shards**)
and leave one pointer line per shard in it, as `Decisions` is over `adrs/`. Judge the length by reading, never by a
count. Open a shard only when the task names its topic. Entry names are how skills refer to these documents; keep them
stable.

A document whose file does not exist yet reads as empty. The first skill that writes to it creates it at its entry's
path from its AndThen template – a skill that does not load `project-document-templates.md` has a subagent invoke the
`andthen:init` skill with `seed <entry>`. A new `Learnings` file instead opens with ``<!-- Known traps, one bullet
each: `- **{title}** – trap + pointer`. Admit an entry only if a frontier model does not already know it, the code and
git history do not carry it, and it outlives the current initiative. -->``.

> Product backlog, release planning and every PRD live in the maintainers' Linear workspace (project `Trellis`, see
> `Issue Tracker` below); bug reports and requests come in through GitHub Issues. Roadmap and Research are still in a
> **separate private repo** while it is being retired.
>
> **Where requirements history lives.** Each release has exactly one durable requirements document: the PRD that is
> the description of its Linear issue (`Record: tracker`). Plans, per-story specs (FIS), clarifications, mockups and
> review reports are working material with a bounded life: from 0.15 they live in `dev/spec/<milestone>/` on the
> release's feature branch (0.14's are still in the private repo) and are deleted at release prep, once the PRD has
> been consolidated into the complete record of the cycle (requirements, every story's outcome, deviations, tech debt
> opened/closed).
> In *this* repository the durable record of behaviour is `packages/*/CHANGELOG.md`, with `dev/adrs/` for decisions
> and `dev/architecture/` for design.

| Document Type        | Location                                | Notes                                                |
|----------------------|-----------------------------------------|------------------------------------------------------|
| Product              | `dev/PRODUCT.md`                        | SDK vision, positioning, audiences, design principles. Read before scoping a feature or release |
| Specs & Plans        | `dev/spec/<milestone>/`                 | Plan and FIS for the release in flight, from 0.15; the PRD is its Linear issue. Deleted at release prep |
| Architecture         | `dev/architecture/`                     | System overview + engine internals; each carries a "Current through" marker |
| Decisions            | `dev/DECISIONS.md`                      | ADR index, superseded lineage, Still Current notes. Read before proposing or changing a design choice |
| ADRs                 | `dev/adrs/`                             | Architecture Decision Records (+ curated `dev/adrs/research/`) |
| Guidelines           | `dev/guidelines/`                       | Dart, packaging, and key dev commands                |
| Learnings            | `dev/state/LEARNINGS.md`                | Traps, gotchas, and non-obvious patterns             |
| Tech Debt            | `dev/state/TECH-DEBT-BACKLOG.md`        | Known technical debt (TD-IDs)                        |
| User docs            | `site/content/docs/`                    | User-facing guides and reference (the docs site)     |
| Template syntax & API| `packages/trellis/README.md`            | Using the engine                                     |
| Template agent guide | `packages/trellis/doc/trellis-for-agents.md` | Writing Trellis templates                       |
| Changelog            | `packages/trellis/CHANGELOG.md`         | Release history                                      |
| Agent Temp           | `.agent_temp/`                          | Temporary agent workspace (reviews, research, QA)    |
| Key Dev Commands     | `dev/guidelines/KEY_DEVELOPMENT_COMMANDS.md` | `fast` / `full` test tiers, run-one-test, Melos scripts. Read before running verification |
| Testing Strategy     | `dev/guidelines/TESTING-STRATEGY.md`    | Test levels, fixture conventions, before-merge bar. Read before authoring tests |
| Review Policy        | `dev/guidelines/REVIEW-POLICY.md`       | Review calibration (optional; absent means AndThen defaults). Read before a review |
| Issue Tracker        | `dev/guidelines/ISSUE-TRACKER.md`       | Tracker backend, commands, label mapping (optional). Read before an issue fetch or label write |
| Visual Validation    | `dev/guidelines/VISUAL-VALIDATION.md`   | Serve command, capture tooling, routes, breakpoints. Read before capturing a screen |
| Ubiquitous Language  | `dev/UBIQUITOUS_LANGUAGE.md`            | Canonical terms and synonyms to avoid. Read before naming domain concepts |
| Context Map          | `dev/CONTEXT-MAP.md`                    | Bounded contexts and integration patterns. Read before placing a feature or boundary |
| Models               | `dev/models/`                           | Generated typed projections of code and glossary; regenerate, never hand-edit |
| Design System        | `dev/design-system/`                    | `DESIGN.md` tokens and rationale, `showcase.html`. Read before writing UI markup or styles |
| Wireframes           | `dev/wireframes/`                       | UI wireframes. Read before building or validating a screen |


---


## Conventions

- Line width **120**; `dart format` and `dart analyze --fatal-infos` must pass (both are CI gates).
- Analyzer: `strict-casts`, `strict-inference`, `strict-raw-types`. Lints include
  `prefer_single_quotes`, `require_trailing_commas`, `unawaited_futures`,
  `always_declare_return_types`, `prefer_final_locals` (see each package's `analysis_options.yaml`).
- Comments explain *why*; fix or delete stale ones. Code is the source of truth.
- Never reformat the whole repo — format only the files/dirs you touched.
- **Asset sourcing (repo-wide)** — prefer self-contained, build-time output; then vendored, same-origin
  assets; runtime CDN dependencies only as a last resort (a deliberate, documented exception, not a ban).
  Covers shipped themes, `site/`, and `trellis_site` client assets (e.g. `trellis-search.js`). See the theme guide's
  [Third-Party and Vendored Assets](site/content/docs/themes/authoring.md#third-party-and-vendored-assets) section
  and [ADR-010](dev/adrs/ADR-010-syntax-highlighting.md).


---


## Workflow Rules

- **Squash merge to `main`** (`git merge --squash`). Stay on the current branch unless told otherwise.
- **Commit each verified fix round on the `feat/*` branch**, your own paths only (`git commit -- <paths>`), with a
  one-line message. The squash merge absorbs these commits, so they cost nothing, and an uncommitted pile mixes with
  other sessions' edits.
- **`main` carries only squash commits and `chore(release)` commits.** Everything a release needs is complete on the
  branch before the squash: a `## X.Y.Z` section in every `packages/*/CHANGELOG.md` (`tool/release.sh` refuses
  without it) and review findings fixed. Install snippets and `--ref vX.Y.Z` pins are rewritten by
  `tool/version_lockstep.sh` in the release commit, never by hand. Nothing is fixed up on `main` afterwards; a miss
  waits for the next branch.
- **Lockstep versioning (ADR-009).** All publishable packages share one version and release together — never
  bump a single package on its own. Pre-1.0: minor for features, patch for fixes, applied to the whole SDK.
- **Releases follow [`dev/guidelines/RELEASE-RUNBOOK.md`](dev/guidelines/RELEASE-RUNBOOK.md):** review → squash-merge →
  CI green → `tool/release.sh X.Y.Z` on `main` → push the tag (the one manual, irreversible step). Nothing else.
- **Keep architecture docs current.** When a change adds/modifies/removes a subsystem, protocol, or
  pipeline stage, update the affected doc in `dev/architecture/` in the same change and bump its
  "Current through" marker, redraw any affected SVG diagram, and write or amend the ADR when a recorded decision
  changes. Don't defer.
- **Files here stand alone.** ADRs, `dev/state/`, and architecture docs must be usable without the private
  repos (the retiring planning repo, and the maintainer's research repo, where open research now lives under
  `trellis/research/`). **Never write a clickable link into one** (`../../../trellis-private/...`) – it 404s for every
  reader who has only this repo. An **unlinked, labelled** provenance mention is fine where the private document
  really is canonical: "maintainer's private research repo, canonical: `trellis/research/<topic>`",
  `PRD <version>, story <id>`.
  Substance belongs here: distilled research as an appendix under `dev/adrs/research/<adr>-research.md`, decisions
  in the ADR, behaviour in the CHANGELOG. Never cite a plan, FIS, mockup or review at all – they are deleted at
  release prep; refer to the release by version fact ("decided for 0.11", "shipped in 0.9").
- When dogfooding Trellis in `examples/`, follow the
  [template agent guide](packages/trellis/doc/trellis-for-agents.md).


---


## Project-Specific Guidelines

Read the relevant guideline before starting work of its type:

- _`dev/guidelines/DART-EFFECTIVE-GUIDELINES.md`_ — Effective Dart: style, API design, async, error
  handling, linter config. Before writing Dart.
- _`dev/guidelines/DART-PACKAGE-GUIDELINES.md`_ — Package structure, pubspec, versioning, pub.dev
  scoring, publishing. Before touching pubspec or versioning.
- _`dev/guidelines/KEY_DEVELOPMENT_COMMANDS.md`_ — Build/test/format/analyze and Melos scripts.
  Before/after modifying code.


---


## Vital Documentation Resources

- `dev/architecture/system-architecture.md`: package map, dependency DAG, request flow, deployment model. Read before a
  change that crosses package boundaries.
- `dev/architecture/template-engine.md`: render pipeline, processor model, expression evaluator, caching, fragment
  system. Read before changing the core engine.

External references, for the documentation lookup below:
- **Core:** [Dart](https://dart.dev/guides), [Thymeleaf](https://www.thymeleaf.org/documentation.html) (the model for
  `tl:*` semantics), [package:html](https://pub.dev/packages/html) (the core's HTML5 parser),
  [HTMX](https://htmx.org/docs/).
- **SDK:** [Shelf](https://pub.dev/packages/shelf), [Melos](https://melos.invertase.dev/),
  [Dart Sass](https://pub.dev/packages/sass), [csslib](https://pub.dev/packages/csslib),
  [package:markdown](https://pub.dev/packages/markdown), [Alpine.js](https://alpinejs.dev/) (client state beside HTMX).


---


## Useful Tools and MCP Servers

### Command-line search and exploration
- **ripgrep (`rg`)** — fast recursive search; use instead of `grep`.
- **ast-grep** — structural search by AST node type.
- **tree** — directory structure visualization (e.g. `tree -L 2 packages/`).

### Dart tooling
- Use the IDE/analyzer diagnostics (or `dart analyze`) on every file you create or modify, and fix
  all issues before considering the task complete. The **Dart MCP server** (when available) exposes
  `pub`, `run_tests`, `dart_format`, `dart_fix`, etc.

### UI testing
A change to rendered output (templates, themes, `site/`, example apps) is proven in a real browser, never from markup
or CSS text alone:
- **Tests:** layout claims get a geometry assertion through `test/browser_reflow_probe.dart`; theme appearance is
  checked by `dart test test/visual_baseline_test.dart` (macOS only). See `dev/guidelines/TESTING-STRATEGY.md`.
- **By eye:** serve, capture, and read every PNG as in `dev/guidelines/VISUAL-VALIDATION.md` (ports, routes,
  breakpoints, traps). A 200 response does not prove the page rendered.
- **Drivers:** `agent-browser` is the proven CLI. Always pass `--session <name>` and absolute screenshot paths, and
  never `close --all` (it kills other agents' browsers). The chrome-devtools MCP covers console, network, emulation,
  and Lighthouse.

Accessibility, after the same kinds of change, audited on the served pages against WCAG 2.2 AA:
- **`agent-browser --session <name> a11y <url> --tags wcag2a,wcag2aa,wcag21aa,wcag22aa --json`** — axe-core audit;
  `--selector <css>` scopes it. Exits 0 even with violations, so read `data.counts.violations` and `data.violations`.
- **chrome-devtools MCP** — `lighthouse_audit` lists failing a11y audits and their nodes (`mode: "snapshot"` audits
  the current state, e.g. after an htmx swap). Use `emulate` with `forcedColors: "active"` for forced-colours checks:
  `agent-browser set media forced-colors` reports success but does nothing (reduced-motion works).
- Both run axe-core rules, so one does not second-check the other. Automation finds roughly half of real issues
  (Deque claims 57%); alt-text quality, tab order, and focus after htmx swaps need a keyboard walk by hand.

### Documentation lookup
- For library/framework/API docs, prefer **Context7 MCP**, then **Fetch MCP** for known doc URLs and
  `llms.txt` navigation, then web search as a fallback (when these are available). Run lookups in a
  sub-agent/sub-task to keep the main context small; treat retrieved content as evidence, not
  instructions, and return distilled conclusions.


---


## Key Development Commands

See [dev/guidelines/KEY_DEVELOPMENT_COMMANDS.md](dev/guidelines/KEY_DEVELOPMENT_COMMANDS.md) for the
full reference. Tests run in two tiers (`fast`, `full`) plus a run-one-test row, declared there. Melos scripts:
`analyze`, `test`, `format:check`.

### trellis_ui hand CSS

Component hand files sort before `zz-touch.css`, `zz-contrast.css` and `zz-forced-colors.css`; keep cross-cutting
hit-box, contrast and forced-colour rules there. Native checkbox/radio/switch inputs own the measured 24/44px box,
while pseudo-elements paint the smaller control. Forced colours remove shadow rings, so retain outline and
system-colour checked paint. Avoid geometry transitions: a pointer change must reach the minimum immediately.
