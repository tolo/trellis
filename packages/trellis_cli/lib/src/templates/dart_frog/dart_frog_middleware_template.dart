import '../htmx_asset.dart';
import '../ui_scaffold_template.dart';

/// Generates the routes/_middleware.dart content for a Dart Frog + Trellis project.
///
/// Uses regular string with \$ escaping for Dart interpolation in generated code.
String dartFrogMiddlewareTemplate(String projectName, {bool htmxCdn = false, bool ui = false}) =>
    "import 'dart:io';\n"
    '\n'
    "import 'package:dart_frog/dart_frog.dart';\n"
    "import 'package:trellis/trellis.dart';\n"
    "import 'package:trellis_dart_frog/trellis_dart_frog.dart';\n"
    "import 'package:trellis_dev/trellis_dev.dart';\n"
    '${ui ? uiImport : ''}'
    '\n'
    '// Dev mode: set DEV=true environment variable.\n'
    '// Enables file watching for live template reload.\n'
    "final _devMode = Platform.environment['DEV'] == 'true';\n"
    '\n'
    "final _loader = FileSystemLoader('templates/', devMode: _devMode);\n"
    'final _engine = Trellis(loader: ${ui ? 'CompositeLoader([_loader, TrellisUiLoader()])' : '_loader'}, devMode: _devMode);\n'
    '${ui ? '' : 'const _csp = ${scaffoldStrictCsp(htmxCdn: htmxCdn, ui: false)};\n'}'
    '\n'
    '// CSRF secret: use an environment variable in production.\n'
    '// WARNING: Change this default before deploying!\n'
    "final _csrfSecret = Platform.environment['CSRF_SECRET'] ?? '$projectName-dev-secret';\n"
    '\n'
    'Handler middleware(Handler handler) {\n'
    '  return handler\n'
    '      .use(trellisProvider(_engine))\n'
    '${ui ? '' : '      .use(trellisSecurityHeaders(csp: _csp))\n'}'
    '      .use(trellisCsrf(secret: _csrfSecret))\n'
    '      .use(requestLogger())\n'
    // devMiddleware from trellis_dev is a Shelf middleware; adapt via fromShelfMiddleware
    '      .use(_devMode ? fromShelfMiddleware(devMiddleware(_loader, staticDirectory: \'public\')) : (h) => h);\n'
    '}\n';
