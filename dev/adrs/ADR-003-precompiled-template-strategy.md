# ADR-003: Pre-Compiled Template Strategy

## Status
Proposed (deferred — see roadmap)

## Context

trellis parses HTML templates via `html_parser.parse()` on every cold start. The in-memory LRU cache avoids re-parsing on warm hits, but when the cache is empty — app restart, serverless cold boot, horizontal scaling — every template must be re-parsed. The roadmap lists "Pre-compiled template format — Serialized DOM for cold-start optimization" as a future candidate.

Five approaches were evaluated:
- **A**: Dart source code generation (`.trellis.dart` factory functions)
- **B**: JSON serialization (`.trellis.json` DOM representation)
- **C**: Binary serialization (custom `.trellis.bin` format)
- **D**: Metadata sidecar (expression ASTs + fragment registry alongside HTML)
- **E**: Optimized pipeline + template validation toolkit (no new format)

Key constraints: zero new runtime dependencies, backward compatible, aligned with trellis's "simple, no codegen, single dep" philosophy.

**Assumption**: trellis's primary use case is long-running server deployments (Shelf, dart_frog). No production usage data exists yet to confirm this — the assumption is based on project intent and the Thymeleaf-inspired design targeting server-rendered HTML.

## Decision

**We will not introduce a pre-compiled template artifact format. Instead, we will pursue incremental pipeline optimizations and template validation tooling.**

Specifically:

1. **Expression AST cache** — Engine-scoped `Map<String, Expr>` injected into `ExpressionEvaluator` on each render, eliminating re-parsing of expressions across renders. The cache lives on `Trellis` (not `ExpressionEvaluator`, which is recreated per render). `Expr` AST nodes are immutable (sealed/final classes), making sharing safe.

2. **Template warm-up API** — `Trellis.warmUp()` to pre-load and cache templates at server startup, moving parse cost from first-request latency to controlled initialization. Preconditions: caching must be enabled, warmed set should fit within `maxCacheSize`, and warm-up must be called before serving requests.

3. **Template validation toolkit** — Static analysis of templates (expression syntax, unknown `tl:*` attributes) with test helpers and CLI tooling. Scope, configuration model, and API contracts to be defined in a follow-on FIS before implementation.

## Consequences

### Positive
- **Zero workflow change** — HTML templates remain the only artifact; no build step, no generated files
- **Zero new dependencies** — uses only existing `package:html` and engine internals
- **Zero version compatibility risk** — no serialized format to version or maintain
- **Incremental delivery** — expression cache, warm-up API, and validator are independently shippable
- **Aligns with project identity** — "small runtime footprint, no code generation" principle preserved

### Negative
- **Does not eliminate HTML parsing** — the dominant cold-start cost (~60-75% of parse time) remains. For serverless/FaaS with frequent cold starts, this approach is insufficient.
- **Warm-up shifts cost, doesn't reduce it** — total parsing work is unchanged; it happens at startup rather than on first request. If the warmed set exceeds `maxCacheSize`, early entries will be evicted silently.
- **Validator introduces a second interpretation of template semantics** — must stay in sync with the processor pipeline as processors are added or changed. Initial scope should be kept minimal to manage this risk.

### Neutral
- Option A (Dart codegen) remains a viable future complement if serverless demand materializes. Options E and A are fully compatible — expression cache and warm-up benefit codegen paths too.
- Expression cache grows without bound in theory, but unique expressions per application are typically hundreds, not thousands. An optional size limit can be added if needed.

## Alternatives Considered

### Option A: Dart Source Code Generation (7.34/10)
- **Pros**: Maximum cold-start speedup (3-8x), zero runtime deps, human-readable generated code
- **Cons**: Mandatory build step, generated file bloat, tension with "no codegen" principle, no Dart DOM codegen precedent
- **Rejected because**: Introduces workflow complexity (build step, generated files) that conflicts with trellis's simplicity goals. For long-running servers, the warm-up API addresses cold-start in practice without codegen. Remains the documented upgrade path if serverless demand materializes.

### Option B: JSON Serialization (5.85/10)
- **Pros**: Simple format, zero runtime deps, portable
- **Cons**: Only ~2x speedup (benchmarked), JSON is 2-7.6x larger than HTML source, SVG/MathML namespace blocker
- **Rejected because**: Marginal speedup does not justify the complexity. JSON parsing + DOM reconstruction is not meaningfully faster than HTML parsing for typical templates.

### Option C: Binary Serialization (3.61/10)
- **Pros**: Compact file size, fast sequential reads
- **Cons**: ~1,500 lines of custom codec, format versioning fragility, msgpack/protobuf violate no-new-dep constraint
- **Rejected because**: Worst complexity-to-benefit ratio. More complex than codegen but slower. Binary format versioning is an ongoing maintenance liability.

### Option D: Metadata Sidecar (6.49/10)
- **Pros**: Graceful degradation, HTML remains source of truth, low version compat risk
- **Cons**: Does not eliminate HTML parsing (addresses only 2-5% of cold-start cost), sidecar I/O may negate gains
- **Rejected because**: The expression re-parsing problem it targets is better solved by an in-memory cache. Thymeleaf (trellis's inspiration) also uses in-memory caching, not sidecar files.

## Implementation Notes

- **Expression AST cache**: Cache lives on `Trellis`, injected into `ExpressionEvaluator` via constructor. Minor internal API change (evaluator accepts external cache map), but zero public API change.
- **Warm-up API**: Requires a `DiscoverableLoader` interface (or equivalent) on `FileSystemLoader` / `MapLoader`. Semantics around cache-disabled mode, partial failures, and capacity limits to be defined in the implementation spec.
- **Validator**: Scope, configuration model (prefix, dialects, filters), sync vs async boundaries, error model, and CLI contract to be defined in a follow-on FIS. Initial scope should be kept minimal — expression syntax checking and unknown standard attribute detection. Fragment reference integrity (async, requires loader I/O) and variable extraction (approximate, high complexity) should be deferred until there is a concrete consumer.

## References
- [Research appendix](research/ADR-003-research.md) — five approaches, trade-off matrix, Option E technical analysis, and recommendation
