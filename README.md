# trellis

[![pub package](https://img.shields.io/pub/v/trellis.svg)](https://pub.dev/packages/trellis)
[![package publisher](https://img.shields.io/pub/publisher/trellis.svg)](https://pub.dev/packages/trellis/publisher)

A Thymeleaf-inspired HTML template engine for Dart. Natural HTML templates with `tl:*` attributes, fragment-first design for HTMX, AOT-compatible (no reflection).

## Features

- **Natural templates** -- valid HTML that browsers render as prototypes without a server
- **Fragment-first** -- `tl:fragment` + `renderFragment()` maps directly to HTMX partial responses
- **Full expression language** -- variables, arithmetic, literal substitution, selection, URL, ternary, Elvis, comparisons, boolean
- **Switch/case, block, remove, inline** -- multi-branch conditionals, virtual elements, output control, inline JS/CSS processing
- **Parameterized fragments** -- `tl:fragment="card(title, body)"` with argument passing at inclusion
- **CSS selector targeting** -- `tl:insert="~{file :: #id}"` and `tl:insert="~{file :: .class}"`
- **Sync-first API** -- `render()` is synchronous; `renderFile()` is async only for I/O
- **LRU DOM cache** -- configurable size, `CacheStats` for hit/miss metrics
- **Strict mode** -- undefined variables/members throw `ExpressionException`
- **Secure** -- `FileSystemLoader` enforces path traversal and symlink escape protection
- **AOT-compatible** -- context is `Map<String, dynamic>`, no reflection

## Installation

```
dart pub add trellis
```

## Quick Start

```dart
import 'package:trellis/trellis.dart';

final engine = Trellis(loader: MapLoader({}));

final html = engine.render(
  '<h1 tl:text="${title}">Default Title</h1>',
  {'title': 'Hello, Trellis!'},
);
// <h1>Hello, Trellis!</h1>
```

## Template Syntax Reference

### Text Substitution

```html
<!-- Escaped text (safe from XSS) -->
<p tl:text="${message}">placeholder</p>

<!-- Unescaped HTML (use with trusted content only) -->
<div tl:utext="${richContent}">placeholder</div>
```

### Conditionals

```html
<div tl:if="${user}">Welcome back!</div>
<div tl:unless="${loggedIn}">Please log in.</div>
```

Truthy: non-null, non-false, non-zero, not `"false"`/`"off"`/`"no"`. Empty strings and empty lists are truthy.

#### Switch / Case

```html
<div tl:switch="${role}">
  <p tl:case="'admin'">Admin view</p>
  <p tl:case="'user'">User view</p>
  <p tl:case="*">Guest view</p>
</div>
```

### Iteration

```html
<li tl:each="item : ${items}" tl:text="${item}">placeholder</li>
```

Status variables are available as `${itemStat}` (or custom name via `item, stat : ${items}`):

| Variable | Description |
|---|---|
| `index` | 0-based index |
| `count` | 1-based count |
| `size` | Total number of items |
| `first` | `true` for first item |
| `last` | `true` for last item |
| `odd` | `true` for 0-based odd indices |
| `even` | `true` for 0-based even indices |
| `current` | Current item value |

### Fragments

```html
<!-- Define a fragment (parameterized) -->
<div tl:fragment="card(title, body)">
  <h2 tl:text="${title}">Title</h2>
  <p tl:text="${body}">Body</p>
</div>

<!-- Include a fragment (keeps host element) -->
<div tl:insert="card('Hello', 'World')">replaced by fragment</div>

<!-- Replace with fragment (replaces host element) -->
<div tl:replace="userCard">replaced entirely</div>

<!-- Cross-file inclusion -->
<div tl:insert="~{components :: header}">loads header from components.html</div>

<!-- CSS selector targeting -->
<div tl:insert="~{components :: #main-nav}">loads by id</div>
```

### Local Variables

```html
<div tl:with="fullName=${first} + ' ' + ${last}">
  <span tl:text="${fullName}">Name</span>
</div>
```

### Object / Selection

```html
<!-- Set object context; *{} accesses fields directly -->
<div tl:object="${user}">
  <span tl:text="*{name}">Name</span>
  <span tl:text="*{email}">Email</span>
</div>
```

Objects are accessed via `toMap()` or `toJson()` if present, otherwise as `Map<String, dynamic>`.

### Attribute Setting

```html
<!-- Shorthand attributes -->
<a tl:href="${url}">link</a>
<img tl:src="${imageUrl}">
<input tl:value="${val}">
<div tl:class="${className}">styled</div>
<div tl:id="${elementId}">identified</div>

<!-- Append to existing class/style -->
<div class="card" tl:classappend="${active} ? 'active'">content</div>
<div style="color:red" tl:styleappend="font-weight:bold">content</div>

<!-- Generic attribute setting -->
<div tl:attr="data-id=${item.id},title=${item.name}">content</div>
```

`tl:class` replaces the existing class (not appends). `tl:classappend`/`tl:styleappend` append. Null values remove the attribute.
Boolean HTML attributes (`disabled`, `checked`, etc.): `true` renders valueless, `false` removes.

### Block (Virtual Element)

```html
<!-- tl:block renders only its children — the host element is not emitted -->
<tl:block tl:each="item : ${items}">
  <dt tl:text="${item.key}">key</dt>
  <dd tl:text="${item.value}">value</dd>
</tl:block>
```

### Remove

```html
<div tl:remove="all">removed entirely from output</div>
<div tl:remove="body">tag kept, children removed</div>
<div tl:remove="tag">children kept, tag removed</div>
<ul tl:remove="all-but-first"><li>kept</li><li tl:remove="all">removed</li></ul>
<div tl:remove="none">kept as-is (prototype marker)</div>
```

### Inline Processing

```html
<!-- Enable inline expressions in element text content -->
<p tl:inline="text">Hello, [[${name}]]! Today is [(${rawHtml})].</p>

<!-- Inline in script blocks -->
<script tl:inline="javascript">
  var user = [[${user.name}]];
</script>

<!-- Inline in style blocks -->
<style tl:inline="css">
  .alert { color: [[${alertColor}]]; }
</style>
```

`[[${expr}]]` — escaped output. `[(${expr})]` — unescaped output.

## Expression Syntax

| Expression | Example | Description |
|---|---|---|
| Variable | `${user.name}` | Dot-notation, null-safe traversal |
| Selection | `*{field}` | Field access on `tl:object` context |
| URL | `@{/users(id=${userId})}` | URL with query params |
| String literal | `'hello'` | Single-quoted string |
| Literal substitution | `\|Hello, ${name}!\|` | Pipe-delimited template string |
| Arithmetic | `${a} + ${b}`, `- * / %` | Numeric arithmetic |
| Dynamic index | `${list[index]}` | List/map access with expression index |
| Ternary | `${active} ? 'yes' : 'no'` | Conditional expression |
| Elvis | `${val} ?: 'default'` | Null-coalescing |
| Comparison | `${a} == ${b}`, `!=`, `<`, `>`, `<=`, `>=` | Value comparison |
| Comparison alias | `gt`, `lt`, `ge`, `le`, `eq`, `ne` | Word-form comparison operators |
| Boolean | `${a} and ${b}`, `or`, `not` | Logical operators |
| Concat | `${first} + ' ' + ${last}` | String concatenation |
| No-op | `_` | Explicitly do nothing (prototype preservation) |

## HTMX Fragment Example

```dart
import 'package:trellis/trellis.dart';
// Also add shelf: dart pub add shelf shelf_io

final engine = Trellis(loader: FileSystemLoader('templates/'));

// Full page render
final page = engine.render(pageTemplate, {'items': items});

// HTMX partial -- render only the fragment
final fragment = engine.renderFragment(
  pageTemplate,
  fragment: 'itemList',
  context: {'items': items},
);

// Render multiple fragments in one call
final fragments = engine.renderFragments(
  pageTemplate,
  fragments: ['header', 'itemList'],
  context: {'items': items},
);
```

## Configuration

```dart
Trellis(
  loader: FileSystemLoader('templates/'), // Default
  cache: true,         // DOM caching with deep-clone (default: true)
  maxCacheSize: 100,   // LRU eviction threshold (default: unbounded)
  prefix: 'tl',        // Attribute prefix (default: 'tl')
  strict: false,       // Throw on undefined variables/members (default: false)
)
```

Use `TrellisContext` for a fluent builder alternative:

```dart
final ctx = TrellisContext()
  ..loader = FileSystemLoader('templates/')
  ..strict = true
  ..maxCacheSize = 50;
final engine = Trellis.fromContext(ctx);
```

### Template Loaders

- **`FileSystemLoader(basePath)`** -- loads from filesystem with security boundaries
- **`MapLoader(templates)`** -- in-memory templates, useful for testing

### HTML5-Valid Attribute Names

Use `data-tl-*` attributes to pass HTML5 validation:

```dart
Trellis(prefix: 'data-tl', separator: '-')
```

```html
<p data-tl-text="${message}">placeholder</p>
```

## Public API

| Method / Property | Returns | Description |
|---|---|---|
| `render(source, context)` | `String` | Render template string |
| `renderFile(name, context)` | `Future<String>` | Load and render template file |
| `renderFragment(source, fragment:, context:)` | `String` | Render named fragment from string |
| `renderFileFragment(name, fragment:, context:)` | `Future<String>` | Load file and render named fragment |
| `renderFragments(source, fragments:, context:)` | `Map<String, String>` | Render multiple fragments from string |
| `renderFileFragments(name, fragments:, context:)` | `Future<Map<String, String>>` | Load file and render multiple fragments |
| `cacheStats` | `CacheStats` | Hit/miss/size metrics for the DOM cache |

## Benchmark

Run the cache benchmark harness:

```bash
dart run benchmark/cache_benchmark.dart
```

The benchmark reports median render latency for `cache: true` vs `cache: false`,
plus a simple RSS delta probe over 10k renders.

## Error Handling

| Exception | When |
|---|---|
| `TemplateException` | Base class for all template errors |
| `ExpressionException` | Malformed or unevaluable expression (also thrown in strict mode for undefined variables) |
| `FragmentNotFoundException` | Named fragment not found in template |
| `TemplateNotFoundException` | Template file not found by loader |
| `TemplateSecurityException` | Path traversal or symlink escape attempt |

## Security

- `tl:utext` renders **unescaped HTML** -- only use with trusted content to avoid XSS
- `tl:inline` in `javascript`/`css` mode escapes output including `</script>` and `</style>` closing tags
- `FileSystemLoader` rejects absolute paths, `..` traversal, and symlink escapes outside the base directory
- `tl:text` always HTML-escapes output

## License

MIT
