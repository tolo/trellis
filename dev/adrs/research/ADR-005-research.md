# ADR-005 Research Appendix: Server Integration Strategy

Curated research supporting [ADR-005](../ADR-005-server-integration-strategy.md).

This appendix condenses the server framework research conducted in March 2026 that informed the decision to build Trellis's server integration on Shelf. It covers the Dart server framework landscape, a comparison of the leading frameworks, framework-agnostic adapter considerations, and the supporting rationale.

---

## Dart Server Framework Landscape (March 2026)

### Comparison Matrix

| Framework | Version | Likes | Downloads | Maintainer | Built On | License | Key Feature |
|---|---|---|---|---|---|---|---|
| **Shelf** | 1.4.2 | 1,030 | 4.99M | Dart team | dart:io | BSD-3 | Middleware pipeline |
| **Dart Frog** | 1.2.6 | 848 | 23.9K | dart-frog.dev (Felix Angelov) | Shelf | MIT | File-based routing, CLI |
| **Serverpod** | 3.4.4 | 716 | — | serverpod.dev | Custom | SSPL-1.0 | Full-stack, code gen, ORM |
| **Jaspr** | 0.22.3 | 690 | — | schultek.dev | Shelf | MIT | Flutter-like SSR components |
| **Alfred** | 1.1.3 | 365 | — | unverified | dart:io | MIT | Express.js-inspired |
| **Conduit** | 6.0.0 | 176 | 1.72K/wk | theconduit.dev | dart:io | BSD-2 | Aqueduct fork, ORM, OAuth2 |
| **Relic** | 1.2.0 | 115 | 57.4K | Serverpod team | Custom | MIT | Trie router, typed headers |
| **Angel3** | 8.6.0 | 55 | 460/wk | DukeFirehawk | dart:io | BSD-3 | Full-stack, DI, GraphQL |
| **Vaden** | 1.0.2 | 32 | — | Flutterando | Custom | MIT | Spring Boot-inspired |
| **Spry** | 7.0.0 | 10 | — | medz.dev | Custom | MIT | Multi-runtime (CF Workers, Bun) |

### The Shelf Ecosystem

Shelf is the Dart team's official HTTP layer (from the `dart-lang/shelf` monorepo). It is deliberately minimal — a middleware pipeline with no built-in routing, DI, or session management. That gap is filled by a stable ecosystem of companion packages:

- `shelf_router` v1.1.4 — URL routing with `<param>` path parameters
- `shelf_static` v1.1.3 — static file serving (4.9M downloads)
- `shelf_web_socket` v3.0.0 — WebSocket upgrade (6.96M downloads)
- `shelf_proxy` — reverse proxy handler
- `shelf_gzip` — response compression
- `shelf_plus` v1.11.0 (community) — convenience wrappers, auto-serialization

### Framework Notes

**Relic is the one to watch.** Built by the Serverpod team as the future foundation for Serverpod's HTTP layer. Features trie-based O(log n) routing, strongly typed HTTP headers (Dart objects, not raw strings), built-in WebSocket, static file serving with ETag/cache busting, and hot reload. Very new at research time (v1.2.0, roughly two days old) but backed by Serverpod's resources. Critically, Relic is **not** Shelf-based — it has its own request/response model, so any Trellis integration would need to be a standalone package rather than reusing the Shelf integration.

**Dart Frog is built on Shelf.** It originated at Very Good Ventures (VGV) but is now independently maintained at `dart-frog.dev` by Felix Angelov (VGV's founder). The GitHub repository moved from `VeryGoodOpenSource/dart_frog` to `dart-frog-dev/dart_frog`. Its CLI (`dart_frog_cli` v1.2.13) was updated 12 days before research; the community transition appears healthy. Because Dart Frog sits on Shelf, Dart Frog users can consume a Shelf-based Trellis integration directly.

**Jaspr is the closest conceptual overlap with Trellis** — server-side Dart rendering with component-based HTML output. Jaspr uses Flutter-style widget trees; Trellis uses natural HTML templates. Different niches, overlapping audiences. (It is built on Shelf, with `jaspr_tailwind` for CSS integration.)

**Serverpod's license is a concern for integration.** Serverpod ships under SSPL-1.0 (Server Side Public License) — running it as a service may require open-sourcing your code. Its client packages use BSD-3. This makes Serverpod itself a poor fit for a Trellis integration, though its Relic offshoot (MIT) is not affected.

### Hot Reload Tooling (supporting context)

The dev workflow combines server-code reload with Trellis's own template hot reload:

- `shelf_hotreload` v1.6.0 — source-change-triggered server restart
- `hotreloader` v4.3.0 — generic hot reload via VM service
- `watcher` v1.2.1 — Dart team cross-platform file watching (inotify/FSEvents/ReadDirectoryChangesW)

Combination: `shelf_hotreload` for Dart code + Trellis `devMode` for templates = full dev workflow with zero manual restarts.

---

## Architectural Trade-Off: Server Integration

The decision deliberation weighed four options:

| Option | Pros | Cons | Risk |
|---|---|---|---|
| **A: Build on Shelf** ✅ | Dart team maintained; already validated in v0.3 | Minimal (no routing/DI/sessions built in) | Low |
| **B: Build on Dart Frog** | File-based routing, DI, CLI | Uncertain future; couples to community framework | High |
| **C: Own server layer** | Total control | Massive maintenance; reinventing Shelf | Very high |
| **D: Adapter pattern** | Framework-agnostic; future-proof | Abstraction complexity; leaky abstraction risk | Low-medium |

**Decision: A (Shelf-first)**, with **D (adapter)** deferred until a second framework shows demand. Reversibility: High.

---

## Framework-Agnostic Adapter Considerations

The adapter pattern (Option D) defines a `TrellisServer` abstraction with pluggable adapters per HTTP layer. It is attractive for future-proofing and user choice, but adds indirection and design complexity upfront, with a real risk of leaky abstractions if introduced prematurely. The research favored deferring it under YAGNI — direct Shelf integration first, with the door open to an adapter (or per-framework packages) once demand from a second framework is demonstrated.

The key constraint shaping any adapter strategy: most leading frameworks (Dart Frog, Jaspr) are Shelf-based and therefore interoperate with a Shelf integration for free, while frameworks with custom request/response models (Relic, Serverpod, Spry, Vaden) cannot be served by the same integration and would each require purpose-built adapters.

---

## Rationale Summary

- **Shelf is the safest long-term bet** — Dart team maintained, stable since 2019, ~5M downloads, and the universal foundation that the most popular higher-level frameworks build on.
- **Low maintenance burden** — Shelf's API is small (roughly five core types) and stable; the companion ecosystem covers routing, static files, WebSockets, proxying, and compression.
- **Already validated** — Trellis's v0.3 framework guide and todo app example were built on Shelf before this decision was formalized.
- **Dart Frog interoperability is feasible** because Dart Frog is built on Shelf; a thin `trellis_dart_frog` convenience layer can provide native-feeling provider/middleware patterns without re-implementing the integration.
- **Relic needs its own integration** — its custom (non-Shelf) request/response model means a separate `trellis_relic` package with dedicated adapters rather than automatic compatibility.

This research supports the broader decision that rather than a single generic adapter abstraction, each framework that shows demand receives a purpose-built integration package that feels native to its conventions, with Shelf as the foundation.
