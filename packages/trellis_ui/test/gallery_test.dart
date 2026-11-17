import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

import '../tool/src/bundle.dart';
import '../tool/src/gallery.dart';

void main() {
  test('the index lists every page file and each page renders under the exact policy header', () async {
    final pages = Directory.systemTemp.createTempSync('suite_pages_');
    addTearDown(() => pages.deleteSync(recursive: true));
    for (final name in ['button', 'second']) {
      File(
        '${pages.path}/$name.html',
      ).writeAsStringSync('<h1>$name</h1><button tl:replace="~{trellis-ui/button :: button}">Example</button>');
    }
    final handler = galleryHandler(Directory.current, pages: pages);
    final index = await handler(Request('GET', Uri.parse('http://localhost/')));
    final text = await index.readAsString();
    for (final name in ['button', 'second']) {
      expect(text, contains('href="/components/$name"'));
      final response = await handler(Request('GET', Uri.parse('http://localhost/components/$name')));
      expect(response.statusCode, 200);
      expect(response.headers['content-security-policy'], galleryPolicy);
      final body = await response.readAsString();
      expect(body, contains('data-slot="button"'));
      expect(body, isNot(contains('tl:')));
      expect(body, contains('<h1>$name</h1>'));
    }
    for (final path in ['/not-found', '/static/not-found.js', '/trellis-ui/nope.css']) {
      final response = await handler(Request('GET', Uri.parse('http://localhost$path')));
      expect(response.statusCode, 404);
      expect(response.headers['content-security-policy'], galleryPolicy);
    }
  });

  test('the shell loads self-hosted htmx with indicator styles off', () async {
    final handler = galleryHandler(Directory.current);
    final response = await handler(Request('GET', Uri.parse('http://localhost/components/button')));
    final html = await response.readAsString();
    expect(html, contains('"allowEval":false'));
    expect(html, contains('"includeIndicatorStyles":false'));
    expect(html, contains('src="/static/htmx.min.js"'));
    expect(html, contains('href="/trellis-ui/htmx-indicator.css"'));
    final script = await handler(Request('GET', Uri.parse('http://localhost/static/htmx.min.js')));
    expect(script.statusCode, 200);
    expect(await script.readAsString(), contains('2.0.10'));
  });

  test('the first stdout line names the base URL', () async {
    final process = await Process.start('dart', [
      'run',
      'packages/trellis_ui/tool/gallery.dart',
      '--port',
      '0',
    ], workingDirectory: '../..');
    final errors = StringBuffer();
    final stderr = process.stderr.transform(utf8.decoder).listen(errors.write);
    try {
      final line = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 20));
      expect(line, matches(r'^Serving http://127\.0\.0\.1:\d+$'), reason: '$errors');
      final client = HttpClient();
      try {
        final base = Uri.parse(line.substring('Serving '.length));
        final response = await (await client.getUrl(base.resolve('/components/button'))).close();
        expect(response.statusCode, 200);
        expect(await utf8.decodeStream(response), contains('trellis-button-variant-default'));
        for (final asset in bundleAssets(Directory.current).entries) {
          final path = '/trellis-ui/${asset.key}';
          final response = await (await client.getUrl(base.resolve(path))).close();
          final bytes = await response.expand((chunk) => chunk).toList();
          final digest = sha256.convert(bytes);
          final content = trellisUiRespond(path)!;
          expect(response.statusCode, 200, reason: path);
          expect(bytes, orderedEquals(asset.value), reason: path);
          expect(bytes, orderedEquals(content.body), reason: path);
          expect(response.headers.value('etag'), '"$digest"', reason: path);
          expect(response.headers.value('etag'), content.headers['etag'], reason: path);
          print('${asset.key}: ${bytes.length} bytes, ETag "$digest"');
        }
      } finally {
        client.close();
      }
    } finally {
      process.kill();
      await process.exitCode;
      await stderr.cancel();
    }
  });
}
