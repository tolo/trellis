/// Generates the routes/index.dart content for a Dart Frog + Trellis project.
///
/// Uses regular string with \$ escaping for Dart interpolation in generated code.
String dartFrogIndexRouteTemplate(String projectName) =>
    "import 'package:dart_frog/dart_frog.dart';\n"
    "import 'package:trellis_dart_frog/trellis_dart_frog.dart';\n"
    '\n'
    'Future<Response> onRequest(RequestContext context) async {\n'
    '  return renderPage(context, \'pages/index.html\', {\n'
    "    'title': 'Home',\n"
    "    'message': 'Welcome to $projectName!',\n"
    "    'features': [\n"
    "      {'name': 'File-based routing', 'description': 'Routes map to files in routes/'},\n"
    "      {'name': 'Natural HTML templates', 'description': 'Templates are valid HTML'},\n"
    "      {'name': 'HTMX integration', 'description': 'Dynamic updates without JavaScript frameworks'},\n"
    "      {'name': 'Hot reload', 'description': 'See template changes instantly'},\n"
    '    ],\n'
    '  });\n'
    '}\n';
