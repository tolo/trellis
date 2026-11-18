import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dev/trellis_dev.dart';

void main() {
  group('static reload', () {
    late Directory root;
    late FileSystemLoader loader;
    late Handler handler;
    late StreamIterator<String> frames;
    setUp(() async {
      root = Directory.systemTemp.createTempSync('trellis_static_reload_');
      final templates = Directory('${root.path}/templates')..createSync();
      Directory('${root.path}/static').createSync();
      loader = FileSystemLoader(templates.path, devMode: true);
      handler = devMiddleware(loader, staticDirectory: '${root.path}/static', validate: false)(
        (_) => Response.ok('app'),
      );
      final response = await handler(Request('GET', Uri.parse('http://localhost/_dev/reload')));
      frames = StreamIterator(
        response.read().transform(utf8.decoder).where((frame) => frame.contains('event: reload')),
      );
      addTearDown(() async {
        await frames.cancel();
        await loader.close();
        root.deleteSync(recursive: true);
      });
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    for (final extension in ['css', 'js']) {
      test('$extension write sends an SSE reload within 1 s', () async {
        final next = frames.moveNext();
        final watch = Stopwatch()..start();
        File('${root.path}/static/styles.$extension').writeAsStringSync('changed');
        expect(await next.timeout(const Duration(seconds: 1)), isTrue);
        expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
      });
    }
    test('unrelated files send no reload', () async {
      final next = frames.moveNext();
      File('${root.path}/static/readme.txt').writeAsStringSync('changed');
      expect(await next.timeout(const Duration(milliseconds: 500), onTimeout: () => false), isFalse);
    });
    test('nested and late-created directories reload', () async {
      final next = frames.moveNext();
      final nested = Directory('${root.path}/static/late/nested')..createSync(recursive: true);
      File('${nested.path}/app.js').writeAsStringSync('changed');
      expect(await next.timeout(const Duration(seconds: 1)), isTrue);
    });
    test('missing static directory still reloads templates', () async {
      final missing = devMiddleware(loader, staticDirectory: '${root.path}/absent', validate: false);
      final response = await missing((_) => Response.ok('app'))(
        Request('GET', Uri.parse('http://localhost/_dev/reload')),
      );
      final missingFrames = StreamIterator(
        response.read().transform(utf8.decoder).where((frame) => frame.contains('event: reload')),
      );
      addTearDown(missingFrames.cancel);
      final next = missingFrames.moveNext();
      File('${root.path}/templates/index.html').writeAsStringSync('<p>changed</p>');
      expect(await next.timeout(const Duration(seconds: 1)), isTrue);
      expect(missingFrames.current, contains('event: reload'));
    });
  });
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

    test('reload client injects same-origin script into HTML response', () async {
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
      expect(body, contains('<script src="/_dev/reload.js"></script>'));
      expect(body, isNot(contains('<script>')));
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

    test('reload client honours custom ssePath and scriptPath', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      const html = '<html><body><h1>Hello</h1></body></html>';
      final middleware = devMiddleware(loader, ssePath: '/my/reload', scriptPath: '/my/reload.js');
      final handler = middleware((_) => Response.ok(html, headers: {'content-type': 'text/html'}));
      final request = Request('GET', Uri.parse('http://localhost/page'));
      final response = await handler(request);

      final body = await response.readAsString();
      expect(body, contains('<script src="/my/reload.js"></script>'));
      final script = await handler(Request('GET', Uri.parse('http://localhost/my/reload.js')));
      expect(script.statusCode, 200);
      expect(script.headers['content-type'], contains('javascript'));
      final source = await script.readAsString();
      expect(source, liveReloadClientScript(ssePath: '/my/reload'));
      expect(source, contains("EventSource('/my/reload')"));
      expect(source, isNot(contains('<script')));
    });
  });
}
