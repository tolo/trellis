# ADR-001: Expression Evaluator Strategy

## Status
Accepted

## Context
trellis's expression evaluator is the highest-complexity component in v0.1. It must parse and evaluate Thymeleaf-style expressions: `${var.path}`, `@{/path(id=${val})}`, string/boolean/numeric/null literals, comparisons (`== != < > <= >=`), boolean operators (`and or not`), ternary (`${cond} ? 'a' : 'b'`), Elvis (`${val} ?: 'default'`), string concatenation (`+`), and null-safe traversal.

trellis's design prioritizes a minimal dependency set while remaining pragmatic about well-motivated, industry-standard deps.

## Decision
**We will use a hand-written recursive descent parser with `package:string_scanner` (Option A′).**

The implementation consists of three layers:
1. **Scanner** — thin wrapper over `StringScanner` for token recognition (~80-120 lines)
2. **Recursive descent parser** — precedence climbing for binary operators, expression dispatch for Thymeleaf-specific constructs (~150-250 lines)
3. **AST evaluator** — tree walker with null-safe context traversal (~100-150 lines)

AST nodes use Dart 3 `sealed class` for exhaustive switching (~80-100 lines).

Total estimated footprint: ~410-620 lines.

## Consequences

### Positive
- **Minimal dependency impact**: `string_scanner` adds one lightweight production dependency and aligns with v0.1 PRD dependency constraints
- **Full grammar control**: Thymeleaf-specific syntax (`${}`, `@{}`, Elvis `?:`, keyword booleans) is first-class — no workarounds or adaptation layers
- **Idiomatic Dart**: this is the exact pattern used by Dart SDK parsers (sass, yaml, csslib) — any Dart contributor will recognize it immediately
- **Excellent error messages**: `StringScanner.error()` + `source_span` produces diagnostics with line/column and source caret, matching PRD `ExpressionException` contract
- **Sealed AST + exhaustive switch**: adding a new expression type in v0.2 produces compile errors at every unhandled switch — strong safety net

### Negative
- **Self-maintained parser**: operator precedence, escaping, and edge cases must be implemented and tested manually
- **No formal grammar spec**: correctness relies on comprehensive test coverage, not a machine-checkable grammar definition
- **Linear maintenance scaling**: parser code grows proportionally with grammar complexity

### Neutral
- Upgrade path to `petitparser` exists if grammar outgrows manual maintenance (trigger: parser exceeds ~1500 lines or precedence bugs become recurring)
- `string_scanner` is Dart-team owned (160/160 pub points, `dart-lang/tools` monorepo) — low dependency risk

## Alternatives Considered

### Option C: Hybrid — petitparser for Grammar, Custom Evaluation
- **Pros**: Battle-tested parsing, automatic operator precedence via `ExpressionBuilder`, excellent extensibility
- **Cons**: Adds additional production dependency beyond the v0.1 dependency target, ternary requires custom combinator layer outside ExpressionBuilder, Thymeleaf-specific wrappers (`${}`, `@{}`) still hand-written — partially negating the "declarative grammar" benefit
- **Rejected because**: Dependency cost not justified for v0.1's small grammar. The benefit (auto precedence) addresses only a subset of the grammar complexity. Remains the documented upgrade path if grammar grows significantly.
- **Weighted score**: 6.76/10 vs A′'s 8.54/10

### Option B: `package:expressions`
- **Pros**: Some expression types work out of the box (literals, comparisons, ternary, member access)
- **Cons**: Adds 15 packages (including rxdart, quiver — unnecessary for trellis). ~50% of Thymeleaf syntax unsupported (no `${}` wrappers, no `@{}` URLs, no Elvis `?:`, no `and`/`or`/`not` keywords). Open bugs on operator precedence (#32) and null handling (#30). 3.7% API documentation coverage.
- **Rejected because**: Grammar mismatch is fundamental — adaptation cost approaches building a purpose-built evaluator while adding a heavy dependency tree.
- **Weighted score**: 3.85/10

### Option D: Simple String-Based Evaluator (No AST)
- **Pros**: Zero dependencies, fastest initial prototype for simplest cases
- **Cons**: Cannot correctly handle balanced delimiters (provable formal limitation), no operator precedence, nested ternary/Elvis breaks string splitting, guaranteed complete rewrite for v0.2 (arithmetic makes `+` ambiguous, dynamic index requires recursive parsing)
- **Rejected because**: False economy — similar code size to recursive descent once edge cases handled, but worse correctness, worse error messages, and zero reusable components for v0.2. Documented anti-pattern in template engine design.
- **Weighted score**: 3.78/10

## Implementation Notes
- Add `string_scanner` as explicit production dependency in `packages/trellis/pubspec.yaml`
- Keep SDK compatibility aligned with PRD (`>=3.7.0 <4.0.0`)
- Expression parse/eval failures must throw `ExpressionException` (extending `TemplateException`) with source snippet + position
- Design `BinaryExpr` with generic `Operator` enum — supports v0.2 arithmetic without AST changes
- Elvis vs ternary disambiguation: 2-char lookahead after `?` (`:` → Elvis, else → ternary)
- Ternary right-associativity: use strict `>` (not `>=`) in precedence climbing loop
- Elvis triggers on **null only** (not false/0/empty), matching Thymeleaf semantics

## References
- [Research appendix](research/ADR-001-research.md) — options evaluated, comparison matrix, decision context, and recommendation
- [dart-sass parser](https://github.com/sass/dart-sass) — reference implementation of `string_scanner` + recursive descent
- [Crafting Interpreters — Parsing Expressions](https://craftinginterpreters.com/parsing-expressions.html)
- [Precedence Climbing](https://eli.thegreenplace.net/2012/08/02/parsing-expressions-by-precedence-climbing)
