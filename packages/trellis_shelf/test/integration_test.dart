import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() {
  group('integration', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({'hello': '<p tl:text="\${name}">placeholder</p>'}));
    });

    test('full pipeline: security headers + engine injection + html response', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisSecurityHeaders())
          .addMiddleware(trellisEngine(engine))
          .addHandler((request) async {
            final eng = getEngine(request);
            final html = await eng.renderFile('hello', {'name': 'World'});
            return htmlResponse(html);
          });

      final response = await handler(Request('GET', Uri.parse('http://localhost/')));

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'text/html; charset=utf-8');
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(response.headers['content-security-policy'], isNotNull);
      expect(await response.readAsString(), contains('World'));
    });

    test('HTMX branch: renders fragment for HTMX requests', () async {
      final fullEngine = Trellis(
        loader: MapLoader({
          'page':
              '<html><body><div id="content" tl:fragment="content" tl:text="\${msg}">placeholder</div></body></html>',
        }),
      );

      final handler = const Pipeline().addMiddleware(trellisEngine(fullEngine)).addHandler((request) async {
        final eng = getEngine(request);
        if (isHtmxRequest(request)) {
          final target = htmxTarget(request);
          if (target != null) {
            final html = await eng.renderFileFragment('page', fragment: target, context: {'msg': 'partial'});
            return htmlResponse(html);
          }
        }
        final html = await eng.renderFile('page', {'msg': 'full page'});
        return htmlResponse(html);
      });

      // Full page request
      final fullResponse = await handler(Request('GET', Uri.parse('http://localhost/')));
      final fullBody = await fullResponse.readAsString();
      expect(fullBody, contains('full page'));
      expect(fullBody, contains('<html>'));

      // HTMX partial request
      final htmxResponse = await handler(
        Request('GET', Uri.parse('http://localhost/'), headers: {'hx-request': 'true', 'hx-target': 'content'}),
      );
      final htmxBody = await htmxResponse.readAsString();
      expect(htmxBody, contains('partial'));
    });
  });
}
