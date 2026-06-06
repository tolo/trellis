# ADR-003 Research Appendix: Pre-Compiled Template Strategy

Curated research supporting [ADR-003](../ADR-003-precompiled-template-strategy.md).

> **Framing.** This is research behind a **deferred** decision. ADR-003 concluded *not* to build a pre-compiled
> template artifact format, opting instead for incremental pipeline optimizations and validation tooling. No new
> artifact format was implemented. The material below records the comparative analysis that led to that conclusion and
> the technical detail of the chosen direction (Option E), so the decision can be revisited if usage patterns change
> (notably, if serverless/FaaS cold-start latency becomes a measured pain point).

## 1. Problem

trellis parses HTML templates via `package:html`'s `html_parser.parse()` on every cold start. An in-memory LRU cache
avoids re-parsing on warm hits, but when the cache is empty — app restart, serverless cold boot (Cloud Run, Lambda),
horizontal scaling — every template must be re-parsed. The question was whether to introduce a pre-compiled template
format to eliminate that cold-start parsing cost.

### Cold-start render pipeline (what a pre-compiled format would skip)

```
1. Load source string         (TemplateLoader)
2. Normalize self-closing     (_fixSelfClosingBlocks)
3. Parse HTML → Document      (html_parser.parse)   ← dominant cold-start cost
4. Cache Document             (LRU map)
5. Clone cached DOM           (doc.clone(true))
6. Collect fragments          (pre-scan pass)
7. Process tl:* attributes    (DomProcessor pipeline; parses expression strings → AST)
8. Serialize to HTML string   (doc.outerHtml)
```

Steps 2–3 are the cold-start cost. Fragment collection (6) and expression parsing inside (7) could optionally also be
pre-computed.

### Constraints

- **Single runtime dependency** (`package:html`) — adding heavy deps conflicts with project philosophy.
- **`package:html` DOM model** — `Document`/`Element`/`Node` are the only DOM types; no built-in serialization beyond
  `.outerHtml`.
- **Sealed AST for expressions** — 14 `Expr` subclasses, hand-rolled parser; expressions are re-parsed from attribute
  value strings on every render.
- **Clone-before-process** — cached DOM is deep-cloned per render, so any pre-compiled format must produce clonable
  `Document` objects.
- **Backward compatible** — non-compiled templates must keep working; no breaking public API changes.

## 2. The Five Approaches Evaluated

| Option | Idea |
|---|---|
| **A — Dart source codegen** | Generate `.trellis.dart` factory functions that rebuild `package:html` DOM via Dart API calls (`Element.tag()`, `.append()`, …). No parsing at runtime. |
| **B — JSON serialization** | Serialize DOM to `.trellis.json`; reconstruct `Document` via `package:html` API at load. |
| **C — Binary serialization** | Custom compact binary format (`.trellis.bin`) via `dart:typed_data`; reconstruct at load. |
| **D — Metadata sidecar** | Keep HTML; add `.trellis.meta.json` with pre-parsed expression ASTs + fragment registry. HTML still parsed at load. |
| **E — Optimized pipeline + validation toolkit** | No new format. Optimize the existing HTML pipeline (in-memory expression AST cache, warm-up API) and add a template validation toolkit. |

## 3. Comparison / Trade-off Matrix

Eight weighted criteria. Scores out of 10; weight in parentheses.

| Criterion (Weight) | E: Optimized Pipeline | A: Dart Codegen | B: JSON | C: Binary | D: Sidecar | Winner |
|---|---|---|---|---|---|---|
| Cold-start perf (9) | 5 — warm-up shifts cost | **7** — 3–8x speedup | 4 — ~2x | 5 — ~2–3x | 3 — misses goal | **A** |
| Impl complexity (8) | **9** — incremental, ~500 LOC | 6 — moderate | 5 — low-med | 3 — high | 5 — low | **E** |
| Runtime deps (9) | **10** — zero | **10** — zero | 9 | 4 | 9 | **E/A** |
| Dev workflow (7) | **9** — zero change | 6 — build step | 6 | 5 | 7 | **E** |
| Maintainability (8) | **8** — validator tracks processors | **8** — stable API | 6 | 2 | 5 | **E/A** |
| Debuggability (6) | **9** — HTML is truth | 7 — readable Dart | 7 | 2 | 8 | **E** |
| Version compat (7) | **10** — no format | 7 — version stamps | 7 | 4 | 9 | **E** |
| Extensibility (5) | **8** — custom rules | 7 — AST codegen | 5 | 6 | 7 | **E** |

### Weighted totals

| Option | Weighted Score | Normalized |
|---|---|---|
| **E: Optimized Pipeline** | **498/640** | **7.78/10** |
| A: Dart Codegen | 433/590 | 7.34/10 |
| D: Metadata Sidecar | 383/590 | 6.49/10 |
| B: JSON Serialization | 345/590 | 5.85/10 |
| C: Binary Serialization | 213/590 | 3.61/10 |

Option E wins 6 of 8 criteria; Option A wins only on raw cold-start performance.

## 4. Per-Option Findings (A–D)

### Option A — Dart Source Code Generation (7.34/10)
- **Performance**: Programmatic DOM construction skips HTML5 tokenization and the tree-builder state machine (~70
  insertion modes). Expected **3–8x speedup** over `html_parser.parse()` on cold start.
- **Runtime deps**: Zero — generated code imports only `package:html`.
- **API stability**: 20+ `package:html` releases with zero breaking changes to `Element.tag()`, `.append()`,
  `.attributes`, `Document()`, `Text()`, `clone()`. Only breaking change was the null-safety migration (0.15.0).
- **Precedent**: Matches `json_serializable`, `drift`, `freezed`. No existing Dart package generates `package:html` DOM
  construction specifically — this would be novel.
- **Workflow**: Standalone CLI strongly preferred over `build_runner` (codegen reads `.html`, not `.dart`, so the
  analyzer's 30+ transitive deps and 3–10s startup are unnecessary).
- **Cost**: ~500–800 generated lines per moderate template (100 elements); 50 templates ≈ 25–40K generated lines.
- **Gotcha**: `_fixSelfClosingBlocks()` must run before codegen parsing, or generated DOM diverges from runtime DOM.
- **Tension**: Conflicts with the "no code generation" principle; must be positioned as opt-in.
- **Verdict**: Best cold-start option; rejected as the default because of workflow complexity (build step, generated
  files). Documented as the upgrade path if serverless demand materializes — fully complementary with Option E.

### Option B — JSON Serialization (5.85/10)
- Benchmarked with actual trellis templates: JSON decode + DOM reconstruction is only **~2x faster** than HTML parsing.
  Absolute saving ≈ 96 microseconds for a 4.6 KB template; HTML parsing is already sub-millisecond.
- JSON is **2–7.6x larger** than HTML source (9.8 KB JSON vs 4.6 KB HTML for the todo app), so added I/O partially
  negates the parsing speedup.
- **Technical blocker**: `Element.tag()` hardcodes the HTML namespace; templates with inline SVG/MathML cannot be
  correctly reconstructed via the public API.
- No major template engine uses JSON-serialized DOM. **Verdict**: optimizes a cost that is already negligible.

### Option C — Binary Serialization (3.61/10)
- ~2–3x speedup — worse than codegen. DOM object allocation is the bottleneck regardless of input format; Dart's
  VM-optimized `jsonDecode` narrows binary's edge over JSON to ~1.5x.
- `msgpack_dart` and `protobuf` both violate the no-new-runtime-deps constraint; only a custom `dart:typed_data` codec
  survives — ~1,000–1,500 lines, comparable to the entire expression evaluator.
- Format versioning is fragile: any change to the DOM model, processors, or expression language breaks compatibility.
- **Verdict**: worst complexity-to-benefit ratio — more complex than JSON, slower than codegen.

### Option D — Metadata Sidecar (6.49/10)
- **Does not address the primary goal**: HTML parsing (1–10 ms/template) dominates cold start; expression parsing
  (~0.02–0.5 ms total per template) and fragment scanning are only **2–5%** of cold-start time.
- A simpler alternative exists: an in-memory expression AST cache (`Map<String, Expr>`) eliminates expression
  re-parsing in ~3 lines, no serialization needed — making the sidecar's expression caching redundant.
- Sidecar I/O (read + JSON-parse the metadata file) may cost as much as the expression parsing it replaces.
- Thymeleaf (trellis's inspiration) caches expression ASTs in memory, not in sidecar files.
- **Strength**: graceful degradation — templates work without metadata; best debuggability of the format options.
- **Verdict**: technically sound but strategically misaligned.

## 5. Option E — Detailed Technical Analysis (Recommended Direction)

Option E optimizes the existing HTML pipeline instead of pre-compiling to an alternative format. The key insight:
trellis already caches parsed DOMs via LRU, so cold-start cost is paid once per template. Option E makes that first
parse cheaper, adds a warm-up API to control *when* it happens, and adds static validation that catches errors at
test/CI time. Weighted score **7.78/10**.

### 5.1 Where time actually goes (evidence-based)

| Phase | Est. cost share | Evidence |
|---|---|---|
| HTML parsing | **~60–75%** | `html_parser.parse()` runs the full HTML5 tokenizer + tree builder with error recovery. Dominant cold-start cost. |
| DOM cloning | ~10–15% | `clone(true)` recursively copies every node, attribute map, and text. |
| Expression parsing | ~2–5% | Each `tl:*` attribute creates a `Scanner` + `Parser`; expressions are short (< 50 chars). |
| Fragment collection | ~1–3% | Simple recursive walk. |
| Serialization | ~5–10% | `outerHtml` concatenation. |
| DomProcessor construction | <1% | Object allocation + list sort. |

**Critical finding**: expression parsing is only 2–5% of cold start, so an expression cache saves *at most* 2–5% on
cold start — but saves 100% of expression re-parsing on warm renders, where it grows to ~15–25% of cost once HTML
parsing is skipped.

### 5.2 Current caching behavior

The cache key is the **full normalized HTML source string** (not the template name). A cache hit still requires
`doc.clone(true)` because the DOM is mutable. LRU eviction uses a `LinkedHashMap` remove+re-insert; `maxCacheSize`
defaults to 256. After the first render, HTML parsing is skipped entirely; the warm path is `clone(true)` +
`collectFragments` + `process`.

### 5.3 Sub-features

**1. Expression AST cache.** Cache parsed expression ASTs to avoid re-parsing the same string.

```dart
class ExpressionEvaluator {
  final Map<String, Expr> _astCache = {};

  dynamic evaluate(String expression, Map<String, dynamic> context) {
    final ast = _astCache[expression] ?? _cacheAst(expression);
    return _eval(ast, expression, context);
  }

  Expr _cacheAst(String expression) {
    final ast = Parser(expression).parse();
    _astCache[expression] = ast;
    return ast;
  }
}
```

- **Complexity**: ~8 lines. `Expr` AST nodes are immutable (sealed/final classes with final fields), so sharing is
  inherently safe.
- **Impact**: ~2–5% cold, ~15–25% warm. Major win for `tl:each` (expression parsed once, evaluated N times) and inline
  expressions (`[[${...}]]`).
- **Risk**: Zero. Cache can grow unbounded in theory, but unique expressions per app are typically hundreds, not
  thousands; an optional `maxExpressionCacheSize` could be added.
- *Note on placement*: in the engine this cache lives on `Trellis` (not on `ExpressionEvaluator`, which is recreated per
  render) and is injected into the evaluator each render — sharing is safe because `Expr` nodes are immutable.

**2. Template warm-up API.** Pre-load and cache templates at server startup, before any request arrives.

```dart
/// Pre-load specific templates into the cache.
Future<int> warmUp(List<String> templateNames) async {
  var loaded = 0;
  for (final name in templateNames) {
    final source = await loader.load(name);
    final normalizedSource = _fixSelfClosingBlocks(source);
    if (!_cache.containsKey(normalizedSource)) {
      _cache[normalizedSource] = html_parser.parse(normalizedSource);
      loaded++;
    }
  }
  return loaded;
}

/// Pre-load all templates discoverable by the loader.
Future<int> warmUpAll() async {
  if (loader case DiscoverableLoader dl) return warmUp(await dl.listTemplates());
  throw UnsupportedError('${loader.runtimeType} does not support template discovery.');
}

abstract class DiscoverableLoader implements TemplateLoader {
  Future<List<String>> listTemplates();
}
```

- **Complexity**: ~40–60 lines; main work is the `DiscoverableLoader` interface + `FileSystemLoader.listTemplates()`.
  `MapLoader` implements it trivially by returning its keys.
- **Impact**: Transforms cold start from "first request pays parse cost" to "server startup pays parse cost". Called in
  `main()` before binding to the port — zero request-latency impact. Reuses the existing LRU cache.
- **Risk**: Low. I/O failures surface as `TemplateNotFoundException`, same as during rendering.

**3. Eager fragment registry.** Collect fragments during warm-up so the per-render scan is skipped. `collectFragments`
lives on `DomProcessor` (created fresh per render) and clones fragment elements, so caching it means storing a
`Map<String, (Element, List<String>)>` alongside the `Document` in `_cache` and re-cloning fragment elements per render.
- **Complexity**: ~30–40 lines; refactors `_parse` return type and `_cache` value type.
- **Impact**: Marginal (~1–3%). **Verdict: low priority** — not worth the refactor unless templates have hundreds of
  fragments.

**4. `parseFragment()` vs `parse()`.** Investigated as a lighter parse path. Both call the same internal `_parse()` /
`mainLoop()` with an identical tokenizer; only the initial tree-builder phase differs (`_initialPhase` vs
`_beforeHtmlPhase`). Phase dispatch differs for perhaps 5–10 callbacks at the start — **well under 1%** for a 500+ token
template. `parseFragment()` also returns `DocumentFragment`, not `Document`, which would break the engine's use of
`documentElement`, `outerHtml`, and `querySelector`. **Verdict: not worth pursuing** — negligible gain, disruptive API
change, and the "skip error recovery for known-valid templates" variant would require forking `package:html`.

**5. TemplateValidator.** Static analysis without rendering — catches errors at test/CI time.

- **5a. Expression syntax validation** — reuse the engine's `Parser` on each `tl:*` value. Each processor has its own
  value format requiring format-aware parsing: `tl:each` (`item : ${collection}` — parse only the collection),
  `tl:with`/`tl:attr` (`var=${expr}, …` — parse each binding), `tl:switch`/`tl:case` (expression, or `'*'` default),
  `tl:fragment` (a definition, not an expression), `tl:insert`/`tl:replace` (fragment reference, may contain expression
  args), `tl:inline`/`tl:remove` (mode/keyword strings, not expressions). ~150–250 lines.
- **5b. Unknown `tl:*` attribute detection** — flag typos like `tl:textt` or `tl:foreach` by checking against the set of
  attributes registered via dialects/custom processors. ~20 lines.
- **5c. Fragment reference integrity** — verify `tl:insert="~{header :: nav}"` resolves; cross-file references require
  loading the referenced template, making this an async I/O operation. ~60–80 lines.
- **5d. Context variable extraction** — statically determine expected variables. **Feasible for ~80%** (simple
  `${variable}` / `${object.member}`) but cannot be 100% accurate due to dynamic member access (`${obj[key]}`),
  `tl:with`/`tl:each`/`tl:object` scope changes, fragment parameters, and divergent conditional branches. Must be
  documented "best effort". ~80–200 lines depending on scope-awareness.

**6. Test helper.** An `isValidTemplate()` `Matcher` for `package:trellis/testing.dart`, so
`expect(source, isValidTemplate())` works in test suites. ~40 lines.

**7. CLI validation tool.** `dart run trellis:validate --dir=templates`, walking `.html` files and exiting non-zero on
errors for CI integration. ~50 lines.

### 5.4 Complexity summary

| Sub-feature | LOC | Complexity |
|---|---|---|
| Expression AST cache | ~8 | Trivial |
| Warm-up API | ~40–60 | Low |
| Eager fragment registry | ~30–40 | Medium |
| TemplateValidator core | ~150–250 | Medium-high |
| Unknown attribute detection | ~20 | Low |
| Fragment reference integrity | ~60–80 | Medium |
| Variable extraction | ~80–150 | Medium-high |
| Test helper | ~40 | Low |
| CLI tool | ~50 | Low |
| **Total** | **~480–700** | Each independently shippable |

No sub-feature touches the hot render path except the additive expression cache. Compare to Option A's ~800–1,200
lines of generator delivered "all or nothing".

### 5.5 Example validation output

```
templates/home.html:
  <span tl:text="${user.name">: ExpressionException: Expected "}" to close variable expression
    user.name
             ^
  <div tl:textt="${title}">: Unknown attribute: "tl:textt" (did you mean "tl:text"?)
  <div tl:insert="~{header :: navv}">: Fragment "navv" not found in template "header"
```

## 6. Recommendation Rationale

Option E was recommended (and adopted by ADR-003) as the primary direction:

1. **Addresses the practical problem, not the theoretical one.** For long-running servers (trellis's primary use case
   with Shelf / dart_frog), cold start is a one-time startup cost. The warm-up API makes it a controlled initialization
   step rather than an unpredictable first-request spike; the expression cache improves every subsequent render.
2. **Zero workflow change.** HTML templates remain the only artifact — no build step, generated files, or sidecar files
   — preserving trellis's "simple, no codegen, single dep" identity.
3. **Validation is unique value.** No major Dart template engine offers built-in validation with test helpers and CLI
   tooling. (Thymeleaf relies on IDE plugins; Jinja2 has `find_undeclared_variables()`; Handlebars has community
   linting like `handlebars-lint`; none ship a first-class CI/CLI validator.)
4. **Lowest implementation risk.** ~480–700 lines, each sub-feature independently shippable and testable, versus Option
   A's larger all-or-nothing generator.
5. **Leaves the door open.** Option A (codegen) can be added later as a complement if serverless/FaaS demand
   materializes; Option E's features benefit all render paths regardless.

### Critical caveats carried into the decision

- **Cold-start parsing is not eliminated.** HTML parsing (~60–75% of parse cost) remains. For serverless/FaaS with
  frequent cold starts, Option E is insufficient — Option A is the better fit for that specific scenario.
- **Warm-up shifts cost, it doesn't reduce it.** Total parsing work is unchanged; if the warmed set exceeds
  `maxCacheSize`, early entries are evicted silently.
- **The validator is a second interpretation of template semantics** that must track the processor pipeline. Keep
  initial scope minimal (expression syntax + unknown standard attributes); an optional `Processor.validateValue()`
  extension point would let processors own their own validation and reduce this maintenance surface. Defer fragment
  reference integrity (async I/O) and variable extraction (approximate) until there is a concrete consumer.
- **Defer to benchmarks.** Before building even the warm-up API, benchmark `html_parser.parse()` on representative
  templates. If parsing is already sub-millisecond, warm-up may be premature optimization and the validator alone could
  be the worthwhile scope.

## 7. Cross-References (plain text)

- The original decision-context document ("ADR input") for this strategy lives in the private specs directory for the
  v0.6 cycle. It contains the full requirements breakdown (must/should/could/won't) and the initial recommendation bias
  toward Option A, later overturned by benchmarks.
- Full source research — the consolidated multi-option research, the trade-off matrix, the recommendation, and the
  Option E deep-dive — lives in the private research directory under `precompiled-template-strategy/`.
