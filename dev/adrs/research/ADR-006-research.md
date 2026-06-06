# ADR-006 Research Appendix: CSS Strategy

Curated research supporting [ADR-006](../ADR-006-css-strategy.md).

This appendix consolidates the CSS-tooling research and the `csslib` round-trip feasibility spike that informed ADR-006. It is self-contained — no external links to private documents. Where the original research referenced other internal documents, those cross-references are described in plain text.

---

## 1. CSS Tooling — Technical Findings

### csslib (Dart team, v1.0.2)

- **Parser API**: `parse(String)` → `StyleSheet` AST; `selector(String)` → `SelectorGroup`; `parseSelectorGroup()`
- **Visitor API**: tree traversal via the `visitor` library
- **Full AST**: Rule, AtRule, Declaration, Comment, Root nodes (equivalent to the PostCSS node model)
- **Utilities**: Color (Rgba, Hsla), tokenization, mixin processing, nested-selector expansion
- **Status**: Dart team (`dart-lang/tools` monorepo), ~4.88M downloads, stable/maintenance mode (last published ~16 months before research)
- **Assumed gap (at research time)**: No CSS serializer/printer for round-tripping AST back to CSS text — believed to be the main implementation gap for a Dart-native purger. *This assumption was later disproven by the spike (see Section 2).*

### Dart SASS (v1.98.0)

- **The canonical SASS implementation** — Dart is the primary/reference implementation, not a port
- Very actively maintained
- Programmatic API: `import 'package:sass/sass.dart' as sass; sass.compile(path)`
- Advanced: `sass_api` package for AST access and load resolution; `sass_builder` for `build_runner` integration (`.scss`/`.sass` → `.css`)

### CSS Purging Algorithm (PurgeCSS reference)

The reference implementation uses intentionally naive text scanning:

1. Scan content files with regex `/[\w-/:]+(?<!/)/g` — extracts class-like tokens
2. Parse CSS to enumerate all selectors
3. Match: retain only selectors that appear in the extracted token set
4. Output: stripped CSS

**Trellis advantage**: Trellis already parses HTML into a DOM (`package:html`). Class extraction is DOM traversal, not regex — more accurate than PurgeCSS (no false positives from class-like strings in non-class contexts).

### CSS `@scope` — Baseline December 2025

- **Browser support**: 86%+ (Chrome 118+, Safari 17.4+, Firefox 146+)
- Native component-level CSS scoping without data attributes or class hashing
- "Donut scope": `@scope (.card) to (.nested) { ... }` scopes CSS to a range
- **Directly maps to `tl:fragment`**: a `tl:scope` processor wraps a fragment's `<style>` in `@scope (.tl-fragment-name) { ... }`
- **Cleaner than Vue/Svelte**: no compile-time attribute injection, no class hashing — purely CSS-native

### Modern CSS vs SASS (2025 assessment)

| Feature | CSS Native | SASS Still Needed? |
|---|---|---|
| Variables | Custom properties (99%+) | No — CSS vars have runtime flexibility |
| Nesting | Native nesting (92%+, Baseline 2023) | No |
| Calculations | `calc()`, `clamp()`, `min()`, `max()` | No |
| Scoping | `@scope` (86%+, Baseline Dec 2025) | No |
| Cascade control | `@layer` (96%+, Baseline 2022) | No |
| Selectors | `:is()`, `:where()`, `:has()` (98%+) | No |
| Container queries | (93%+) | No |
| **Mixins** | No equivalent | **Yes** |
| **Loops/conditionals** | No equivalent | **Yes** |
| **`@extend`** | No equivalent | **Yes** (but discouraged) |
| **Module system** | `@import` only (no namespacing) | **Yes** (`@use`/`@forward`) |

**Consensus**: For new projects, native CSS covers most SASS use cases. SASS is still needed for mixins, loops, and complex logic.

### Recommended CSS pairings for Trellis users

- **Open Props** — CSS custom properties as design tokens, ~7KB gzipped, zero build step
- **DaisyUI** — pure CSS component library, no JavaScript, works via CDN
- **Tailwind CSS v4** — when utility-first CSS is desired; Tailwind CLI works with Trellis templates out of the box (plain-text scanner)
- **Vanilla CSS** — modern CSS features cover most use cases for new projects

### Trade-off summary (CSS strategy decision)

| Option | Pros | Cons | Risk |
|---|---|---|---|
| **A: Dart SASS + purger** (selected) | SASS is Dart-native; csslib for parsing | csslib serialization gap (assumed); SASS losing market share | Medium |
| **B: Custom CSS processor** | Zero deps; tailored to Trellis | Building a CSS parser is a massive effort | High |
| **C: Shell out to external tools** | Best-in-class tools | Requires Node.js; breaks "pure Dart" positioning | Medium |
| **D: Dart-native utility CSS generator** | Pure Dart differentiator; template-aware | Substantial engineering; users must learn new classes | Medium |

**Outcome**: Hybrid — A (SASS + purger) as primary, with D (utility generator) as a future differentiator and C (external tools) as an escape hatch. Reversibility: high.

---

## 2. csslib Round-Trip Feasibility Spike

**Conducted**: 2026-03-15 to 2026-03-17. **Verdict**: feasible for standard CSS; not feasible for modern CSS features (`@scope`, `@layer`, `@container`).

### Why the spike ran

ADR-006 identified a serialization gap in `csslib` as the critical risk for building a Dart-native CSS purger, and deferred purging/minification to a later phase pending validation. The spike set out to determine feasibility, estimate effort, and identify alternatives before committing to implementation.

### Key finding: the serialization gap does not exist

`csslib` already ships a built-in `CssPrinter` visitor (`lib/src/css_printer.dart`) with both pretty-print and compact (minified) modes — used extensively in csslib's own test suite. The assumed serializer gap was incorrect. The **actual** gap is in the **parser**: it does not support `@scope`, `@layer`, or `@container`.

The AST exposes 57 node types and a `Visitor` base with 58 `visit*` methods (double-dispatch via `node.visit(visitor)`), making selector-filtering visitors straightforward to write.

Usage:

```dart
import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';

final stylesheet = css.parse(cssInput);
final output   = (CssPrinter()..visitTree(stylesheet, pretty: true)).toString();
final minified = (CssPrinter()..visitTree(stylesheet, pretty: false)).toString();
```

### Round-trip test results

Idempotency criterion: `parse → print → parse → print` must produce identical output on both prints. Total: **54 tests, all passing.**

| Test Case | Rules | Idempotent | Parse Errors | Verdict |
|---|---|---|---|---|
| Minimal (10 rules, simple selectors) | 10 | Yes | 0 | PASS |
| Modern CSS (`@media`, `@supports`, `@keyframes`, `@font-face`) | 8 | Yes | 0 | PASS |
| Custom properties (csslib `var-` syntax) | 6 | Yes | 0 | PASS |
| Standard custom properties (`--name` / `var(--name)`) | 4 | Yes | 0 | PASS |
| `var(--name, fallback)` (default values) | 2 | Yes | 0 | PASS |
| DaisyUI-like (component library CSS) | 18+ | Yes | 0 | PASS |
| Tailwind-like (utility CSS, 50+ rules) | 55+ | Yes | 0 | PASS |
| Complex selectors (combinators, pseudo-elements, attribute selectors) | 9 | Yes | 0 | PASS |
| `@import` / `@charset` | 3 | Yes | 0 | PASS |
| `calc()` expressions | 2 | Yes | 0 | PASS |
| Multiple backgrounds | 1 | Yes | 0 | PASS |
| Grid properties | 1 | Yes | 0 | PASS |
| `!important` declarations | 1 | Yes | 0 | PASS |
| Unicode range (`@font-face`) | 1 | Yes | 0 | PASS |
| **Foundation CSS** (real-world, 169KB, 5617 lines) | 1530 | Yes | 0 | PASS |
| Foundation-like snippet (grid system) | 14 | Yes | 0 | PASS |
| `@layer` | – | N/A | 5 | FAIL (not parsed) |
| `@scope` | – | N/A | 7 | FAIL (not parsed) |
| `@container` | – | N/A | 2 | FAIL (not parsed) |
| Nested selectors (LESS-style) | 1 | Partial | 0 | WARN (spurious semicolons) |
| Comments | 3 | Yes | 0 | WARN (comments dropped) |

**Performance** (Foundation CSS, 169KB, 1530 rule blocks): parse 96ms, print 18ms, full round-trip (2nd parse + print) 35ms.

### Feature-level findings

| Feature | Parser | Printer | Notes |
|---|---|---|---|
| `@scope` | No | No | Parser errors; produces garbled/lost output |
| `@layer` | No | No | Interpreted as a `var-layer` declaration |
| `@container` | No | No | Interpreted as a `var-container` declaration |
| CSS nesting (spec `&`) | Partial | Partial | LESS-style nesting works; spec nesting partially works |
| Comments | Parsed | Dropped | Parsed into `CssComment` nodes but dropped by the printer in non-testing mode |
| `@namespace` | Parsed | Buggy | Null-check error when URI uses an alternate quoted format |
| Color normalization | N/A | Lossy | `#0066cc` → `#06c`; `red` → `#f00` (functionally equivalent, not byte-identical) |

**Works perfectly (100% fidelity)**: standard rule sets at any selector complexity; all combinators (descendant, `>`, `+`, `~`); pseudo-classes and pseudo-elements; attribute selectors; multi-selector rules; `@media` (incl. nested `@supports`); `@supports`; `@keyframes`; `@font-face` (incl. `unicode-range`); `@import` (url and string forms); `@charset`; `var(--name)` and `var(--name, fallback)`; `--name: value` declarations; `calc()`; `rgba()`/`hsla()` and other functions; multi-value declarations; `!important`; compact/minified output.

### Verdict and implications

**Partially feasible** — feasible for CSS purging and minification, not feasible for purging CSS that contains `@scope`/`@layer`/`@container` blocks (csslib's parser corrupts them). This matters because `@scope` is the foundation of the `tl:scope` processor: a purger built naively on csslib would corrupt scoped CSS.

| Capability | Feasible with csslib? | Notes |
|---|---|---|
| CSS purging (remove unused selectors) | Yes | Core use case works perfectly |
| CSS minification | Yes | `CssPrinter(pretty: false)` is built-in |
| Purging CSS with `@scope` blocks | No | Parser fails on `@scope` |
| Purging CSS with `@layer` | No | Parser fails on `@layer` |
| Purging CSS with `@container` | No | Parser fails on `@container` |
| Template-aware class extraction | Yes | Orthogonal to CSS parsing |

### Effort estimates

| Scope | Effort | Description |
|---|---|---|
| CSS purger (standard CSS only) | S | Built-in printer works; implement selector-filtering visitor + class extraction |
| CSS purger (with `@scope`/`@layer` support) | L | Requires upstream csslib parser support OR a custom parser for modern at-rules |
| CSS minification | XS | Already built-in: `CssPrinter(pretty: false)` |
| Comment preservation | S | Override `visitCssComment` in a custom printer subclass |

### Recommended approach (hybrid)

1. **Use csslib for purging standard CSS** — the round-trip pipeline is production-ready; build the selector-filtering visitor and template-aware class extractor.
2. **Preserve `@scope`/`@layer`/`@container` blocks as opaque strings** — pre-extract modern at-rule blocks as raw strings before parsing, then splice them back after purging.
3. **Use `CssPrinter(pretty: false)` for minification** of the standard portions; modern blocks pass through (un-minified or via a simple whitespace reducer).
4. **Consider an upstream contribution** — adding `@scope`/`@layer`/`@container` to csslib's parser (in `dart-lang/tools`) is the best long-term fix.
5. **Alternative fallback**: `lightningcss` (Rust, standalone binary) via process/FFI if the opaque-string approach proves too fragile — though it breaks "pure Dart" positioning.

### Alternatives evaluated

| Alternative | Feasibility | Effort | Trade-offs |
|---|---|---|---|
| csslib + opaque modern blocks (recommended) | High | M | Purging works for ~95% of CSS; modern blocks pass through unpurged |
| Upstream csslib contribution | Medium | L | Best long-term; depends on Dart team review velocity |
| String-level CSS purging | High | M | Parse selectors only with regex; match against used classes; no AST |
| `lightningcss` via process | High | S | Breaks "pure Dart"; proven tool; handles all modern CSS |
| Defer purging entirely | High | None | Document Tailwind CLI as the purging solution; ship minification-only |

---

## 3. How this maps to ADR-006

- The **assumed serializer gap** that motivated deferring purging to a later phase **does not exist** — csslib ships a working `CssPrinter`. The real constraint is the parser's lack of `@scope`/`@layer`/`@container` support.
- Purging and minification of standard CSS are **low-effort (S/XS)** and validated against real-world CSS (Foundation, 169KB) at 100% fidelity.
- The hybrid "opaque modern blocks" strategy reconciles purging with the `tl:scope`/`@scope` direction chosen in the ADR, preserving the "pure Dart, no npm" positioning while keeping the external-tool (`lightningcss`/Tailwind CLI) escape hatch available.
