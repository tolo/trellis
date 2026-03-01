# CLAUDE.md

## Project Overview

**trellis** — A Thymeleaf-inspired HTML template engine for Dart. Natural HTML templates with `tl:*` attributes, fragment-first design for HTMX, AOT-compatible (no reflection).

## Key Design Decisions

- **Minimal dependencies**: `package:html` (HTML5 parser) + `package:string_scanner` (tokenizer) — both Dart team packages
- **No reflection**: Context is `Map<String, dynamic>`, AOT-safe
- **Natural templates**: Templates are valid HTML — browsers render them as prototypes without a server
- **Fragment-first**: `tl:fragment` + `renderFragment()` maps directly to HTMX partial responses
- **Sync-first**: `render()` is sync; `renderFile()` is async only for I/O
- **Clone-before-process**: Cached parsed DOM is deep-cloned before each render
- **Configurable prefix**: Default `tl`, allows custom namespace (e.g. `data-tl` for strict HTML5)

## Core tl:* Attributes (v0.1 scope)

| Attribute | Purpose |
|---|---|
| `tl:text` | Escape & replace element text |
| `tl:utext` | Unescaped HTML in element body |
| `tl:if` / `tl:unless` | Conditional show/hide |
| `tl:each` | Loop with status vars (index, count, first, last, odd, even) |
| `tl:fragment` | Define reusable fragment |
| `tl:insert` / `tl:replace` | Include fragment |
| `tl:with` | Bind local variables |
| `tl:attr` / `tl:href` / `tl:src` / `tl:value` / `tl:class` / `tl:id` | Set attributes |

## Expression Types

- `${var.path}` — Variable expression (dot-notation, map/list access)
- `@{/path(param=${val})}` — URL expression
- `'literal'` — String literal
- Ternary: `${cond} ? 'a' : 'b'`
- Elvis: `${val} ?: 'default'`
- Comparisons: `== != < > <= >=`
- Boolean: `and or not`

## Processing Priority Order

1. `tl:with` — bind locals (highest)
2. `tl:if` / `tl:unless` — conditionals
3. `tl:each` — iteration
4. `tl:insert` / `tl:replace` — fragment inclusion
5. `tl:text` / `tl:utext` — content
6. `tl:attr` etc. — attribute mutation

## Conventions

- 120-char line width
- `dart format`, `dart analyze` must pass
- Strict casts, strict raw types enabled
- `prefer_single_quotes`, `require_trailing_commas`

## Key Development Commands

```bash
dart pub get          # Install dependencies
dart format lib test  # Format (120-char line width)
dart analyze          # Static analysis
dart test             # All tests
dart test test/engine_test.dart  # Single test file
```

## Documentation Resources

- **Dart** — https://dart.dev/guides
- **Thymeleaf reference** — https://www.thymeleaf.org/documentation.html
- **package:html** — https://pub.dev/packages/html — HTML5 parser (sole runtime dependency)
- **HTMX** — https://htmx.org/docs/
