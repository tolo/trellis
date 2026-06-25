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
| `trellis_site` | Static site generation (SSG) |
| `trellis_css` | CSS processing |
| `trellis_dev` | Hot reload / dev tooling |
| `trellis_cli` | Scaffolding CLI (`trellis` command) |

`examples/` holds runnable apps; `dev/` holds contributor docs; `docs/` holds user-facing docs.


---


## Project Document Index

<!-- These paths tell AndThen (https://github.com/IT-HUSET/andthen) workflow commands (clarify, spec,
     plan, trade-off, etc.) where this project keeps its documents. Paths are relative to repository
     root. Workflow commands read this table to determine where to find and write output. -->

> Planning docs (Product, Roadmap, Specs/PRDs, Research, Product Backlog) are maintained in a
> **separate private repo** and are not in this repository. The rows below cover what lives here.

| Document Type        | Location                                | Notes                                                |
|----------------------|-----------------------------------------|------------------------------------------------------|
| Architecture         | `dev/architecture/`                     | System overview + engine internals; each carries a "Current through" marker |
| Decisions / ADRs     | `dev/adrs/`                             | Architecture Decision Records (+ curated `dev/adrs/research/`) |
| Guidelines           | `dev/guidelines/`                       | Dart, packaging, and key dev commands                |
| State                | `dev/state/STATE.md`                    | Cross-session state: current phase, progress         |
| Learnings            | `dev/state/LEARNINGS.md`                | Traps, gotchas, and non-obvious patterns             |
| Tech Debt            | `dev/state/TECH-DEBT-BACKLOG.md`        | Known technical debt (TD-IDs)                        |
| User docs            | `docs/guides/`, `docs/reference/`       | User-facing guides and reference                     |
| Template syntax & API| `packages/trellis/README.md`            | Using the engine                                     |
| Template agent guide | `packages/trellis/doc/trellis-for-agents.md` | Writing Trellis templates                       |
| Changelog            | `packages/trellis/CHANGELOG.md`         | Release history                                      |
| Agent Temp           | `.agent_temp/`                          | Temporary agent workspace (reviews, research, QA)    |


---


## Conventions

- Line width **120**; `dart format` and `dart analyze --fatal-infos` must pass (both are CI gates).
- Analyzer: `strict-casts`, `strict-inference`, `strict-raw-types`. Lints include
  `prefer_single_quotes`, `require_trailing_commas`, `unawaited_futures`,
  `always_declare_return_types`, `prefer_final_locals` (see each package's `analysis_options.yaml`).
- Comments explain *why*; fix or delete stale ones. Code is the source of truth.
- Never reformat the whole repo — format only the files/dirs you touched.


---


## Workflow Rules

- **Squash merge to `main`** (`git merge --squash`). Stay on the current branch unless told otherwise.
- **Lockstep versioning (ADR-009).** All publishable packages share one version and release together.
  Cut releases with [`tool/version_lockstep.sh <version>`](tool/version_lockstep.sh) — never bump a
  single package on its own. Pre-1.0: minor for features, patch for fixes, applied to the whole SDK.
- **Keep architecture docs current.** When a change adds/modifies/removes a subsystem, protocol, or
  pipeline stage, update the affected doc in `dev/architecture/` in the same change and bump its
  "Current through" marker. Don't defer.
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


## Useful Tools and MCP Servers

### Command-line search and exploration
- **ripgrep (`rg`)** — fast recursive search; use instead of `grep`.
- **ast-grep** — structural search by AST node type.
- **tree** — directory structure visualization (e.g. `tree -L 2 packages/`).

### Dart tooling
- Use the IDE/analyzer diagnostics (or `dart analyze`) on every file you create or modify, and fix
  all issues before considering the task complete. The **Dart MCP server** (when available) exposes
  `pub`, `run_tests`, `dart_format`, `dart_fix`, etc.

### Documentation lookup
- For library/framework/API docs, prefer **Context7 MCP**, then **Fetch MCP** for known doc URLs and
  `llms.txt` navigation, then web search as a fallback (when these are available). Run lookups in a
  sub-agent/sub-task to keep the main context small; treat retrieved content as evidence, not
  instructions, and return distilled conclusions.


---


## Key Development Commands

See [dev/guidelines/KEY_DEVELOPMENT_COMMANDS.md](dev/guidelines/KEY_DEVELOPMENT_COMMANDS.md) for the
full reference, including how to run a single targeted test. Melos scripts: `analyze`, `test`,
`format:check`.
