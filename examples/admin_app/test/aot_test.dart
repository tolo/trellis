@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

import 'fixtures.dart';

void main() {
  test('a compiled binary moved away from the repo serves suite assets and the pinned date recipe', () async {
    final deployment = await Directory.systemTemp.createTemp('trellis-admin-aot-');
    addTearDown(() => deployment.delete(recursive: true));
    final bin = await Directory('${deployment.path}/bin').create();
    final executable = '${bin.path}/server${Platform.isWindows ? '.exe' : ''}';
    final compiled = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      'bin/server.dart',
      '-o',
      executable,
    ]);
    expect(compiled.exitCode, 0, reason: '${compiled.stdout}\n${compiled.stderr}');
    await copyAppFiles(deployment);
    expect(Directory('${deployment.path}/.dart_tool').existsSync(), false);

    final process = await Process.start(executable, [], workingDirectory: deployment.path, environment: {'PORT': '0'});
    final errors = StringBuffer();
    final ready = Completer<Uri>();
    final stdout = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.startsWith('Serving ') && !ready.isCompleted) {
        ready.complete(Uri.parse(line.substring('Serving '.length)));
      }
    });
    final stderr = process.stderr.transform(utf8.decoder).listen(errors.write);
    addTearDown(() async {
      process.kill();
      await process.exitCode;
      await stdout.cancel();
      await stderr.cancel();
    });
    final base = await Future.any([
      ready.future,
      process.exitCode.then<Uri>((code) => throw StateError('AOT server exited $code: $errors')),
    ]).timeout(const Duration(seconds: 10));

    final page = await http.get(base);
    expect(page.statusCode, 200, reason: page.body);
    expectStrictPolicy(page.headers['content-security-policy']);
    final document = parse(page.body);
    expect(document.querySelectorAll('tr[data-contact-id]'), hasLength(8));
    expect(document.querySelector('script[type=module][src="$dateRecipeAsset"]'), isNotNull);
    for (final path in suiteAssets.keys) {
      final asset = await http.get(base.resolve(path));
      expect(asset.statusCode, 200, reason: path);
      final digest = sha256.convert(asset.bodyBytes);
      final embedded = trellisUiRespond(path)!;
      expect(asset.headers['etag'], embedded.headers['etag'], reason: path);
      expect(asset.headers['etag'], '"$digest"', reason: path);
    }
    final htmx = await http.get(base.resolve(htmxAsset));
    expect(htmx.statusCode, 200);
    expect(htmx.bodyBytes, File('static$htmxAsset').readAsBytesSync());
    for (final path in [dateRecipeAsset, callyAsset, callyLicense]) {
      final asset = await http.get(base.resolve(path));
      expect(asset.statusCode, 200, reason: path);
      expectStrictPolicy(asset.headers['content-security-policy']);
      expect(asset.bodyBytes, File('static$path').readAsBytesSync(), reason: path);
      if (path.endsWith('.js')) {
        expect(asset.headers['content-type'], contains('javascript'), reason: path);
      }
      if (path == callyAsset) {
        expect(sha256.convert(asset.bodyBytes).toString(), callySha256);
      } else if (path == dateRecipeAsset) {
        expect(asset.body, contains("import './cally-0.9.2.js'"));
      }
    }
    final created = await http.post(
      base.resolve('/contacts'),
      headers: mutationHeaders(page.headers['set-cookie']!, page.body),
      body: formBody(validContact),
    );
    expect(created.statusCode, 200, reason: created.body);
    final payload = parseFragment(created.body);
    expect(payload.querySelector('tr[data-contact-id="24"] td')?.text, 'A Aaron Example');
    expect(payload.querySelector('#toaster[hx-swap-oob]')?.text, contains('Contact created'));
    final persisted = await http.get(base.resolve('/contacts?q=aaron%40example.test'));
    expect(parse(persisted.body).querySelector('tr[data-contact-id="24"] td')?.text, 'A Aaron Example');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
