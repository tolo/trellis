import 'dart:io';
import 'dart:typed_data';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

import 'serving_contract.dart';

Response suiteHandler(Request request) {
  final asset = trellisUiRespond(request.url.path, ifNoneMatch: request.headers['if-none-match']?.join(','));
  if (asset == null) return Response.notFound();
  final contentType = asset.headers['content-type'];
  return Response(
    asset.statusCode,
    headers: Headers.fromMap(asset.headers.map((k, v) => MapEntry(k, [v]))),
    // Relic takes Content-Type from the body and drops it from the headers.
    body: Body(
      bytes: Uint8List.fromList(asset.body),
      bodyType: contentType == null ? null : BodyType.fromContentType(ContentTypeHeader.parse(contentType)),
    ),
  );
}

void main() {
  // Over a real socket, because Relic frames Content-Type and Content-Length
  // at the adapter: the Response object alone does not show what is sent.
  late RelicServer server;
  late HttpClient client;
  setUpAll(() async {
    server = await (RelicApp()..get('/**', suiteHandler)).serve(port: 0);
    client = HttpClient();
  });
  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  test('serves the suite assets with validators', () async {
    await servingContract((path, headers) async {
      final request = await client.get('localhost', server.port, path);
      headers.forEach(request.headers.set);
      final response = await request.close();
      final served = <String, String>{};
      response.headers.forEach((name, values) => served[name] = values.join(','));
      return (status: response.statusCode, headers: served, body: await response.expand((chunk) => chunk).toList());
    });
  });
}
