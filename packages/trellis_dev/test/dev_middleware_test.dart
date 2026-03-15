import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dev/trellis_dev.dart';

void main() {
  group('devMiddleware', () {
    test('throws StateError when loader.changes is null', () {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final loader = FileSystemLoader(dir.path, devMode: false);
      expect(() => devMiddleware(loader), throwsA(isA<StateError>()));
    });

    test('routes SSE path to live reload handler', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final middleware = devMiddleware(loader);
      final handler = middleware((_) => Response.ok('app'));
      final request = Request('GET', Uri.parse('http://localhost/_dev/reload'));
      final response = await handler(request);

      expect(response.headers['content-type'], equals('text/event-stream'));
      expect(response.context['shelf.io.buffer_output'], isFalse);
    });

    test('forwards other paths to inner handler', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final middleware = devMiddleware(loader);
      final handler = middleware((_) => Response.ok('hello'));
      final request = Request('GET', Uri.parse('http://localhost/page'));
      final response = await handler(request);

      final body = await response.readAsString();
      expect(body, equals('hello'));
    });

    test('injects script into HTML response when injectScript is true', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      const html = '<html><body><h1>Hello</h1></body></html>';
      final middleware = devMiddleware(loader);
      final handler = middleware((_) => Response.ok(html, headers: {'content-type': 'text/html'}));
      final request = Request('GET', Uri.parse('http://localhost/page'));
      final response = await handler(request);

      final body = await response.readAsString();
      expect(body, contains('<script>'));
      expect(body, contains('EventSource'));
      expect(body, contains('</body>'));
    });

    test('does not inject script when injectScript is false', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      const html = '<html><body><h1>Hello</h1></body></html>';
      final middleware = devMiddleware(loader, injectScript: false);
      final handler = middleware((_) => Response.ok(html, headers: {'content-type': 'text/html'}));
      final request = Request('GET', Uri.parse('http://localhost/page'));
      final response = await handler(request);

      final body = await response.readAsString();
      expect(body, equals(html));
    });

    test('does not inject script into non-HTML responses', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final middleware = devMiddleware(loader);
      final handler = middleware((_) => Response.ok('{"key":"value"}', headers: {'content-type': 'application/json'}));
      final request = Request('GET', Uri.parse('http://localhost/api'));
      final response = await handler(request);

      final body = await response.readAsString();
      expect(body, equals('{"key":"value"}'));
    });

    test('does not inject into HTML without </body>', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      const html = '<html><h1>No body tag</h1></html>';
      final middleware = devMiddleware(loader);
      final handler = middleware((_) => Response.ok(html, headers: {'content-type': 'text/html'}));
      final request = Request('GET', Uri.parse('http://localhost/page'));
      final response = await handler(request);

      final body = await response.readAsString();
      expect(body, isNot(contains('<script>')));
    });

    test('does not inject into streamed responses (null contentLength)', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      const html = '<html><body><h1>Streamed</h1></body></html>';
      final middleware = devMiddleware(loader);
      // Create a streamed response (contentLength will be null).
      final handler = middleware(
        (_) => Response.ok(Stream.value(utf8.encode(html)), headers: {'content-type': 'text/html'}),
      );
      final request = Request('GET', Uri.parse('http://localhost/page'));
      final response = await handler(request);

      final body = await response.readAsString();
      expect(body, equals(html));
      expect(body, isNot(contains('<script>')));
    });

    test('uses custom ssePath', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final middleware = devMiddleware(loader, ssePath: '/my/reload');
      final handler = middleware((_) => Response.ok('app'));

      // Custom path should route to SSE handler.
      final sseRequest = Request('GET', Uri.parse('http://localhost/my/reload'));
      final sseResponse = await handler(sseRequest);
      expect(sseResponse.headers['content-type'], equals('text/event-stream'));

      // Default path should forward to inner handler.
      final otherRequest = Request('GET', Uri.parse('http://localhost/_dev/reload'));
      final otherResponse = await handler(otherRequest);
      final body = await otherResponse.readAsString();
      expect(body, equals('app'));
    });

    test('injected script uses custom ssePath', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      const html = '<html><body><h1>Hello</h1></body></html>';
      final middleware = devMiddleware(loader, ssePath: '/my/reload');
      final handler = middleware((_) => Response.ok(html, headers: {'content-type': 'text/html'}));
      final request = Request('GET', Uri.parse('http://localhost/page'));
      final response = await handler(request);

      final body = await response.readAsString();
      expect(body, contains("EventSource('/my/reload')"));
    });
  });
}
