# Framework Integration Guide

Trellis is framework-agnostic: render HTML with `render()`/`renderFile()` and return it as an HTTP
response. The SDK provides three integration packages that add framework-specific middleware,
response helpers, HTMX utilities, and security patterns.

This guide covers:

- [1. Engine Setup](#1-engine-setup) — shared across all frameworks
- [2. Shelf Integration](#2-shelf-integration) — using `trellis_shelf`
- [3. Dart Frog Integration](#3-dart-frog-integration) — using `trellis_dart_frog`
- [4. Relic Integration](#4-relic-integration) — using `trellis_relic`
- [5. HTMX Patterns](#5-htmx-patterns) — fragment rendering with all three frameworks
- [6. Security](#6-security) — headers, CSRF, and CSP
- [7. Template Testing](#7-template-testing) — using `trellis/testing.dart`
- [8. Error Handling](#8-error-handling) — exception types and safe rendering
- [9. AOT Deployment Notes](#9-aot-deployment-notes) — loader choices and compilation

---

## 1. Engine Setup

This section applies to all three frameworks. Create the engine once (typically as a top-level
singleton or injected via middleware) and reuse it for the lifetime of the application.

```dart
import 'package:html/dom.dart';
import 'package:trellis/trellis.dart';

// Custom processor — sets the `title` attribute from an expression
class TooltipProcessor extends Processor {
  @override
  String get attribute => 'tooltip';

  @override
  ProcessorPriority get priority => ProcessorPriority.afterContent;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final text = context.evaluate(value, context.variables)?.toString() ?? '';
    if (text.isNotEmpty) {
      element.attributes['title'] = text;
    }
    return true;
  }
}

// Custom dialect — groups related processors and filters
class UiDialect extends Dialect {
  @override
  String get name => 'UI';

  @override
  List<Processor> get processors => [TooltipProcessor()];

  @override
  Map<String, Function> get filters => {
    'badge': (dynamic v, [List<dynamic>? args]) {
      final label = v?.toString() ?? '';
      final variant = (args != null && args.isNotEmpty)
          ? args.first.toString()
          : 'neutral';
      return '<span class="badge badge-$variant">$label</span>';
    },
  };
}

final engine = Trellis(
  loader: FileSystemLoader('templates/', devMode: true), // file watching in dev
  devMode: true,
  strict: true, // catches missing variables during development
  dialects: [UiDialect()],
  filters: {
    'currency': (dynamic v, [List<dynamic>? args]) {
      final code = (args != null && args.isNotEmpty)
          ? args.first.toString()
          : 'USD';
      final value = (v as num?) ?? 0;
      return '$code ${value.toStringAsFixed(2)}';
    },
  },
  messageSource: MapMessageSource(messages: {
    'en': {'welcome.message': 'Welcome, {0}!'},
    'sv': {'welcome.message': 'Välkommen, {0}!'},
  }),
  locale: 'en',
);
```

Template markup using the configured features:

```html
<h1 tl:text="#{welcome.message(${user.name})}">Welcome</h1>
<p tl:text="${price | currency:'USD'}">USD 0.00</p>
<p tl:utext="${status | badge:'success'}">status badge</p>
<button tl:tooltip="${helpText}">Save</button>
```

> For a deep dive into custom processors, dialects, and filters, see the
> [Custom Processors](https://github.com/tolo/trellis/blob/main/README.md#custom-processors)
> and
> [Dialects](https://github.com/tolo/trellis/blob/main/README.md#dialects)
> sections in the Trellis README.

---

## 2. Shelf Integration

The `trellis_shelf` package provides middleware, response helpers, HTMX utilities, and security
for Shelf applications.

**Add dependency:**

```yaml
dependencies:
  trellis_shelf: ^0.1.0
```

**Import:**

```dart
import 'package:trellis_shelf/trellis_shelf.dart';
```

### Middleware and Engine Access

`trellisEngine(engine)` injects the engine into the Shelf request context. Handlers retrieve it
via `getEngine(request)`.

```dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:trellis/trellis.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

final engine = Trellis(
  loader: FileSystemLoader('templates/', devMode: true),
  devMode: true,
  strict: true,
);

// Full page handler
Future<Response> homeHandler(Request request) async {
  return renderPage(request, 'index', {'title': 'Home', 'items': ['Alpha', 'Beta', 'Gamma']});
}

// HTMX handler — fragment on HTMX request, full page on navigation
Future<Response> todosHandler(Request request) async {
  final todos = ['Review PR', 'Write docs'];
  if (isHtmxRequest(request)) {
    return renderFragment(request, 'todos', 'todoList', {'todos': todos});
  }
  return renderPage(request, 'todos', {'todos': todos});
}

// POST handler — return OOB updates after mutation
Future<Response> createTodoHandler(Request request) async {
  final form = Uri.splitQueryString(await request.readAsString());
  final title = (form['title'] ?? '').trim();
  final todos = <String>['Review PR', 'Write docs'];
  if (title.isNotEmpty) todos.add(title);

  return renderOobFragments(request, 'todos', ['todoList', 'todoCount'], {'todos': todos});
}

void main() async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(trellisSecurityHeaders())
      .addMiddleware(trellisEngine(engine))
      .addMiddleware(trellisCsrf(secret: 'your-secret-key'))
      .addHandler((request) => switch (request.url.path) {
            '' || 'home' => homeHandler(request),
            'todos' when request.method == 'GET' => todosHandler(request),
            'todos' when request.method == 'POST' => createTodoHandler(request),
            _ => Future.value(Response.notFound('Not found')),
          });

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('http://${server.address.host}:${server.port}');
}
```

### Response Helpers

| Function | Description |
|---|---|
| `renderPage(request, template, context)` | Renders a full page (or `htmxFragment` when HTMX request) |
| `renderFragment(request, template, fragment, context)` | Renders a single named fragment |
| `renderOobFragments(request, template, fragments, context)` | Renders multiple fragments (OOB) |
| `htmlResponse(html)` | Wraps an HTML string in a `text/html` response |

Response helpers automatically merge request-context values (including the CSRF token) into the
template context.

### Hot Reload in Dev Mode

Pair `devMode: true` (enables file watching in `FileSystemLoader`) with `trellis_dev` for
browser-side live reload over SSE. See the [`trellis_dev` README](../../packages/trellis_dev/README.md)
for setup instructions.

---

## 3. Dart Frog Integration

The `trellis_dart_frog` package provides a provider middleware, response helpers, HTMX utilities,
and security middleware for Dart Frog applications.

**Add dependency:**

```yaml
dependencies:
  trellis_dart_frog: ^0.1.0
```

**Import:**

```dart
import 'package:trellis_dart_frog/trellis_dart_frog.dart';
```

### Middleware (`routes/_middleware.dart`)

`trellisProvider(engine)` makes the engine available via `context.read<Trellis>()`. Security
middleware is applied in the same chain using Dart Frog's `.use()` pattern.

```dart
// routes/_middleware.dart
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

final _engine = Trellis(
  loader: FileSystemLoader('templates/', devMode: true),
  devMode: true,
  strict: true,
);

Handler middleware(Handler handler) {
  return handler
      .use(trellisProvider(_engine))
      .use(trellisSecurityHeaders())
      .use(trellisCsrf(secret: 'your-secret-key'));
}
```

### Full Page Route (`routes/index.dart`)

```dart
// routes/index.dart
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  return renderPage(context, 'index', {
    'title': 'Dashboard',
    'items': ['One', 'Two', 'Three'],
  });
}
```

### HTMX Partial Route (`routes/todos.dart`)

```dart
// routes/todos.dart
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

final _todos = <String>['Write tests'];

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    final form = Uri.splitQueryString(await context.request.body());
    final title = (form['title'] ?? '').trim();
    if (title.isNotEmpty) _todos.add(title);

    return renderOobFragments(context, 'todos', ['todoList', 'todoCount'], {
      'todos': List<String>.from(_todos),
    });
  }

  if (isHtmxRequest(context)) {
    return renderFragment(context, 'todos', 'todoList', {
      'todos': List<String>.from(_todos),
    });
  }

  return renderPage(context, 'todos', {'todos': List<String>.from(_todos)});
}
```

### Response Helpers (Dart Frog)

Dart Frog response helpers accept `RequestContext` (not `Request`) as the first argument. This
is different from `trellis_shelf` where handlers receive a `Request`.

| Function | Description |
|---|---|
| `renderPage(context, template, templateContext)` | Full page (or `htmxFragment` for HTMX requests) |
| `renderFragment(context, template, fragment, templateContext)` | Single named fragment |
| `renderOobFragments(context, template, fragments, templateContext)` | Multiple fragments (OOB) |

### Hot Reload in Dev Mode

`trellis_dev` SSE works alongside `dart_frog dev`. The `devMode: true` flag on the engine enables
file-system watching so templates reload automatically on change.

---

## 4. Relic Integration

The `trellis_relic` package provides response helpers, HTMX utilities, and security headers for
Relic applications.

**Add dependency:**

```yaml
dependencies:
  trellis_relic: ^0.1.0
```

**Import:**

```dart
import 'package:trellis_relic/trellis_relic.dart';
```

### Complete Application

Relic has no dependency-injection mechanism, so the engine is passed **explicitly** to every
response helper as the second argument.

```dart
import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

// Engine is a top-level singleton — passed explicitly to response helpers
final engine = Trellis(
  loader: FileSystemLoader('templates/', devMode: true),
  devMode: true,
  strict: true,
);

final _todos = <String>['Write tests'];

void main() async {
  final app = RelicApp()
    ..use('/', trellisSecurityHeaders())
    ..get('/', (request) async {
      return renderPage(request, engine, 'index', {'title': 'Home'});
    })
    ..get('/todos', (request) async {
      if (isHtmxRequest(request)) {
        return renderFragment(request, engine, 'todos', 'todoList', {
          'todos': List<String>.from(_todos),
        });
      }
      return renderPage(request, engine, 'todos', {'todos': List<String>.from(_todos)});
    })
    ..post('/todos', (request) async {
      final body = await request.readAsString();
      final form = Uri.splitQueryString(body);
      final title = (form['title'] ?? '').trim();
      if (title.isNotEmpty) _todos.add(title);

      return renderOobFragments(request, engine, 'todos', ['todoList', 'todoCount'], {
        'todos': List<String>.from(_todos),
      });
    });

  await app.serve(port: 8080);
}
```

### Response Helpers (Relic)

Relic response helpers take `request` and `engine` as the first two arguments:

| Function | Description |
|---|---|
| `renderPage(request, engine, template, context)` | Full page (or `htmxFragment` for HTMX requests) |
| `renderFragment(request, engine, template, fragment, context)` | Single named fragment |
| `renderOobFragments(request, engine, template, fragments, context)` | Multiple fragments (OOB) |
| `htmlResponse(html)` | Wraps an HTML string in a `text/html` response |

> **Engine is always explicit** — unlike Shelf and Dart Frog, where the engine is retrieved from
> the request context, Relic response helpers require the engine to be passed directly.

> **CSRF not available for Relic** — see [Section 6.2](#62-csrf-protection) for details.

> **Middleware scope** — Relic middleware only fires for matched routes. A `404` or `405`
> response does **not** pass through `trellisSecurityHeaders()`. Shelf's `Pipeline`, by contrast,
> always runs middleware regardless of routing outcome.

---

## 5. HTMX Patterns

These patterns apply to all three frameworks. Each subsection shows the shared template markup
and per-framework snippets for the handler side.

### 5.1 Fragment-per-endpoint

Return a single fragment for a dedicated endpoint (e.g. `/todos/list`). HTMX targets the
fragment's root element in the DOM.

**Template:**

```html
<ul id="todo-list" tl:fragment="todoList">
  <li tl:each="todo : ${todos}" tl:text="${todo}">Sample</li>
</ul>
```

**Handler snippets:**

```dart
// Shelf
return renderFragment(request, 'todos', 'todoList', {'todos': todos});

// Dart Frog
return renderFragment(context, 'todos', 'todoList', {'todos': todos});

// Relic
return renderFragment(request, engine, 'todos', 'todoList', {'todos': todos});
```

### 5.2 OOB Multi-target Updates

Return multiple fragments concatenated in a single response. HTMX swaps each fragment into the
matching element via `hx-swap-oob`.

**Template:**

```html
<ul id="todo-list" tl:fragment="todoList" hx-swap-oob="true">
  <li tl:each="todo : ${todos}" tl:text="${todo}">Sample</li>
</ul>

<p id="todo-count" tl:fragment="todoCount" hx-swap-oob="true">
  Total: <span tl:text="${#lists.size(todos)}">0</span>
</p>
```

**Handler snippets:**

```dart
// Shelf
return renderOobFragments(request, 'todos', ['todoList', 'todoCount'], ctx);

// Dart Frog
return renderOobFragments(context, 'todos', ['todoList', 'todoCount'], ctx);

// Relic
return renderOobFragments(request, engine, 'todos', ['todoList', 'todoCount'], ctx);
```

### 5.3 Full Page vs. Partial Content Negotiation

Detect the `HX-Request` header to return a fragment for HTMX navigation and a full page for
normal browser navigation to the same URL.

```dart
// Shelf
if (isHtmxRequest(request)) {
  return renderFragment(request, 'todos', 'content', ctx);
}
return renderPage(request, 'todos', ctx);

// Dart Frog
if (isHtmxRequest(context)) {
  return renderFragment(context, 'todos', 'content', ctx);
}
return renderPage(context, 'todos', ctx);

// Relic
if (isHtmxRequest(request)) {
  return renderFragment(request, engine, 'todos', 'content', ctx);
}
return renderPage(request, engine, 'todos', ctx);
```

Alternatively, use the `htmxFragment` parameter on `renderPage` to handle this in one call:

```dart
// Shelf — renders 'content' fragment for HTMX, full page otherwise
return renderPage(request, 'todos', ctx, htmxFragment: 'content');

// Dart Frog
return renderPage(context, 'todos', ctx, htmxFragment: 'content');

// Relic
return renderPage(request, engine, 'todos', ctx, htmxFragment: 'content');
```

### 5.4 Complete Template Example

This template works with all three frameworks — the rendering API is framework-specific but the
template itself is not.

```html
<section>
  <form hx-post="/todos" hx-target="#todo-list" hx-swap="outerHTML">
    <input type="hidden" name="_csrf" tl:value="${csrfToken}">
    <input name="title" placeholder="New todo">
    <button type="submit">Add</button>
  </form>

  <ul id="todo-list" tl:fragment="todoList" hx-swap-oob="true">
    <li tl:each="todo : ${todos}" tl:text="${todo}">Sample</li>
  </ul>

  <p id="todo-count" tl:fragment="todoCount" hx-swap-oob="true">
    Total: <span tl:text="${#lists.size(todos)}">0</span>
  </p>
</section>
```

> `${csrfToken}` is automatically available in Shelf and Dart Frog when `trellisCsrf` middleware
> is active. For Relic, CSRF is not available — see [Section 6.2](#62-csrf-protection).

---

## 6. Security

### 6.1 Security Headers

`trellisSecurityHeaders()` adds the following headers to responses:

| Header | Default Value |
|---|---|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `X-XSS-Protection` | `0` |
| `Content-Security-Policy` | Sensible defaults via `CspBuilder` |

**Setup per framework:**

```dart
// Shelf — in Pipeline
const Pipeline()
    .addMiddleware(trellisSecurityHeaders())
    .addMiddleware(trellisEngine(engine))
    ...

// Dart Frog — in routes/_middleware.dart
Handler middleware(Handler handler) {
  return handler
      .use(trellisProvider(_engine))
      .use(trellisSecurityHeaders());
}

// Relic — via app.use()
final app = RelicApp()
  ..use('/', trellisSecurityHeaders())
  ...
```

**Customising CSP with `CspBuilder`:**

```dart
trellisSecurityHeaders(
  csp: CspBuilder(
    scriptSrc: "'self'",
    styleSrc: "'self' 'unsafe-inline'",
    connectSrc: "'self' ws:", // required for trellis_dev SSE in development
  ),
)
```

### 6.2 CSRF Protection

`trellisCsrf` uses a double-submit cookie pattern with HMAC-SHA256 signing.

**Available for:** Shelf, Dart Frog
**Not available for:** Relic — see the note below.

**Shelf setup:**

```dart
const Pipeline()
    .addMiddleware(trellisEngine(engine))
    .addMiddleware(trellisCsrf(
      secret: 'your-secret-key', // keep this private
      cookieName: '__csrf',      // optional, this is the default
      fieldName: '_csrf',        // form field name
      headerName: 'X-CSRF-Token', // or submit via header
      excludedPaths: ['/webhooks/stripe'], // paths to skip
    ))
    ...
```

**Dart Frog setup:**

```dart
Handler middleware(Handler handler) {
  return handler
      .use(trellisProvider(_engine))
      .use(trellisCsrf(secret: 'your-secret-key'));
}
```

**Template usage** — the token is automatically merged into the template context by the response
helpers. Use `${csrfToken}` in a hidden form field:

```html
<form hx-post="/todos">
  <input type="hidden" name="_csrf" tl:value="${csrfToken}">
  ...
</form>
```

**Relic — CSRF not available.** Relic does not expose a built-in form body parser, and the
double-submit pattern requires reading form fields server-side to validate the submitted token.
For Relic apps that need CSRF protection, options include:

- Parse `request.body` manually and validate the token against the signed cookie.
- Rely exclusively on HTMX's `hx-headers` to submit the token via `X-CSRF-Token` (avoids form
  parsing, but requires HTMX for all state-changing requests).
- Wait for Relic's own security middleware to mature in a future phase.

### 6.3 CSP for HTMX + `trellis_dev`

When using `trellis_dev` for browser-side live reload (via SSE), add `connect-src 'self' ws:` to
allow the WebSocket connection. Use different CSP configurations for dev and production:

```dart
final isDev = bool.fromEnvironment('TRELLIS_DEV', defaultValue: false);

trellisSecurityHeaders(
  csp: CspBuilder(
    connectSrc: isDev ? "'self' ws:" : null, // null omits the directive
  ),
)
```

### Per-Framework Security Matrix

| Feature | Shelf | Dart Frog | Relic |
|---|---|---|---|
| Security Headers | `trellisSecurityHeaders()` | `trellisSecurityHeaders()` | `trellisSecurityHeaders()` |
| CSP via `CspBuilder` | Yes | Yes | Yes |
| CSRF Protection | `trellisCsrf(secret:)` | `trellisCsrf(secret:)` | Not available |
| CSRF Token in Templates | `${csrfToken}` auto-merged | `${csrfToken}` auto-merged | N/A |
| Middleware Scope | All requests | All requests | Matched routes only |

---

## 7. Template Testing

The core `trellis` package includes testing utilities via `testing.dart` — snapshot testing,
CSS-selector-based HTML matchers, and fragment isolation helpers.

**Import:**

```dart
import 'package:trellis/testing.dart';
```

### 7.1 Test Engine Setup

`testEngine()` creates a strict-mode engine backed by `MapLoader`. Templates are defined inline
— no filesystem access needed in tests.

```dart
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis/testing.dart';

void main() {
  late Trellis engine;

  setUp(() {
    engine = testEngine(templates: {
      'page': r'''
        <html>
          <h1 tl:text="${title}">Title</h1>
          <ul><li tl:each="item : ${items}" tl:text="${item}">Item</li></ul>
        </html>
      ''',
      'nav': r'''
        <nav tl:fragment="mainNav">
          <a tl:each="link : ${links}"
             tl:href="${link.url}"
             tl:text="${link.label}">Link</a>
        </nav>
      ''',
    });
  });
  ...
}
```

> Use raw strings (`r'...'`) for templates containing `${...}` expressions to prevent Dart from
> interpreting them as string interpolations.

### 7.2 CSS-Selector Assertions

Assert on rendered HTML using CSS selector matchers:

```dart
test('page renders heading and list', () {
  final html = engine.render(
    engine.loader.loadSync('page')!,
    {'title': 'Hello', 'items': ['Alpha', 'Beta', 'Gamma']},
  );

  expect(html, hasElement('h1', withText: 'Hello'));
  expect(html, hasElement('li', count: 3));
  expect(html, hasNoElement('.error'));
  expect(html, hasElement('li', withText: 'Beta'));
});
```

| Matcher | Description |
|---|---|
| `hasElement(selector)` | At least one element matches the selector |
| `hasElement(selector, withText: 'x')` | Element contains the given text |
| `hasElement(selector, count: n)` | Exactly `n` elements match |
| `hasElement(selector, withAttribute: 'x')` | Element has the given attribute |
| `hasNoElement(selector)` | No elements match the selector |
| `hasAttribute(selector, attr, value)` | First matching element has attribute `attr` equal to `value` |
| `elementCount(selector, n)` | Exactly `n` elements match (pure count assertion) |

### 7.3 Fragment Testing

Test a single fragment in isolation using `testFragment`:

```dart
test('nav fragment renders links', () {
  final html = testFragment(engine, 'nav', 'mainNav', {
    'links': [
      {'url': '/home', 'label': 'Home'},
      {'url': '/about', 'label': 'About'},
    ],
  });

  expect(html, hasElement('a', count: 2));
  expect(html, hasAttribute('a', 'href', '/home'));
});
```

For file-based templates, use the async `testFragmentFile`:

```dart
test('nav fragment from file', () async {
  final html = await testFragmentFile(engine, 'partials/nav', 'mainNav', {
    'links': [{'url': '/home', 'label': 'Home'}],
  });
  expect(html, hasElement('a', withText: 'Home'));
});
```

### 7.4 Snapshot Testing

`expectSnapshot` renders a template and compares the output against a golden file:

```dart
test('page matches golden snapshot', () async {
  await expectSnapshot(
    engine,
    'page',
    {'title': 'Test', 'items': ['X', 'Y']},
    goldenFile: 'test/goldens/page.html',
  );
});
```

**First run:** The golden file is auto-created and the test passes with an info message.

**Mismatch:** The test fails with a readable line-by-line diff.

**Update goldens:** Re-run with the environment variable set:

```sh
TRELLIS_UPDATE_GOLDENS=true dart test
```

You can also test inline templates with `expectSnapshotFromSource`:

```dart
test('inline snapshot', () {
  expectSnapshotFromSource(
    engine,
    r'<h1 tl:text="${title}">x</h1>',
    {'title': 'Hello'},
    goldenFile: 'test/goldens/heading.html',
  );
});
```

---

## 8. Error Handling

### 8.1 Exception Types

| Exception | When thrown |
|---|---|
| `TemplateNotFoundException` | Template file/key not found in the loader |
| `FragmentNotFoundException` | Named fragment not found in the template |
| `TemplateException` | General rendering error (base class) |
| `ExpressionException` | Expression cannot be parsed or evaluated |
| `TemplateSecurityException` | Path traversal or security boundary violation |

### 8.2 Safe Rendering Pattern

Wrap `renderPage` / `renderFile` in a try/catch and return appropriate HTTP responses:

```dart
// Shelf
Future<Response> safeRender(Request request, String template, Map<String, dynamic> ctx) async {
  try {
    return await renderPage(request, template, ctx);
  } on TemplateNotFoundException {
    return Response.notFound('Page not found');
  } on FragmentNotFoundException {
    return Response.notFound('Fragment not found');
  } on ExpressionException catch (e) {
    // In development, expose the error detail for easier debugging
    return Response.internalServerError(body: 'Expression error: ${e.message}');
  } on TemplateException {
    return Response.internalServerError(body: 'Rendering failed');
  }
}
```

```dart
// Dart Frog
Future<Response> safeRender(RequestContext context, String template, Map<String, dynamic> ctx) async {
  try {
    return await renderPage(context, template, ctx);
  } on TemplateNotFoundException {
    return Response(statusCode: 404, body: 'Page not found');
  } on TemplateException {
    return Response(statusCode: 500, body: 'Rendering failed');
  }
}
```

```dart
// Relic
Future<Response> safeRender(
  Request request,
  Trellis engine,
  String template,
  Map<String, dynamic> ctx,
) async {
  try {
    return await renderPage(request, engine, template, ctx);
  } on TemplateNotFoundException {
    return Response.notFound();
  } on TemplateException {
    return Response.internalServerError();
  }
}
```

### 8.3 Custom Error Pages

Render a Trellis template for error pages, with a plain-text fallback:

```dart
Future<Response> errorPage(Request request, int status, String message) async {
  try {
    return Response(
      status,
      body: await engine.renderFile('errors/$status', {'message': message}),
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  } on TemplateException {
    // Error template itself failed — return plain text
    return Response(status, body: message);
  }
}
```

---

## 9. AOT Deployment Notes

### Loader Comparison

| Loader | AOT Compatible | Description |
|---|---|---|
| `FileSystemLoader` | Yes | Reads templates from the filesystem at runtime. Preferred for most deployments. |
| `MapLoader` | Yes | Embeds templates as Dart strings. Enables single-binary deployment with no external files. |
| `CompositeLoader` | Yes | Tries loaders in order. Use for fallback chains (e.g. filesystem first, map second). |
| `AssetLoader` | JIT only | Uses `Isolate.resolvePackageUri`. Does **not** work in AOT binaries. |

For production, always use `FileSystemLoader` (or `MapLoader` for embedded templates) and set
`devMode: false` to disable file watching:

```dart
final engine = Trellis(
  loader: FileSystemLoader('templates/'),
  devMode: false, // disable file watching in production
  strict: false,  // or true — strict mode has no runtime performance cost
);
```

### Per-Framework Compilation

**Shelf:**

```sh
dart compile exe bin/server.dart -o build/server
```

Bundle the `templates/` directory alongside the compiled binary.

**Dart Frog:**

```sh
dart_frog build
```

`dart_frog build` produces an AOT binary in `build/`. Templates must be bundled alongside the
binary (the build step does not embed them automatically). Check the
[Dart Frog documentation](https://dartfrog.vgv.dev) for how to include assets in the build output.

**Relic:**

```sh
dart compile exe bin/server.dart -o build/server
```

Same considerations as Shelf: bundle `templates/` alongside the binary.

### Template Embedding with `MapLoader`

For a single-binary deployment where no external files are needed:

```dart
// lib/templates.dart — generated or maintained by hand
const templates = {
  'index': '''
    <html>
      <body tl:text="${message}">hello</body>
    </html>
  ''',
};

// main.dart
final engine = Trellis(
  loader: MapLoader(templates),
  devMode: false,
);
```
