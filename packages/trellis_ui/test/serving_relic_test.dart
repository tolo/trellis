import 'dart:typed_data';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

import 'serving_contract.dart';

Response suiteHandler(Request request) {
  final asset = trellisUiRespond(request.url.path, ifNoneMatch: request.headers['if-none-match']?.join(','));
  if (asset == null) return Response.notFound();
  return Response(
    asset.statusCode,
    headers: Headers.fromMap(asset.headers.map((k, v) => MapEntry(k, [v]))),
    body: Body.fromData(Uint8List.fromList(asset.body)),
  );
}

// Relic's public Request has no constructor; only the HTTP edge is represented
// here. The handler, response headers and body are the real framework objects.
class EdgeRequest implements Request {
  EdgeRequest(String path, Map<String, String> values)
    : url = Uri.parse('http://localhost$path'),
      headers = Headers.fromMap(values.map((k, v) => MapEntry(k, [v])));
  @override
  final Uri url;
  @override
  final Headers headers;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('serves the suite assets with validators', () async {
    await servingContract((path, headers) async {
      final response = suiteHandler(EdgeRequest(path, headers));
      return (
        status: response.statusCode,
        headers: response.headers.map((k, v) => MapEntry(k, v.join(','))),
        body: await response.body.read().expand((chunk) => chunk).toList(),
      );
    });
  });
}
