import 'package:mocktail/mocktail.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

class MockRequest extends Mock implements Request {}

Request makeRequest({Map<String, Iterable<String>>? headers}) {
  final req = MockRequest();
  final h = Headers.fromMap(headers ?? {});
  when(() => req.headers).thenReturn(h);
  return req;
}

const _pageTemplate = '''
<html>
  <body>
    <h1 tl:text="\${title}">Title</h1>
    <div tl:fragment="content" tl:text="\${msg}">Content</div>
  </body>
</html>
''';

void main() {
  late Trellis engine;

  setUp(() {
    engine = Trellis(loader: MapLoader({'page': _pageTemplate}));
  });

  group('security headers + renderPage integration', () {
    test('response has both security headers and rendered HTML content', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware(
        (request) => renderPage(request, engine, 'page', {'title': 'Hello', 'msg': 'World'}),
      );

      final result = await handler(makeRequest()) as Response;
      final body = await result.readAsString();

      // Security headers present
      expect(result.headers['X-Content-Type-Options']?.first, equals('nosniff'));
      expect(result.headers['X-Frame-Options']?.first, equals('DENY'));
      expect(result.headers['Content-Security-Policy'], isNotNull);

      // Rendered content present
      expect(body, contains('Hello'));
      expect(body, contains('<html'));
    });

    test('security headers do not alter status code or body', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware(
        (request) => renderPage(request, engine, 'page', {'title': 'T', 'msg': 'M'}),
      );

      final result = await handler(makeRequest()) as Response;
      expect(result.statusCode, equals(200));
      final body = await result.readAsString();
      expect(body, contains('T'));
    });
  });

  group('HTMX flow integration', () {
    test('non-HTMX request returns full page', () async {
      final req = makeRequest();
      final response = await renderPage(
        req,
        engine,
        'page',
        {'title': 'Page', 'msg': 'Msg'},
        htmxFragment: 'content',
      );
      final body = await response.readAsString();
      expect(body, contains('<html'));
      expect(body, contains('Page'));
    });

    test('HTMX request with htmxFragment returns fragment only', () async {
      final req = makeRequest(headers: {'HX-Request': ['true']});
      final response = await renderPage(
        req,
        engine,
        'page',
        {'title': 'Page', 'msg': 'FragmentContent'},
        htmxFragment: 'content',
      );
      final body = await response.readAsString();
      expect(body, contains('FragmentContent'));
      expect(body, isNot(contains('<html')));
    });

    test('HTMX request without htmxFragment returns full page', () async {
      final req = makeRequest(headers: {'HX-Request': ['true']});
      final response = await renderPage(
        req,
        engine,
        'page',
        {'title': 'Page', 'msg': 'Msg'},
      );
      final body = await response.readAsString();
      expect(body, contains('<html'));
    });

    test('security headers middleware + HTMX fragment response', () async {
      final middleware = trellisSecurityHeaders();
      final handler = middleware(
        (request) => renderPage(
          request,
          engine,
          'page',
          {'title': 'T', 'msg': 'HtmxContent'},
          htmxFragment: 'content',
        ),
      );

      final result = await handler(
        makeRequest(headers: {'HX-Request': ['true']}),
      ) as Response;
      final body = await result.readAsString();

      // Security headers present
      expect(result.headers['X-Content-Type-Options']?.first, equals('nosniff'));
      // Fragment rendered (no full page)
      expect(body, contains('HtmxContent'));
      expect(body, isNot(contains('<html')));
    });
  });
}
