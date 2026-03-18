import 'dart:io';

import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

import 'package:trellis_relic_example/handlers.dart';

Future<void> main() async {
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
  const csp = CspBuilder(scriptSrc: "'self' https://cdn.jsdelivr.net");

  final app = RelicApp()
    // Security headers middleware — applies to all matched routes.
    // Note: Relic middleware only fires for matched routes, so 404/405
    // responses do NOT get security headers. This is a behavioral
    // difference from Shelf.
    ..use('/', trellisSecurityHeaders(csp: csp))
    // Page routes
    ..get('/', (request) => homePage(request, engine))
    ..get('/about', (request) => aboutPage(request, engine))
    // Counter HTMX endpoints
    ..post('/counter/increment', (request) => incrementCounter(request, engine))
    ..post('/counter/decrement', (request) => decrementCounter(request, engine))
    ..post('/counter/reset', (request) => resetCounter(request, engine))
    // Static CSS — Relic has no built-in static file handler like shelf_static.
    // A dedicated route is the idiomatic approach for a small number of assets.
    ..get('/styles.css', (_) async {
      final css = await File('$staticDir/styles.css').readAsString();
      return Response.ok(body: Body.fromString(css, mimeType: MimeType.css));
    });

  await app.serve(address: InternetAddress.anyIPv4, port: 8080);
  print('Relic + Trellis example running at http://localhost:8080');
}
