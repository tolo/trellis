import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

import 'serving_contract.dart';

Response suiteHandler(RequestContext context) {
  final asset = trellisUiRespond(context.request.uri.path, ifNoneMatch: context.request.headers['if-none-match']);
  if (asset == null) return Response(statusCode: 404);
  return Response.bytes(statusCode: asset.statusCode, headers: asset.headers, body: asset.body);
}

void main() {
  test('serves the suite assets with validators', () async {
    final server = await serve(suiteHandler, InternetAddress.loopbackIPv4, 0);
    try {
      await servingContract((path, headers) async {
        final response = await http.get(
          Uri(scheme: 'http', host: server.address.address, port: server.port, path: path),
          headers: headers,
        );
        return (status: response.statusCode, headers: response.headers, body: response.bodyBytes);
      });
    } finally {
      await server.close();
    }
  });
}
