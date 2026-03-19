# Trellis Examples

## Quick Start

```dart
import 'package:trellis/trellis.dart';

void main() {
  final engine = Trellis(loader: MapLoader({}));

  final html = engine.render(
    '<h1 tl:text="\${title}">Default</h1>',
    {'title': 'Hello, Trellis!'},
  );
  print(html); // <html><head></head><body><h1>Hello, Trellis!</h1></body></html>

  // Fragment rendering for HTMX partial responses
  const template = '''
  <ul tl:fragment="items">
    <li tl:each="item : \${items}" tl:text="\${item}">placeholder</li>
  </ul>
  ''';
  final fragment = engine.renderFragment(
    template,
    fragment: 'items',
    context: {'items': ['Alpha', 'Beta', 'Gamma']},
  );
  print(fragment); // <ul><li>Alpha</li><li>Beta</li><li>Gamma</li></ul>
}
```

## Examples

Commands below assume you're in the repository root.

### [shelf_app/](shelf_app/) -- Shelf + HTMX Starter App

A materialized version of the default `trellis create` starter for Shelf.
It demonstrates the same counter app used by the Dart Frog and Relic examples:
Home + About pages, HTMX SPA navigation, counter fragment updates, security
headers, CSRF protection, and optional dev-mode hot reload.

```bash
cd examples/shelf_app
dart pub get
dart run bin/server.dart
# Open http://localhost:8080
```

See [shelf_app/README.md](shelf_app/README.md) for the framework-specific notes.

### [dart_frog_app/](dart_frog_app/) -- Dart Frog + HTMX Starter App

A complete server-side rendered counter application demonstrating trellis with
[Dart Frog](https://dartfrog.vgv.dev/) and [HTMX](https://htmx.org).

Features demonstrated:
- File-based routing (`routes/` directory convention)
- `trellis_dart_frog` provider and middleware integration
- HTMX counter updates via fragment rendering
- CSRF protection with double-submit cookie pattern
- Template inheritance (`tl:extends` + `tl:define`)
- Security headers via `trellisSecurityHeaders()`
- Dev mode hot reload via `trellis_dev`

```bash
cd examples/dart_frog_app
dart pub get
dart_frog dev
# Open http://localhost:8080
```

### [todo_app/](todo_app/) -- Full Shelf + HTMX App

A complete server-side rendered todo application demonstrating trellis with
[Shelf](https://pub.dev/packages/shelf) and [HTMX](https://htmx.org).

Features demonstrated:
- External `.html` template files (natural templates)
- Fragment-first architecture for HTMX partial responses
- `tl:each`, `tl:if`, `tl:unless`, `tl:text`, `tl:attr`, `tl:classappend`, `tl:with`, `tl:insert`
- `renderFile()` for full pages, `renderFragment()` / `renderFragments()` for HTMX partials
- Custom filters (`date`, `capitalize`)
- In-memory data store with CRUD operations

```bash
cd examples/todo_app
dart pub get
dart run bin/server.dart
# Open http://localhost:8080
```

**Project structure**

```
todo_app/
├── bin/server.dart          # Shelf server, Trellis engine setup, route registration
├── lib/
│   ├── handlers.dart        # Route handlers — rendering logic and fragment strategy
│   ├── models.dart          # TodoList and Todo data models with toMap() for templates
│   └── store.dart           # In-memory CRUD store
├── templates/
│   └── app.html             # Single template file — full page + all named fragments
└── static/
    └── styles.css           # Application styles
```

**Key architectural concepts**

*Single template file* — `app.html` serves as both the full-page template and the
source of all named fragments (`sidebar`, `main-content`, `todo-list`, `todo-row`).
`renderFile()` renders the whole document; `renderFragments()` extracts specific
sections for HTMX partial responses. See the comment block at the top of `app.html`
for details, including how to split fragments across multiple files instead.

*Two render strategies* — handlers choose between two fragment combinations depending
on what changed. Todo CRUD operations return `todo-list` + OOB `sidebar` (counts
update, header stays). List navigation/mutation returns `main-content` + OOB `sidebar`
(full main area replaced including header). See `handlers.dart` for the rationale.

*OOB sidebar* — the sidebar carries `hx-swap-oob="true"`, so a single HTMX response
can update both the primary target and the sidebar counts simultaneously.

*`todoCount` as integer* — Trellis treats empty lists as truthy (unlike Thymeleaf),
so `tl:if="${todos}"` would never hide the empty state. `tl:if="${todoCount}"` (where
`0` is falsy) is the correct pattern for empty-collection guards in Trellis.

See [todo_app/README.md](todo_app/README.md) for setup notes and route/template pointers.

### [relic_app/](relic_app/) -- Relic + HTMX Starter App

A minimal Relic application showing explicit-engine wiring, template inheritance,
the same counter + Home/About flow, HTMX fragment responses, and Relic-specific
middleware behavior.

```bash
cd examples/relic_app
dart pub get
dart run bin/server.dart
# Open http://localhost:8080
```

See [relic_app/README.md](relic_app/README.md) for framework-specific notes.
