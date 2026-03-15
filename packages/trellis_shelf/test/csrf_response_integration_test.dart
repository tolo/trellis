import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() {
  group('CSRF + response helpers integration', () {
    late Trellis engine;
    late Handler handler;

    setUp(() {
      engine = Trellis(
        loader: MapLoader({
          'form':
              '<form>'
              '<input tl:attr="value=\${csrfToken}" name="_csrf" type="hidden">'
              '<span tl:text="\${msg}">placeholder</span>'
              '<div tl:fragment="result" tl:text="\${msg}">result</div>'
              '</form>',
        }),
      );

      handler = const Pipeline()
          .addMiddleware(trellisEngine(engine))
          .addMiddleware(trellisCsrf(secret: 'integration-secret'))
          .addHandler((request) async {
            if (request.method == 'GET') {
              return renderPage(request, 'form', {'msg': 'Hello'});
            }
            // POST — render fragment
            return renderFragment(request, 'form', 'result', {'msg': 'Submitted'});
          });
    });

    test('GET renders page with CSRF token in template', () async {
      final response = await handler(Request('GET', Uri.parse('http://localhost/')));
      expect(response.statusCode, 200);
      final body = await response.readAsString();
      // Token should be a 64-char hex string rendered in the hidden input
      expect(RegExp(r'value="[0-9a-f]{64}"').hasMatch(body), isTrue);
      expect(body, contains('Hello'));
    });

    test('GET -> extract token -> POST with valid token succeeds', () async {
      // Step 1: GET to obtain token
      final getResponse = await handler(Request('GET', Uri.parse('http://localhost/')));
      final setCookie = getResponse.headers['set-cookie']!;
      final cookieValue = setCookie.split(';').first.substring(setCookie.indexOf('=') + 1);
      final rawToken = cookieValue.split('.').first;

      // Step 2: POST with valid token
      final postResponse = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'content-type': 'application/x-www-form-urlencoded'},
          body: '_csrf=$rawToken',
        ),
      );
      expect(postResponse.statusCode, 200);
      final body = await postResponse.readAsString();
      expect(body, contains('Submitted'));
    });

    test('POST without token returns 403', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: 'msg=test',
        ),
      );
      expect(response.statusCode, 403);
    });

    test('HTMX POST with X-CSRF-Token header succeeds', () async {
      // GET to obtain token
      final getResponse = await handler(Request('GET', Uri.parse('http://localhost/')));
      final setCookie = getResponse.headers['set-cookie']!;
      final cookieValue = setCookie.split(';').first.substring(setCookie.indexOf('=') + 1);
      final rawToken = cookieValue.split('.').first;

      // HTMX POST with header token
      final postResponse = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'x-csrf-token': rawToken, 'hx-request': 'true'},
        ),
      );
      expect(postResponse.statusCode, 200);
    });
  });
}
