import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

import 'test_utils.dart';

Handler simpleHandler(Middleware middleware) {
  return const Pipeline().addMiddleware(middleware).addHandler((_) async => Response(body: 'ok'));
}

void main() {
  group('trellisSecurityHeaders', () {
    test('adds all default security headers', () async {
      final response = await testGet(simpleHandler(trellisSecurityHeaders()));
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(response.headers['x-frame-options'], 'DENY');
      expect(response.headers['referrer-policy'], 'strict-origin-when-cross-origin');
      expect(response.headers['x-xss-protection'], '0');
      expect(response.headers['content-security-policy'], isNotNull);
    });

    test('allows custom CSP configuration via CspBuilder', () async {
      final csp = CspBuilder(scriptSrc: "'self' 'nonce-abc123'");
      final response = await testGet(simpleHandler(trellisSecurityHeaders(csp: csp)));
      expect(response.headers['content-security-policy'], contains("'nonce-abc123'"));
    });

    test('omits CSP when enableCsp is false', () async {
      final response = await testGet(simpleHandler(trellisSecurityHeaders(enableCsp: false)));
      expect(response.headers['content-security-policy'], isNull);
    });

    test('allows custom header values', () async {
      final response = await testGet(simpleHandler(trellisSecurityHeaders(xFrameOptions: 'SAMEORIGIN')));
      expect(response.headers['x-frame-options'], 'SAMEORIGIN');
    });
  });

  group('trellisCsrf', () {
    test('sets CSRF cookie on GET request', () async {
      final response = await testGet(simpleHandler(trellisCsrf(secret: 'test-secret')));
      expect(response.headers['set-cookie'], contains('__csrf='));
    });

    test('cookie contains signed token in token.hmac format', () async {
      final response = await testGet(simpleHandler(trellisCsrf(secret: 'test-secret')));
      final cookieFull = response.headers['set-cookie']!;
      final cookieValue = parseCookieValue(cookieFull, '__csrf')!;
      expect(cookieValue, contains('.'));
      final parts = cookieValue.split('.');
      expect(parts.length, 2);
      expect(parts[0].length, 64); // 32 bytes hex = 64 chars
    });

    test('accepts POST with valid CSRF token in header', () async {
      final middleware = trellisCsrf(secret: 'test-secret');
      final handler = simpleHandler(middleware);

      // Step 1: GET to obtain token and cookie.
      final getResponse = await testGet(handler);
      final cookieFull = getResponse.headers['set-cookie']!;
      final cookieValue = parseCookieValue(cookieFull, '__csrf')!;
      final rawToken = cookieValue.split('.').first;

      // Step 2: POST with valid token.
      final postResponse = await testPost(
        handler,
        headers: {'cookie': '__csrf=$cookieValue', 'x-csrf-token': rawToken},
      );
      expect(postResponse.statusCode, 200);
      expect(postResponse.body, 'ok');
    });

    test('rejects POST with missing CSRF token (403)', () async {
      final response = await testPost(simpleHandler(trellisCsrf(secret: 'test-secret')));
      expect(response.statusCode, 403);
    });

    test('rejects POST with invalid CSRF token (403)', () async {
      final middleware = trellisCsrf(secret: 'test-secret');
      final handler = simpleHandler(middleware);

      final getResponse = await testGet(handler);
      final cookieFull = getResponse.headers['set-cookie']!;
      final cookieValue = parseCookieValue(cookieFull, '__csrf')!;

      final postResponse = await testPost(
        handler,
        headers: {'cookie': '__csrf=$cookieValue', 'x-csrf-token': 'invalid-token'},
      );
      expect(postResponse.statusCode, 403);
    });

    test('makes CSRF token available via csrfToken()', () async {
      final handler = const Pipeline().addMiddleware(trellisCsrf(secret: 'test-secret')).addHandler((context) async {
        final token = csrfToken(context);
        return Response(body: token ?? 'no-token');
      });

      final response = await testGet(handler);
      expect(response.body, isNot('no-token'));
      expect(response.body.length, 64); // 64-char hex string
    });

    test('reuses existing valid token on subsequent GET (no new cookie)', () async {
      final middleware = trellisCsrf(secret: 'test-secret');
      final handler = simpleHandler(middleware);

      // First GET — gets a cookie
      final firstResponse = await testGet(handler);
      final cookieFull = firstResponse.headers['set-cookie']!;
      final cookieValue = parseCookieValue(cookieFull, '__csrf')!;

      // Second GET with existing cookie — token should be reused (no new cookie)
      final secondResponse = await testGet(handler, headers: {'cookie': '__csrf=$cookieValue'});
      expect(secondResponse.statusCode, 200);
      // When reusing, no Set-Cookie is issued
      expect(secondResponse.headers['set-cookie'], isNull);
    });
  });

  group('middleware chain', () {
    test('security headers and CSRF middleware work together', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisSecurityHeaders())
          .addMiddleware(trellisCsrf(secret: 'chain-secret'))
          .addHandler((_) async => Response(body: 'ok'));

      final response = await testGet(handler);
      expect(response.statusCode, 200);
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(response.headers['set-cookie'], contains('__csrf='));
    });
  });
}
