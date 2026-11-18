import '../htmx_asset.dart';
import '../ui_scaffold_template.dart';

/// Generates the bin/server.dart content for a Relic + Trellis project.
///
/// Uses regular string concatenation with \$ escaping for Dart interpolation
/// in generated code.
String relicServerTemplate(String projectName, {bool htmxCdn = false, bool ui = false}) =>
    "import 'dart:io';\n"
    '\n'
    "import 'package:relic/relic.dart';\n"
    "import 'package:trellis/trellis.dart';\n"
    "import 'package:trellis_relic/trellis_relic.dart';\n"
    '${ui ? uiImport : ''}'
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
    '    loader: ${ui ? 'CompositeLoader([FileSystemLoader(templatesDir, devMode: true), TrellisUiLoader()])' : 'FileSystemLoader(templatesDir, devMode: true)'},\n'
    '    devMode: true,\n'
    '  );\n'
    '  const csp = ${scaffoldStrictCsp(htmxCdn: htmxCdn, ui: ui, indent: '  ')};\n'
    '\n'
    '  final app = RelicApp()\n'
    '    // Security headers — applies to all matched routes.\n'
    "    ..use('/', trellisSecurityHeaders(csp: csp))\n"
    '    // Page routes\n'
    "    ..get('/', (request) => homePage(request, engine))\n"
    "    ..get('/about', (request) => aboutPage(request, engine))\n"
    '${ui ? "    ..get('/ui', (request) => uiPage(request, engine))\n    ..get('/trellis-ui/:asset', uiAsset)\n" : ''}'
    '    // Counter HTMX endpoints\n'
    "    ..post('/counter/increment', (request) => incrementCounter(request, engine))\n"
    "    ..post('/counter/decrement', (request) => decrementCounter(request, engine))\n"
    "    ..post('/counter/reset', (request) => resetCounter(request, engine))\n"
    "    // Static CSS — one file, so a plain route; Relic's StaticHandler suits a directory.\n"
    "    ..get('/styles.css', (_) async {\n"
    "      final css = await File('\$staticDir/styles.css').readAsString();\n"
    '      return Response.ok(body: Body.fromString(css, mimeType: MimeType.css));\n'
    '    })'
    '${htmxCdn ? '' : "\n    ..get('/js/htmx.min.js', (_) async {\n      final js = await File('\$staticDir/js/htmx.min.js').readAsString();\n      return Response.ok(body: Body.fromString(js, mimeType: MimeType.javascript));\n    })"}'
    ';\n'
    '\n'
    '  await app.serve(address: InternetAddress.anyIPv4, port: 8080);\n'
    "  print('$projectName running at http://localhost:8080');\n"
    '}\n';
