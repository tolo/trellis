import 'package:mocktail/mocktail.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:trellis_relic/trellis_relic.dart';

class MockRequest extends Mock implements Request {}

Request makeRequest() {
  final req = MockRequest();
  when(() => req.headers).thenReturn(Headers.empty());
  return req;
}

Handler okHandler(String body) => (request) async => Response(200, body: Body.fromString(body));

void main() {
  group('CspBuilder', () {
    test('default output contains all standard directives', () {
      final csp = CspBuilder().build();
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
      final csp = CspBuilder().build();
      expect(csp, isNot(contains('connect-src')));
      expect(csp, isNot(contains('font-src')));
    });

    test('custom overrides replace defaults', () {
      final defaultCsp = CspBuilder().build();
      final customCsp = CspBuilder(scriptSrc: "'self' cdn.example.com").build();
      // Default has "script-src 'self'"
      expect(defaultCsp, contains("script-src 'self'"));
      // Custom replaces it — the old value is gone, the new value is present
      expect(customCsp, contains("script-src 'self' cdn.example.com"));
      expect(customCsp, isNot(contains("script-src 'self';")));
      expect(customCsp, isNot(contains("script-src 'self' '")));
    });

    test('null directives are omitted', () {
      final csp = CspBuilder(
        objectSrc: null,
        frameAncestors: null,
      ).build();
      expect(csp, isNot(contains('object-src')));
      expect(csp, isNot(contains('frame-ancestors')));
    });

    test('optional connect-src and font-src are included when set', () {
      final csp = CspBuilder(
        connectSrc: "'self' ws:",
        fontSrc: "'self' data:",
      ).build();
      expect(csp, contains("connect-src 'self' ws:"));
      expect(csp, contains("font-src 'self' data:"));
    });

    test('custom directives are appended', () {
      final csp = CspBuilder(
        custom: {'report-uri': '/csp-report'},
      ).build();
      expect(csp, contains('report-uri /csp-report'));
    });

    test('directives are semicolon-separated', () {
      final csp = CspBuilder().build();
      expect(csp, contains('; '));
      // No trailing semicolon
      expect(csp, isNot(endsWith(';')));
    });

    test('all-null builder produces empty string', () {
      final csp = CspBuilder(
        defaultSrc: null,
        scriptSrc: null,
        styleSrc: null,
        imgSrc: null,
        objectSrc: null,
        frameAncestors: null,
        baseUri: null,
        formAction: null,
      ).build();
      expect(csp, isEmpty);
    });
  });

  group('trellisSecurityHeaders', () {
    test('adds X-Content-Type-Options: nosniff by default', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware(okHandler('ok'));
      final result = await handler(makeRequest()) as Response;
      expect(result.headers['X-Content-Type-Options']?.first, equals('nosniff'));
    });

    test('adds X-Frame-Options: DENY by default', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware(okHandler('ok'));
      final result = await handler(makeRequest()) as Response;
      expect(result.headers['X-Frame-Options']?.first, equals('DENY'));
    });

    test('adds Referrer-Policy: strict-origin-when-cross-origin by default', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware(okHandler('ok'));
      final result = await handler(makeRequest()) as Response;
      expect(
        result.headers['Referrer-Policy']?.first,
        equals('strict-origin-when-cross-origin'),
      );
    });

    test('adds X-XSS-Protection: 0 by default', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware(okHandler('ok'));
      final result = await handler(makeRequest()) as Response;
      expect(result.headers['X-XSS-Protection']?.first, equals('0'));
    });

    test('adds Content-Security-Policy by default', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware(okHandler('ok'));
      final result = await handler(makeRequest()) as Response;
      expect(result.headers['Content-Security-Policy'], isNotNull);
      expect(result.headers['Content-Security-Policy']?.first, contains("default-src 'self'"));
    });

    test('custom xFrameOptions override works', () async {
      final middleware = trellisSecurityHeaders(xFrameOptions: 'SAMEORIGIN');
      final handler = middleware(okHandler('ok'));
      final result = await handler(makeRequest()) as Response;
      expect(result.headers['X-Frame-Options']?.first, equals('SAMEORIGIN'));
    });

    test('custom CspBuilder override works', () async {
      final middleware = trellisSecurityHeaders(
        csp: CspBuilder(scriptSrc: "'self' 'unsafe-inline'"),
      );
      final handler = middleware(okHandler('ok'));
      final result = await handler(makeRequest()) as Response;
      expect(
        result.headers['Content-Security-Policy']?.first,
        contains("script-src 'self' 'unsafe-inline'"),
      );
    });

    test('enableCsp: false omits CSP header', () async {
      final middleware = trellisSecurityHeaders(enableCsp: false);
      final handler = middleware(okHandler('ok'));
      final result = await handler(makeRequest()) as Response;
      expect(result.headers['Content-Security-Policy'], isNull);
    });

    test('preserves response body and status code', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware((request) async => Response(201, body: Body.fromString('hello')));
      final result = await handler(makeRequest()) as Response;
      expect(result.statusCode, equals(201));
      expect(await result.readAsString(), equals('hello'));
    });

    test('all default security headers are present in one response', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware(okHandler('ok'));
      final result = await handler(makeRequest()) as Response;
      expect(result.headers['X-Content-Type-Options'], isNotNull);
      expect(result.headers['X-Frame-Options'], isNotNull);
      expect(result.headers['Referrer-Policy'], isNotNull);
      expect(result.headers['X-XSS-Protection'], isNotNull);
      expect(result.headers['Content-Security-Policy'], isNotNull);
    });
  });
}
