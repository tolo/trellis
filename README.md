<p align="center">
  <img src="https://raw.githubusercontent.com/tolo/trellis/main/assets/logo-with-text.png" alt="Trellis" width="400">
</p>

<p align="center">
  <a href="https://pub.dev/packages/trellis"><img src="https://img.shields.io/pub/v/trellis.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/trellis/publisher"><img src="https://img.shields.io/pub/publisher/trellis.svg" alt="package publisher"></a>
</p>

A natural HTML template engine for Dart — templates are valid HTML that browsers render as prototypes without a server. Fragment-first design built for hypermedia-driven web frameworks like [HTMX](https://htmx.org/). Inspired by [Thymeleaf](https://www.thymeleaf.org/).

## Features

- **Natural templates** -- valid HTML that browsers render as prototypes without a server
- **Fragment-first** -- `tl:fragment` + `renderFragment()` maps directly to HTMX partial responses
- **Full expression language** -- variables, arithmetic, literal substitution, selection, URL, ternary, Elvis, comparisons, boolean
- **i18n message expressions** -- `#{key}` with `MessageSource`, parameterized messages, and locale support
- **Filter arguments** -- `| filterName:arg1:arg2` parameterized filter syntax
- **Switch/case, block, remove, inline** -- multi-branch conditionals, virtual elements, output control, inline JS/CSS processing
- **Parameterized fragments** -- `tl:fragment="card(title, body)"` with argument passing at inclusion
- **CSS selector targeting** -- `tl:insert="~{file :: #id}"` and `tl:insert="~{file :: .class}"`
- **Custom processors & dialects** -- register `Processor` implementations; compose feature sets with `Dialect`
- **Sync-first API** -- `render()` is synchronous; `renderFile()` is async only for I/O
- **LRU DOM cache** -- configurable size, `CacheStats` for hit/miss metrics
- **Strict mode** -- undefined variables/members throw `ExpressionException`
- **Secure** -- `FileSystemLoader` enforces path traversal and symlink escape protection
- **AOT-compatible** -- context is `Map<String, dynamic>`, no reflection

## Requirements

- Dart SDK `^3.10.0`

## Installation

```
dart pub add trellis
```

## Quick Start

```dart
import 'package:trellis/trellis.dart';

final engine = Trellis();

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
  <p tl:case="admin">Admin view</p>
  <p tl:case="user">User view</p>
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

Circular fragment inclusions are detected and reported with the full cycle path.

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
<div class="card" tl:classappend="${active} ? 'active' : ''">content</div>
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

<!-- Self-closing form also supported -->
<tl:block tl:utext="${bodyHtml}"/>
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

### Filters

Filters transform expression values using pipe syntax:

```html
<span tl:text="${name | upper}">NAME</span>
<span tl:text="${input | trim | lower}">cleaned</span>
```

Built-in filters: `upper`, `lower`, `trim`, `length`.

Filters accept arguments using colon-separated syntax. Argument types supported: string (single-quoted, with `\'` escape), int, double, bool, null, and bare identifiers.

```html
<span tl:text="${price | currency:'USD':2}">price</span>
<span tl:text="${text | truncate:100}">long text</span>
```

Custom filters via constructor:

```dart
Trellis(filters: {
  'currency': (v) => '\$${(v as num).toStringAsFixed(2)}',
  // Filter with arguments: FilterFunction signature
  'truncate': (v, [args]) {
    final limit = (args?.firstOrNull as int?) ?? 80;
    final s = v.toString();
    return s.length <= limit ? s : '${s.substring(0, limit)}…';
  },
})
```

### i18n Message Expressions

Use `#{key}` to look up messages from a `MessageSource`:

```html
<p tl:text="#{welcome.title}">Welcome</p>
<p tl:text="#{greeting(${user.name})}">Hello, user!</p>
```

Wire up a `MessageSource` when constructing the engine:

```dart
Trellis(
  messageSource: MapMessageSource(messages: {
    'en': {
      'welcome.title': 'Welcome to Trellis',
      'greeting': 'Hello, {0}!',
    },
    'es': {
      'welcome.title': 'Bienvenido a Trellis',
      'greeting': '¡Hola, {0}!',
    },
  }),
  locale: 'en', // default locale; override per-request via _locale context key
)
```

Positional placeholders `{0}`, `{1}`, ... are replaced by the arguments passed in the expression. Missing keys return the key itself in lenient mode or throw in strict mode.

## Expression Syntax

| Expression | Example | Description |
|---|---|---|
| Variable | `${user.name}` | Dot-notation, null-safe traversal |
| Selection | `*{field}` | Field access on `tl:object` context |
| Message | `#{welcome.title}` | i18n key lookup via `MessageSource` |
| URL | `@{/users(id=${userId})}` | URL with query params |
| String literal | `'hello'` | Single-quoted string |
| Literal substitution | `\|Hello, ${name}!\|` | Pipe-delimited template string |
| Arithmetic | `${a} + ${b}`, `- * / %` | Numeric arithmetic |
| Dynamic index | `${list[index]}` | List/map access with expression index |
| Ternary | `${active} ? 'yes' : 'no'` | Conditional expression |
| Elvis | `${val} ?: 'default'` | Null-coalescing |
| Comparison | `${a} == ${b}`, `!=`, `<`, `>`, `<=`, `>=` | Value comparison |
| Comparison alias | `gt`, `lt`, `ge`, `le`, `eq`, `ne` | Word-form comparison operators |
| Boolean | `${a} and ${b}`, `or`, `not` / `!` | Logical operators |
| Concat | `${first} + ' ' + ${last}` | String concatenation |
| Filter | `${name \| upper}`, `${price \| fmt:'USD'}` | Pipe-based value transformation, with optional args |
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
  cache: true,           // DOM caching with deep-clone (default: true)
  devMode: false,        // File watching for dev (default: false)
  maxCacheSize: 100,     // LRU eviction threshold (default: 256)
  prefix: 'tl',          // Attribute prefix (default: 'tl')
  strict: false,         // Throw on undefined variables/members (default: false)
  messageSource: ...,    // i18n MessageSource implementation
  locale: 'en',          // Default locale for message lookup
  processors: [...],     // Additional custom Processor instances
  dialects: [...],       // Dialect instances contributing processors + filters
  includeStandard: true, // Include the built-in StandardDialect (default: true)
)
```

`TrellisContext` is a fluent builder for constructing rendering context maps:

```dart
final context = TrellisContext()
  .set('title', 'Hello')
  .set('user', {'name': 'Alice'})
  .setAll({'items': ['a', 'b', 'c']})
  .build();

final html = engine.render(template, context);
```

### Dev Mode (File Watching)

Enable `devMode` to automatically reload templates when files change on disk — ideal for development:

```dart
final engine = Trellis(
  loader: FileSystemLoader('templates/', devMode: true),
  devMode: true,
);

// Templates are re-read automatically when modified.
// Call close() when shutting down to release the file watcher:
await engine.close();
```

When `devMode` is `false` (the default), no file watcher is created and there is zero runtime overhead.

**Note:** `Trellis.close()` also closes the associated `FileSystemLoader`. If you share a loader across multiple engine instances, manage the loader's lifecycle separately.

### Template Loaders

- **`FileSystemLoader(basePath)`** -- loads from filesystem with security boundaries
- **`AssetLoader(packageUri)`** -- loads from Dart package assets (JIT only, see [AOT limitations](doc/guides/framework-integration.md))
- **`CompositeLoader(delegates)`** -- tries multiple loaders in order with fallback
- **`MapLoader(templates)`** -- in-memory templates, useful for testing

### Custom Processors

Implement the `Processor` interface to add new `tl:*` attributes. Processors declare their attribute name, priority, and whether to recurse into children:

```dart
class HighlightProcessor implements Processor {
  @override
  String get attribute => 'highlight';

  @override
  ProcessorPriority get priority => ProcessorPriority.afterContent;

  @override
  bool get autoProcessChildren => true;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    element.attributes['style'] =
        '${element.attributes['style'] ?? ''}background:yellow';
    element.attributes.remove('tl:highlight');
    return true;
  }
}

final engine = Trellis(processors: [HighlightProcessor()]);
```

### Dialects

Group processors and filters into a reusable `Dialect`:

```dart
class MyDialect implements Dialect {
  @override
  String get name => 'MyDialect';

  @override
  List<Processor> get processors => [HighlightProcessor()];

  @override
  Map<String, Function> get filters => {
    'shout': (v) => v.toString().toUpperCase() + '!!!',
  };
}

final engine = Trellis(dialects: [MyDialect()]);

// Use only custom dialects, omitting the built-in StandardDialect:
final minimal = Trellis(dialects: [MyDialect()], includeStandard: false);
```

## Framework Integration

Trellis integrates with any Dart server framework in a few lines. Here's a minimal shelf example:

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:trellis/trellis.dart';

final engine = Trellis(loader: FileSystemLoader('templates/'));

Future<Response> handler(Request request) async {
  final html = await engine.renderFile('index', {'title': 'Hello'});
  return Response.ok(html,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

void main() async {
  await shelf_io.serve(handler, 'localhost', 8080);
}
```

HTMX partial responses use `renderFragment()`:

```dart
// Return only the todo list fragment for HTMX swap
final html = engine.renderFragment(
  source,
  fragment: 'todoList',
  context: {'todos': todos},
);
```

Full guide with shelf middleware, dart_frog handlers, HTMX OOB swaps, and error handling: **[Framework Integration Guide](doc/guides/framework-integration.md)**.

### HTML5-Valid Attribute Names

Use `data-tl-*` attributes to pass HTML5 validation:

```dart
Trellis(prefix: 'data-tl')
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
| `renderFragments(source, fragments:, context:)` | `String` | Render multiple fragments concatenated |
| `renderFileFragments(name, fragments:, context:)` | `Future<String>` | Load file and render multiple fragments |
| `clearCache()` | `void` | Clear DOM cache and reset statistics |
| `cacheStats` | `CacheStats` | Hit/miss/size metrics for the DOM cache |
| `close()` | `Future<void>` | Release file-watch resources; also closes the loader (no-op when devMode is false) |

`ExpressionEvaluator` can be used standalone for expression evaluation without templates:

```dart
final evaluator = ExpressionEvaluator(strict: true);
final result = evaluator.evaluate(r'${a} + ${b}', {'a': 1, 'b': 2}); // 3
```

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

## Contributing

Trellis is in early development and we're not accepting pull requests at this time. That said, we'd love to hear from you — bug reports, feature ideas, and general feedback are all very welcome! Please feel free to [open an issue](https://github.com/tolo/trellis/issues).

## License

MIT
