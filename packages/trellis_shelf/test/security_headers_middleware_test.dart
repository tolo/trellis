import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() {
  group('CspBuilder', () {
    test('default output contains all standard directives', () {
      final csp = const CspBuilder().build();
      expect(csp, contains("default-src 'self'"));
      expect(csp, contains("script-src 'self'"));
      expect(csp, contains("style-src 'self' 'unsafe-inline'"));
      expect(csp, contains("img-src 'self' data:"));
      expect(csp, contains("object-src 'none'"));
      expect(csp, contains("frame-ancestors 'none'"));
      expect(csp, contains("base-uri 'self'"));
      expect(csp, contains("form-action 'self'"));
    });

    test('omits connect-src and font-src by default', () {
      final csp = const CspBuilder().build();
      expect(csp, isNot(contains('connect-src')));
      expect(csp, isNot(contains('font-src')));
    });

    test('custom overrides replace defaults', () {
      final csp = const CspBuilder(scriptSrc: "'self' 'unsafe-inline'", connectSrc: "'self' ws:").build();
      expect(csp, contains("script-src 'self' 'unsafe-inline'"));
      expect(csp, contains("connect-src 'self' ws:"));
    });

    test('null directives are omitted', () {
      final csp = const CspBuilder(objectSrc: null, frameAncestors: null).build();
      expect(csp, isNot(contains('object-src')));
      expect(csp, isNot(contains('frame-ancestors')));
    });

    test('custom directives are appended', () {
      final csp = const CspBuilder(custom: {'report-uri': '/csp-report'}).build();
      expect(csp, contains('report-uri /csp-report'));
    });

    test('directives are semicolon-separated', () {
      final csp = const CspBuilder().build();
      expect(csp, contains('; '));
    });
  });

  group('trellisSecurityHeaders middleware', () {
    Future<Response> handle(
      Request request, {
      String xContentTypeOptions = 'nosniff',
      String xFrameOptions = 'DENY',
      String referrerPolicy = 'strict-origin-when-cross-origin',
      String xXssProtection = '0',
      CspBuilder? csp,
      bool enableCsp = true,
    }) async {
      final handler = const Pipeline()
          .addMiddleware(
            trellisSecurityHeaders(
              xContentTypeOptions: xContentTypeOptions,
              xFrameOptions: xFrameOptions,
              referrerPolicy: referrerPolicy,
              xXssProtection: xXssProtection,
              csp: csp,
              enableCsp: enableCsp,
            ),
          )
          .addHandler((_) => Response.ok('ok'));

      return handler(request);
    }

    test('adds all default security headers', () async {
      final response = await handle(Request('GET', Uri.parse('http://localhost/')));
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(response.headers['x-frame-options'], 'DENY');
      expect(response.headers['referrer-policy'], 'strict-origin-when-cross-origin');
      expect(response.headers['x-xss-protection'], '0');
      expect(response.headers['content-security-policy'], isNotNull);
    });

    test('allows custom frame options', () async {
      final response = await handle(Request('GET', Uri.parse('http://localhost/')), xFrameOptions: 'SAMEORIGIN');
      expect(response.headers['x-frame-options'], 'SAMEORIGIN');
    });

    test('allows custom CSP builder', () async {
      final response = await handle(
        Request('GET', Uri.parse('http://localhost/')),
        csp: const CspBuilder(scriptSrc: "'self' 'unsafe-eval'"),
      );
      expect(response.headers['content-security-policy'], contains("script-src 'self' 'unsafe-eval'"));
    });

    test('omits CSP header when enableCsp is false', () async {
      final response = await handle(Request('GET', Uri.parse('http://localhost/')), enableCsp: false);
      expect(response.headers['content-security-policy'], isNull);
    });

    test('preserves response body and status', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisSecurityHeaders())
          .addHandler((_) => Response(201, body: 'created'));

      final response = await handler(Request('GET', Uri.parse('http://localhost/')));
      expect(response.statusCode, 201);
      expect(await response.readAsString(), 'created');
    });
  });
}
