import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  test('Relic streams one event per template, CSS and nested JS edit and releases its watches', () async {
    final root = Directory.systemTemp.createTempSync('trellis_relic_reload_');
    addTearDown(() => root.deleteSync(recursive: true));
    final paths = ['templates/index.html', 'static/styles.css', 'static/js/app.js'];
    for (final path in paths) {
      File('${root.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync('original');
    }

    final library = await Isolate.resolvePackageUri(Uri.parse('package:trellis_relic/trellis_relic.dart'));
    final packageRoot = File.fromUri(library!).parent.parent;
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'test/fixtures/dev_reload_app.dart',
      root.path,
    ], workingDirectory: packageRoot.path);
    final stderr = process.stderr.transform(utf8.decoder).join();
    addTearDown(() async {
      process.kill();
      await process.exitCode;
    });
    final port = await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .map(int.tryParse)
        .firstWhere((port) => port != null, orElse: () => null)
        .timeout(const Duration(seconds: 15));
    if (port == null) fail('Relic fixture exited ${await process.exitCode}: ${await stderr}');
    final origin = Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: port);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    Future<HttpClientResponse> get(String path) async =>
        (await client.getUrl(origin.resolve(path))).close().timeout(const Duration(seconds: 3));

    final response = await get('/_dev/reload');
    expect(response.statusCode, 200, reason: 'The reload route is mounted on the real Relic application');
    expect(response.headers.contentType?.mimeType, 'text/event-stream');
    final frames = StreamIterator(
      response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) => line == ': connected' || line.startsWith('event: ') || line.startsWith('data: ')),
    );
    addTearDown(frames.cancel);
    Future<String> nextLine(String reason) async {
      expect(await frames.moveNext().timeout(const Duration(seconds: 3)), isTrue, reason: reason);
      return frames.current;
    }

    expect(await nextLine('The handshake arrives before any file edit'), ': connected');
    for (final path in paths) {
      File('${root.path}/$path').writeAsStringSync('\nchanged', mode: FileMode.append);
      expect(await nextLine(path), 'event: reload', reason: path);
      expect(await nextLine(path), 'data: reload', reason: path);
    }

    final script = await get('/_dev/reload.js');
    expect(script.statusCode, 200);
    expect(script.headers.contentType?.mimeType, 'text/javascript');
    expect(await script.transform(utf8.decoder).join(), contains("new EventSource('/_dev/reload')"));

    final page = await get('/');
    expect(page.statusCode, 202);
    expect(page.headers.value('x-fixture'), 'page');
    expect(page.headers.value('content-security-policy'), contains("script-src 'self'; style-src 'self'"));
    expect(page.headers.contentType?.charset, 'iso-8859-1');
    expect(
      await page.transform(latin1.decoder).join(),
      '<!doctype html><html><body><h1>Café</h1><script src="/_dev/reload.js"></script>\n</body></html>',
    );
    final documentCharset = await get('/document-charset');
    expect(documentCharset.statusCode, 200);
    expect(documentCharset.headers.contentType?.charset, isNull);
    expect(
      await documentCharset.transform(latin1.decoder).join(),
      '<!doctype html><meta charset="iso-8859-1"><body>Café<script src="/_dev/reload.js"></script>\n</body>',
    );
    expect(await (await get('/fragment')).transform(utf8.decoder).join(), '<h1>Fragment</h1>');
    expect(await (await get('/stream')).transform(utf8.decoder).join(), contains('<h1>Café</h1></body>'));

    final stop = await (await client.postUrl(origin.resolve('/stop'))).close();
    expect(stop.statusCode, 200);
    await stop.drain<void>();
    expect(
      await frames.moveNext().timeout(const Duration(seconds: 3)),
      isFalse,
      reason: 'Exactly one event per edit, then the same response closes with the loader',
    );
    final exit = await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('The fixture stayed alive after shutdown; a static file watch may have leaked.'),
    );
    expect(exit, 0, reason: await stderr);
  });
}
