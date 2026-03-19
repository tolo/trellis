/// Generates the lib/handlers.dart content for a Relic + Trellis project.
///
/// Demonstrates the no-DI pattern: engine is passed explicitly to each handler.
String relicHandlersTemplate(String projectName) =>
    "import 'package:relic/relic.dart';\n"
    "import 'package:trellis/trellis.dart';\n"
    "import 'package:trellis_relic/trellis_relic.dart';\n"
    '\n'
    '// In-memory counter state. In a real app this would be session-scoped\n'
    '// or stored in a database.\n'
    'int _counter = 0;\n'
    '\n'
    'Map<String, dynamic> _counterContext() => {\n'
    "  'count': _counter,\n"
    "  'isZero': _counter == 0,\n"
    '};\n'
    '\n'
    '/// GET / — Home page with counter.\n'
    '///\n'
    '/// Full page on direct request; page-content fragment only on HTMX navigation.\n'
    'Future<Response> homePage(Request request, Trellis engine) async {\n'
    '  final context = {\n'
    "    'title': 'Home',\n"
    "    'pageTitle': 'Home — $projectName',\n"
    "    'appTitle': '$projectName',\n"
    '    ..._counterContext(),\n'
    '  };\n'
    '\n'
    '  if (isHtmxRequest(request)) {\n'
    "    return renderFragment(request, engine, 'index.html', 'page-content', context);\n"
    '  }\n'
    '\n'
    "  return renderPage(request, engine, 'index.html', context);\n"
    '}\n'
    '\n'
    '/// GET /about — About page.\n'
    'Future<Response> aboutPage(Request request, Trellis engine) async {\n'
    "  final context = {'title': 'About', 'pageTitle': 'About — $projectName', 'appTitle': '$projectName'};\n"
    '\n'
    '  if (isHtmxRequest(request)) {\n'
    "    return renderFragment(request, engine, 'about.html', 'page-content', context);\n"
    '  }\n'
    '\n'
    "  return renderPage(request, engine, 'about.html', context);\n"
    '}\n'
    '\n'
    '/// POST /counter/increment — Increment counter, return counter fragment.\n'
    'Future<Response> incrementCounter(Request request, Trellis engine) async {\n'
    '  _counter++;\n'
    "  return renderFragment(request, engine, 'index.html', 'counter', _counterContext());\n"
    '}\n'
    '\n'
    '/// POST /counter/decrement — Decrement counter, return counter fragment.\n'
    'Future<Response> decrementCounter(Request request, Trellis engine) async {\n'
    '  _counter--;\n'
    "  return renderFragment(request, engine, 'index.html', 'counter', _counterContext());\n"
    '}\n'
    '\n'
    '/// POST /counter/reset — Reset counter to zero, return counter fragment.\n'
    'Future<Response> resetCounter(Request request, Trellis engine) async {\n'
    '  _counter = 0;\n'
    "  return renderFragment(request, engine, 'index.html', 'counter', _counterContext());\n"
    '}\n';
