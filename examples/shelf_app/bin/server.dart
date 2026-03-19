import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dev/trellis_dev.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

import 'package:trellis_shelf_example/handlers.dart';

Future<void> main(List<String> args) async {
  final devMode = args.contains('--dev') || Platform.environment['DEV'] == 'true';
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path;
  final templatesDir = '$scriptDir/templates';
  final staticDir = '$scriptDir/static';

  final loader = FileSystemLoader(templatesDir, devMode: devMode);
  final engine = Trellis(loader: loader, devMode: devMode);
  final csrfSecret = Platform.environment['CSRF_SECRET'] ?? 'trellis_shelf_example-dev-secret';
  const csp = CspBuilder(scriptSrc: "'self' 'unsafe-inline' https://cdn.jsdelivr.net", connectSrc: "'self' ws:");

  final router = Router()
    ..get('/', indexPage)
    ..get('/about', aboutPage)
    ..post('/counter/increment', incrementCounter)
    ..post('/counter/decrement', decrementCounter)
    ..post('/counter/reset', resetCounter);

  final staticHandler = createStaticHandler(staticDir, defaultDocument: 'index.html');
  final cascade = Cascade().add(staticHandler).add(router.call);

  var pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(trellisSecurityHeaders(csp: csp))
      .addMiddleware(trellisEngine(engine))
      .addMiddleware(trellisCsrf(secret: csrfSecret));

  if (devMode) {
    pipeline = pipeline.addMiddleware(devMiddleware(loader));
  }

  final handler = pipeline.addHandler(cascade.handler);
  final server = await shelf_io.serve(handler, 'localhost', port);
  print('trellis_shelf_example running at http://localhost:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    await engine.close();
    await server.close();
  });
}
