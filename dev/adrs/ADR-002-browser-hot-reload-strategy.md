# ADR-002: Browser Hot Reload Strategy

**Status**: Accepted (implemented in `trellis_dev`)
**Context**: v0.5 shipped dev-mode file watching (server-side cache invalidation). Browser still requires manual refresh.
**Research**: [Research appendix](research/ADR-002-research.md)

## Decision Drivers

- trellis is HTMX-first — solution should leverage HTMX idioms
- trellis core has zero framework dependencies — must not add `shelf` to main package
- `FileSystemLoader.changes` stream already provides the change signal
- Dev-mode only — zero production footprint

## Options

### 1. SSE endpoint in separate `trellis_dev` package (Recommended)

Separate package provides an SSE handler/middleware for Shelf. Browser connects via HTMX SSE extension or vanilla EventSource.

- (+) Core package stays dependency-free
- (+) HTMX SSE extension = zero custom JS, declarative HTML
- (+) SSE is proxy-friendly, no protocol upgrade
- (+) Streaming-compatible (no response buffering)
- (+) Natural extension point for future dev tools
- (-) Second package to publish and maintain
- (-) Users must add a dev dependency

### 2. Script injection middleware in separate package

Shelf middleware buffers HTML responses and injects a reload `<script>` before `</body>`.

- (+) Zero-config for users — just add middleware
- (-) Requires response buffering (breaks streaming, memory overhead)
- (-) Fragile HTML string manipulation
- (-) Not HTMX-native

### 3. Built into trellis core

Add SSE/middleware directly to trellis, with `shelf` as dependency.

- (+) Single package, zero-config
- (-) Adds production dependency for dev-only feature
- (-) Couples template engine to specific web framework
- (-) Violates "small runtime footprint" principle

### 4. Documented recipe only

Provide a code snippet in the framework integration guide.

- (+) No package to maintain
- (-) No reuse, fragmented implementations
- (-) Higher barrier for users

## Decision

**Option 1: SSE endpoint in `trellis_dev` package.**

Package provides:
- `liveReloadHandler(FileSystemLoader loader)` — Shelf `Handler` serving SSE on a configurable path (default `/_dev/reload`)
- Documentation for HTMX SSE integration (primary path) and vanilla JS fallback
- Optional: `devMiddleware()` combining SSE endpoint + script injection for non-HTMX projects

## Consequences

- trellis core remains dependency-free
- Users add `trellis_dev` as dev dependency, mount SSE handler on their Shelf router
- HTMX users get declarative reload with `sse-connect` attribute
- Non-HTMX users use a small EventSource script
- Future: SSE data could include file paths for HTMX partial/OOB reload (differentiator)

## Implementation Scope (Future Milestone)

Estimated components:
- `trellis_dev` package scaffold (pubspec, barrel export)
- SSE handler (~30 lines)
- Optional script injection middleware (~40 lines)
- Updated todo_app example wiring
- Documentation in framework-integration guide
- Tests for SSE handler lifecycle and event emission
