# ADR-002 Research Appendix: Browser Hot Reload Strategy

Curated research supporting [ADR-002](../ADR-002-browser-hot-reload-strategy.md).

## Context

v0.5 added dev-mode file watching — `FileSystemLoader` detects template changes and clears the engine cache, but the browser still requires a manual refresh. The server-side change signal already exists:

- `FileSystemLoader.changes` — a broadcast `Stream<void>` emitting on template file changes (shipped in v0.5)
- `Trellis.close()` — async cleanup of watcher resources
- The todo app example uses Shelf + HTMX

The foundation (server-side change detection) is in place. The missing piece is server→browser notification.

## Approaches Evaluated

### A. SSE Endpoint (Recommended)

The server exposes a Server-Sent Events endpoint. The browser connects via `EventSource` or the HTMX SSE extension.

```
[FileSystemLoader.changes] → SSE endpoint → Browser EventSource → reload
```

Server side (~15 lines): a Shelf `Handler` listens to `loader.changes` and writes `event: reload\ndata: \n\n` to a `text/event-stream` response for each change.

Browser side — HTMX (zero JS):

```html
<body hx-ext="sse" sse-connect="/_dev/reload" sse-swap="reload">
```

Browser side — vanilla JS fallback:

```html
<script>
new EventSource('/_dev/reload').addEventListener('reload', () => location.reload());
</script>
```

- Pros: No response buffering, no HTML mutation, works with streaming, HTMX-native
- Cons: Requires explicit endpoint setup

### B. Script Injection Middleware

Shelf middleware intercepts HTML responses and injects a `<script>` tag before `</body>`.

```
[Response HTML] → middleware buffers → injects script → sends modified response
```

- Pros: Zero config for users — just add the middleware
- Cons: Must buffer the entire response (memory), breaks streaming, fragile HTML manipulation

### C. WebSocket

Similar to SSE but bidirectional. Overkill for unidirectional reload signals.

- Pros: Very low latency
- Cons: Protocol upgrade, proxy issues, needs a `shelf_web_socket` dependency, more complex

## Dart Ecosystem Survey

No existing Dart package does browser-level template hot reload — a gap trellis can fill.

| Tool | What it reloads | Mechanism | Applicable? |
|------|----------------|-----------|-------------|
| `webdev --auto=reload` | Dart web (compiled JS) | Injected client.js + DevTools protocol | No (dart2js, not SSR) |
| `hotreloader` | Dart VM code | VM service hot reload | No (code, not templates) |
| `shelf_hotreload` | Shelf server code | VM service | No (code, not browser) |
| `dart_frog dev` | Server code + routes | VM hot reload | No (code, not templates) |

## Trade-Off Matrix

| Criterion | SSE Endpoint | Script Injection | WebSocket |
|-----------|-------------|------------------|-----------|
| Setup complexity | Low | Medium | Medium |
| Dependencies | None (Shelf only) | None | shelf_web_socket |
| HTMX integration | Native | Custom JS | Custom JS |
| Streaming compat | Yes | No (buffering) | Yes |
| Proxy friendly | Yes | N/A | Poor |
| Memory overhead | Low | Medium | Low |

## Package Architecture Options

- **Separate `trellis_dev` package (Recommended)** — barrel export plus `live_reload_handler.dart` (SSE endpoint) and an optional `dev_middleware.dart` (script injection); depends on `trellis` and `shelf`. Keeps trellis dependency-free with opt-in dev tooling and clear separation; cost is a second package to maintain.
- **Built into trellis** — zero-config, but adds `shelf` as a production dependency for a dev-only feature and couples trellis to Shelf.
- **Documented recipe only** — a ~20-line snippet in the framework-integration guide; no package, but fragmented, no reuse, and users must understand SSE.

## HTMX Integration (Key Differentiator)

Because trellis is HTMX-first, the SSE approach unlocks reload modes no existing tool offers:

1. **Full page reload** — `sse-swap` triggers `hx-get="/"` on the body for a full refresh via HTMX
2. **Partial reload** — the server sends changed fragment names in the SSE data; HTMX fetches only those fragments via OOB swap
3. **CSS-only reload** — filter `.css` changes and inject the updated stylesheet without a full reload

The partial reload path is a genuine differentiator — no existing tool does HTMX-aware template hot reload.

## Recommendation

An SSE endpoint in a `trellis_dev` package, with two client integration paths:

1. **HTMX path (primary)** — document `sse-connect` + `sse-swap` attributes; zero JS, declarative
2. **Vanilla path (fallback)** — a small JS snippet or optional injection middleware

This aligns with trellis's design philosophy (natural HTML, HTMX-first) and keeps the core package dependency-free.

## Open Questions Carried into the ADR

1. Should `trellis_dev` provide a Shelf `Middleware` (wraps inner handler) or a standalone `Handler` (mounted on a route)?
2. Should SSE data include the changed file path (enabling partial reload) or just a generic "reload" signal?
3. Should `trellis_dev` also provide a `devMiddleware()` that combines the SSE endpoint with optional script injection?
4. Naming: `trellis_dev`, `trellis_tools`, or `trellis_reload`?
5. Should this be a v0.6 milestone or a separate project?
