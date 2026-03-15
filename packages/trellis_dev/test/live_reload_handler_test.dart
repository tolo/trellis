import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dev/trellis_dev.dart';

void main() {
  group('liveReloadHandler', () {
    test('throws StateError when loader.changes is null', () {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final loader = FileSystemLoader(dir.path, devMode: false);
      expect(
        () => liveReloadHandler(loader),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('devMode: true'))),
      );
    });

    test('returns a Handler', () {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final handler = liveReloadHandler(loader);
      expect(handler, isA<Handler>());
    });

    test('SSE response has correct content-type header', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final handler = liveReloadHandler(loader);
      final request = Request('GET', Uri.parse('http://localhost/_dev/reload'));
      final response = await handler(request);

      expect(response.headers['content-type'], equals('text/event-stream'));
    });

    test('SSE response has shelf.io.buffer_output set to false', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final handler = liveReloadHandler(loader);
      final request = Request('GET', Uri.parse('http://localhost/_dev/reload'));
      final response = await handler(request);

      expect(response.context['shelf.io.buffer_output'], isFalse);
    });

    test('emits SSE frame on file change', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final handler = liveReloadHandler(loader);
      final request = Request('GET', Uri.parse('http://localhost/_dev/reload'));
      final response = await handler(request);

      // Listen for the first SSE frame.
      final completer = Completer<String>();
      final subscription = response.read().listen((List<int> bytes) {
        if (!completer.isCompleted) {
          completer.complete(utf8.decode(bytes));
        }
      });

      // Trigger a file change.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      File('${dir.path}/test.html').writeAsStringSync('hello');

      final frame = await completer.future.timeout(const Duration(seconds: 5));
      expect(frame, equals('event: reload\ndata: reload\n\n'));

      await subscription.cancel();
    });

    test('emits multiple SSE frames for multiple changes', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final handler = liveReloadHandler(loader);
      final request = Request('GET', Uri.parse('http://localhost/_dev/reload'));
      final response = await handler(request);

      final frames = <String>[];
      final subscription = response.read().listen((List<int> bytes) {
        frames.add(utf8.decode(bytes));
      });

      await Future<void>.delayed(const Duration(milliseconds: 200));
      File('${dir.path}/a.html').writeAsStringSync('one');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      File('${dir.path}/b.html').writeAsStringSync('two');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(frames.length, greaterThanOrEqualTo(2));
      for (final frame in frames) {
        expect(frame, equals('event: reload\ndata: reload\n\n'));
      }

      await subscription.cancel();
    });

    test('multiple concurrent connections receive events independently', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final handler = liveReloadHandler(loader);

      final request1 = Request('GET', Uri.parse('http://localhost/_dev/reload'));
      final request2 = Request('GET', Uri.parse('http://localhost/_dev/reload'));
      final response1 = await handler(request1);
      final response2 = await handler(request2);

      final completer1 = Completer<String>();
      final completer2 = Completer<String>();

      final sub1 = response1.read().listen((List<int> bytes) {
        if (!completer1.isCompleted) completer1.complete(utf8.decode(bytes));
      });
      final sub2 = response2.read().listen((List<int> bytes) {
        if (!completer2.isCompleted) completer2.complete(utf8.decode(bytes));
      });

      await Future<void>.delayed(const Duration(milliseconds: 200));
      File('${dir.path}/test.html').writeAsStringSync('change');

      final frame1 = await completer1.future.timeout(const Duration(seconds: 5));
      final frame2 = await completer2.future.timeout(const Duration(seconds: 5));

      expect(frame1, equals('event: reload\ndata: reload\n\n'));
      expect(frame2, equals('event: reload\ndata: reload\n\n'));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('stream cleanup on cancel', () async {
      final dir = Directory.systemTemp.createTempSync('trellis_dev_test_');
      final loader = FileSystemLoader(dir.path, devMode: true);
      addTearDown(() async {
        await loader.close();
        dir.deleteSync(recursive: true);
      });

      final handler = liveReloadHandler(loader);
      final request = Request('GET', Uri.parse('http://localhost/_dev/reload'));
      final response = await handler(request);

      final subscription = response.read().listen((_) {});
      // Cancel should not throw.
      await subscription.cancel();
    });
  });
}
