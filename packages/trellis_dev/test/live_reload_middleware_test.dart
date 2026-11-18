import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis_dev/trellis_dev.dart';

void main() {
  group('liveReloadMiddleware', () {
    late StreamController<void> changes;
    late Handler handler;

    setUp(() {
      changes = StreamController<void>.broadcast();
      handler = const Pipeline().addMiddleware(liveReloadMiddleware(changes.stream)).addHandler((request) {
        if (request.url.path == 'app.css') {
          return Response.ok('body{}</body>', headers: {'content-type': 'text/css'});
        }
        return Response.ok('<html><body><p>Hi</p></body></html>', headers: {'content-type': 'text/html'});
      });
    });

    tearDown(() async {
      if (!changes.isClosed) await changes.close();
    });

    Request get(String path) => Request('GET', Uri.parse('http://localhost$path'));

    test('injects the same-origin reload script before </body> in HTML', () async {
      final body = await (await handler(get('/'))).readAsString();
      expect(body, '<html><body><p>Hi</p><script src="/_dev/reload.js"></script>\n</body></html>');
    });

    test('leaves non-HTML responses untouched', () async {
      final body = await (await handler(get('/app.css'))).readAsString();
      expect(body, 'body{}</body>');
    });

    test('serves the client script pointing at the SSE path', () async {
      final response = await handler(get('/_dev/reload.js'));
      expect(response.headers['content-type'], 'application/javascript');
      expect(await response.readAsString(), contains("new EventSource('/_dev/reload')"));
    });

    test('sends one reload event per change, and closing the stream ends the connection', () async {
      final response = await handler(get('/_dev/reload'));
      expect(response.headers['content-type'], 'text/event-stream');
      final frames = response.read().transform(utf8.decoder).join();

      // Let the SSE subscription attach before emitting.
      await Future<void>.delayed(Duration.zero);
      changes
        ..add(null)
        ..add(null);
      await changes.close();

      final text = await frames.timeout(const Duration(seconds: 2));
      expect('event: reload'.allMatches(text), hasLength(2));
    });
  });
}
