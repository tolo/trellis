import 'package:test/test.dart';
import 'package:trellis_relic/trellis_relic.dart';

void main() {
  group('htmlResponse', () {
    test('returns Response with status 200 by default', () {
      final response = htmlResponse('<h1>Hello</h1>');
      expect(response.statusCode, equals(200));
    });

    test('body contains the HTML string', () async {
      final response = htmlResponse('<h1>Hello</h1>');
      final bodyStr = await response.readAsString();
      expect(bodyStr, equals('<h1>Hello</h1>'));
    });

    test('has text/html content type', () {
      final response = htmlResponse('<p>Test</p>');
      expect(response.body.bodyType?.mimeType.primaryType, equals('text'));
      expect(response.body.bodyType?.mimeType.subType, equals('html'));
    });

    test('respects custom status code', () {
      final response = htmlResponse('Not Found', statusCode: 404);
      expect(response.statusCode, equals(404));
    });

    test('handles empty string body', () async {
      final response = htmlResponse('');
      final bodyStr = await response.readAsString();
      expect(bodyStr, isEmpty);
    });
  });
}
