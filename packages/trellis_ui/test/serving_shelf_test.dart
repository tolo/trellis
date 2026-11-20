import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

import 'serving_contract.dart';

Response suiteHandler(Request request) {
  final asset = trellisUiRespond(request.requestedUri.path, ifNoneMatch: request.headers['if-none-match']);
  if (asset == null) return Response.notFound('Not found');
  return Response(asset.statusCode, headers: asset.headers, body: asset.body);
}

void main() {
  test('serves the suite assets with validators', () async {
    await servingContract((path, headers) async {
      final response = suiteHandler(Request('GET', Uri.parse('http://localhost$path'), headers: headers));
      return (
        status: response.statusCode,
        headers: response.headers,
        body: await response.read().expand((chunk) => chunk).toList(),
      );
    });
  });
}
