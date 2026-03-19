/// Generates the lib/handlers.dart content for a new Shelf + Trellis project.
///
/// Demonstrates full-page rendering, HTMX fragment responses for SPA
/// navigation and counter updates, and automatic request-context merging via
/// `trellis_shelf`.
String handlersTemplate(String projectName) {
  return "import 'package:shelf/shelf.dart';\n"
      "import 'package:trellis_shelf/trellis_shelf.dart';\n"
      '\n'
      '// In-memory counter state. In a real app this would be request- or\n'
      '// session-scoped, or stored in a database.\n'
      'int _counter = 0;\n'
      '\n'
      'Map<String, dynamic> _counterContext() => {\n'
      "  'count': _counter,\n"
      "  'isZero': _counter == 0,\n"
      '};\n'
      '\n'
      'Map<String, dynamic> _homeContext() => {\n'
      "  'title': 'Home',\n"
      "  'pageTitle': 'Home — $projectName',\n"
      "  'appTitle': '$projectName',\n"
      '  ..._counterContext(),\n'
      '  \'features\': [\n'
      '    {\n'
      '      \'name\': \'Shelf pipeline\',\n'
      '      \'description\': \'Middleware composes logging, security headers, engine access, CSRF, and hot reload.\',\n'
      '    },\n'
      '    {\n'
      '      \'name\': \'HTMX fragments\',\n'
      '      \'description\': \'Navigation swaps page-content, while counter updates replace only the counter fragment.\',\n'
      '    },\n'
      '    {\n'
      '      \'name\': \'Template inheritance\',\n'
      '      \'description\': \'Base layout + child pages use tl:extends and tl:define for shared structure.\',\n'
      '    },\n'
      '    {\n'
      '      \'name\': \'Security defaults\',\n'
      '      \'description\': \'trellisSecurityHeaders() and trellisCsrf() protect the generated app out of the box.\',\n'
      '    },\n'
      '  ],\n'
      '};\n'
      '\n'
      '/// GET / — Home page with counter.\n'
      'Future<Response> indexPage(Request request) async {\n'
      '  return renderPage(\n'
      '    request,\n'
      "    'pages/index.html',\n"
      '    _homeContext(),\n'
      "    htmxFragment: 'page-content',\n"
      '  );\n'
      '}\n'
      '\n'
      '/// GET /about — About page.\n'
      'Future<Response> aboutPage(Request request) async {\n'
      '  return renderPage(\n'
      '    request,\n'
      "    'pages/about.html',\n"
      "    {'title': 'About', 'pageTitle': 'About — $projectName', 'appTitle': '$projectName'},\n"
      "    htmxFragment: 'page-content',\n"
      '  );\n'
      '}\n'
      '\n'
      '/// POST /counter/increment — Increment counter, return counter fragment.\n'
      'Future<Response> incrementCounter(Request request) async {\n'
      '  _counter++;\n'
      "  return renderFragment(request, 'pages/index.html', 'counter', _counterContext());\n"
      '}\n'
      '\n'
      '/// POST /counter/decrement — Decrement counter, return counter fragment.\n'
      'Future<Response> decrementCounter(Request request) async {\n'
      '  _counter--;\n'
      "  return renderFragment(request, 'pages/index.html', 'counter', _counterContext());\n"
      '}\n'
      '\n'
      '/// POST /counter/reset — Reset counter to zero, return counter fragment.\n'
      'Future<Response> resetCounter(Request request) async {\n'
      '  _counter = 0;\n'
      "  return renderFragment(request, 'pages/index.html', 'counter', _counterContext());\n"
      '}\n';
}
