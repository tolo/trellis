---
title: trellis (core engine)
description: The Trellis template engine – configuration, template loaders, fragments, validation, custom processors, and the public API.
weight: 10
---

`trellis` is the template engine at the heart of the SDK: a natural HTML
template engine for Dart. Templates are valid HTML that browsers render as
prototypes without a server, with a fragment-first design built for
hypermedia-driven frameworks like [HTMX](https://htmx.org/).

This guide covers the engine's runtime API – how you construct and configure the
engine, load templates, render fragments, validate, and extend it. It assumes
you already know the template language:

- New to Trellis? Start with [Getting Started](/docs/getting-started/).
- Looking up an attribute or expression? See the
  [Syntax Reference](/docs/syntax/) – every `tl:*` attribute, the `<tl:block>`
  element, and every expression form, each with a worked example.

## Requirements and installation

- Dart SDK `^3.10.0`

```bash
dart pub add trellis
```

The only runtime dependency is `package:html`, the Dart team's HTML5 parser.

## Rendering

```dart
import 'package:trellis/trellis.dart';

final engine = Trellis();

final html = engine.render(
  '<h1 tl:text="${title}">Default Title</h1>',
  {'title': 'Hello, Trellis!'},
);
// <h1>Hello, Trellis!</h1>
```

`render()` is synchronous. `renderFile()` is asynchronous only because it reads
from disk. For the full template language – text, conditionals, iteration,
fragments, attributes, expressions – see the
[Syntax Reference](/docs/syntax/).

## Configuration

The `Trellis` constructor takes named options:

```dart
Trellis(
  loader: FileSystemLoader('templates/'), // template source
  cache: true,           // DOM caching with deep-clone (default: true)
  devMode: false,        // file watching for dev (default: false)
  maxCacheSize: 100,     // LRU eviction threshold (default: 256)
  prefix: 'tl',          // attribute prefix (default: 'tl')
  strict: false,         // throw on undefined variables/members (default: false)
  messageSource: ...,    // i18n MessageSource implementation
  locale: 'en',          // default locale for message lookup
  processors: [...],     // additional custom Processor instances
  dialects: [...],       // Dialect instances contributing processors + filters
  includeStandard: true, // include the built-in StandardDialect (default: true)
)
```

`TrellisContext` is a fluent builder for constructing rendering-context maps:

```dart
final context = TrellisContext()
  .set('title', 'Hello')
  .set('user', {'name': 'Alice'})
  .setAll({'items': ['a', 'b', 'c']})
  .build();

final html = engine.render(template, context);
```

### Strict mode

With `strict: true`, undefined variables and members throw `ExpressionException`
instead of rendering empty. Use it to catch template typos early.

## Template loaders

A loader tells the engine where to find named templates for `renderFile()` and
cross-file fragment includes (`~{file :: fragment}`):

- **`FileSystemLoader(basePath)`** – loads from the filesystem, enforcing
  path-traversal and symlink-escape protection.
- **`AssetLoader(packageUri)`** – loads from Dart package assets (JIT only; not
  AOT-compatible).
- **`CompositeLoader(delegates)`** – tries multiple loaders in order with
  fallback.
- **`MapLoader(templates)`** – in-memory templates, useful for testing.

`FileSystemLoader` rejects absolute paths, `..` traversal, and symlink escapes
outside the base directory, throwing `TemplateSecurityException`.

## Fragments and HTMX

Fragments are the bridge to HTMX partial responses: define a piece with
`tl:fragment`, then render just that piece. See the
[Fragments](/docs/syntax/fragments/) reference for the template-side syntax; the
engine side is the render API:

```dart
final engine = Trellis(loader: FileSystemLoader('templates/'));

// Full page render
final page = engine.render(pageTemplate, {'items': items});

// HTMX partial — render only the named fragment
final fragment = engine.renderFragment(
  pageTemplate,
  fragment: 'itemList',
  context: {'items': items},
);

// Render multiple fragments in one call (e.g. HTMX out-of-band swaps)
final fragments = engine.renderFragments(
  pageTemplate,
  fragments: ['header', 'itemList'],
  context: {'items': items},
);
```

For a framework-specific request/response layer – middleware, response helpers,
and HTMX detection – use the integration package for your server:
[trellis_shelf](/docs/packages/trellis_shelf/),
[trellis_dart_frog](/docs/packages/trellis_dart_frog/), or
[trellis_relic](/docs/packages/trellis_relic/).

## Dev mode (file watching)

Enable `devMode` to reload templates automatically when files change on disk:

```dart
final engine = Trellis(
  loader: FileSystemLoader('templates/', devMode: true),
  devMode: true,
);

// Templates are re-read automatically when modified.
// Call close() when shutting down to release the file watcher:
await engine.close();
```

When `devMode` is `false` (the default), no file watcher is created and there is
zero runtime overhead. `Trellis.close()` also closes the associated
`FileSystemLoader`; if you share a loader across engines, manage its lifecycle
separately.

For live browser refresh on template changes, pair this with
[trellis_dev](/docs/packages/trellis_dev/).

## Template validation

Validate templates in unit tests with the matcher from
`package:trellis/testing.dart`:

```dart
import 'package:test/test.dart';
import 'package:trellis/testing.dart';

void main() {
  test('template is valid', () {
    expect('<p tl:text="${name}">x</p>', isValidTemplate());
  });
}
```

For direct validation, use `TemplateValidator`:

```dart
final validator = TemplateValidator();
final issues = validator.validate('<p tl:text=""></p>');
```

For CI or local checks, validate a directory recursively:

```bash
dart run trellis:validate                       # scans ./templates
dart run trellis:validate templates             # or pass the directory positionally
dart run trellis:validate --dir templates --prefix tl
dart run trellis:validate --strict              # CI gate: warnings also fail the build
```

CLI behavior:

- Success prints nothing and exits `0`.
- Validation issues are printed to `stderr` as
  `path:line: severity: message (attribute)`.
- Validation errors exit `1`.
- Warnings – including the silent HTML5-parser mutations that strip `tl:*`
  directives (duplicate `tl:attr`, table/select foster-parenting) – are printed
  but exit `0` by default. Pass `--strict` (alias `--fatal-warnings`) to make
  them exit `1` too.

For CI, run with `--strict` so those silent-mutation warnings become a real
gate. Equivalently, assert zero issues inside `dart test` with
`isValidTemplate()` over your shipping templates.

## Template testing

Testing utilities are built into the core package via `testing.dart` – no extra
dependency needed:

```dart
import 'package:trellis/testing.dart';
import 'package:test/test.dart';

void main() {
  final engine = testEngine(templates: {
    'card': '<div tl:fragment="card"><h2 tl:text="${title}">Title</h2></div>',
  });

  test('card fragment renders title', () {
    final html = testFragment(engine, 'card', 'card', {'title': 'Hello'});
    expect(html, hasElement('h2', withText: 'Hello'));
    expect(html, hasNoElement('.missing'));
  });

  test('snapshot', () async {
    await expectSnapshotFromSource(engine, '<p tl:text="${msg}">x</p>', {'msg': 'hi'});
  });
}
```

## Extending the engine

### Custom processors

Implement the `Processor` interface to add a new `tl:*` attribute. A processor
declares its attribute name, priority, and whether to recurse into children:

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

A `Dialect` groups processors and filters into a reusable feature set:

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

The built-in `CssDialect` from [trellis_css](/docs/packages/trellis_css/) is an
example of a dialect you can register to add the `tl:scope` processor.

## Public API

| Method / Property | Returns | Description |
|---|---|---|
| `render(source, context)` | `String` | Render template string |
| `renderFile(name, context)` | `Future<String>` | Load and render template file |
| `warmUp(names)` | `Future<WarmUpResult>` | Pre-load named templates into the DOM cache |
| `warmUpAll()` | `Future<WarmUpResult>` | Discover and pre-load templates from `FileSystemLoader`/`MapLoader` |
| `renderFragment(source, fragment:, context:)` | `String` | Render named fragment from string |
| `renderFileFragment(name, fragment:, context:)` | `Future<String>` | Load file and render named fragment |
| `renderFragments(source, fragments:, context:)` | `String` | Render multiple fragments concatenated |
| `renderFileFragments(name, fragments:, context:)` | `Future<String>` | Load file and render multiple fragments |
| `clearCache()` | `void` | Clear DOM cache and reset statistics |
| `cacheStats` | `CacheStats` | Hit/miss/size metrics for the DOM cache plus `expressionCacheSize` |
| `close()` | `Future<void>` | Release file-watch resources; also closes the loader (no-op when devMode is false) |

`ExpressionEvaluator` can be used standalone for expression evaluation without
templates:

```dart
final evaluator = ExpressionEvaluator(strict: true);
final result = evaluator.evaluate(r'${a} + ${b}', {'a': 1, 'b': 2}); // 3
```

## Error handling

| Exception | When |
|---|---|
| `TemplateException` | Base class for all template errors |
| `ExpressionException` | Malformed or unevaluable expression (also thrown in strict mode for undefined variables) |
| `FragmentNotFoundException` | Named fragment not found in template |
| `TemplateNotFoundException` | Template file not found by loader |
| `TemplateSecurityException` | Path-traversal or symlink-escape attempt |

## Security

- `tl:text` always HTML-escapes output – safe for user-supplied data.
- `tl:utext` renders **unescaped HTML** – only use it with trusted content to
  avoid XSS.
- `tl:inline` in `javascript`/`css` mode escapes output, including `</script>`
  and `</style>` closing tags.
- `FileSystemLoader` rejects absolute paths, `..` traversal, and symlink escapes
  outside the base directory.

See [Text](/docs/syntax/text/) and [Attributes](/docs/syntax/attributes/) for
the escaping rules that bear on template syntax.
