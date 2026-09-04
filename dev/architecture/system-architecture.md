# Trellis SDK — System Architecture

Canonical reference for understanding the Trellis SDK architecture: how the packages compose, what each package is responsible for, the dependency graph, and how a request flows through the system.

**Current through**: v0.11.0 SDK + the 2026-09-03 docs-site SSG positioning change (first-class Sites documentation,
Lattice `site_demo` home block, and the `examples/docs_site/` proof) + the 2026-09-04 HTMX 4 adapter
compatibility (ADR-011 amendment).

---

## System Overview

Trellis is a Dart toolkit for building server-rendered web applications and static sites. It consists of independently publishable packages in a monorepo, centered around a core template engine.

![SDK Package Dependency Graph](sdk-package-dag.svg)

*Source diagram maintained in the project's internal design repository.*

---

## Package Responsibilities

### Current (v0.10.2, lockstep)

| Package | Responsibility | Dependencies | Status |
|---|---|---|---|
| **`trellis`** | HTML template engine: parsing, expression evaluation (incl. utility objects), processor pipeline, fragment rendering, caching, validation, template inheritance, contextual escaping. Also includes testing utilities via `testing.dart` (test engine factory, CSS-selector matchers, snapshot golden file testing, fragment helpers). | `package:html` | v0.10.2 (published) |
| **`trellis_shelf`** | Shelf middleware: engine injection, HTMX helpers, security defaults (CSRF, CSP), response builders | `trellis`, `shelf`, `crypto` | v0.10.2 (published) |
| **`trellis_dart_frog`** | Dart Frog integration: `trellisProvider()` DI middleware, response helpers (`renderPage`, `renderFragment`, `renderOobFragments`), HTMX detection, CSRF/security middleware bridged from `trellis_shelf` | `trellis`, `trellis_shelf`, `dart_frog` | v0.10.2 (published) |
| **`trellis_relic`** | Serverpod Relic integration: response helpers with explicit engine passing, HTMX detection, `trellisSecurityHeaders()` middleware. No CSRF (Relic form parser gap). | `trellis`, `relic` | v0.10.2 (published) |
| **`trellis_dev`** | Dev tools: SSE browser hot reload, script injection middleware | `trellis`, `shelf` | v0.10.2 (published) |
| **`trellis_css`** | CSS processing: Dart-native SASS/SCSS compilation via `package:sass`, `tl:scope` fragment-scoped CSS via CSS `@scope` | `trellis`, `sass`, `html` | v0.10.2 (published) |
| **`trellis_site`** | Static site generation: content discovery, front matter, Markdown, taxonomies, pagination, sitemap, shortcodes, data cascade, Atom/RSS feed generation, JSON search index | `trellis`, `markdown`, `yaml` | v0.10.2 (published) |
| **`trellis_cli`** | CLI tool: `trellis create` (htmx + blog + dart_frog + relic templates), `trellis build` (SSG pipeline + SASS), `trellis serve` (local preview server), and `trellis theme` (`add`, `update`, `list`, `info`, `remove`) | `args`, `shelf`, `shelf_static`, `trellis_css`, `trellis_site` | v0.10.2 (published) |
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

**Version policy and coupling boundary (ADR-011)** — the core engine is
hypermedia-agnostic: `hx-*` attributes pass through untouched and `renderFragments()`
is generic concatenation. All HTMX protocol coupling is five request-header reads
(`HX-Request`, `HX-Target`, `HX-Source`, `HX-Trigger`, `HX-Boosted`) confined to the three
optional adapter packages; the helpers accept both the HTMX 2 and the HTMX 4 header
formats, so a project can run either version against unchanged packages. Scaffolded projects pin the HTMX `latest` dist-tag (2.x) from a single
constant, `trellis_cli`'s `htmx_asset.dart`; the HTMX 4 migration is deferred pending an
explicit trigger. See [ADR-011](../adrs/ADR-011-htmx-version-policy.md).

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
2. **Discover** pages — recursive `.md` scan, Hugo-style URL derivation (with optional `pathPrefix` applied at the single `deriveUrl` seam), page bundle detection
3. **Parse** front matter — YAML extraction, draft flagging
4. **Shortcodes (pre-MD)** — `{{% name %}}` and `{{% name %}} content {{% /name %}}` processed before Markdown
5. **Render** Markdown — GitHub-flavored via `package:markdown`, summary + TOC extraction
6. **Highlight** code (ADR-010) — build-time syntax highlighting woven into the Markdown render and both shortcode passes: when `highlight.enabled` (default), `CodeHighlighter` (`package:highlight`) rewrites each fenced `<pre><code class="language-x">` block into `.hljs-*` token spans; disabled or unknown-language blocks stay plain `<pre><code>`. No client-side highlighter JS ships — runs before path-prefix link rewriting in step 9
7. **Shortcodes (post-MD)** — `<!-- tl:name -->` processed after Markdown
8. **Taxonomies** — collect terms from front matter, generate virtual listing and term pages
9. **Generate** HTML — priority-ordered layout resolution, 5-level data cascade, Trellis `renderFile()`, final path-prefix link rewriting
10. **Static assets** — copy (skip `.scss`/`.sass`), copy bundle assets
11. **Sitemap** — `sitemap.xml` with `<lastmod>` from date or mtime
12. **Feeds** — Atom `feed.xml` (+ optional `rss.xml`) when `feeds:` config present; per-section feeds supported
13. **Search index** — JSON array at configured path when `search.enabled: true`

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

Global data has its own theme/site precedence. A theme's `data/*.yaml` files load first as fallbacks; the site's
`data/*.yaml` files load second. The filename stem becomes the key below `${data}` (`navigation.yaml` →
`${data.navigation}`), and a site file replaces the complete theme value at the same stem rather than deep-merging it.
Non-overlapping stems from both sources remain available.

### Pagination

List pages (section, home, taxonomy term) are automatically paginated when `paginate` is set in config. Templates access `${pagination.page}`, `${pagination.totalPages}`, `${pagination.hasNext}`, `${pagination.prevUrl}`, `${pagination.nextUrl}`.

Hybrid static/dynamic: Same Trellis templates can serve both SSG-generated pages and HTMX-enabled dynamic fragments at runtime.

### Content Ordering & Nested Sections

A single canonical comparator defines page order everywhere. Within a section, integer-`weight` pages sort first (ascending by `weight`); ties and all unweighted pages fall through to the existing date-descending-then-URL order, so sections with no `weight` are byte-for-byte unchanged. A malformed `weight` is warned about (naming the page) and treated as unweighted; the build never aborts.

The content model is additive-nested: `Page.section` stays the top-level folder, while the new immutable `Page.sectionPath` field carries the full lineage (e.g. `docs/guides`), surfaced to templates as `${page.sectionPath}` and `${page.ancestors}` (a plain list of cumulative section paths). A separate, additive `${page.breadcrumbs}` field carries the same trail as structured `{url, title}` nodes — each ancestor section's prefixed URL (or `''` for a synthesized `_index.md`-less folder) plus a menu-consistent 3-tier-fallback title — for themes that render a breadcrumb bar without re-deriving titles. A nested `_index.md` lists exactly its own level's pages (excluding sibling sub-sections).

`orderedSectionPages(sectionPath, allPages)` is the single reusable ordered-section seam (own-level lineage filter + canonical comparator). `PageGenerator`'s `${pages}` listing and pagination route through it, and it is the contract downstream navigation (menu tree) and prev/next resolution consume verbatim — one ordering source, no divergent second sort.

### Navigation Menu Tree

`NavigationBuilder` produces one nested `${site.menu}` tree of `{title, url, children}` map nodes, mirroring the content section hierarchy. It is built once from the discovered pages and injected into the shared `siteParams` (`site.menu`) at both assembly sites (with and without taxonomy), so it rides the existing every-page context to **every** render — single, section, home, and taxonomy virtual pages — satisfying FR3's every-page requirement with a single injection point (list-page-only assembly would omit it from single/home renders). Own-level page order comes from `orderedSectionPages` (the builder holds no comparator or lineage filter of its own); sections nest by `Page.sectionPath` lineage. Because the tree is shared across renders it carries **no** per-page active flag: a theme resolves the active page and its ancestor trail by comparing each `node.url` against `${page.url}` at render time. Title precedence is `menu_title` → `title` → humanized URL slug. Drafts and `menu_exclude: true` pages are filtered (mirroring `!isDraft`); an opted-out section drops its own node but hoists surviving children to its parent, while a folder with no `_index.md` still yields a synthesized node. Empty content yields `[]`, and sites not referencing `${site.menu}` stay byte-for-byte unchanged. Taxonomy virtual pages are injected after the tree is built, so they receive the menu but never appear as menu nodes.

### In-Section Prev/Next

`PageGenerator._resolvePrevNext(page, allPages)` supplies each **single doc page** with `${page.prev}`/`${page.next}` neighbor references (`{url, title}` maps). It holds **no** comparator or lineage filter of its own: it calls `orderedSectionPages(page.sectionPath, allPages)` — the same single ordering seam the `${pages}` listing and the `NavigationBuilder` menu tree consume — finds the page's index in that own-level sequence, and returns the flanking pages. Prev/next order therefore matches sidebar and list order by construction; a second sort here would be the only way they could diverge. Boundaries are handled by absence (no `prev` at index 0, no `next` at the last index, neither for a single-element section), and the keys attach **additively** onto the existing `pageToMap` output in `_buildContext` — each only when present. Attachment is gated to the non-list single-doc render branch (`PageKind.single` and not a list page), so section, home, and taxonomy pages (including single-kind taxonomy *term* pages, which are list pages via `termName`) receive neither key and keep their `paginator.dart` sequencing. The `arbor` theme's `_default/single.html` renders a `tl:if`-guarded region reading these values, so only the links that exist appear. Because attachment only adds keys (never mutates existing ones), a site whose templates do not reference `${page.prev}`/`${page.next}` is byte-for-byte unchanged.

### Per-Page Term Links

`TaxonomyCollector.termLinksForPage(page, index)` resolves each page's **own** front-matter terms to link maps, keyed by taxonomy, surfaced additively as `${page.termLinks.<taxonomy>}` (each entry `{name, slug, url, count}`). The `url`/`slug` come from the same collected `TaxonomyIndex` that `buildVirtualPages` emits the term pages from, so a pill link and its target term page share one canonical, slugified path **by construction** — never string-built as `/{taxonomy}/{rawTerm}/`, which 404s for any term needing slugification (uppercase, spaces, punctuation, e.g. `Hello World` → `/tags/hello-world/`). The builder injects `termLinks` into each non-draft content page's front matter after `collect` and before `buildVirtualPages`, gated on `taxonomies` being declared — so pills render only when the term pages they point at actually exist. `${taxonomy.<name>}` remains the site-global term list (all terms, for tag clouds/listing pages); `${page.termLinks.<name>}` is this page's subset. The `verdant` theme's `_default/single.html` iterates it (`tl:href="${tag.url}"`), mirroring how `tags/list.html` already links via each term's `${term.url}`. Pages with no declared taxonomy or no terms receive no key, so templates not reading it are byte-for-byte unchanged.

### URL Path-Prefix

`pathPrefix` (config) serves a site under a sub-path (e.g. GitHub project pages at `/my-site/`). It is applied at the **single `deriveUrl` seam** during discovery, so `page.url` itself carries the prefix and every downstream consumer inherits it with no per-consumer change: `${page.url}` links, the section/menu tree, prev/next, and the search-index `url` fields. Sitemap/feed generators compose `baseUrl` + the (now-prefixed) `page.url`, so the prefix appears exactly once (`baseUrl` — the canonical origin — and `pathPrefix` — the sub-path — are orthogonal and compose). `SiteConfig.normalizeBaseUrl` removes a configured trailing slash before the value reaches `${site.baseUrl}`, preventing themes that join it to root-absolute `${page.url}` from emitting a doubled slash. Only internal root-absolute paths (leading `/`, not `//` protocol-relative, not scheme-bearing) are rewritten; absolute/external URLs pass through verbatim. `SiteConfig` normalizes the prefix (`x`, `/x`, `x/`, `/x/` → `/x/`; `''` and `/` → no prefix) and rejects an un-normalizable value (scheme-bearing/protocol-relative or non-string) with a `SiteConfigException` before any output is written. The empty (default) prefix is a literal no-op — output is byte-for-byte unchanged. Hand-written literal asset references the engine cannot see are opted in by theme authors via `${site.pathPrefix}` (e.g. `tl:href="${site.pathPrefix} + 'css/main.css'"`). The prefix lives in emitted URLs only, **not** in the on-disk output layout: page files are written at their *unprefixed* paths (via `stripPathPrefix` in the output-write + bundle-asset steps), so the whole `output/` tree is published as the site root and the host mounts it under the prefix (GitHub Project Pages serves the artifact root at `/<repo>/`). Nesting output under the prefix would double-apply it. **Hand-written links get the prefix too:** a final `applyPathPrefixToLinks` pass over each emitted page rewrites root-absolute internal `href`/`src` (Markdown content links, theme literals, vendored-asset refs) that are not already prefixed — expected SSG behavior — while relative links, anchors, external URLs, and escaped code examples are left untouched. Theme resolution (`themeDir`) is `p.normalize`d at all three computation sites (engine manifest/loader + CLI SASS compile) so a relative `theme:` value that escapes the site dir resolves; the CLI's `build` also carries `pathPrefix` through and accepts a `--path-prefix` override.

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
  isHtmxRequest(context)  htmxTarget(context)  htmxSource(context)  ← HTMX detection
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
- Only `PageKind.single` content pages indexed; draft pages, excluded sections, and `search: false` front matter omitted

---

## Themes & Docs Site (through the 0.11 implementation milestone)

Themes ship in `themes/` alongside the packages, and the **Trellis docs site** lives in `site/`. Themes are installable
assets consumed through a `theme:` reference; neither themes nor the site are publishable packages. The site is content
built by `trellis_cli`.

### Arbor Docs Theme (`themes/arbor/`)

A documentation-oriented theme sitting beside the `verdant` blog theme (both are standard-params-contract themes). It consumes the SSG's navigation surfaces directly: a hierarchical sidebar from `${site.menu}` (active/active-trail highlighting resolved at render time), an in-page TOC from `${page.toc}`, a breadcrumb bar from `${page.breadcrumbs}`, and prev/next links from `${page.prev}`/`${page.next}`. A CLI-generated SASS **bridge wrapper** in the consuming site's `.trellis/build/` directory `@import`s the selected theme's params + `sass/main.scss` so `trellis build` compiles the theme's stylesheet with the site's `theme_params` bound.

**Build-time syntax highlighting (ADR-010)** — arbor ships **no** highlighter JS. `trellis_site` colors fenced code at build time (`CodeHighlighter`, `package:highlight`), baking `.hljs-*` token spans into the HTML; the theme carries only the matching token CSS (`sass/_code.scss`), so code is colored with JavaScript disabled. See [ADR-010](../adrs/ADR-010-syntax-highlighting.md).

**Vendored-JS discipline** — the two remaining client-side scripts are both first-party (no third-party library), vendored (committed) and served same-origin with `defer`; no Subresource Integrity hash is used, since for a same-origin script committed alongside the HTML that loads it an SRI hash guards nothing extra (anyone who can alter a served script can alter the served HTML). **No CDN, no `npm`/Node, no runtime fetch from an external host.** Two assets:

- **`search.js`** — a hand-authored, dependency-free vanilla-JS search client (no Lunr/Fuse/MiniSearch vendored library), chosen to keep the asset small and fully auditable while still satisfying the vendored, same-origin discipline.
- **`code-enhance.js`** — adds a language label and copy button to each code block; reads the language from the `language-*` class and the code from `textContent`, so it is independent of the build-time tokenizer. Provenance for both is recorded in `themes/arbor/VENDORED.md`.

Both search and the code copy button are **progressive enhancements**: the docs are fully readable and navigable with JavaScript disabled (and highlighting, being build-time, needs no client JS at all).

### Lattice Docs Theme (`themes/lattice/`)

Lattice carries the same documentation-navigation contracts as Arbor and adds a content-driven home surface. Its theme
data provides default `lattice.yaml` landing content; a consuming site's same-stem file replaces that value as one unit.
The repository's `site/` selects Lattice and supplies its own landing data, while retaining the theme's sidebar, TOC,
breadcrumbs, prev/next navigation, search client, and build-time code highlighting. The additive `show_site_demo` param
defaults to `false`; when enabled, the home layout renders its Markdown-to-page block only if `site_demo.title`,
`site_demo.markdown_html`, and `site_demo.page_title` are all present. This leaf-level guard preserves existing installs
and prevents a partial whole-file data override from publishing an empty section or failing the build.

### Client-Side Search Flow (S09)

The engine and the theme meet at one artifact — `search-index.json`:

```
trellis_site build                         selected theme (browser)
  SearchIndexGenerator                       search.js (vendored, same-origin)
  (search.enabled: true)                       │
        │  emits                                │  reads index URL from the shell's
        ▼                                       │  data-search-index attribute
  output/search-index.json  ──────────────────►│  (computed with ${site.pathPrefix},
        (url fields already                     │   so the fetch resolves under any
         pathPrefix-prefixed)                    │   deploy sub-path)
                                                 ▼
                                          same-origin fetch → in-memory filter →
                                          result list (title + snippet, entry.url used verbatim)
```

The `<input>` ships `disabled` in the static HTML and is enabled only after the index loads; any index-fetch failure (missing file, non-OK response, malformed payload) hides the control so the page stays usable. Result links use each entry's already-prefixed `url` verbatim — never re-prefixed client-side.

### Docs Site (`site/`)

The `site/` tree is the Trellis marketing landing + documentation IA. It presents server-rendered applications and static
sites as co-equal tracks: engine getting-started and the full `tl:*` syntax reference sit beside a first-class Sites
section for content, layouts, themes, search/feeds, and deployment, plus a per-package reference for each SDK package.
The site carries no `pubspec` of its own; `trellis build`
reads `site/trellis_site.yaml` from the working directory, which wires `theme: ../../themes/lattice` (a relative escape
resolving to `<repo>/themes/lattice`), `search.enabled: true`, and the deploy target. Lattice's theme data supplies landing
defaults, while the site's same-stem data replaces them wholesale. The site opts into the `site_demo` block and the
shared "Built with Trellis" footer attribution. The generated themes gallery reads
`site/data/themes.yaml` and site-owned screenshot copies under `site/static/themes/`; its inventory is regenerated from
installed theme manifests. The GitHub Pages workflow described under
[Deployment Model](#docs-site-static-github-pages) is configured to build the site under `pathPrefix: /trellis/` and gate
publication on the link-integrity check.

### Delivered Theme Inventory

- **`verdant`** – minimal blog theme.
- **`arbor`** – documentation theme with hierarchical navigation and build-time highlighting.
- **`bloom`** – bold product/marketing landing theme.
- **`lattice`** – garden-inspired documentation theme with the content-driven home surface used by `site/`.
- **`folio`** – bookish documentation/reference theme with semantic figures and sidenotes.
- **`meadow`** – fresh product-landing theme with content-driven marketing sections.

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
│   └── trellis_cli/              # CLI (create, build, serve); scaffold templates in lib/src/templates/
├── themes/
│   ├── arbor/                    # documentation theme
│   ├── bloom/                    # product/marketing landing theme
│   ├── folio/                    # bookish documentation/reference theme
│   ├── lattice/                  # docs + expressive home theme used by site/
│   ├── meadow/                   # product landing theme
│   └── verdant/                  # minimal blog theme
├── site/                         # the Lattice-powered docs/marketing site (built by trellis_cli)
├── examples/
│   ├── docs_site/                # Markdown docs site built with Arbor and trellis_cli
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

### Docs site (static, GitHub Pages)

The documentation site (`site/`) is a separate static-deploy path from the app/server
model above. `.github/workflows/deploy-docs-site.yml` builds `site/` with `trellis
build` on every push to `main` (pure Dart, no npm/Node), gates the deploy on a
pure-Dart link-integrity check (`tool/link_check.dart`), and publishes `site/output`
to GitHub Pages. The deploy target is **config-driven** via `baseUrl` + `pathPrefix`
in `site/trellis_site.yaml` (currently the Project Pages sub-path `/trellis/`); the
workflow hardcodes no domain, so a later custom-domain move is a config edit. The
integrity check is the real gate: a wrong-base-path link produces valid HTML and a
green build but a dead link in production, so it runs (with `--base-path` matching
`pathPrefix`) between build and publish and blocks the deploy on any broken internal
ref. A second, non-live root-served variant is built and checked with no base-path as
an FR10 portability regression guard.

### CLI distribution channels

The `trellis` CLI ships through four channels, all keyed off the lockstep
`vX.Y.Z` release tag (ADR-009). `.github/workflows/release-binaries.yml` compiles
per-platform AOT binaries (macOS arm64/x64, Linux x64/arm64, Windows x64) and
attaches them to the GitHub Release, then updates the Homebrew tap
`tolo/homebrew-trellis` so `brew install tolo/trellis/trellis` resolves. A parallel
`scoop` job (post-publish) renders the Windows manifest with
`tool/render_scoop_manifest.dart` and pushes it to the Scoop bucket repo
`tolo/scoop-trellis`, so `scoop bucket add trellis https://github.com/tolo/scoop-trellis`
then `scoop install trellis` resolves. The same tag drives `publish.yml`, which
publishes the packages to pub.dev independently. The linux-arm64 binary is
cross-compiled on an x64 runner (`--target-os/--target-arch`); both the Homebrew
and Scoop jobs skip gracefully when `TAP_TOKEN` is absent.

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
