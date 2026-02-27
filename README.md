# trellis

[![pub package](https://img.shields.io/pub/v/trellis.svg)](https://pub.dev/packages/trellis)
[![package publisher](https://img.shields.io/pub/publisher/trellis.svg)](https://pub.dev/packages/trellis/publisher)

A Thymeleaf-inspired HTML template engine for Dart. Natural HTML templates with `tl:*` attributes, fragment-first design for HTMX, AOT-compatible (no reflection).

## Features

- **Natural templates** -- valid HTML that browsers render as prototypes without a server
- **Fragment-first** -- `tl:fragment` + `renderFragment()` maps directly to HTMX partial responses
- **Full expression language** -- variables, URL expressions, ternary, Elvis, comparisons, boolean operators
- **Sync-first API** -- `render()` is synchronous; `renderFile()` is async only for I/O
- **DOM caching** -- parsed templates cached and deep-cloned per render
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
  '<h1 tl:text="\${title}">Default Title</h1>',
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
<!-- Define a fragment -->
<div tl:fragment="userCard">
  <span tl:text="${user.name}">Name</span>
</div>

<!-- Include a fragment (keeps host element) -->
<div tl:insert="userCard">replaced by fragment</div>

<!-- Replace with fragment (replaces host element) -->
<div tl:replace="userCard">replaced entirely</div>

<!-- Cross-file inclusion -->
<div tl:insert="~{components :: header}">loads header from components.html</div>
```

### Local Variables

```html
<div tl:with="fullName=${first} + ' ' + ${last}">
  <span tl:text="${fullName}">Name</span>
</div>
```

### Attribute Setting

```html
<!-- Shorthand attributes -->
<a tl:href="${url}">link</a>
<img tl:src="${imageUrl}">
<input tl:value="${val}">
<div tl:class="${className}">styled</div>
<div tl:id="${elementId}">identified</div>

<!-- Generic attribute setting -->
<div tl:attr="data-id=${item.id},title=${item.name}">content</div>
```

`tl:class` replaces the existing class (not appends). Null values remove the attribute. Boolean HTML attributes (`disabled`, `checked`, etc.): `true` renders valueless, `false` removes.

## Expression Syntax

| Expression | Example | Description |
|---|---|---|
| Variable | `${user.name}` | Dot-notation, null-safe traversal |
| URL | `@{/users(id=${userId})}` | URL with query params |
| String literal | `'hello'` | Single-quoted string |
| Ternary | `${active} ? 'yes' : 'no'` | Conditional expression |
| Elvis | `${val} ?: 'default'` | Null-coalescing |
| Comparison | `${a} == ${b}`, `!=`, `<`, `>`, `<=`, `>=` | Value comparison |
| Boolean | `${a} and ${b}`, `or`, `not` | Logical operators |
| Concat | `${first} + ' ' + ${last}` | String concatenation |

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
```

## Configuration

```dart
Trellis(
  loader: FileSystemLoader('templates/'), // Default
  cache: true,     // DOM caching with deep-clone (default: true)
  prefix: 'tl',   // Attribute prefix (default: 'tl')
)
```

### Template Loaders

- **`FileSystemLoader(basePath)`** -- loads from filesystem with security boundaries
- **`MapLoader(templates)`** -- in-memory templates, useful for testing

## Public API

| Method | Returns | Description |
|---|---|---|
| `render(source, context)` | `String` | Render template string |
| `renderFile(name, context)` | `Future<String>` | Load and render template file |
| `renderFragment(source, fragment:, context:)` | `String` | Render named fragment from string |
| `renderFileFragment(name, fragment:, context:)` | `Future<String>` | Load file and render named fragment |

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
| `ExpressionException` | Malformed or unevaluable expression |
| `FragmentNotFoundException` | Named fragment not found in template |
| `TemplateNotFoundException` | Template file not found by loader |
| `TemplateSecurityException` | Path traversal or symlink escape attempt |

## Security

- `tl:utext` renders **unescaped HTML** -- only use with trusted content to avoid XSS
- `FileSystemLoader` rejects absolute paths, `..` traversal, and symlink escapes outside the base directory
- `tl:text` always HTML-escapes output

## License

MIT
