# Example

Minimal Trellis usage with an in-memory template:

```dart
import 'package:trellis/trellis.dart';

final engine = Trellis(
  loader: MapLoader({
    'greeting.html': '<h1 tl:text="${title}">Hello</h1>',
  }),
);

final html = await engine.renderFile('greeting.html', {
  'title': 'Hello Trellis',
});
```

This demonstrates:

- `MapLoader` for in-memory templates
- `renderFile()` with a named template
- `tl:text` data binding

Full example apps:

- Shelf starter app: https://github.com/tolo/trellis/tree/main/examples/shelf_app
- Dart Frog starter app: https://github.com/tolo/trellis/tree/main/examples/dart_frog_app
- Relic starter app: https://github.com/tolo/trellis/tree/main/examples/relic_app
- Full Shelf todo app: https://github.com/tolo/trellis/tree/main/examples/todo_app
