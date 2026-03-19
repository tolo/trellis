/// Generates the routes/index.dart content for a Dart Frog + Trellis project.
String dartFrogIndexRouteTemplate(String projectName) =>
    "import 'package:dart_frog/dart_frog.dart';\n"
    "import 'package:$projectName/counter_state.dart';\n"
    "import 'package:trellis_dart_frog/trellis_dart_frog.dart';\n"
    '\n'
    'Future<Response> onRequest(RequestContext context) async {\n'
    '  return renderPage(\n'
    '    context,\n'
    "    'pages/index.html',\n"
    '    homeContext(),\n'
    "    htmxFragment: 'page-content',\n"
    '  );\n'
    '}\n';
