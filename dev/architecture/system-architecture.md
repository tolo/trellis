# Trellis SDK — System Architecture

Canonical reference for understanding the Trellis SDK architecture: how the packages compose, what each package is responsible for, the dependency graph, and how a request flows through the system.

**Current through**: v0.7 (engine) / SDK Phase 3 (post `trellis_test` merge)

---

## System Overview

Trellis is a Dart toolkit for building server-rendered web applications and static sites. It consists of independently publishable packages in a monorepo, centered around a core template engine.

![SDK Package Dependency Graph](sdk-package-dag.svg)

*Source diagram maintained in the project's internal design repository.*

---

## Package Responsibilities

### Current (v0.7 / SDK Phase 3)

| Package | Responsibility | Dependencies | Status |
|---|---|---|---|
| **`trellis`** | HTML template engine: parsing, expression evaluation (incl. utility objects), processor pipeline, fragment rendering, caching, validation, template inheritance, contextual escaping. Also includes testing utilities via `testing.dart` (test engine factory, CSS-selector matchers, snapshot golden file testing, fragment helpers). | `package:html` | v0.7.0 (unpublished) |
| **`trellis_shelf`** | Shelf middleware: engine injection, HTMX helpers, security defaults (CSRF, CSP), response builders | `trellis`, `shelf`, `crypto` | v0.1.0 (unpublished) |
| **`trellis_dart_frog`** | Dart Frog integration: `trellisProvider()` DI middleware, response helpers (`renderPage`, `renderFragment`, `renderOobFragments`), HTMX detection, CSRF/security middleware bridged from `trellis_shelf` | `trellis`, `trellis_shelf`, `dart_frog` | v0.1.0 (unpublished) |
| **`trellis_relic`** | Serverpod Relic integration: response helpers with explicit engine passing, HTMX detection, `trellisSecurityHeaders()` middleware. No CSRF (Relic form parser gap). | `trellis`, `relic` | v0.1.0 (unpublished) |
| **`trellis_dev`** | Dev tools: SSE browser hot reload, script injection middleware | `trellis`, `shelf` | v0.1.0 (unpublished) |
| **`trellis_css`** | CSS processing: Dart-native SASS/SCSS compilation via `package:sass`, `tl:scope` fragment-scoped CSS via CSS `@scope` | `trellis`, `sass`, `html` | v0.1.0 (unpublished) |
| **`trellis_site`** | Static site generation: content discovery, front matter, Markdown, taxonomies, pagination, sitemap, shortcodes, data cascade, Atom/RSS feed generation, JSON search index | `trellis`, `markdown`, `yaml` | v0.1.0 (unpublished) |
| **`trellis_cli`** | CLI tool: `trellis create` (htmx + blog + dart_frog + relic templates), `trellis build` (SSG pipeline + SASS), `trellis serve` (local preview server) | `args`, `shelf`, `shelf_static`, `trellis_css`, `trellis_site` | v0.2.0 (unpublished) |
| ~~`trellis_test`~~ | *Merged into `trellis` core as `testing.dart` entry point (2026-03-18)* | — | — |

---

## Dependency Rules

From [ADR-004](../adrs/ADR-004-sdk-package-architecture.md):

1. **`trellis` (core) depends on no SDK package** — only `package:html`
2. **Integration packages** (`trellis_shelf`, `trellis_dev`) may depend on `trellis`, never the reverse
3. **Tooling packages** (`trellis_css`, `trellis_cli`) may depend on runtime packages only for orchestration
4. **No cyclic package dependencies** — the dependency graph is a DAG
5. **Optional features stay optional** — CSS, SSG, and dev tools never become transitive deps of core

```bash
trellis_cli ──► trellis_site ──► trellis ──► package:html
     │               │
     │               ├──► markdown
     │               └──► yaml
     ├──► trellis_css ──► trellis
     │         │
     │         ├──► sass
     │         └──► html
     ├──► shelf
     └──► shelf_static
trellis_shelf ──► trellis ──► package:html
     │
     └──► shelf
trellis_dart_frog ──► trellis_shelf ──► trellis
     │
     └──► dart_frog
trellis_relic ──► trellis ──► package:html
     │
     └──► relic
trellis_dev ──► trellis
     │
     └──► shelf
```

---

## Request Flow: Shelf + Trellis + HTMX

A typical request through a Trellis SDK application:

```
 Browser request
        │
        ▼
┌───────────────────────────────────────────────────┐
│                  Shelf Pipeline                   │
│                                                   │
│  logRequests()                                    │
│       │                                           │
│       ▼                                           │
│  trellisSecurityHeaders()  ← X-Frame, CSP, etc.   │
│       │                                           │
│       ▼                                           │
│  trellisEngine(engine)     ← inject into context  │
│       │                                           │
│       ▼                                           │
│  trellisCsrf(secret: ...)  ← token gen/validate   │
│       │                                           │
│       ▼                                           │
│  Router                                           │
│   ├─ GET /           → homeHandler                │
│   ├─ POST /todos     → createTodoHandler          │
│   └─ static files    → shelf_static               │
└───────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│                  Route Handler                    │
│                                                   │
│  1. Get engine from request context               │
│  2. Check: isHtmxRequest(request)?                │
│     ├─ Yes → renderFragment(source, fragment, ctx)│
│     └─ No  → render(source, ctx)                  │
│  3. Return htmlResponse(html)                     │
└───────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│               Trellis Engine                      │
│                                                   │
│  1. Parse HTML (or LRU cache hit)                 │
│  2. Clone DOM                                     │
│  3. Collect fragments                             │
│  4. Process DOM (priority-sorted processors)      │
│  5. Serialize to HTML string                      │
└───────────────────────────────────────────────────┘
        │
        ▼
  HTML response → Browser
  (full page or HTMX fragment)
```

### HTMX Fragment Pattern

When the browser makes an HTMX request (`HX-Request: true`), the handler returns only the targeted fragment instead of the full page. `renderFragment()` extracts and processes a single `tl:fragment` from the template. `renderFragments()` returns multiple fragments for OOB (out-of-band) swaps.

### Dev-Mode Hot Reload (trellis_dev)

In development, a parallel SSE connection keeps the browser updated:

```
Browser                          Server
   │                                │
   ├── EventSource(/_dev/reload) ──►│  SSE connection
   │                                │
   │   [developer edits template]   │
   │                                ├── FileSystemLoader.changes fires
   │                                ├── Engine cache cleared
   │◄── SSE: event: reload ─────────│  Broadcast to all clients
   │                                │
   ├── location.reload() ──────────►│  Browser refreshes
   │                                │
```

---

## Template Inheritance (SDK Phase 1)

Template inheritance adds a **pre-pass** before the normal render pipeline:

```
Source HTML string
       │
       ▼
┌──────────────────┐
│ 1. Normalize     │
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 2. Parse + Cache │
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 3. Clone DOM     │
└──────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ NEW: Inheritance Resolution Pre-Pass │
│                                      │
│  Detect tl:extends on root element   │
│  ├─ Load parent layout               │
│  ├─ Resolve recursively (if parent   │
│  │   also extends)                   │
│  ├─ Merge: replace tl:define blocks  │
│  │   in parent with child overrides  │
│  └─ Remove tl:extends/tl:define attrs│
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────┐
│ 4. Collect       │  ← runs on MERGED DOM
│    Fragments     │     (parent fragments visible)
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 5. Process DOM   │
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 6. Serialize     │
└──────────────────┘
```

See [Template Engine Architecture](template-engine.md) for render pipeline details.
Template inheritance (`tl:extends`/`tl:define`) is part of the SDK Phase 1 feature set.

---

## CSS Processing (SDK Phase 2)

`trellis_css` provides two capabilities:

### SASS/SCSS Compilation

Dart-native SASS compilation via `package:sass` (the canonical Dart SASS implementation). No Node.js or npm required.

```bash
Source (.scss/.sass)  ──►  TrellisCss.compileSass()  ──►  CSS output
                           TrellisCss.compileSassString()
                           - OutputStyle: expanded / compressed
                           - Syntax: scss / sass (indented)
                           - Load paths for @use/@import
```

The `trellis build` CLI command automatically compiles `.scss`/`.sass` files in the static directory (skipping `_` partials) and writes `.css` files to the output directory.

### Fragment-Scoped CSS (`tl:scope`)

The `CssDialect` registers a `ScopeProcessor` that wraps fragment `<style>` content in CSS `@scope`:

```html
<div tl:fragment="card">              <div class="tl-scope-card">
  <style tl:scope>                      <style>
    h2 { color: navy; }      ──►         @scope (.tl-scope-card) {
  </style>                                  h2 { color: navy; }
  <h2>Title</h2>                          }
</div>                                  </style>
                                        <h2>Title</h2>
                                      </div>
```

- Scope class added to fragment root element
- Per-fragment CSS travels with HTMX partial responses
- Requires CSS `@scope` browser support (Baseline Dec 2025)

---

## Static Site Generation (SDK Phase 2)

`trellis_site` provides a full SSG pipeline orchestrated by `TrellisSite.build()`:

```
content/**/*.md   ──►  ContentDiscovery    (recursive .md scanning, URL derivation)
                       FrontMatterParser   (YAML extraction, draft detection)
                       ShortcodeProcessor  (pre-Markdown: {{% name %}})
data/**/*.yaml    ──►  MarkdownRenderer    (GitHub-flavored MD → HTML, TOC, summary)
                       ShortcodeProcessor  (post-Markdown: <!-- tl:name -->)
layouts/**/*.html ──►  TaxonomyCollector   (term collection, virtual pages)
static/**         ──►  PageGenerator       (layout resolution, data cascade, Trellis render)
                       SitemapGenerator    (sitemap.xml with lastmod)
                       FeedGenerator       (Atom + RSS feeds — opt-in)
                       SearchIndexGenerator (JSON search index — opt-in)
                       Static asset copy   (+ bundle asset copy)
                            │
                            ▼
                      output/ directory
```

### Pipeline Stages

1. **Clean** output directory
2. **Discover** pages — recursive `.md` scan, Hugo-style URL derivation, page bundle detection
3. **Parse** front matter — YAML extraction, draft flagging
4. **Shortcodes (pre-MD)** — `{{% name %}}` and `{{% name %}} content {{% /name %}}` processed before Markdown
5. **Render** Markdown — GitHub-flavored via `package:markdown`, summary + TOC extraction
6. **Shortcodes (post-MD)** — `<!-- tl:name -->` processed after Markdown
7. **Taxonomies** — collect terms from front matter, generate virtual listing and term pages
8. **Generate** HTML — priority-ordered layout resolution, 5-level data cascade, Trellis `renderFile()`
9. **Static assets** — copy (skip `.scss`/`.sass`), copy bundle assets
10. **Sitemap** — `sitemap.xml` with `<lastmod>` from date or mtime
11. **Feeds** — Atom `feed.xml` (+ optional `rss.xml`) when `feeds:` config present; per-section feeds supported
12. **Search index** — JSON array at configured path when `search.enabled: true`

### Layout Resolution Order

1. Front matter `layout` field
2. Type-specific: `{type}/{single|list}.html`
3. Section-specific: `{section}/{single|list}.html`
4. Default: `_default/{single|list}.html`
5. Home pages: `home.html` > `index.html` > `_default/list.html`

### Data Cascade (lowest to highest priority)

1. Site params (`${site.*}`)
2. Global data files (`${data.*}` from `data/*.yaml`)
3. Section front matter (from `_index.md`)
4. Page front matter

### Pagination

List pages (section, home, taxonomy term) are automatically paginated when `paginate` is set in config. Templates access `${pagination.page}`, `${pagination.totalPages}`, `${pagination.hasNext}`, `${pagination.prevUrl}`, `${pagination.nextUrl}`.

Hybrid static/dynamic: Same Trellis templates can serve both SSG-generated pages and HTMX-enabled dynamic fragments at runtime.

---

## Expression Utility Objects (SDK Phase 3)

`trellis` core gains a `${#name.method(args)}` utility object syntax, resolved at the evaluator level — not injected into the user context map.

```
${#strings.capitalize(name)}     →  "Hello"
${#lists.where(items, 'active')} →  filtered list
${#dates.format(date, 'yyyy-MM-dd')} →  "2026-03-17"
```

### Built-in Utility Objects

| Object | Methods | Notes |
|---|---|---|
| `#strings` | `capitalize`, `upperCase`, `lowerCase`, `trim`, `isEmpty`, `isNotEmpty`, `length`, `contains`, `startsWith`, `endsWith`, `replace`, `substring`, `indexOf`, `split`, `join`, `repeat` | 16 methods |
| `#numbers` | `abs`, `min`, `max`, `round`, `floor`, `ceil`, `isOdd`, `isEven`, `formatDecimal`, `formatCurrency`, `formatPercent` | 10 methods |
| `#dates` | `format`, `formatDate`, `formatTime`, `now`, `year`, `month`, `day`, `hour`, `minute`, `second`, `isBefore`, `isAfter` | 12 methods |
| `#lists` | `size`, `isEmpty`, `isNotEmpty`, `first`, `last`, `contains`, `sort`, `sortBy`, `reverse`, `take`, `skip`, `where`, `map`, `join`, `flatten` | 15 methods |

`#dates.format` and `#numbers.format` detect `package:intl` at runtime — use locale-aware formatting if available, fall back to English-only built-in implementation. No new dependencies added to core `trellis`.

Parser: `${#ident.method(args)}` is parsed inside `_parseDollarExpr()` → `UtilityCallExpr` AST node. `#{key}` message expressions are parsed in `_parseMessageExpr()` — no collision.

---

## Framework Integrations (SDK Phase 3)

### Dart Frog (`trellis_dart_frog`)

Wraps `trellis_shelf` for use in Dart Frog's `RequestContext`-based DI system:

```
routes/_middleware.dart
  trellisProvider(engine)      ← engine → RequestContext
  trellisSecurityHeaders()     ← bridged from trellis_shelf via fromShelfMiddleware
  trellisCsrf(secret: ...)     ← bridged from trellis_shelf via fromShelfMiddleware

route handler
  renderPage(context, 'template', ctx)         ← full page
  renderFragment(context, 'template', 'frag', ctx)  ← named fragment
  renderOobFragments(context, 'template', [...], ctx) ← HTMX OOB
  isHtmxRequest(context)  htmxTarget(context)  ← HTMX detection
```

The CSRF bridge reads the Dart Frog request body via `request.bytes()` then creates a `shelf.Request` to hand off to `trellis_shelf.trellisCsrf`. Dart Frog test files use `concurrency: 1` (`dart_test.yaml`) because `serve()` starts real HTTP servers that cannot run in parallel within a single Dart isolate.

### Relic (`trellis_relic`)

Thin adapter for Serverpod Relic — no DI framework, engine passed explicitly:

```
RelicApp(hostname, port)
  .use(trellisSecurityHeaders())    ← Relic middleware chain

handler(Request request) async {
  return renderPage(request, engine, 'template', ctx);
    ← returns Relic Response with Body.fromString(html, mimeType: MimeType.html)
}
```

No CSRF support (Relic lacks a form body parser). Middleware only fires for matched routes (Relic behavioral difference vs Shelf). Does NOT depend on `trellis_shelf` or `shelf`.

---

## SSG Feed & Search Index (SDK Phase 3)

`trellis_site` pipeline gains two optional post-generation steps:

```
... (steps 1-9 as before) ...
10. Feed generation   ← opt-in via feeds: config; Atom (RFC 4287) + optional RSS 2.0
11. Search index      ← opt-in via search: config; JSON array (Lunr.js / Fuse.js / Pagefind)
```

### Feed Generation (`FeedGenerator`)

- Activated by `feeds:` section in `trellis_site.yaml`
- Outputs `output/feed.xml` (Atom) and optionally `output/rss.xml` (RSS 2.0)
- Per-section feeds at `output/{section}/feed.xml`
- Items sorted newest-first, limited by `feeds.limit`; draft pages and `feed: false` front matter excluded
- `${site.feeds.atom}` injected into template context for `<link rel="alternate">` tags
- XML built via string construction — no new dependencies

### Search Index (`SearchIndexGenerator`)

- Activated by `search: enabled: true` in `trellis_site.yaml`
- Outputs a JSON array at configured path (default: `output/search-index.json`)
- Configurable fields: `title`, `summary`, `content`, `tags`, `date`, `section`, `url`
- HTML stripping (`search.stripHtml: true`) and content truncation (`search.maxContentLength`)
- Draft pages and excluded sections omitted

---

## Monorepo Structure

From [ADR-004](../adrs/ADR-004-sdk-package-architecture.md) and [ADR-007](../adrs/ADR-007-monorepo-tooling.md):

```
trellis/                          # monorepo root
├── pubspec.yaml                  # Dart workspace + Melos config
├── packages/
│   ├── trellis/                  # core template engine
│   ├── trellis_shelf/            # Shelf integration
│   ├── trellis_dart_frog/        # Dart Frog integration
│   ├── trellis_relic/            # Serverpod Relic integration
│   ├── trellis_dev/              # dev tools (hot reload)
│   ├── trellis_css/              # CSS processing (SASS + tl:scope)
│   ├── trellis_site/             # static site generation
│   └── trellis_cli/              # CLI (create, build, serve)
├── starters/                     # project templates
├── examples/
│   └── relic_app/                # Relic + Trellis + HTMX example
└── docs/                         # guides, API docs
```

Tooling: Dart native workspaces (shared `pubspec.lock`, local linking) + Melos v7 (versioning, changelogs, publishing, CI scripts).

---

## Deployment Model

```
Development                    Production

dart run bin/server.dart       dart compile exe bin/server.dart
      │                              │
      ▼                              ▼
  JIT execution                 Native binary (~10-20MB)
  + devMode: true               + devMode: false
  + file watching               + no watchers
  + SSE hot reload              + LRU cache (warm-up on start)
  + shelf_hotreload             + static file serving
                                + security headers
                                      │
                                      ▼
                               Docker / Cloud Run / Fly.io
                               Single binary + templates/ + static/
```

---

## Cross-References

### Architecture Documents
- [Template Engine Architecture](template-engine.md) — Engine internals, processor pipeline, expression evaluator, caching

### ADRs
- [ADR-001: Expression Evaluator Strategy](../adrs/ADR-001-expression-evaluator-strategy.md)
- [ADR-002: Browser Hot Reload Strategy](../adrs/ADR-002-browser-hot-reload-strategy.md)
- [ADR-003: Pre-compiled Template Strategy](../adrs/ADR-003-precompiled-template-strategy.md) — deferred
- [ADR-004: SDK Package Architecture](../adrs/ADR-004-sdk-package-architecture.md)
- [ADR-005: Server Integration Strategy](../adrs/ADR-005-server-integration-strategy.md)
- [ADR-006: CSS Strategy](../adrs/ADR-006-css-strategy.md)
- [ADR-007: Monorepo Tooling](../adrs/ADR-007-monorepo-tooling.md)

### Specs
- SDK Vision — product vision, competitive positioning, phased roadmap (internal)
- SDK Phase 1 — server integration, hot reload, template inheritance, CLI (internal)

### Diagrams

Architecture diagrams are maintained as Excalidraw source files in the project's internal design repository; the dependency-graph export is embedded above.
