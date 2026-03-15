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

### [basic/](basic/) -- API Demos

Self-contained examples showing core trellis features with inline templates.

```bash
cd example/basic
dart pub get
dart run bin/example.dart        # Template features: text, if, each, switch, fragments
dart run bin/shelf_example.dart  # Shelf integration pattern
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
cd example/todo_app
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
