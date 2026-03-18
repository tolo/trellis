import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

import 'test_utils.dart';

void main() {
  late Trellis engine;

  setUp(() {
    engine = Trellis(
      loader: MapLoader({
        'page':
            '<html><body>'
            '<h1 tl:text="\${title}">Title</h1>'
            '<div tl:fragment="content" tl:text="\${msg}">Content</div>'
            '</body></html>',
        'csrf-page': '<form><input name="_csrf" tl:attr="value=\${csrfToken}" type="hidden"></form>',
      }),
    );
  });

  Handler buildFullChain({bool includeCsrf = true}) {
    var pipeline = const Pipeline().addMiddleware(trellisProvider(engine)).addMiddleware(trellisSecurityHeaders());

    if (includeCsrf) {
      pipeline = pipeline.addMiddleware(trellisCsrf(secret: 'integration-secret'));
    }

    return pipeline.addHandler((context) => renderPage(context, 'page', {'title': 'Integration', 'msg': 'Test'}));
  }

  group('full middleware chain', () {
    test('GET renders HTML with security headers and CSRF cookie', () async {
      final response = await testGet(buildFullChain());

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(response.headers['x-frame-options'], 'DENY');
      expect(response.headers['set-cookie'], contains('__csrf='));
      expect(response.body, contains('Integration'));
      expect(response.body, contains('<html>'));
    });

    test('CSRF token appears in rendered template context', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisProvider(engine))
          .addMiddleware(trellisCsrf(secret: 'integration-secret'))
          .addHandler((context) => renderPage(context, 'csrf-page', {}));

      final response = await testGet(handler);
      // The 64-char hex CSRF token should appear as the input value.
      expect(response.body, matches(RegExp(r'value="[0-9a-f]{64}"')));
    });

    test('POST with valid CSRF token succeeds', () async {
      final middleware = trellisCsrf(secret: 'integration-secret');

      // Step 1: GET to obtain token and signed cookie.
      final getHandler = const Pipeline().addMiddleware(middleware).addHandler((_) async => Response(body: 'ok'));
      final getResponse = await testGet(getHandler);
      final cookieFull = getResponse.headers['set-cookie']!;
      final cookieValue = parseCookieValue(cookieFull, '__csrf')!;
      final rawToken = cookieValue.split('.').first;

      // Step 2: POST with valid token through the full chain.
      final postHandler = const Pipeline()
          .addMiddleware(trellisProvider(engine))
          .addMiddleware(trellisSecurityHeaders())
          .addMiddleware(middleware)
          .addHandler((context) => renderPage(context, 'page', {'title': 'T', 'msg': 'M'}));

      final postResponse = await testPost(
        postHandler,
        headers: {'cookie': '__csrf=$cookieValue', 'x-csrf-token': rawToken},
      );
      expect(postResponse.statusCode, 200);
      expect(postResponse.body, contains('M'));
    });

    test('POST without CSRF token returns 403', () async {
      final response = await testPost(buildFullChain());
      expect(response.statusCode, 403);
    });

    test('HTMX fragment rendering works through full chain', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisProvider(engine))
          .addMiddleware(trellisSecurityHeaders())
          .addHandler(
            (context) =>
                renderPage(context, 'page', {'title': 'T', 'msg': 'Fragment content'}, htmxFragment: 'content'),
          );

      final response = await testGet(handler, headers: {'hx-request': 'true'});
      expect(response.statusCode, 200);
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(response.body, contains('Fragment content'));
      expect(response.body, isNot(contains('<html>')));
    });

    test('GET without CSRF middleware succeeds with no CSRF cookie', () async {
      final response = await testGet(buildFullChain(includeCsrf: false));
      expect(response.statusCode, 200);
      expect(response.headers['set-cookie'], isNull);
    });
  });
}
