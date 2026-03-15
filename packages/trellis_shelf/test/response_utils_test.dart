import 'package:test/test.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() {
  group('htmlResponse', () {
    test('returns 200 status by default', () {
      final response = htmlResponse('<h1>Hello</h1>');
      expect(response.statusCode, 200);
    });

    test('body matches input HTML', () async {
      final response = htmlResponse('<h1>Hello</h1>');
      expect(await response.readAsString(), '<h1>Hello</h1>');
    });

    test('sets content-type to text/html with utf-8 charset', () {
      final response = htmlResponse('<h1>Hello</h1>');
      expect(response.headers['content-type'], 'text/html; charset=utf-8');
    });

    test('supports custom status codes', () {
      expect(htmlResponse('Not Found', statusCode: 404).statusCode, 404);
      expect(htmlResponse('Error', statusCode: 500).statusCode, 500);
    });
  });
}
