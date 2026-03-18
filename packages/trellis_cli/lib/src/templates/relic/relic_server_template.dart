/// Generates the bin/server.dart content for a Relic + Trellis project.
///
/// Uses regular string concatenation with \$ escaping for Dart interpolation
/// in generated code.
String relicServerTemplate(String projectName) =>
    "import 'dart:io';\n"
    '\n'
    "import 'package:relic/relic.dart';\n"
    "import 'package:trellis/trellis.dart';\n"
    "import 'package:trellis_relic/trellis_relic.dart';\n"
    '\n'
    "import 'package:$projectName/handlers.dart';\n"
    '\n'
    'Future<void> main() async {\n'
    '  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path;\n'
    "  final templatesDir = '\$scriptDir/templates';\n"
    "  final staticDir = '\$scriptDir/static';\n"
    '\n'
    '  // Engine is an application-level singleton — Relic has no DI/context\n'
    '  // mechanism. Route handlers capture it via closure.\n'
    '  final engine = Trellis(\n'
    '    loader: FileSystemLoader(templatesDir, devMode: true),\n'
    '    devMode: true,\n'
    '  );\n'
    '  const csp = CspBuilder(\n'
    "    scriptSrc: \"'self' https://cdn.jsdelivr.net\",\n"
    '  );\n'
    '\n'
    '  final app = RelicApp()\n'
    '    // Security headers — applies to all matched routes.\n'
    "    ..use('/', trellisSecurityHeaders(csp: csp))\n"
    '    // Page routes\n'
    "    ..get('/', (request) => homePage(request, engine))\n"
    "    ..get('/about', (request) => aboutPage(request, engine))\n"
    '    // Counter HTMX endpoints\n'
    "    ..post('/counter/increment', (request) => incrementCounter(request, engine))\n"
    "    ..post('/counter/decrement', (request) => decrementCounter(request, engine))\n"
    "    ..post('/counter/reset', (request) => resetCounter(request, engine))\n"
    '    // Static CSS — Relic has no built-in static file handler.\n'
    "    ..get('/styles.css', (_) async {\n"
    "      final css = await File('\$staticDir/styles.css').readAsString();\n"
    '      return Response.ok(body: Body.fromString(css, mimeType: MimeType.css));\n'
    '    });\n'
    '\n'
    '  await app.serve(address: InternetAddress.anyIPv4, port: 8080);\n'
    "  print('$projectName running at http://localhost:8080');\n"
    '}\n';
