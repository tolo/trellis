# ADR-005: Server Integration Strategy

## Status
Accepted (extended — Phase 3 adds `trellis_dart_frog` and `trellis_relic`)

## Context
The Trellis SDK needs a server integration package. The decision is whether to build on an existing Dart server framework, build a custom server layer, or provide a framework-agnostic adapter. This determines maintenance burden, community alignment, and lock-in risk.

Trellis already has a Shelf integration guide (v0.3) and a Shelf-based todo app example. ADR-002 specifies a `trellis_dev` package using Shelf handlers for SSE hot reload.

Research: [Research appendix](research/ADR-005-research.md)

## Decision Drivers

- Trellis core must remain framework-agnostic (no `shelf` dependency in core)
- The integration package should be stable and long-lived
- Maintenance burden must be manageable for a small team
- The HTMX-first architecture requires HTTP request/response patterns, not RPC or code-gen

## Options

### 1. Build on Shelf (Recommended)
Build `trellis_shelf` as middleware and handlers on top of Shelf.

- (+) Shelf is the Dart team's official HTTP layer — stable, maintained since 2019, 4.99M downloads
- (+) Already validated: v0.3 framework guide and todo app use Shelf
- (+) Dart Frog provides Shelf adapter APIs (`fromShelfHandler`, `fromShelfMiddleware`) for interoperability
- (+) Small, predictable dependency — Shelf API is ~5 core types
- (-) Shelf is deliberately minimal — no routing, DI, or session management in core
- (-) Building convenience layers on top means maintaining glue code

### 2. Build on Dart Frog
Build integration on top of dart_frog's provider/DI and file-based routing.

- (+) Better out-of-box DX — file-based routing, DI, CLI
- (-) Dart Frog's future uncertain — VGV shifted focus, now community-maintained by Felix Angelov
- (-) Couples Trellis audience to dart_frog users only
- (-) dart_frog makes routing decisions that may conflict with Trellis SDK opinions

### 3. Build own server layer on dart:io
Custom HTTP server abstraction directly on `dart:io`.

- (+) Total control over API design
- (-) Massive maintenance burden: HTTP parsing, keep-alive, compression, TLS
- (-) Incompatible with Shelf ecosystem (can't use shelf_router, shelf_static, etc.)
- (-) Reinventing what Shelf does well

### 4. Framework-agnostic adapter pattern
Define a `TrellisServer` abstraction with pluggable adapters for Shelf, Dart Frog, etc.

- (+) Users choose their preferred HTTP layer
- (+) Future-proof against framework changes
- (-) Abstraction adds indirection and design complexity upfront
- (-) Must design carefully to avoid leaky abstractions

## Decision

**Option 1: Build on Shelf**, with the door open for Option 4 (adapter pattern) if a second framework shows demand.

`trellis_shelf` provides Shelf middleware and handlers. Dart Frog users can use `trellis_shelf` directly since Dart Frog is built on Shelf. A separate `trellis_dart_frog` convenience package can be added later if there's demand.

## Consequences

### Positive
- Shelf is the safest long-term bet — Dart team maintained, universal foundation
- Low maintenance burden — Shelf API is stable and minimal
- Follows Trellis's established patterns (TemplateLoader, Dialect, Processor are all strategy patterns)
- Dart Frog interoperability is feasible via its documented Shelf adapter APIs

### Negative
- Must build convenience layers (routing helpers, DI) that Dart Frog provides for free
- Users who prefer non-Shelf frameworks must wrap `trellis_shelf` or wait for an adapter

### Neutral
- Starting with direct Shelf integration (no abstraction layer) is fine — YAGNI applies
- Relic (Serverpod team) is a separate server framework, not Shelf-based — if it gains traction, it would need its own adapter rather than being automatically compatible

## Update (SDK Phase 3)

The original decision to start with Shelf proved correct — `trellis_shelf` shipped in Phase 1 and is battle-tested. Phase 3 extends the strategy to cover the broader Dart server framework landscape:

- **`trellis_dart_frog`** — Dart Frog convenience wrapper. Since Dart Frog is built on Shelf, this is a thin layer providing native provider/middleware patterns and route handler helpers. `trellis_shelf` remains the foundation.
- **`trellis_relic`** — Serverpod Relic integration. Relic has its own request/response model (not Shelf-based), so this is a standalone integration package with request/response adapters and middleware.

This validates the original "door open for Option 4" approach — rather than a generic adapter abstraction, each framework gets a purpose-built integration package that feels native to that framework's conventions.
