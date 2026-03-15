// Example: Using trellis with Dart Shelf for server-side rendering.
//
// Prerequisites — add shelf to your pubspec.yaml:
//   dart pub add shelf shelf_io
//
// Run: dart run bin/shelf_example.dart
// Then open http://localhost:8080 in your browser.

import 'package:trellis/trellis.dart';

/// Page template demonstrating tl:text, tl:if, tl:each, tl:attr, and
/// tl:fragment for HTMX partial rendering.
const pageTemplate = '''
<html>
<head><title tl:text="\${title}">Default Title</title></head>
<body>
  <h1 tl:text="\${title}">Default Title</h1>

  <!-- Conditional: only show greeting when user is present -->
  <p tl:if="\${user}" tl:text="'Welcome, ' + \${user.name} + '!'">
    Welcome, Guest!
  </p>

  <!-- Iteration with status variables and attribute setting -->
  <ul tl:fragment="itemList">
    <li tl:each="item : \${items}"
        tl:text="\${item}"
        tl:attr="data-index=\${itemStat.index}"
        tl:class="\${itemStat.odd} ? 'odd' : 'even'">
      placeholder
    </li>
  </ul>
</body>
</html>
''';

void main() {
  // Create engine with in-memory templates (use FileSystemLoader for files).
  final engine = Trellis(loader: MapLoader({'page': pageTemplate}));

  final context = {
    'title': 'Trellis Demo',
    'user': {'name': 'Alice'},
    'items': ['Alpha', 'Beta', 'Gamma'],
  };

  // Full page render.
  final fullPage = engine.render(pageTemplate, context);
  print('=== Full Page ===');
  print(fullPage);

  // Fragment render — only the <ul> with tl:fragment="itemList".
  // Perfect for HTMX partial responses.
  final fragment = engine.renderFragment(
    pageTemplate,
    fragment: 'itemList',
    context: context,
  );
  print('\n=== Fragment (HTMX partial) ===');
  print(fragment);

  // --- Shelf integration (uncomment imports above to use) ---
  //
  // Response handler(Request request) {
  //   if (request.url.path == 'items') {
  //     // HTMX fragment endpoint
  //     final html = engine.renderFragment(
  //       pageTemplate,
  //       fragment: 'itemList',
  //       context: context,
  //     );
  //     return Response.ok(html, headers: {'content-type': 'text/html'});
  //   }
  //   // Full page render
  //   final html = engine.render(pageTemplate, context);
  //   return Response.ok(html, headers: {'content-type': 'text/html'});
  // }
  //
  // final server = await shelf_io.serve(handler, 'localhost', 8080);
  // print('Serving at http://${server.address.host}:${server.port}');
}
