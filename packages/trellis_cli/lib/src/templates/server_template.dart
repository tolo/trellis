import 'htmx_asset.dart';
import 'ui_scaffold_template.dart';

/// Generates the bin/server.dart content for a new Shelf + Trellis project.
///
/// Demonstrates the full middleware stack, HTMX counter endpoints, CSRF, and
/// dev-mode hot reload.
String serverTemplate(String projectName, {bool htmxCdn = false, bool ui = false}) =>
    '''
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dev/trellis_dev.dart';
import 'package:trellis_shelf/trellis_shelf.dart';
${ui ? uiImport : ''}
import 'package:$projectName/handlers.dart';

void main(List<String> args) async {
  // Dev mode: pass --dev flag or set DEV=true environment variable.
  // Enables file watching for live reload — templates auto-refresh in browser.
  final devMode = args.contains('--dev') ||
      Platform.environment['DEV'] == 'true';

  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path;
  final templatesDir = '\$scriptDir/templates';
  final staticDir = '\$scriptDir/static';

${ui ? "  if (devMode) materializeTrellisUi(Directory('\$scriptDir/$staticUiPreview'));\n\n" : ''}  // FileSystemLoader resolves template names relative to templatesDir.
  // devMode: true enables file watching — templates are re-read on change.
  final loader = FileSystemLoader(templatesDir, devMode: devMode);
  final engine = Trellis(loader: ${ui ? 'CompositeLoader([loader, TrellisUiLoader()])' : 'loader'}, devMode: devMode);

  // CSRF secret: use an environment variable in production.
  // WARNING: Change this default before deploying to production!
  final csrfSecret = Platform.environment['CSRF_SECRET'] ?? '$projectName-dev-secret';
  const csp = CspBuilder.strict(${htmxCdn ? '\n    scriptSrc: "\'self\' $htmxCdnOrigin",\n  ' : ''});

  final router = Router()
    ..get('/', (Request req) => indexPage(req))
    ..get('/about', (Request req) => aboutPage(req))
${ui ? "    ..get('/ui', uiPage)\n" : ''}    ..post('/counter/increment', (Request req) => incrementCounter(req))
    ..post('/counter/decrement', (Request req) => decrementCounter(req))
    ..post('/counter/reset', (Request req) => resetCounter(req));

  final staticHandler = createStaticHandler(
    staticDir,
    defaultDocument: 'index.html',
  );
  final cascade = Cascade().add(staticHandler).add(router.call);

  // Middleware pipeline — order matters:
  //
  // 1. logRequests()          — logs method, path, status, timing
  // 2. trellisSecurityHeaders — adds X-Content-Type-Options, X-Frame-Options,
  //                             CSP, etc. Outermost so all responses get headers.
  // 3. trellisEngine          — injects Trellis engine into request context;
  //                             handlers retrieve via getEngine(request).
  // 4. trellisCsrf            — double-submit cookie CSRF protection;
  //                             must be after trellisEngine since response
  //                             helpers need the engine from context.
  // 5. devMiddleware          — (dev only) routes /_dev/reload to SSE handler
  //                             and injects live-reload script into HTML.
  var pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(trellisSecurityHeaders(csp: csp))
      .addMiddleware(trellisEngine(engine))
      .addMiddleware(trellisCsrf(secret: csrfSecret));

  if (devMode) {
    pipeline = pipeline.addMiddleware(devMiddleware(loader, staticDirectory: staticDir));
  }

  final handler = pipeline.addHandler(${ui ? '_withUiAssets(cascade.handler)' : 'cascade.handler'});

  final server = await shelf_io.serve(handler, 'localhost', 8080);
  print('$projectName running at http://localhost:\${server.port}');
  if (devMode) {
    print('Dev mode enabled — live reload active.');
  }

  // Graceful shutdown: close file watcher and HTTP server on Ctrl+C.
  ProcessSignal.sigint.watch().listen((_) async {
${ui ? '    await loader.close();\n' : ''}    await engine.close();
    await server.close();
  });
}
${ui ? _uiAssetsMiddleware : ''}''';

const _uiAssetsMiddleware = '''

Handler _withUiAssets(Handler app) => (request) {
  final path = request.requestedUri.path;
  if (!path.startsWith('/trellis-ui/')) return app(request);
  if (request.method != 'GET' && request.method != 'HEAD') return Response.notFound('Not found');
  final asset = trellisUiRespond(path, ifNoneMatch: request.headers['if-none-match']);
  if (asset == null) return Response.notFound('Not found');
  return Response(asset.statusCode, headers: asset.headers, body: asset.body);
};
''';
