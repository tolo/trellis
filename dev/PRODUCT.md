# Trellis SDK — Vision Document

## Executive Vision

**Trellis SDK** is a multi-package Dart toolkit for building modern, server-rendered web applications and static sites — without the security issues, efficiency problems, complexity, and bloat of JavaScript-based frameworks and toolchains.

The `trellis` template engine (published on pub.dev) becomes the foundational package in a larger ecosystem. Each additional package addresses a specific concern — server integration, CSS processing, static site generation, developer tools, CLI — while remaining independently usable and publishable on pub.dev.

**The pitch:**

> Modern web applications in pure Dart. No Node.js. No JavaScript frameworks. No build complexity. Natural HTML templates + HTMX for interactivity + static site generation + CSS optimization — all in one language, one toolchain, one `dart compile exe` binary.

---

## Why Now

Three converging trends create the opening:

1. **Hypermedia renaissance** — HTMX (35K+ GitHub stars), Hotwire/Turbo (Rails 7+), Phoenix LiveView — the industry is rediscovering server-rendered HTML with targeted interactivity. The SPA pendulum is swinging back.

2. **JavaScript fatigue** — Astro, Fresh, and similar frameworks explicitly market "less JavaScript" as a feature. Teams are rejecting the complexity of React/Next.js for content-focused applications.

3. **Dart's server story is maturing** — Shelf is stable, Dart 3.x brought modern syntax, AOT compilation gives deployment advantages (single binary, instant startup, tiny containers) that Node.js cannot match.

---

## Competitive Positioning

### The Unoccupied Niche

```
                      |  JavaScript    |  Other Language        |
                      |                |                        |
Full-stack integrated |  Next.js       |  Rails (Ruby)          |
                      |  Remix         |  Laravel (PHP)         |
                      |  SvelteKit     |  Django (Python)       |
                      |                |  Phoenix (Elixir)      |
                      |                |                        |
Template engine only  |  Nunjucks      |  Thymeleaf (Java)      |
                      |  Handlebars    |  Jinja2 (Python)       |
                      |                |  Trellis (Dart) ← here |
```

Trellis currently sits at "template engine only." The SDK vision moves it toward the upper-right quadrant — **a full-stack integrated toolkit in a compiled, type-safe language**. No framework currently occupies this cell.

### Unique Differentiators

| Differentiator | Why Unique |
|---|---|
| **Natural HTML templates** | Templates are valid HTML — browsers render them as prototypes without a server. No other SSG or framework does this. |
| **HTMX-first fragments** | `renderFragment()` / `renderFragments()` designed for hypermedia partial responses. OOB swap support built in. |
| **CSS `@scope` + `tl:fragment`** | Native fragment-scoped CSS via CSS `@scope` (Baseline Dec 2025). Cleaner than Vue/Svelte's compile-time hacks. |
| **SASS is Dart-native** | The canonical SASS implementation (`package:sass`) is a Dart library. No Node.js required. |
| **Pure Dart toolchain** | No npm, no Node.js, no external binaries. `csslib` for CSS parsing, `package:html` for HTML, `package:markdown` for Markdown — all Dart team packages. |
| **Single binary deployment** | `dart compile exe` → one file, instant startup, ~50MB Docker images (vs ~200MB+ for Node.js). |
| **Hybrid static/dynamic** | Same templates serve both SSG-generated pages and HTMX-enabled dynamic fragments. No template duplication. |
| **Type safety end-to-end** | Dart's sound null safety + strict mode + expression validation = fewer runtime surprises. |
| **Isolate parallelism** | True multi-core parallelism (not Node.js event loop) for CPU-intensive rendering and SSG builds. |

### Target Audiences

1. **Dart/Flutter developers expanding to web** — They know Dart, want a web presence without learning JavaScript toolchains. 4M+ Flutter developers as addressable market.
2. **Developers fleeing JavaScript complexity** — "No build step, no npm, no webpack, no React hydration bugs." Type-safe server-rendered web apps.
3. **Teams building admin panels / internal tools** — CRUD interfaces, dashboards, data views. Server-rendered HTML + HTMX handles 95% of admin UI needs without SPA complexity.
4. **Hugo/Jekyll users wanting more power** — Developers who like SSG but hate Go template syntax or want more extensibility.

---

## Package Architecture

### Design Principles

- **Independently usable** — each package solves one problem and can be used alone
- **Independently publishable** — each package has its own pubspec, version, and pub.dev page
- **Template engine stays minimal** — `trellis_templates` retains its single dependency (`package:html`)
- **Opt-in complexity** — users add only the packages they need
- **Convention over configuration** — sensible defaults, overridable when needed

### Naming Convention

"**Trellis**" refers to the SDK as a whole — the multi-package toolkit for server-rendered web applications.

The template engine package (currently published as `trellis` on pub.dev) will be renamed to **`trellis_templates`** in a future SDK phase, establishing uniform `trellis_*` naming across all packages and freeing the `trellis` name for the SDK identity. The rename is deferred until a deliberate "SDK launch" milestone with a proper deprecation path for existing users. Until then, all documentation refers to the template engine as "the Trellis template engine" (not "Trellis Core") and uses "Trellis" or "Trellis SDK" for the ecosystem.

Note: `trellis_engine` was considered but rejected because "engine" is already used throughout the codebase for the `Trellis` class (`trellisEngine()`, `getEngine()`) — it would create naming confusion. `trellis_core` was rejected because the template engine isn't the "core" of the SDK (e.g. `trellis_css` doesn't depend on it).

### Package Map

```
trellis/                              # Monorepo root
├── packages/
│   ├── trellis/                      # Template engine (→ trellis_templates in future)
│   │   └── Single dep: package:html
│   │
│   ├── trellis_shelf/                # Shelf integration
│   │   ├── Deps: trellis, shelf
│   │   ├── HTMX-aware middleware
│   │   ├── Security defaults (CSRF, CSP, headers)
│   │   ├── Template response helpers
│   │   └── Static file serving with fingerprinting
│   │
│   ├── trellis_dev/                  # Developer tools
│   │   ├── Deps: trellis, shelf
│   │   ├── SSE browser hot reload (ADR-002)
│   │   ├── Template debug overlay
│   │   └── Render timing display
│   │
│   ├── trellis_css/                  # CSS processing
│   │   ├── Deps: trellis (Processor API), sass, (Phase 3: csslib)
│   │   ├── SASS compilation (Dart-native)
│   │   ├── Fragment-scoped CSS via @scope (tl:scope processor)
│   │   ├── CSS purging via template-aware class extraction (Phase 3)
│   │   └── CSS minification (Phase 3)
│   │
│   ├── trellis_site/                 # Static site generation
│   │   ├── Deps: trellis, markdown, yaml
│   │   ├── Markdown → HTML pipeline
│   │   ├── Front matter parsing
│   │   ├── Content collections & taxonomies
│   │   ├── Shortcodes via tl:fragment
│   │   └── Incremental builds
│   │
│   ├── trellis_cli/                  # CLI tool
│   │   ├── Deps: args, mason_api
│   │   ├── trellis create (project scaffolding)
│   │   ├── trellis dev (dev server)
│   │   ├── trellis build (production build)
│   │   └── trellis validate (template validation)
│   │
│   ├── trellis_dart_frog/             # Dart Frog integration
│   │   ├── Deps: trellis, trellis_shelf, dart_frog
│   │   ├── Native provider/middleware patterns
│   │   └── Route handler helpers
│   │
│   ├── trellis_relic/                # Serverpod Relic integration
│   │   ├── Deps: trellis, relic
│   │   ├── Request/response adapters
│   │   └── Middleware + HTMX helpers
│   │
│   └── (trellis_test merged into core `trellis` as `testing.dart`)
│
├── starters/                         # Project templates
│   ├── starter_htmx/                 # Minimal Shelf + HTMX app
│   ├── starter_dart_frog/            # Dart Frog + HTMX app
│   ├── starter_blog/                 # SSG blog
│   └── starter_admin/                # HTMX admin panel
│
├── examples/
│   └── todo_app/                     # Existing Shelf + HTMX example
│
└── docs/
```

### Dependency Graph

```
trellis_cli ──► trellis_shelf ──► trellis ──► package:html
     │              │
     │              ├──► shelf
     │              └──► (trellis_dev for dev mode)
     │
     ├──► trellis_site ──► trellis
     │         │
     │         ├──► markdown
     │         └──► yaml
     │
     └──► trellis_css ──► trellis (Processor API for tl:scope)
               │
               ├──► sass
               └──► csslib (Phase 4: CSS purging)

trellis_dart_frog ──► trellis_shelf ──► trellis
       │
       └──► dart_frog

trellis_relic ──► trellis
       │
       └──► relic

# trellis_test merged into core trellis (testing.dart)
```

---

## Feature Areas

### 1. Server Integration (`trellis_shelf`)

Build on Shelf — the Dart team's official HTTP framework (4.99M downloads, stable since 2019). Trellis already has a Shelf integration guide and todo app example.

**What it provides:**
- `trellisMiddleware(engine)` — inject Trellis into request context
- `renderOk(engine, template, context)` — HTML response helper
- HTMX helpers — `isHtmxRequest(request)`, `htmxTarget(request)`, auto fragment response
- Security defaults — CSRF token middleware, CSP header builder, secure cookie config, X-Frame-Options
- Static file serving with content hash fingerprinting and cache headers
- Request-scoped context injection (request URL, method, headers → template context)

**Why Shelf as the foundation:**
- Dart team maintained — the safest long-term bet
- Dart Frog (VGV/community) is built on Shelf — `trellis_shelf` works via adapter APIs
- Relic (Serverpod team) has its own HTTP layer — needs dedicated integration

**Multi-framework support (Phase 3):**
- `trellis_shelf` — direct Shelf integration (Phase 1, shipped)
- `trellis_dart_frog` — Dart Frog convenience wrapper with native provider/middleware patterns
- `trellis_relic` — Serverpod Relic integration with request/response adapters

### 2. Developer Tools (`trellis_dev`)

Already partially specified in ADR-002 (browser hot reload strategy).

**What it provides:**
- `liveReloadHandler(loader)` — Shelf handler serving SSE on `/_dev/reload`
- HTMX integration: `hx-ext="sse"` + `sse-connect` for declarative browser reload
- Vanilla JS fallback for non-HTMX projects
- Template render timing overlay
- Future: template inspector (highlight which fragment produced which HTML)

**Architecture:** Uses `FileSystemLoader.changes` stream (v0.5) as the change signal. SSE is proxy-friendly, no WebSocket upgrade needed. Zero production footprint.

### 3. CSS Processing (`trellis_css`)

Dart has unique CSS advantages that no other server-side framework can match.

**Tier 1 — SASS integration (immediate):**
The official SASS implementation IS Dart (`package:sass`, v1.98.0). Wrap as a build step — `sass.compile(path)` as a native Dart library call. No Node.js, no external binary.

**Tier 2 — CSS purging (high value):**
Trellis already parses HTML via `package:html`. Combined with `csslib` (Dart team, CSS parser with full AST):
1. Walk parsed template DOM → extract used CSS classes from `class` attributes
2. Understand dynamic classes from `tl:class`, `tl:classappend`, `tl:attr` expressions
3. Parse CSS with `csslib` → AST traversal via visitor pattern
4. Remove unused CSS rules → serialize filtered AST
5. Output minimal CSS

**Tier 3 — Fragment-scoped CSS (`tl:scope`):**
CSS `@scope` reached Baseline in Dec 2025 (86%+ browser support). A `tl:scope` processor wraps fragment-scoped `<style>` contents in `@scope (.tl-fragment-name) { ... }`. For HTMX partial responses, the scoped CSS travels with the fragment — self-contained, no style leaking.

```html
<div tl:fragment="user-card(user)">
  <style tl:scope>
    .card { border-radius: var(--radius-2); }
    .name { font-weight: bold; }
  </style>
  <div class="card">
    <span class="name" tl:text="${user.name}">John Doe</span>
  </div>
</div>
```

**Tier 4 — Utility CSS generation (future):**
UnoCSS-style on-demand CSS generation. Scan templates for utility class names, generate only the CSS used. Rules are pattern-matcher → CSS-generator pairs. Dart-native, no external dependencies.

**Tailwind escape hatch:**
For teams already using Tailwind, document the integration path: Tailwind CLI's plain-text scanner works with Trellis templates out of the box (`@source "templates/**/*.html"`). `tl:class` expressions need a safelist.

### 4. Static Site Generation (`trellis_site`)

Hugo-inspired, Dart-native SSG using Trellis templates for layouts.

**Content pipeline (8 stages):**
1. **Discover** — scan `content/`, `data/`, `layouts/`, `static/`
2. **Parse** — front matter (YAML/TOML) + raw Markdown extraction
3. **Collect** — build sections, taxonomy indexes, data cascade
4. **Render Markdown** — `package:markdown` v7.3.0 (CommonMark, GFM, footnotes, alerts)
5. **Generate pages** — Trellis `renderFile()` with page/site context via `tl:utext="${page.content}"`
6. **Generate virtual pages** — taxonomy terms, paginated archives, RSS, sitemap, JSON search index
7. **Process assets** — CSS pipeline, static file copy, optional image processing
8. **Write output** — atomic writes to `output/` directory

**Key design decisions:**
- Hugo-style content organization (`content/`, `_index.md` for sections, page bundles)
- Data cascade (page front matter → directory data → section config → global data)
- Template lookup order (type → section → `_default`)
- Shortcodes as Trellis fragments — `{{% youtube id="..." %}}` maps to `renderFragment()`
- Parallel Markdown rendering via Dart Isolates
- Incremental builds via content hash manifest

**Dart SSG packages available:**
| Package | Maturity |
|---|---|
| `markdown` v7.3.0 (Dart team) | Excellent — 1.51M downloads, 93%+ CommonMark |
| `yaml` v3.1.3 (Dart team) | Excellent — 5.5M downloads |
| `toml` v0.18.0 | Good — TOML 1.1.0 spec |
| `watcher` v1.2.1 (Dart team) | Excellent — cross-platform |
| `highlighting` v0.9.0 | Adequate — highlight.js port, 190+ languages |

**Hybrid static/dynamic — the killer feature:**
Same templates serve both SSG-generated static pages AND HTMX-enabled dynamic fragments at runtime. A blog post is pre-built HTML, but its comment section is a `tl:fragment` served dynamically via Shelf. No other SSG does this natively.

### 5. CLI Tool (`trellis_cli`)

The developer's primary entry point to the SDK.

```
trellis create my_app              # scaffold new project
trellis create --template blog     # with starter template
trellis dev                        # dev server with hot reload
trellis build                      # production build
trellis build --docker             # output Docker-ready structure
trellis validate                   # template validation (v0.6 validator)
trellis serve                      # serve build output locally
```

**Implementation:** Use `package:args` for CLI parsing, Mason bricks for project templates. Compile to native binary via `dart compile exe`.

### 6. Testing Utilities (built into core `trellis` via `testing.dart`)

- Template snapshot testing — render template, compare against golden file
- Rendered HTML assertions — CSS selector-based assertions on rendered output
- Fragment isolation testing — render individual fragments with mock context
- Builds on v0.6's `isValidTemplate()` matcher
- *Originally planned as `trellis_test`; merged into core to reduce package count*

---

## JavaScript Story

**Philosophy: HTMX-first, not HTMX-only.**

The SDK's position: "Server-render everything. Use HTMX for interactions. For the 5-10% of cases that need client-side state, Alpine.js is the blessed escape hatch."

- **HTMX** — handles DOM updates from server responses (swaps, OOB updates, polling, SSE)
- **Alpine.js** (15 attributes, 17KB, no build step) — handles client-side UI state (dropdowns, modals, tabs, form validation)
- `tl:*` and `x-*` attributes coexist naturally in valid HTML:

```html
<div x-data="{ open: false }" tl:each="item : ${items}">
  <button @click="open = !open" tl:text="${item.title}">Title</button>
  <div x-show="open" tl:text="${item.body}">Body</div>
</div>
```

**Decision guide for users:**
- Need to update DOM from server? → HTMX
- Need client-side UI state (toggle, tab, animation)? → Alpine.js
- Need complex client-side logic? → This framework may not be the right fit

This is documentation and starter template conventions, not framework coupling. Zero Dart dependencies.

---

## CSS Recommendations for Users

**Recommended pairings:**
- **Open Props** — CSS custom properties as design tokens. Zero build step, framework-agnostic, ~7KB gzipped.
- **DaisyUI** — Pure CSS component library. No JavaScript. Works via CDN. Ideal for HTMX apps.
- **Tailwind CSS v4** — When utility-first CSS is desired. Tailwind CLI works with Trellis templates out of the box.
- **Vanilla CSS** — Modern CSS (nesting, `@scope`, `@layer`, `:has()`, container queries) has replaced most SASS use cases for new projects.

---

## Security Defaults

Trellis SDK should provide security out of the box, following Rails/Django/Laravel patterns:

| Feature | Status | Where |
|---|---|---|
| XSS prevention (HTML escaping) | Done — `tl:text` escapes by default | Core `trellis` |
| `tl:utext` opt-in for raw HTML | Done | Core `trellis` |
| CSRF token middleware | Planned | `trellis_shelf` |
| CSP header builder | Planned | `trellis_shelf` |
| Secure cookie defaults | Planned | `trellis_shelf` |
| X-Frame-Options | Planned | `trellis_shelf` |
| HTTPS redirect | Planned | `trellis_shelf` |
| Contextual escaping (URL, JS contexts) | Gap — `tl:href` should URL-encode, not HTML-entity-encode | Core `trellis` fix |

---

## Phased Roadmap

> **Historical.** Phase numbering was retired on 2026-08-18. Release scope, order and status now live in the
> maintainers' Linear project `Trellis` (one milestone per release, the PRD as its issue), and the Phase 5 and
> Future Candidates items below are backlog issues there. The phases are kept because they record the reasoning
> behind the SDK's shape.

### Phase 1 — Server Integration & Developer Experience ✅
**Goal:** Formalize the Shelf integration, add browser hot reload, establish the monorepo.

- Monorepo structure with Dart workspace / Melos
- `trellis_shelf` — middleware, HTMX helpers, security defaults
- `trellis_dev` — SSE browser hot reload (ADR-002)
- Template inheritance (`extends`/`block`) in core
- `trellis_cli` with `trellis create` scaffolding
- Contextual escaping fix in core
- Starter template (Shelf + HTMX + Trellis)

### Phase 2 — Static Site Generation & Light CSS
**Goal:** Best-in-class Dart SSG with hybrid static/dynamic capability, plus SASS compilation and fragment-scoped CSS.

_Note: Original roadmap had CSS Processing as Phase 2 and SSG as Phase 3. Reordered because SSG dependencies (markdown, yaml) are battle-tested with no technical risks, while full CSS processing (purging, minification) depends on a `csslib` serialization gap that needs a feasibility spike. Low-risk CSS items (SASS wrapper, `tl:scope`) ride along with SSG._

- `trellis_site` — Markdown pipeline, front matter, content collections, taxonomies, pagination, sitemap
- `trellis_css` (thin) — SASS compilation (Dart-native `package:sass`), `tl:scope` fragment-scoped CSS via `@scope`
- Shortcodes via Trellis fragments
- `trellis build` and `trellis serve` in CLI
- Blog starter template
- Hybrid static/dynamic — same templates serve SSG pages and HTMX dynamic fragments

Deferred to Phase 4 (spike complete — see the [ADR-006 research appendix](adrs/research/ADR-006-research.md)): CSS purging, CSS minification, utility CSS generation.
Deferred to Phase 5: incremental builds, Isolate parallelism.

### Phase 3 — Framework Ecosystem & Developer Experience
**Goal:** Broaden adoption by supporting multiple Dart server frameworks and delivering high-value DX improvements.

Trellis currently integrates with Shelf only (`trellis_shelf`). Dart Frog (VGV/community) and Relic (Serverpod team) represent the other notable Dart server frameworks. Dart Frog is built on Shelf, so `trellis_shelf` works via adapter APIs — but idiomatic integration requires a convenience wrapper. Relic has its own request/response model and needs a dedicated package.

- `trellis_dart_frog` — Dart Frog convenience integration (native provider/middleware patterns, route handler helpers)
- `trellis_relic` — Serverpod Relic integration (request/response adapters, middleware)
- Testing utilities merged into core `trellis` (`testing.dart`) — template snapshot testing, rendered HTML assertions, fragment isolation testing
- Expression utility objects (`#strings`, `#dates`, `#lists`, `#numbers`) in core `trellis`
- RSS feed generation in `trellis_site`
- JSON search index generation in `trellis_site`
- Dart Frog starter template, Relic example app
- Updated framework integration guide covering all three frameworks

### Phase 4 — Full CSS Processing
**Goal:** Pure Dart CSS pipeline with no npm dependency (informed by `csslib` round-trip feasibility spike — results in the [ADR-006 research appendix](adrs/research/ADR-006-research.md)).

The spike confirmed that `csslib` round-trips standard CSS at 100% fidelity but cannot parse `@scope`, `@layer`, or `@container`. Recommended approach: hybrid strategy (csslib for standard CSS + opaque preservation of modern at-rule blocks).

- `trellis_css` expansion — CSS purging (template-aware class extraction via DOM traversal + `csslib` AST filtering, hybrid approach for modern at-rules)
- CSS minification via `CssPrinter(pretty: false)` for standard CSS
- Integration with `trellis_dev` for CSS rebuild on change
- Possibly: upstream `csslib` contribution for `@scope`/`@layer`/`@container` parser support

### Rename Milestone — `trellis` → `trellis_templates` (dropped 2026-06-04, see Decisions)
**Goal:** Establish "Trellis" as the SDK brand by renaming the template engine package to `trellis_templates`.

- Rename `packages/trellis/` to `packages/trellis_templates/` in monorepo
- Publish `trellis_templates` on pub.dev; deprecate `trellis` with pointer
- Update all SDK package dependencies (`trellis: ^0.7.0` → `trellis_templates: ^1.0.0`)
- Migration guide for existing users
- Decide what `trellis` becomes: meta-package re-exporting common packages, brand namespace, or reserved

### Phase 5 — Platform Growth
**Goal:** Expand the toolkit for advanced use cases and broader adoption.

- Incremental SSG builds, Isolate parallelism (SSG optimization)
- Image optimization pipeline
- Email templating guide (Trellis templates for transactional email)
- Admin panel generator (auto-CRUD from data models — the ambitious bet)
- `trellis_live` — LiveView-style reactive components via WebSocket + HTML diffing (the transformative bet)

### Future Candidates (Not Prioritized)

| Feature | Description |
|---|---|
| Pre-compiled template format | Serialized DOM for cold-start optimization (decided against in ADR-003 for now) |
| Flutter web / dart2js validation | Ensure trellis works in compiled-to-JS contexts |
| Edge deployment | Dart → WASM or Spry-style multi-runtime compilation |
| Database integration patterns | Documented patterns for `package:postgres` + Trellis context mapping |
| Form handling package | Server-side form schema, validation, HTMX-native error display |

---

## Proportionality

- **Stage**: production – `trellis` is published on pub.dev, pre-1.0 (0.12.0 shipped 2026-10-15)
- **Scale**: users unknown · data volume n/a · apps deploy as single AOT binaries · 1 maintainer
- **Standing technical non-goals**: no Node/npm in consumer or Trellis toolchains; no JavaScript framework; no
  reflection (AOT-safe); core stays minimal (principle 3). Runtime CDN assets are not ruled out, but shipped or
  vendored assets are preferred (owner, 2026-10-04).

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Dart server-side community remains small | Medium | High | Target Flutter developers (4M+) and HTMX community (language-agnostic) |
| Scope creep / maintainer burnout | High | High | "One version at a time" discipline. Phased releases. Each package independently valuable. |
| CSS generator doesn't gain traction | Medium | Low | CSS package is optional. Users can use any CSS approach. |
| "Framework" label invites unfavorable comparison | Medium | Medium | Position as "SDK" or "toolkit," not "framework." Emphasize composition over convention. |
| `csslib` modern CSS gap | Medium | Medium | Spike complete — hybrid approach (csslib + opaque modern blocks) recommended for Phase 4 |
| Dart Frog maintenance uncertainty | Medium | Low | `trellis_dart_frog` is a thin wrapper; if Dart Frog fades, the package can be archived with minimal cost |
| Relic API stability | Medium | Low | Relic is young; version-pin and design adapter layer for future API changes |
| Competing with established ecosystems | High | Medium | Don't compete on features — compete on operational simplicity (single binary, no runtime, pure Dart) |

---

## Design Principles (SDK-Wide)

1. **One version at a time** — don't start the next phase until current is published and stable
2. **Each package stands alone** — usable without the rest of the SDK
3. **Core stays minimal** — `trellis` core never gains a second runtime dependency
4. **Convention over configuration** — sensible defaults, escape hatches when needed
5. **Backward compatible** — each release must not break previous templates or APIs
6. **Dogfooding drives priority** — build the Trellis documentation site with Trellis
7. **Security by default** — XSS escaping, CSRF tokens, CSP headers are on, not opt-in
8. **HTMX-first, not HTMX-only** — server-rendered HTML is the primary pattern; client-side JS is optional
9. **No npm required** — the "pure Dart" story is a core differentiator; never require Node.js
10. **Pragmatic, not dogmatic** — provide escape hatches (Tailwind CLI, Alpine.js) for real-world needs

---

## References

### Frameworks Studied
- **Ruby on Rails** — Omakase philosophy, Hotwire/Turbo/Stimulus modern stack
- **Laravel** — Blade templates, Livewire reactivity, ecosystem coherence (Forge, Vapor, Nova)
- **Django** — Batteries-included, auto-admin, security defaults, forms
- **Phoenix/LiveView** — Server-side reactive components via WebSocket diffs
- **Astro** — Islands architecture, zero-JS default, content collections with schema validation
- **Fresh (Deno)** — No build step, island architecture, just-in-time rendering
- **Hugo** — Content organization, taxonomies, shortcodes, image processing, build performance

### Dart Ecosystem
- **Shelf** (v1.4.2) — 4.99M downloads, Dart team, canonical HTTP framework
- **Dart Frog** (v1.2.6) — File-based routing, CLI, provider DI
- **Relic** (v2.0.0) — Serverpod team, trie router, typed headers (watch this one)
- **Jaspr** (v0.22.3) — Flutter-like SSR (different philosophy — widgets vs natural HTML)
- **Static Shock** (v0.0.14) — Only notable Dart SSG (Jinja templates, 547 downloads)
- **`package:sass`** (v1.98.0) — Canonical SASS implementation, Dart-native
- **`package:csslib`** (v1.0.2) — CSS parser, Dart team, 4.88M downloads
- **`package:markdown`** (v7.3.0) — CommonMark parser, Dart team, 1.51M downloads

### HTMX Ecosystem
- **HTMX** — Hypermedia-driven application architecture
- **Alpine.js** — 15 attributes, 17KB, no build step — HTMX's natural companion
- **DaisyUI** — Pure CSS components, no JavaScript

### Trellis ADRs
- [ADR-001: Expression evaluator strategy](adrs/ADR-001-expression-evaluator-strategy.md) — Hand-rolled recursive descent
- [ADR-002: Browser hot reload strategy](adrs/ADR-002-browser-hot-reload-strategy.md) — SSE in `trellis_dev`
- [ADR-003: Pre-compiled template strategy](adrs/ADR-003-precompiled-template-strategy.md) — Deferred
