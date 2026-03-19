/// Generates the routes/about.dart content for a Dart Frog + Trellis project.
String dartFrogAboutRouteTemplate(String projectName) =>
    "import 'package:dart_frog/dart_frog.dart';\n"
    "import 'package:trellis_dart_frog/trellis_dart_frog.dart';\n"
    '\n'
    'Future<Response> onRequest(RequestContext context) async {\n'
    '  return renderPage(\n'
    '    context,\n'
    "    'pages/about.html',\n"
    "    {'title': 'About', 'pageTitle': 'About — $projectName', 'appTitle': '$projectName'},\n"
    "    htmxFragment: 'page-content',\n"
    '  );\n'
    '}\n';
