# Trellis Template Engine — Architecture

Canonical reference for the internal architecture of the core `trellis` template engine package. Covers the render pipeline, processor model, expression evaluation, caching, fragment system, and extension points.

**Current through**: SDK Phase 1 (S06) + 0.10.2 (`FileSystemLoader` per-directory dev-mode watching on Linux; symlink-free `listTemplates()`)

---

## Design Philosophy

| Principle | Implication |
|---|---|
| Natural HTML templates | Templates are valid HTML; `tl:*` attributes are metadata, not syntax |
| Single runtime dependency | Only `package:html` (HTML5 parser) — no reflection, no code generation |
| AOT-safe | Context is `Map<String, dynamic>` — no mirrors, works with `dart compile exe` |
| Clone-before-process | Cached parsed DOM is deep-cloned before each render — templates are immutable |
| Sync-first | `render()` is synchronous; `renderFile()` is async only for I/O |
| Fragment-first | `tl:fragment` + `renderFragment()` maps directly to HTMX partial responses |

---

## Render Pipeline

**Diagram**: Render Pipeline *(maintained in internal design repository)*

The render flow for `render(source, context)`:

```
Source HTML string
       │
       ▼
┌──────────────────┐
│ 1. Normalize      │  fixSelfClosingBlocks(): <tl:block .../> → <tl:block ...></tl:block>
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 2. Parse          │  html_parser.parse(source) → Document
│    + Cache        │  LRU cache keyed on normalized source; hit → clone & skip parse
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 3. Clone DOM      │  doc.clone(true) — deep clone preserves cached original
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 3.5 Inheritance   │  InheritanceResolver: if root has tl:extends,
│     Pre-Pass      │  load parent chain, merge tl:define blocks,
│                   │  strip inheritance attrs. Recursive (max depth 16).
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 4. Collect        │  Pre-scan: find all tl:fragment definitions
│    Fragments      │  Build registry: name → (Element, paramNames)
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 5. Process DOM    │  Priority-sorted processor pipeline (see below)
│                   │  Recursive: process element → process children
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ 6. Serialize      │  doc.outerHtml → output string
└──────────────────┘
       │
       ▼
  Output HTML string
```

For `renderFragment()`, steps 1-4 are the same, then the named fragment element is extracted from the cloned DOM before step 5 processes only that subtree.

For `renderFragments()` (HTMX OOB), all named fragments are extracted (fail-fast if any missing), each processed independently, then concatenated.

---

## Processor Pipeline

**Diagram**: Processor Pipeline *(planned)*

### Priority Model

Processors execute in a deterministic order defined by `ProcessorPriority` — 8 named slots:

```
ProcessorPriority.highest           ← tl:with, tl:object, tl:if, tl:unless, tl:switch
ProcessorPriority.afterLocals       ← (open for custom processors)
ProcessorPriority.afterConditionals ← tl:each
ProcessorPriority.afterIteration    ← tl:insert, tl:replace
ProcessorPriority.afterContent      ← tl:text, tl:utext, tl:inline
ProcessorPriority.afterAttributes   ← tl:attr + shorthands (tl:href, tl:src, etc.)
ProcessorPriority.afterRemoval      ← tl:remove
ProcessorPriority.lowest            ← (open for custom processors)
```

Within a priority slot, registration order is preserved: StandardDialect built-ins first, then dialect processors, then engine-level custom processors.

### Processing a Single Element

For each element in the DOM tree:

1. **Fragment-def check**: If the element has a parameterized `tl:fragment`, skip it (fragments are rendered on demand, not inline)
2. **Processor loop**: For each processor in priority order:
   - Check if the element has the processor's attribute (e.g., `tl:if`)
   - Call `processor.process(element, value, processorContext)` → returns `bool`
   - If `false`: element was removed/consumed — stop processing this element
   - If `true`: element remains — capture any context mutations
3. **Attribute cleanup**: Remove all `tl:*` attributes from the element
4. **Child recursion**: If `autoProcessChildren` is true, recursively process child elements with the (possibly mutated) context
5. **Block unwrap**: If the element is a `<tl:block>` virtual container, replace it with its children

### Context Mutation

Context-modifying processors (`tl:with`, `tl:object`) update `processorContext.variables` directly. The DOM processor captures the updated context after each processor runs and passes it to child recursion. This means:
- `tl:with` bindings are visible to all subsequent processors on the same element AND to all children
- Context changes do not propagate upward or to siblings

### Built-in Processors (StandardDialect)

| # | Processor | Attribute | Priority | Returns false when | Notes |
|---|---|---|---|---|---|
| 1 | `WithProcessor` | `with` | highest | Never | Binds local variables via `parseBindings()` |
| 2 | `ObjectProcessor` | `object` | highest | Never | Sets selection object for `*{field}` expressions |
| 3 | `IfProcessor` | `if` | highest | Condition falsy → element removed | Uses `isTruthy()` |
| 4 | `UnlessProcessor` | `unless` | highest | Condition truthy → element removed | Inverse of `tl:if` |
| 5 | `SwitchProcessor` | `switch` | highest | No matching case → element removed | Evaluates against `tl:case` children |
| 6 | `EachProcessor` | `each` | afterConditionals | Collection empty → element removed | Clones element per item; `autoProcessChildren=false` |
| 7 | `InsertProcessor` | `insert` | afterIteration | Never | Loads fragment, inserts as children |
| 8 | `ReplaceProcessor` | `replace` | afterIteration | Always (replaces element) | Loads fragment, replaces element |
| 9 | `TextProcessor` | `text` | afterContent | Never | HTML-escapes value, replaces element text |
| 10 | `UtextProcessor` | `utext` | afterContent | Never | Raw HTML insertion (no escaping) |
| 11 | `InlineProcessor` | `inline` | afterContent | Never | `[[${expr}]]` escaped, `[(${expr})]` unescaped |
| 12 | `AttrProcessor` | `attr` + shorthands | afterAttributes | Never | Sets/appends/removes attributes |
| 13 | `RemoveProcessor` | `remove` | afterRemoval | Varies | Modes: `all`, `body`, `tag`, `all-but-first`, `none` |

---

## Expression Evaluator

Three-layer architecture (ADR-001):

```
Expression string
       │
       ▼
┌──────────────────┐
│ Scanner           │  Tokenizes input (StringScanner wrapper)
│                   │  Tokens: literals, identifiers, operators, delimiters
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ Parser            │  Recursive descent with precedence climbing
│                   │  Produces sealed-class AST nodes
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ AST Evaluator     │  Tree-walker evaluates against context Map
│                   │  Null-safe traversal, strict mode via containsKey()
└──────────────────┘
       │
       ▼
  Result (dynamic)
```

### Expression Types

| Syntax | AST Node | Example |
|---|---|---|
| `${var.path}` | `VariableExpr` → `MemberAccessExpr` | `${user.name}` |
| `@{/path(param=${val})}` | `UrlExpr` | `@{/items(id=${item.id})}` |
| `#{key(args)}` | `MessageExpr` | `#{welcome.message(${user.name})}` |
| `*{field}` | `SelectionExpr` | `*{name}` (with `tl:object`) |
| `\|literal ${expr}\|` | `LiteralSubstitutionExpr` | `\|Hello, ${name}!\|` |
| `${expr} ? a : b` | `TernaryExpr` | `${active} ? 'yes' : 'no'` |
| `${expr} ?: default` | `ElvisExpr` | `${name} ?: 'Anonymous'` |
| `${val \| filter:arg}` | `PipeExpr` | `${date \| format:'yyyy-MM-dd'}` |
| Comparisons | `BinaryExpr` | `${count > 0}`, `${status == 'active'}` |
| Boolean | `BinaryExpr` / `UnaryExpr` | `${a and b}`, `not ${flag}` |
| Arithmetic | `BinaryExpr` | `${price * quantity}` |

### Expression Cache (v0.6)

Parsed `Expr` ASTs are cached at the engine level (`Map<String, Expr>`). The cache persists across all renders for the engine's lifetime. Sealed AST classes are immutable — safe to share across concurrent renders. Cleared alongside DOM cache on `clearCache()`.

---

## Caching Strategy

### DOM Cache (LRU)

- **Key**: Normalized source string (after `fixSelfClosingBlocks()`)
- **Value**: Parsed `Document` from `package:html`
- **Eviction**: LRU via `LinkedHashMap` remove+re-insert pattern — O(1)
- **Max size**: Configurable (`maxCacheSize`, default 256)
- **Clone**: Every cache hit returns `doc.clone(true)` — the cached DOM is never mutated
- **Dev mode**: `clearCache()` called on any file change (aggressive but simple — v0.5 design decision)

### Expression Cache (v0.6)

- **Key**: Expression string
- **Value**: Parsed `Expr` AST (immutable sealed classes)
- **Scope**: Engine-level, injected into `ExpressionEvaluator` on each render
- **Eviction**: Unbounded (expression count typically hundreds per application)
- **Cleared**: Alongside DOM cache on `clearCache()`

### Statistics

`CacheStats` snapshot: `size` (cached DOMs), `hits`, `misses`, `expressionCacheSize`.

---

## Fragment System

### Fragment Registration

Pre-scan pass (`collectFragments`) before rendering:
1. Walk the DOM tree
2. Find all elements with `tl:fragment="name"` or `tl:fragment="name(param1, param2)"`
3. Build registry: `Map<String, (Element, List<String>)>` — name → (cloned element, parameter names)

### Fragment Rendering

`renderFragment(source, fragment: name, context: ctx)`:
1. Parse and clone the full template DOM
2. Collect fragments from the cloned DOM
3. Look up the named fragment in the registry
4. Clone the fragment element
5. Process the cloned fragment with merged context (caller context + fragment parameters)
6. Serialize and return

### Cross-File Fragment Inclusion

`tl:insert="~{template :: fragment}"` / `tl:replace="~{template :: fragment}"`:
1. Load the external template via the loader
2. Parse and collect fragments from the external template
3. Push external fragment registry onto `_fragmentRegistryStack`
4. Resolve the named fragment
5. Process the included fragment
6. Pop the external registry

### Cycle Detection

Fragment inclusions are tracked via an inclusion stack. If a fragment ID (template + fragment name) appears twice, a `TemplateException` is thrown with the full cycle path. Maximum inclusion depth: 32.

---

## Template Loaders

```
                 TemplateLoader (abstract)
                      │
        ┌─────────────┼─────────────┬──────────────┐
        ▼             ▼             ▼              ▼
  FileSystem      MapLoader     AssetLoader    Composite
   Loader       (in-memory)   (package: URI)    Loader
   │                                            (fallback
   ├─ Path security                              chain)
   ├─ Dev-mode watching
   └─ listTemplates()
```

| Loader | Source | Security | Dev Mode | `listTemplates()` |
|---|---|---|---|---|
| `FileSystemLoader` | Filesystem directory | Path traversal rejection, symlink boundary checks | `Directory.watch()` with extension filter — one native recursive watch on macOS/Windows, one watch per directory on Linux (dart:io ignores `recursive` there) | Yes (does not follow symlinks) |
| `MapLoader` | `Map<String, String>` | N/A | N/A | Yes |
| `AssetLoader` | `package:` URIs | Same as FileSystemLoader | N/A | No |
| `CompositeLoader` | Delegate chain | Delegates to children | N/A | No |

---

## Extension Points

### Custom Processors

```dart
class TooltipProcessor extends Processor {
  @override String get attribute => 'tooltip';
  @override ProcessorPriority get priority => ProcessorPriority.afterContent;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final text = context.evaluate(value, context.variables)?.toString() ?? '';
    element.attributes['title'] = text;
    return true;
  }
}
```

### Custom Dialects

```dart
class UiDialect extends Dialect {
  @override String get name => 'UI';
  @override List<Processor> get processors => [TooltipProcessor()];
  @override Map<String, Function> get filters => {
    'badge': (dynamic v, [List<dynamic>? args]) => '<span class="badge">${v}</span>',
  };
}
```

### Custom Filters

Registered at engine level or via dialect:
- Old-style: `Function(dynamic)` — value only
- New-style: `Function(dynamic, List<dynamic>)` — value + arguments
- Arity auto-detected at registration; mismatch throws `ExpressionException`

---

## Inheritance System

Template inheritance (`tl:extends` / `tl:define`) allows layout decoration — child templates extend parent layouts and override named blocks.

### How It Works

1. **Detection**: `InheritanceResolver.resolve()` checks for `tl:extends="parent-name"` on the root `<html>` element
2. **Validation**: `tl:extends` on non-root elements throws `TemplateException`
3. **Parent loading**: Parent template loaded via `TemplateLoader.loadSync()`, parsed through engine's cached `_parse()` path
4. **Recursive resolution**: If parent also has `tl:extends`, chain continues (max depth 16, with cycle detection)
5. **Block collection**: Depth-first walk of child collects `tl:define="name"` elements into a `Map<String, Element>` (last wins for duplicates)
6. **Block merge**: For each `tl:define` in the resolved parent, if child has a matching override, parent element's **children** are replaced with child block's children (parent element tag/attrs preserved)
7. **Cleanup**: All `tl:extends` and `tl:define` attributes stripped from the merged DOM

### Key Design Decisions

- **Pre-pass, not a Processor**: Runs before fragment collection (step 4) so parent fragments are visible to `renderFragment()`
- **Sync loading**: Uses `loadSync()` to maintain the sync-first contract of `render()`
- **Separate cycle detection**: Inheritance has its own ancestor stack, independent of fragment inclusion cycle detection
- **Non-extends passthrough**: `tl:define` in templates without `tl:extends` has attrs stripped but content preserved — useful for defining optional blocks in partial templates

### Constraints

- `tl:extends` value is a template name literal (not an expression)
- No conditional inheritance (`tl:extends` with `tl:if`)
- Nested `tl:define` inside another `tl:define` — outer override replaces everything including inner

---

## Source Map

```
lib/
├── trellis.dart ..................... Barrel exports (public API)
└── src/
    ├── engine.dart .................. Trellis class (render, cache, lifecycle)
    ├── processor.dart ............... DomProcessor (pipeline, fragment registry)
    ├── processor_api.dart ........... Processor interface, ProcessorPriority, ProcessorContext
    ├── dialect.dart ................. Dialect + StandardDialect
    ├── evaluator.dart ............... ExpressionEvaluator (parse + eval)
    ├── inheritance.dart ............. InheritanceResolver (tl:extends/tl:define pre-pass)
    ├── exceptions.dart .............. 5 exception types
    ├── cache_stats.dart ............. CacheStats snapshot
    ├── context_builder.dart ......... TrellisContext fluent builder
    ├── message_source.dart .......... MessageSource + MapMessageSource (i18n)
    ├── truthiness.dart .............. isTruthy() per Thymeleaf semantics
    ├── validator.dart ............... TemplateValidator (v0.6)
    ├── warm_up_result.dart .......... WarmUpResult (v0.6)
    ├── utils/
    │   ├── binding_parser.dart ...... parseBindings() / splitTopLevel()
    │   └── html_normalizer.dart ..... Self-closing block normalization
    ├── expression/
    │   ├── scanner.dart ............. Tokenizer
    │   ├── parser.dart .............. Recursive descent parser
    │   └── ast.dart ................. Sealed AST node types
    ├── loaders/
    │   ├── template_loader.dart ..... Abstract interface
    │   ├── file_loader.dart ......... FileSystemLoader
    │   ├── map_loader.dart .......... MapLoader
    │   ├── asset_loader.dart ........ AssetLoader
    │   └── composite_loader.dart .... CompositeLoader
    └── processors/
        ├── with_processor.dart
        ├── object_processor.dart
        ├── condition_processor.dart .. tl:if + tl:unless
        ├── switch_processor.dart
        ├── each_processor.dart
        ├── fragment_processor.dart ... tl:insert + tl:replace + tl:fragment
        ├── text_processor.dart
        ├── inline_processor.dart
        ├── attr_processor.dart
        └── remove_processor.dart
```

---

## Cross-References

- [ADR-001: Expression Evaluator Strategy](../adrs/ADR-001-expression-evaluator-strategy.md) — Hand-rolled recursive descent parser
- [ADR-003: Pre-compiled Template Strategy](../adrs/ADR-003-precompiled-template-strategy.md) — Deferred
- SDK Vision — how the engine fits into the broader SDK (internal)
- SDK Phase 1 — template inheritance (`tl:extends`/`tl:define`) adds a pre-pass before step 4 (internal spec)

### Diagrams

Architecture diagrams are maintained as Excalidraw source files in the project's internal design repository.
