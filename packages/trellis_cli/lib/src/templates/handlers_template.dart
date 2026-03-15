/// Generates the lib/handlers.dart content for a new Trellis project.
///
/// Demonstrates `renderPage()` for full pages, `renderFragment()` for HTMX
/// partial responses, and `isHtmxRequest()` detection.
String handlersTemplate(String projectName) {
  // Use regular string with \$ escaping for Dart interpolation in generated code.
  return "import 'package:shelf/shelf.dart';\n"
      "import 'package:trellis_shelf/trellis_shelf.dart';\n"
      '\n'
      '/// GET / \u2014 Renders the index page.\n'
      '///\n'
      '/// renderPage() retrieves the Trellis engine from request context (injected by\n'
      '/// trellisEngine middleware) and automatically merges the CSRF token into the\n'
      '/// template context.\n'
      'Future<Response> indexPage(Request request) async {\n'
      '  final context = <String, dynamic>{\n'
      "    'title': '$projectName',\n"
      "    'message': 'Welcome to $projectName!',\n"
      "    'features': [\n"
      "      {'name': 'Natural HTML templates', 'description': 'Templates are valid HTML'},\n"
      "      {'name': 'Fragment-first design', 'description': 'Built for HTMX partial responses'},\n"
      "      {'name': 'Hot reload', 'description': 'See changes instantly during development'},\n"
      '    ],\n'
      '  };\n'
      '\n'
      "  return renderPage(request, 'pages/index.html', context);\n"
      '}\n'
      '\n'
      '/// POST /greet \u2014 HTMX endpoint that returns a greeting fragment.\n'
      '///\n'
      '/// Renders the greeting fragment from the index page template.\n'
      '/// User input is safely escaped by Trellis (tl:text).\n'
      '/// For non-HTMX requests, redirects to home.\n'
      'Future<Response> greet(Request request) async {\n'
      '  final body = await request.readAsString();\n'
      '  final params = Uri.splitQueryString(body);\n'
      "  final name = params['name']?.trim() ?? 'World';\n"
      '\n'
      '  if (isHtmxRequest(request)) {\n'
      "    return renderFragment(request, 'partials/htmx.html', 'greeting',\n"
      "        {'name': name});\n"
      '  }\n'
      '\n'
      '  // Non-HTMX fallback \u2014 redirect to home.\n'
      "  return Response.seeOther(Uri.parse('/'));\n"
      '}\n'
      '\n'
      '/// GET /status \u2014 HTMX endpoint demonstrating hx-get.\n'
      '///\n'
      '/// Returns a server status fragment (swapped into #status-result).\n'
      'Future<Response> status(Request request) async {\n'
      "  return renderFragment(request, 'partials/htmx.html', 'status',\n"
      "      {'uptime': DateTime.now().toIso8601String()});\n"
      '}\n';
}
