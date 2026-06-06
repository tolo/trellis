# ADR-001 Research Appendix: Expression Evaluator Strategy

Curated research supporting [ADR-001](../ADR-001-expression-evaluator-strategy.md).

This appendix condenses the trade-off analysis behind ADR-001. Research conducted February 2026, evaluating four approaches for trellis's expression evaluator, which must parse and evaluate Thymeleaf-style expressions: `${var.path}`, `@{/path(id=${val})}`, literals (string/boolean/numeric/null), comparisons (`== != < > <= >=`), boolean operators (`and`/`or`/`not`), ternary (`${cond} ? 'a' : 'b'`), Elvis (`${val} ?: 'default'`), string concatenation (`+`), and null-safe traversal.

## Options Evaluated

### Option A′ — Hand-Written Recursive Descent with `string_scanner` (chosen)

`package:string_scanner` (Dart-team owned) as the tokenizer foundation → custom recursive descent parser → lightweight AST → custom evaluator walking the AST against the context map. This is the pattern used by Dart SDK parsers (sass, yaml, csslib).

- **`string_scanner` API**: provides `scan()`, `expect()`, `peekChar()`, `readChar()`, position tracking, save/restore for backtracking, and `error()` with `SourceSpan`-based position-annotated messages. The `SpanScanner` subclass adds precise span tracking.
- **Dependency impact**: adds 1 new package; its sole dependency (`source_span`) is already resolved transitively via `package:html`. (Note: `string_scanner` was *not* previously a transitive production dep of `html` — it appeared in the lockfile only via the `test` dev dependency. The effective incremental footprint is nonetheless minimal because `source_span` is already present.)
- **Real-world precedent**: Sass (dart-sass), yaml, and csslib all use `string_scanner` + recursive descent. Sass's expression parser uses precedence climbing (a Pratt-parser variant) — roughly 300 lines for the operator-precedence loop plus ~200 lines for primary expression dispatch. trellis's grammar is dramatically simpler (~15 expression types vs ~40+ in Sass).
- **Operator precedence**: a 7-level table (not → comparisons → equality → and → or → concat → ternary/Elvis), handled by a precedence climbing loop in ~60 lines.
- **Error quality**: `StringScannerException` produces messages with line/column, source context, and caret pointing — comparable to Thymeleaf's Java error messages.
- **Code size estimate**: 400–640 lines total — AST nodes 80–120, scanner 80–120, parser 150–250, evaluator 100–150.

**Implementation warnings**:
1. Ternary is right-associative — the precedence loop must use `>` not `>=` for the ternary level.
2. Elvis `?:` vs ternary `? :` requires a 2-char lookahead after `?`.
3. `+` is overloaded (string concat in v0.1, arithmetic later) — design the AST with a generic `BinaryOp` node now.
4. No formal grammar specification — comprehensive tests are the only safeguard.

### Option C — Hybrid: petitparser for Grammar, Custom Evaluation

`package:petitparser` (7.0.x) defines the grammar declaratively via `ExpressionBuilder`; custom evaluation code walks parse results against the context map.

- **Quality**: 160/160 pub points, 385 likes, 7.49M downloads, maintained by Lukas Renggli; deps are only `meta` + `collection` (both already transitive).
- **`ExpressionBuilder`** declares operator precedence via descending groups and supports `.left()`, `.right()`, `.prefix()`, `.postfix()`, `.wrapper()` — mapping cleanly to trellis's operator set.
- **Thymeleaf construct handling**: `${...}`/`@{...}` wrappers require custom parser composition around `ExpressionBuilder` (not native); Elvis vs ternary needs careful PEG-ordering of alternatives; ternary is *not* a binary operator, so it cannot use `.left()`/`.right()` and needs a custom combinator layer; URL expressions need a separate composed sub-parser.
- **Error reporting**: position-based (character offset, not line:column); custom messages require deliberate `.flatten(message:)` and `.labeled()` placement, otherwise defaults are cryptic for nested combinators.
- **Versioning**: 3 major versions (5.0 → 6.0 → 7.0) in ~3 years, each with breaking changes.
- **Code size estimate**: 360–580 lines with an explicit AST (or 250–400 with inline callbacks, which couples parsing and evaluation).
- **Key downside**: violates the "single production dependency" design goal, and the Thymeleaf-specific wrappers must be hand-written regardless — partially negating the declarative-grammar benefit.

### Option B — `package:expressions`

Existing Dart expression parser library (0.2.5+3).

- **Dependency explosion**: adds 4 direct deps (petitparser, quiver, rxdart, meta) + 11 transitive = 15 new packages, moving trellis from 1 to 16 production deps. `rxdart` is only used by `AsyncExpressionEvaluator` (irrelevant here); `quiver` is used for a single `hash3` call.
- **Grammar mismatch** (critical) — see table below; roughly 50% of trellis's syntax is unsupported, so custom code is still needed for `${}` extraction, `@{}` URL parsing, Elvis, keyword booleans, null-safe traversal, and error wrapping.
- **Maintenance**: 15 open issues (operator precedence #32, hex literal #42, null handling #30), 3.7% API documentation coverage, solo maintainer with slow cadence, 125/160 pub points.

| trellis requirement | Supported by `package:expressions`? |
|---|---|
| `${...}` wrapper syntax | No |
| `@{/url(params)}` | No |
| Elvis `?:` | No (`??` only) |
| `and`/`or`/`not` keywords | No (`&&`/`\|\|`/`!` only) |
| Null-safe traversal | No |
| Dot-notation, brackets, literals, comparisons, ternary, concat | Yes |

Other libraries assessed (`math_expressions`, `eval_ex`, `function_tree`) are math-only with no member access or template syntax. `package:expression_language` is abandoned (~4 years). No widely-adopted Dart parser generator exists (no ANTLR equivalent).

### Option D — Simple String-Based Evaluator (No AST)

Regex matching, `split()`, `indexOf()`, `substring()` to identify expression parts, evaluating inline without an AST.

Where it breaks down:
1. **Nested expressions in URL params**: `@{/path(id=${user.id})}` — `indexOf(')')` matches the wrong paren; needs bracket-depth tracking (i.e. a parser).
2. **Ternary with operators in branches**: `${a} ? ${b} ?: 'x' : 'y'` — naive `split('?')` can't distinguish ternary `?` from Elvis `?:`.
3. **String literals containing operators**: `'hello ? world'` — the `?` inside the literal is matched by naive regex.
4. **Operator precedence**: `${a or b and c}` must bind as `a or (b and c)`; a flat left-to-right scan gets this wrong.
5. **Formal limitation**: matching balanced delimiters is provably impossible with regex alone (regular languages).

Code size is ~440–650 lines — *not* smaller than recursive descent once edge cases are handled — and v0.2 features (arithmetic making `+` ambiguous, dynamic index `${items[${index}]}`) guarantee a complete rewrite with zero transferable components. Every well-known template engine (Thymeleaf, Jinja2, Handlebars, Twig) uses a proper parser; regex-based expression evaluation is a documented anti-pattern.

## Comparison Matrix

Criteria are weighted (weight in parentheses); cell values are scores out of 10. The weighted total is the sum of weight × score across all criteria.

| Criterion (Weight) | A′: string_scanner RD | C: petitparser hybrid | B: pkg:expressions | D: String-based |
|---|---|---|---|---|
| Dependencies (9) | 9 — +1 pkg (`source_span` already present) | 4 — +1 pkg, violates "single dep" | 2 — +15 packages | 10 — zero |
| Correctness (9) | 8 — proven pattern, manual precedence | 9 — auto precedence, battle-tested | 5 — open bugs (#32, #30) | 3 — can't handle nested/balanced |
| Grammar control (8) | 10 — full, unrestricted | 7 — ternary needs custom combinator | 3 — grammar mismatch | 3 — fundamentally limited |
| Extensibility v0.2+ (8) | 9 — new AST node + parser method per feature | 9 — new `.group()` per operator | 4 — fork required for new syntax | 1 — guaranteed rewrite |
| Error messages (7) | 9 — SourceSpan, line/col, caret | 6 — char offset, manual effort | 3 — generic failures | 2 — position-only at best |
| Maintenance burden (7) | 7 — self-maintained, linear growth | 6 — external dep + custom code | 3 — 15 open issues, solo maintainer | 2 — write-only code |
| v0.1 effort (6) | 7 — moderate, investment not waste | 5 — learning curve offsets auto-precedence | 4 — 50% still custom | 6 — fast start, slow finish |
| Community/ecosystem (5) | 9 — THE Dart SDK parser pattern | 8 — well-established combinator lib | 4 — modest adoption | 2 — documented anti-pattern |
| **Weighted Total** | **504 / 590** | **399 / 590** | **227 / 590** | **223 / 590** |

## Risk Analysis (chosen option)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Operator precedence bugs in hand-written parser | Medium | High | Comprehensive test matrix; reference the Sass parser implementation |
| Grammar outgrows manual maintenance (v0.3+) | Low–Medium | Medium | Migrate to petitparser when the parser exceeds ~1500 lines |
| Ternary right-associativity bug | Medium | Medium | Use `>` not `>=` in the precedence loop; explicit test `a ? b : c ? d : e` = `a ? b : (c ? d : e)` |
| Elvis/ternary disambiguation error | Low | High | 2-char lookahead after `?` (`:` → Elvis, else → ternary); dedicated edge-case tests |

## Thymeleaf Internals Reference

Background informing the grammar scope:

- Thymeleaf (Java) uses OGNL (or SpringEL with Spring) *inside* `${...}` for property navigation; a separate Standard Expression layer handles operators *outside* the braces (ternary, Elvis, comparisons, arithmetic, string concat, `|...|` pipe syntax).
- trellis only needs the Standard Expression layer plus basic dot-notation/bracket property navigation — full OGNL is not required.
- Implicit operator precedence: OGNL → arithmetic → comparators → boolean → ternary/Elvis.
- Elvis `?:` triggers on **null only** (not false/0/empty).
- `|...|` literal substitution (shorthand for concatenation) and textual comparison aliases (`gt`, `lt`, `ge`, `le`) were deferred.

## Recommendation Rationale

Option A′ wins by a significant margin (504 vs 399 for the runner-up). Decisive factors:

1. **Minimal dependency impact** (highest-weight criterion): one package whose sole dependency is already in the production tree — effectively zero new transitive deps — aligning with trellis's minimal-dependency goal while remaining pragmatic (`string_scanner` is Dart-team-owned infrastructure, not an opinionated framework).
2. **Proven Dart ecosystem pattern**: the idiomatic approach used by the Dart SDK team itself (sass, yaml, csslib); any Dart developer recognizes it immediately.
3. **Full grammar control**: Thymeleaf-specific constructs (`${}`, `@{}`, Elvis `?:`, keyword booleans) are first-class — no workarounds, combinator layering, or grammar adaptation.
4. **Excellent error messages**: `StringScanner.error()` + `source_span` produces publication-quality diagnostics with line/column and caret pointing — critical for a developer-facing template engine.
5. **Clean upgrade path**: if the grammar outgrows manual maintenance (unlikely before v0.3+), migration to petitparser is the documented escape hatch, so starting with A′ preserves optionality.

Options B and D are clearly unsuitable: B combines a fundamental grammar mismatch with dependency explosion, and D has provable correctness limitations plus a guaranteed v0.2 rewrite. The options are discrete — either hand-write the parser or use a combinator library — so no further hybrid was pursued. **Decision confidence: high.**

## External References

- dart-sass parser — reference implementation of `string_scanner` + recursive descent: https://github.com/sass/dart-sass
- Crafting Interpreters — Parsing Expressions: https://craftinginterpreters.com/parsing-expressions.html
- Precedence Climbing: https://eli.thegreenplace.net/2012/08/02/parsing-expressions-by-precedence-climbing
