import 'dart:async';
import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

Future<void> main(List<String> args) async {
  final root = args.single;
  final loader = FileSystemLoader('$root/templates', devMode: true);
  final stopping = Completer<void>();
  const page = '<!doctype html><html><body><h1>Café</h1></body></html>';
  final streamed = utf8.encode(page);
  final app = RelicApp()
    ..use('/', trellisSecurityHeaders(csp: const CspBuilder.strict()))
    ..get(
      '/',
      (_) => Response(
        202,
        headers: Headers.fromMap({
          'x-fixture': ['page'],
        }),
        body: Body.fromString(page, mimeType: MimeType.html, encoding: latin1),
      ),
    )
    ..get(
      '/document-charset',
      (_) => Response.ok(
        body: Body(
          bytes: latin1.encode('<!doctype html><meta charset="iso-8859-1"><body>Café</body>'),
          bodyType: BodyType(mimeType: MimeType.html),
        ),
      ),
    )
    ..get('/fragment', (_) => htmlResponse('<h1>Fragment</h1>'))
    ..get(
      '/stream',
      (_) => Response.ok(
        body: Body.fromDataStream(Stream.value(streamed), contentLength: streamed.length, mimeType: MimeType.html),
      ),
    )
    ..post('/stop', (_) async {
      await loader.close();
      stopping.complete();
      return Response.ok();
    });
  trellisDevReload(app, loader, staticDirectory: '$root/static');

  final server = await app.serve(port: 0);
  print(server.port);
  await stopping.future;
  await app.close();
}
