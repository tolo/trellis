# ADR-006: CSS Strategy

## Status
Accepted (phasing updated — see note below)

## Context
A web SDK needs a CSS story. The decision is how much CSS tooling Trellis should build vs delegate. Trellis has unique advantages: it already parses HTML (`package:html`), and the canonical SASS implementation is a Dart library (`package:sass`). CSS `@scope` reached Baseline in December 2025 (86%+ browser support), opening fragment-scoped CSS without compile-time hacks.

Research: [Research appendix](research/ADR-006-research.md)

## Decision Drivers

- "No npm required" is a core SDK differentiator — CSS tooling should ideally be pure Dart
- Trellis's HTML parsing gives a structural advantage for class extraction (DOM traversal vs regex)
- The CSS processing package must be optional — users who bring their own CSS shouldn't pay for it
- `csslib` (Dart team) provides CSS parsing but lacks a serializer for round-tripping

## Options

### 1. Dart SASS integration + CSS purger (Recommended — Phase 2)
Wrap `package:sass` for SASS compilation; build a Dart-native CSS purger using `csslib` + Trellis's HTML parsing.

- (+) SASS is literally written in Dart — native library call, no shell-out
- (+) Template-aware purging: DOM traversal is more accurate than regex scanning
- (+) Pure Dart — no npm, no external binaries
- (-) `csslib` lacks a CSS serializer/printer — custom implementation needed
- (-) Dynamic class names (`tl:class="${cond ? 'a' : 'b'}"`) require safelisting

### 2. Lightweight Dart-native CSS processor
Build a custom CSS processor supporting nesting, variables, and purging.

- (+) Zero external dependencies
- (-) Building a CSS parser is non-trivial (spec is complex)
- (-) Users lose SASS compatibility

### 3. Shell out to external tools (Tailwind CLI, PostCSS)
Run external CSS tools via `Process.run()` in the build pipeline.

- (+) Best-in-class tools
- (-) Requires Node.js or standalone binaries — breaks "pure Dart" positioning
- (-) Less control over error messages and integration quality

### 4. Dart-native utility CSS generator (Future — Phase 2+)
UnoCSS-style on-demand CSS: scan templates for utility class names, generate only the CSS used. Rules are pattern-matcher → CSS-generator pairs.

- (+) Pure Dart differentiator — template-aware utility CSS generation
- (+) Produces minimal CSS by default (only classes used in templates)
- (-) Substantial engineering effort
- (-) Users familiar with Tailwind must learn different conventions (unless we mirror Tailwind classes)

## Decision

**Hybrid approach, phased:**

1. **Immediate (Phase 1)**: Document Tailwind CLI + SASS integration for current users (zero code — just guides). Tailwind's plain-text scanner works with Trellis templates out of the box.

2. **SDK Phase 2** (revised — originally all CSS was Phase 2): `trellis_css` package (thin) with:
   - SASS compilation via `package:sass` (Dart-native library call)
   - `tl:scope` processor for fragment-scoped CSS via CSS `@scope`

3. **SDK Phase 3**: `trellis_css` expansion with:
   - CSS purging via `csslib` + DOM traversal (template-aware class extraction)
   - CSS minification
   - Informed by the csslib round-trip feasibility spike (see the [research appendix](research/ADR-006-research.md))

4. **Future**: Dart-native utility CSS generator (Option 4) as an optional capability within `trellis_css`.

**Phasing rationale (2026-03-15)**: CSS purging and minification require a custom CSS printer for `csslib` (which lacks a serializer). This is a non-trivial risk. SASS compilation and `tl:scope` are low-risk and ship with Phase 2 (alongside SSG). Full CSS processing is deferred to Phase 3 pending a feasibility spike.

External tool integration (Tailwind CLI) remains as a documented escape hatch for teams with existing CSS pipelines.

### CSS purger static analysis boundary

The purger's class extraction is **strictly static** — it does not evaluate Trellis expressions at build time:

- **Automatically extracted**: literal class tokens from `class="..."` attributes, static strings in `tl:class="'active'"`, `tl:classappend="'highlight'"`
- **Safelisted by user**: any runtime-dependent or concatenated class generation (e.g., `tl:class="${condition ? 'active' : 'inactive'}"`, `tl:attr="class='prefix-' + ${value}"`)
- **Not attempted**: full Trellis expression evaluation, variable resolution, or conditional analysis at build time

This keeps the purger predictable and avoids scope creep into expression-analysis complexity.

### `tl:scope` integration contract

`tl:scope` is an **optional processor provided by `trellis_css`**, not part of core `trellis`:

- Registered via `trellis_css`'s dialect (uses the existing `Dialect`/`Processor` extension API)
- Targets `<style tl:scope>` elements within a `tl:fragment`
- Emits: wraps the `<style>` contents in `@scope (.tl-scope-{fragment-name}) { ... }` and adds `class="tl-scope-{fragment-name}"` to the fragment's root element
- Requires the fragment to have a single root element (emits a validation warning otherwise)
- Browser support target: modern browsers with `@scope` support (Baseline Dec 2025, 86%+). No fallback mode in Phase 2 — apps targeting older browsers should not use `tl:scope`.

## Consequences

### Positive
- Phase 2 delivers a pure Dart CSS pipeline — no npm dependency
- Template-aware purging is more accurate than Tailwind/PurgeCSS regex scanning, within a well-defined static analysis boundary
- `tl:scope` + `@scope` provides fragment-scoped CSS — a genuine first for server-side template engines
- SASS integration is a native library call — uniquely Dart advantage
- `tl:scope` stays optional (in `trellis_css`, not core) — no impact on users who don't need it

### Negative
- `csslib` serialization gap requires custom printer implementation (non-trivial)
- Dynamic class names always need safelisting — fundamental limitation shared with all CSS purging tools
- SASS as a dep adds weight (though optional — only if user opts in to SASS compilation)

### Neutral
- Tailwind CLI escape hatch means no user is blocked by the Dart-native approach
- `csslib` printer can be contributed upstream if successful
- CSS `@scope` browser support (86%) will only grow — safe to adopt now for modern-browser targets
