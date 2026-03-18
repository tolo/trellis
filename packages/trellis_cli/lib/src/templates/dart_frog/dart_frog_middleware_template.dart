/// Generates the routes/_middleware.dart content for a Dart Frog + Trellis project.
///
/// Uses regular string with \$ escaping for Dart interpolation in generated code.
String dartFrogMiddlewareTemplate(String projectName) =>
    "import 'dart:io';\n"
    '\n'
    "import 'package:dart_frog/dart_frog.dart';\n"
    "import 'package:trellis/trellis.dart';\n"
    "import 'package:trellis_dart_frog/trellis_dart_frog.dart';\n"
    "import 'package:trellis_dev/trellis_dev.dart';\n"
    '\n'
    '// Dev mode: set DEV=true environment variable.\n'
    '// Enables file watching for live template reload.\n'
    "final _devMode = Platform.environment['DEV'] == 'true';\n"
    '\n'
    "final _loader = FileSystemLoader('templates/', devMode: _devMode);\n"
    'final _engine = Trellis(loader: _loader, devMode: _devMode);\n'
    'const _csp = CspBuilder(\n'
    "  scriptSrc: \"'self' 'unsafe-inline' https://cdn.jsdelivr.net\",\n"
    ');\n'
    '\n'
    '// CSRF secret: use an environment variable in production.\n'
    '// WARNING: Change this default before deploying!\n'
    "final _csrfSecret = Platform.environment['CSRF_SECRET'] ?? '$projectName-dev-secret';\n"
    '\n'
    'Handler middleware(Handler handler) {\n'
    '  return handler\n'
    '      .use(trellisProvider(_engine))\n'
    '      .use(trellisSecurityHeaders(csp: _csp))\n'
    '      .use(trellisCsrf(secret: _csrfSecret))\n'
    '      .use(requestLogger())\n'
    // devMiddleware from trellis_dev is a Shelf middleware; adapt via fromShelfMiddleware
    '      .use(_devMode ? fromShelfMiddleware(devMiddleware(_loader)) : (h) => h);\n'
    '}\n';
