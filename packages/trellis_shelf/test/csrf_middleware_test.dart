import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() {
  const secret = 'test-secret-key';

  Handler csrfPipeline({
    String cookieName = '__csrf',
    String fieldName = '_csrf',
    String headerName = 'X-CSRF-Token',
    List<String> excludedPaths = const [],
    Handler? inner,
  }) {
    return const Pipeline()
        .addMiddleware(
          trellisCsrf(
            secret: secret,
            cookieName: cookieName,
            fieldName: fieldName,
            headerName: headerName,
            excludedPaths: excludedPaths,
          ),
        )
        .addHandler(
          inner ??
              (request) {
                final token = csrfToken(request);
                return Response.ok('token=$token');
              },
        );
  }

  /// Extracts the raw token from a Set-Cookie header value.
  String extractRawToken(String setCookie, {String cookieName = '__csrf'}) {
    // Format: __csrf=<rawToken>.<hmac>; Path=/; HttpOnly; SameSite=Strict
    final value = setCookie.split(';').first; // __csrf=<rawToken>.<hmac>
    final afterEquals = value.substring(value.indexOf('=') + 1); // <rawToken>.<hmac>
    return afterEquals.split('.').first; // <rawToken>
  }

  group('CSRF token generation (safe methods)', () {
    test('GET sets Set-Cookie with signed token', () async {
      final handler = csrfPipeline();
      final response = await handler(Request('GET', Uri.parse('http://localhost/')));

      expect(response.statusCode, 200);
      final setCookie = response.headers['set-cookie'];
      expect(setCookie, isNotNull);
      expect(setCookie!, startsWith('__csrf='));
      expect(setCookie, contains('.'));
      expect(setCookie, contains('Path=/'));
      expect(setCookie, contains('HttpOnly'));
      expect(setCookie, contains('SameSite=Strict'));
    });

    test('GET stores raw token in request context', () async {
      final handler = csrfPipeline();
      final response = await handler(Request('GET', Uri.parse('http://localhost/')));
      final body = await response.readAsString();
      expect(body, startsWith('token='));
      final token = body.substring('token='.length);
      expect(token.length, 64); // 32 bytes hex-encoded
    });

    test('HEAD skips CSRF validation', () async {
      final handler = csrfPipeline();
      final response = await handler(Request('HEAD', Uri.parse('http://localhost/')));
      expect(response.statusCode, 200);
    });

    test('OPTIONS skips CSRF validation', () async {
      final handler = csrfPipeline();
      final response = await handler(Request('OPTIONS', Uri.parse('http://localhost/')));
      expect(response.statusCode, 200);
    });

    test('token is 64-character hex string', () async {
      final handler = csrfPipeline();
      final response = await handler(Request('GET', Uri.parse('http://localhost/')));
      final setCookie = response.headers['set-cookie']!;
      final rawToken = extractRawToken(setCookie);
      expect(rawToken.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(rawToken), isTrue);
    });
  });

  group('CSRF validation (state-changing methods)', () {
    /// Helper: GET to obtain a token, then POST with it.
    Future<(String rawToken, String cookieValue)> getToken(Handler handler) async {
      final getResponse = await handler(Request('GET', Uri.parse('http://localhost/')));
      final setCookie = getResponse.headers['set-cookie']!;
      final rawToken = extractRawToken(setCookie);
      final cookieValue = setCookie.split(';').first.substring('__csrf='.length);
      return (rawToken, cookieValue);
    }

    test('POST with valid form token succeeds', () async {
      final handler = csrfPipeline();
      final (rawToken, cookieValue) = await getToken(handler);

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'content-type': 'application/x-www-form-urlencoded'},
          body: '_csrf=$rawToken',
        ),
      );
      expect(response.statusCode, 200);
    });

    test('POST with valid header token succeeds', () async {
      final handler = csrfPipeline();
      final (rawToken, cookieValue) = await getToken(handler);

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'x-csrf-token': rawToken},
        ),
      );
      expect(response.statusCode, 200);
    });

    test('POST without cookie returns 403', () async {
      final handler = csrfPipeline();
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: '_csrf=fake-token',
        ),
      );
      expect(response.statusCode, 403);
      expect(await response.readAsString(), 'CSRF token mismatch');
    });

    test('POST without submitted token returns 403', () async {
      final handler = csrfPipeline();
      final (_, cookieValue) = await getToken(handler);

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'content-type': 'application/x-www-form-urlencoded'},
          body: '',
        ),
      );
      expect(response.statusCode, 403);
    });

    test('POST with wrong token returns 403', () async {
      final handler = csrfPipeline();
      final (_, cookieValue) = await getToken(handler);

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'content-type': 'application/x-www-form-urlencoded'},
          body: '_csrf=wrong-token-value',
        ),
      );
      expect(response.statusCode, 403);
    });

    test('POST with tampered cookie HMAC returns 403', () async {
      final handler = csrfPipeline();
      final (rawToken, _) = await getToken(handler);

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$rawToken.tampered-hmac', 'content-type': 'application/x-www-form-urlencoded'},
          body: '_csrf=$rawToken',
        ),
      );
      expect(response.statusCode, 403);
    });

    test('PUT validates CSRF', () async {
      final handler = csrfPipeline();
      final response = await handler(Request('PUT', Uri.parse('http://localhost/')));
      expect(response.statusCode, 403);
    });

    test('DELETE validates CSRF', () async {
      final handler = csrfPipeline();
      final response = await handler(Request('DELETE', Uri.parse('http://localhost/')));
      expect(response.statusCode, 403);
    });

    test('PATCH validates CSRF', () async {
      final handler = csrfPipeline();
      final response = await handler(Request('PATCH', Uri.parse('http://localhost/')));
      expect(response.statusCode, 403);
    });
  });

  group('configuration', () {
    test('custom cookie name', () async {
      final handler = csrfPipeline(cookieName: 'my_csrf');
      final response = await handler(Request('GET', Uri.parse('http://localhost/')));
      expect(response.headers['set-cookie'], startsWith('my_csrf='));
    });

    test('custom field name', () async {
      final handler = csrfPipeline(fieldName: 'my_token');

      // GET to obtain token
      final getResponse = await handler(Request('GET', Uri.parse('http://localhost/')));
      final setCookie = getResponse.headers['set-cookie']!;
      final rawToken = extractRawToken(setCookie);
      final cookieValue = setCookie.split(';').first.substring('__csrf='.length);

      // POST with custom field name
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'content-type': 'application/x-www-form-urlencoded'},
          body: 'my_token=$rawToken',
        ),
      );
      expect(response.statusCode, 200);
    });

    test('custom header name', () async {
      final handler = csrfPipeline(headerName: 'X-My-Token');

      final getResponse = await handler(Request('GET', Uri.parse('http://localhost/')));
      final setCookie = getResponse.headers['set-cookie']!;
      final rawToken = extractRawToken(setCookie);
      final cookieValue = setCookie.split(';').first.substring('__csrf='.length);

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'x-my-token': rawToken},
        ),
      );
      expect(response.statusCode, 200);
    });

    test('excluded paths bypass validation', () async {
      final handler = csrfPipeline(excludedPaths: ['/api/webhook']);

      final response = await handler(Request('POST', Uri.parse('http://localhost/api/webhook')));
      expect(response.statusCode, 200);
    });
  });

  group('token reuse on safe requests', () {
    test('GET reuses existing valid cookie instead of rotating', () async {
      final handler = csrfPipeline();

      // First GET — generates a new token
      final firstResponse = await handler(Request('GET', Uri.parse('http://localhost/')));
      final firstCookie = firstResponse.headers['set-cookie']!;
      final firstToken = extractRawToken(firstCookie);
      final firstCookieValue = firstCookie.split(';').first.substring('__csrf='.length);

      // Second GET with existing cookie — should reuse, no new Set-Cookie
      final secondResponse = await handler(
        Request('GET', Uri.parse('http://localhost/'), headers: {'cookie': '__csrf=$firstCookieValue'}),
      );

      expect(secondResponse.statusCode, 200);
      expect(secondResponse.headers['set-cookie'], isNull);

      // Token in context should be the same
      final body = await secondResponse.readAsString();
      expect(body, 'token=$firstToken');
    });

    test('GET generates new token when cookie has invalid HMAC', () async {
      final handler = csrfPipeline();

      final response = await handler(
        Request('GET', Uri.parse('http://localhost/'), headers: {'cookie': '__csrf=badtoken.badhash'}),
      );

      expect(response.statusCode, 200);
      expect(response.headers['set-cookie'], isNotNull);
      expect(response.headers['set-cookie']!, startsWith('__csrf='));
    });

    test('GET generates new token when no cookie present', () async {
      final handler = csrfPipeline();

      final response = await handler(Request('GET', Uri.parse('http://localhost/')));

      expect(response.statusCode, 200);
      expect(response.headers['set-cookie'], isNotNull);
    });

    test('page token remains valid after subsequent safe asset request', () async {
      final handler = csrfPipeline();

      // Initial page load
      final pageResponse = await handler(Request('GET', Uri.parse('http://localhost/')));
      final pageCookie = pageResponse.headers['set-cookie']!;
      final rawToken = extractRawToken(pageCookie);
      final cookieValue = pageCookie.split(';').first.substring('__csrf='.length);

      // Simulate asset request (e.g. CSS) — same cookie sent
      final assetResponse = await handler(
        Request('GET', Uri.parse('http://localhost/styles.css'), headers: {'cookie': '__csrf=$cookieValue'}),
      );
      // No cookie rotation — token should still be valid
      expect(assetResponse.headers['set-cookie'], isNull);

      // Form POST with the original page token — should succeed
      final postResponse = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'content-type': 'application/x-www-form-urlencoded'},
          body: '_csrf=$rawToken',
        ),
      );
      expect(postResponse.statusCode, 200);
    });
  });

  group('Set-Cookie preservation', () {
    test('preserves existing Set-Cookie headers from inner handlers', () async {
      final handler = csrfPipeline(
        inner: (request) {
          return Response.ok('ok', headers: {'set-cookie': 'session=abc123; Path=/'});
        },
      );

      final response = await handler(Request('GET', Uri.parse('http://localhost/')));
      expect(response.statusCode, 200);
      // Both the session cookie and CSRF cookie should be present
      final setCookie = response.headers['set-cookie']!;
      expect(setCookie, contains('session=abc123'));
      expect(setCookie, contains('__csrf='));
    });
  });

  group('body re-attachment', () {
    test('inner handler can read body after CSRF extraction', () async {
      String? receivedBody;
      final handler = const Pipeline().addMiddleware(trellisCsrf(secret: secret)).addHandler((request) async {
        receivedBody = await request.readAsString();
        return Response.ok('ok');
      });

      // Get token first
      final getResponse = await handler(Request('GET', Uri.parse('http://localhost/')));
      final setCookie = getResponse.headers['set-cookie']!;
      final rawToken = extractRawToken(setCookie);
      final cookieValue = setCookie.split(';').first.substring('__csrf='.length);

      final body = '_csrf=$rawToken&name=test';
      await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {'cookie': '__csrf=$cookieValue', 'content-type': 'application/x-www-form-urlencoded'},
          body: body,
        ),
      );

      expect(receivedBody, body);
    });
  });
}
