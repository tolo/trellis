import 'dart:io';

import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

import 'package:trellis_relic_example/handlers.dart';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  // Resolve directories relative to the script location.
  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path;
  final templatesDir = '$scriptDir/templates';
  final staticDir = '$scriptDir/static';

  // Engine is an application-level singleton — Relic has no DI/context
  // mechanism. Route handlers capture it via closure.
  final engine = Trellis(
    loader: FileSystemLoader(templatesDir, devMode: true),
    devMode: true,
  );
  // CSRF secret: use an environment variable in production.
  final csrfSecret =
      Platform.environment['CSRF_SECRET'] ?? 'trellis_relic_example-dev-secret';
  const csp = CspBuilder(scriptSrc: "'self' https://cdn.jsdelivr.net");

  final app = RelicApp()
    // Security headers middleware — applies to all matched routes.
    // Note: Relic middleware only fires for matched routes, so 404/405
    // responses do NOT get security headers. This is a behavioral
    // difference from Shelf.
    ..use('/', trellisSecurityHeaders(csp: csp))
    // Double-submit cookie CSRF check on POST/PUT/DELETE/PATCH; templates get
    // the token as csrfToken, and /js/csrf.js sends it on HTMX requests.
    ..use('/', trellisCsrf(secret: csrfSecret))
    // Page routes
    ..get('/', (request) => homePage(request, engine))
    ..get('/about', (request) => aboutPage(request, engine))
    // Counter HTMX endpoints
    ..post('/counter/increment', (request) => incrementCounter(request, engine))
    ..post('/counter/decrement', (request) => decrementCounter(request, engine))
    ..post('/counter/reset', (request) => resetCounter(request, engine))
    // Static files — two, so plain routes; Relic's StaticHandler suits a
    // directory of assets.
    ..get('/styles.css', (_) async {
      final css = await File('$staticDir/styles.css').readAsString();
      return Response.ok(body: Body.fromString(css, mimeType: MimeType.css));
    })
    ..get('/js/csrf.js', (_) async {
      final js = await File('$staticDir/js/csrf.js').readAsString();
      return Response.ok(
        body: Body.fromString(js, mimeType: MimeType.javascript),
      );
    });

  await app.serve(address: InternetAddress.anyIPv4, port: port);
  print('Relic + Trellis example running at http://localhost:$port');
}
