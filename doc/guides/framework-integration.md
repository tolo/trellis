# Framework Integration Guide

Trellis is framework-agnostic: render HTML with `render()`/`renderFile()` and return it as an HTTP response.

This guide covers:
- `shelf`
- `dart_frog`
- HTMX partial rendering with `renderFragment()` and `renderFragments()`

## Engine Setup

This setup demonstrates custom processors, dialects, filters with arguments, and i18n messages.

```dart
import 'package:html/dom.dart';
import 'package:trellis/trellis.dart';

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
  loader: FileSystemLoader('templates/'),
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
    'sv': {'welcome.message': 'Valkommen, {0}!'},
  }),
  locale: 'en',
);
```

Template usage for that setup:

```html
<h1 tl:text="#{welcome.message(${user.name})}">Welcome</h1>
<p tl:text="${price | currency:'USD'}">USD 0.00</p>
<p tl:utext="${status | badge:'success'}">status badge</p>
<button tl:tooltip="${helpText}">Save</button>
```

## shelf

### Basic Setup + Middleware Injection

```dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:trellis/trellis.dart';

const _engineKey = 'trellis.engine';

Middleware trellisMiddleware({bool devMode = false}) {
  final engine = Trellis(
    loader: FileSystemLoader('templates/', devMode: devMode),
    devMode: devMode,
    strict: true,
  );
  return (inner) {
    return (request) => inner(request.change(context: {_engineKey: engine}));
  };
}

Trellis getEngine(Request request) => request.context[_engineKey]! as Trellis;

Response htmlResponse(String html, {int statusCode = 200}) {
  return Response(
    statusCode,
    body: html,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

Future<Response> homeHandler(Request request) async {
  final engine = getEngine(request);
  final html = await engine.renderFile('index', {
    'title': 'Home',
    'items': ['Alpha', 'Beta', 'Gamma'],
  });
  return htmlResponse(html);
}

Future<void> main() async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(trellisMiddleware(devMode: true)) // file watching in dev
      .addHandler((request) {
    return switch (request.url.path) {
      '' || 'home' => homeHandler(request),
      _ => Future.value(Response.notFound('Not found')),
    };
  });

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('http://${server.address.host}:${server.port}');
}
```

### HTMX Fragments With shelf

```dart
import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';

final _todos = <String>['Review PR', 'Write docs'];

Response htmlResponse(String html, {int statusCode = 200}) {
  return Response(
    statusCode,
    body: html,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

Future<Response> todosHandler(Request request, Trellis engine) async {
  final source = await engine.loader.load('todos.html');
  final context = {'todos': List<String>.from(_todos)};

  if (request.headers['hx-request'] == 'true') {
    final html = engine.renderFragment(
      source,
      fragment: 'todoList',
      context: context,
    );
    return htmlResponse(html);
  }

  final html = engine.render(source, context);
  return htmlResponse(html);
}

Future<Response> createTodoHandler(Request request, Trellis engine) async {
  final form = Uri.splitQueryString(await request.readAsString());
  final title = (form['title'] ?? '').trim();
  if (title.isNotEmpty) {
    _todos.add(title);
  }

  final source = await engine.loader.load('todos.html');
  final context = {'todos': List<String>.from(_todos)};

  final html = engine.renderFragments(
    source,
    fragments: ['todoList', 'todoCount'],
    context: context,
  );

  return htmlResponse(html);
}
```

Template for the HTMX example:

```html
<section>
  <form hx-post="/todos" hx-target="#todo-list" hx-swap="outerHTML">
    <input name="title" placeholder="New todo">
    <button type="submit">Add</button>
  </form>

  <ul id="todo-list" tl:fragment="todoList" hx-swap-oob="true">
    <li tl:each="todo : ${todos}" tl:text="${todo}">Sample</li>
  </ul>

  <p id="todo-count" tl:fragment="todoCount" hx-swap-oob="true">
    Total: <span tl:text="${todos.length}">0</span>
  </p>
</section>
```

## dart_frog

### Middleware Injection

```dart
// routes/_middleware.dart
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';

final _engine = Trellis(
  loader: FileSystemLoader('templates/', devMode: true),
  devMode: true, // file watching in dev
);

Handler middleware(Handler handler) {
  return handler.use(provider<Trellis>((_) => _engine));
}
```

### Route Handler (Full Page)

```dart
// routes/index.dart
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';

Future<Response> onRequest(RequestContext context) async {
  final engine = context.read<Trellis>();
  final html = await engine.renderFile('index', {
    'title': 'Dashboard',
    'items': ['One', 'Two', 'Three'],
  });

  return Response(
    body: html,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}
```

### HTMX Partial Route

```dart
// routes/todos.dart
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';

final _todos = <String>['Write tests'];

Future<Response> onRequest(RequestContext context) async {
  final engine = context.read<Trellis>();
  final source = await engine.loader.load('todos.html');

  if (context.request.method == HttpMethod.post) {
    final form = Uri.splitQueryString(await context.request.body());
    final title = (form['title'] ?? '').trim();
    if (title.isNotEmpty) {
      _todos.add(title);
    }

    final html = engine.renderFragments(
      source,
      fragments: ['todoList', 'todoCount'],
      context: {'todos': List<String>.from(_todos)},
    );

    return Response(
      body: html,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  final html = engine.renderFragment(
    source,
    fragment: 'todoList',
    context: {'todos': List<String>.from(_todos)},
  );

  return Response(
    body: html,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}
```

## HTMX Patterns

### Fragment-per-endpoint
- Use one endpoint per fragment (`/todos/list`, `/todos/count`).
- Return `renderFragment(source, fragment: ..., context: ...)`.

### OOB multi-target updates
- Return multiple fragments in one response via `renderFragments(...)`.
- Mark fragment roots in template with `hx-swap-oob="true"`.

### Full page vs partial content negotiation
- Detect `HX-Request` (`request.headers['hx-request'] == 'true'`).
- For HTMX requests: render fragment(s).
- For normal navigation: render full page.

## Error Handling

```dart
import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';

Future<Response> safeRender(
  Trellis engine,
  String template,
  Map<String, dynamic> context,
) async {
  try {
    final html = await engine.renderFile(template, context);
    return Response.ok(
      html,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  } on TemplateNotFoundException {
    return Response.notFound('Template not found: $template');
  } on TemplateException {
    return Response.internalServerError(body: 'Template rendering failed');
  }
}
```

## AOT Deployment Notes

- `AssetLoader` relies on `Isolate.resolvePackageUri` and works in JIT (`dart run`).
- For AOT deployments, prefer `FileSystemLoader` (or another loader that works in your deployment environment).
- If you need fallback lookup, compose loaders with `CompositeLoader` (for example filesystem first, then assets in development).
