import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

class _BufferStdout implements Stdout {
  _BufferStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late Directory siteDir;

  setUp(() {
    siteDir = Directory.systemTemp.createTempSync('trellis_dev_cmd_');
  });

  tearDown(() {
    siteDir.deleteSync(recursive: true);
  });

  void writeFile(String relative, String content) {
    final file = File(p.join(siteDir.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  void writeHome(String title) => writeFile('content/_index.md', '---\ntitle: $title\n---\nHello.\n');

  /// A site deployed under `/sub/`, whose home page links to `/docs/`.
  void minimalSite() {
    writeFile('trellis_site.yaml', 'title: Test Site\nbaseUrl: https://example.com\npathPrefix: /sub/\n');
    writeHome('Home');
    const layout = '''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">Title</title></head>
<body><h1 tl:text="\${page.title}">Title</h1><a href="/docs/">Docs</a></body>
</html>
''';
    writeFile('layouts/_default/list.html', layout);
    writeFile('layouts/home.html', layout);
  }

  Future<int> freePort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  Future<({int status, String body})> get(int port, String path) async {
    final client = HttpClient();
    try {
      final response = await (await client.get('127.0.0.1', port, path)).close();
      return (status: response.statusCode, body: await response.transform(utf8.decoder).join());
    } finally {
      client.close(force: true);
    }
  }

  Future<void> until(FutureOr<bool> Function() condition, String what) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Starts `trellis dev` in [workingDirectory] with captured output, and waits until it serves.
  Future<({int port, StringBuffer out, StringBuffer err, Completer<void> stop, Future<int> run})> startDev(
    String workingDirectory,
  ) async {
    final port = await freePort();
    final stop = Completer<void>();
    final out = StringBuffer();
    final err = StringBuffer();
    final cli = TrellisCli(serveStopSignal: stop.future, workingDirectory: workingDirectory);
    final run = IOOverrides.runZoned(
      () => cli.run(['dev', '--port', '$port']),
      stdout: () => _BufferStdout(out),
      stderr: () => _BufferStdout(err),
    );
    // Stop and await the command even when an expectation fails, so its temp build directory is removed.
    addTearDown(() async {
      if (!stop.isCompleted) stop.complete();
      await run.timeout(const Duration(seconds: 10), onTimeout: () => -1);
    });
    await until(() => out.toString().contains('Serving http://localhost:$port'), 'the server to start\n$err');
    return (port: port, out: out, err: err, stop: stop, run: run);
  }

  group('DevCommand', () {
    test('--help exits 0', () async {
      expect(await TrellisCli(workingDirectory: siteDir.path).run(['dev', '--help']), 0);
    });

    test('invalid port exits 1', () async {
      minimalSite();
      expect(await TrellisCli(workingDirectory: siteDir.path).run(['dev', '--port', '0']), 1);
    });

    test('missing trellis_site.yaml exits 1', () async {
      expect(await TrellisCli(workingDirectory: siteDir.path).run(['dev']), 1);
    });

    test('serves a root-prefixed preview, rebuilds and reloads on change, keeps the last good build', () async {
      minimalSite();
      final (:port, :out, :err, :stop, :run) = await startDev(siteDir.path);

      final first = await get(port, '/');
      expect(first.status, 200);
      expect(first.body, contains('<h1>Home</h1>'));
      // pathPrefix /sub/ is cleared, so internal links work from the root.
      expect(first.body, contains('href="/docs/"'));
      expect(first.body, contains('<script src="/_dev/reload.js"></script>'));
      // The preview never touches the deployable output directory.
      expect(Directory(p.join(siteDir.path, 'output')).existsSync(), isFalse);

      final sse = HttpClient();
      addTearDown(() => sse.close(force: true));
      final events = StringBuffer();
      final sseResponse = await (await sse.get('127.0.0.1', port, '/_dev/reload')).close();
      sseResponse.transform(utf8.decoder).listen(events.write, onError: (_) {});
      await until(() => events.toString().contains(': connected'), 'the SSE connection');

      writeHome('Changed');
      await until(() => events.toString().contains('event: reload'), 'a reload event\n$err');
      expect((await get(port, '/')).body, contains('<h1>Changed</h1>'));

      // A broken edit fails the rebuild; the last good build stays served and no reload is sent.
      final reloadsBefore = 'event: reload'.allMatches(events.toString()).length;
      writeFile('content/_index.md', '---\ntitle: [unclosed\n---\n');
      await until(() => err.toString().contains('Still serving the last successful build.'), 'the failed rebuild');
      final afterFailure = await get(port, '/');
      expect(afterFailure.status, 200);
      expect(afterFailure.body, contains('<h1>Changed</h1>'));
      expect('event: reload'.allMatches(events.toString()).length, reloadsBefore);

      // Fixing the file recovers without a restart.
      writeHome('Fixed');
      await until(() async => (await get(port, '/')).body.contains('<h1>Fixed</h1>'), 'the recovered build\n$err');

      // Edits to the deployable output directory are not sources and trigger nothing.
      final rebuildsBefore = 'Change detected'.allMatches(out.toString()).length;
      writeFile('output/stray.html', '<p>stray</p>');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect('Change detected'.allMatches(out.toString()).length, rebuildsBefore);

      stop.complete();
      expect(await run.timeout(const Duration(seconds: 10)), 0);
    });

    test('rebuilds on edits to a theme reached through a symlink, as in a theme project example', () async {
      // Theme project layout: the theme at the root, its example site linking back via example/themes/<name>.
      final themeDir = siteDir;
      writeFile('theme.yaml', 'name: my_theme\nversion: 1.0.0\n');
      const layout = '<!DOCTYPE html><html><body><h1>Theme v1</h1></body></html>\n';
      writeFile('layouts/home.html', layout);
      writeFile('layouts/_default/list.html', layout);
      writeFile('example/trellis_site.yaml', 'title: Example\nbaseUrl: https://example.com\ntheme: my_theme\n');
      writeFile('example/content/_index.md', '---\ntitle: Home\n---\n');
      try {
        Link(p.join(themeDir.path, 'example', 'themes', 'my_theme')).createSync(themeDir.path, recursive: true);
      } on FileSystemException {
        markTestSkipped('symlink creation not permitted on this platform');
        return;
      }

      final (:port, :out, :err, :stop, :run) = await startDev(p.join(themeDir.path, 'example'));
      expect((await get(port, '/')).body, contains('<h1>Theme v1</h1>'));

      writeFile('layouts/home.html', layout.replaceFirst('v1', 'v2'));
      await until(() async => (await get(port, '/')).body.contains('<h1>Theme v2</h1>'), 'the theme rebuild\n$out$err');
    });

    for (final (stage, badConfig) in [
      ('reading the config', 'search:\n  output: 42\n'),
      ('building the site', 'feeds:\n  atom: true\nparams:\n  author: 42\n'),
    ]) {
      test('keeps serving and recovers after a type error $stage', () async {
        minimalSite();
        final (:port, :err, :out, stop: _, run: _) = await startDev(siteDir.path);

        writeFile('trellis_site.yaml', badConfig);
        await until(() => err.toString().contains('Still serving the last successful build.'), 'the failed rebuild');
        expect((await get(port, '/')).body, contains('<h1>Home</h1>'));

        minimalSite();
        writeHome('Recovered');
        await until(() async => (await get(port, '/')).body.contains('<h1>Recovered</h1>'), 'recovery\n$out$err');
      });
    }

    test('watches the new external theme and ignores the new output directory after a config edit', () async {
      minimalSite();
      for (final name in ['first', 'second']) {
        writeFile('$name/theme.yaml', 'name: $name\nversion: 1.0.0\n');
        writeFile('$name/layouts/home.html', '<html><body><h1>$name</h1></body></html>');
      }
      writeFile('example/content/_index.md', '---\ntitle: Home\n---\n');
      writeFile('example/trellis_site.yaml', 'theme: ../../first\n');
      final (:port, :out, :err, stop: _, run: _) = await startDev(p.join(siteDir.path, 'example'));
      expect((await get(port, '/')).body, contains('<h1>first</h1>'));

      writeFile('example/trellis_site.yaml', 'theme: ../../second\noutputDir: publish\n');
      await until(() async => (await get(port, '/')).body.contains('<h1>second</h1>'), 'the newly configured theme');
      writeFile('second/layouts/home.html', '<html><body><h1>Changed</h1></body></html>');
      await until(() async => (await get(port, '/')).body.contains('<h1>Changed</h1>'), 'the new theme edit\n$out$err');

      final rebuildsBefore = 'Change detected'.allMatches(out.toString()).length;
      writeFile('example/publish/stray.html', '<p>stray</p>');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect('Change detected'.allMatches(out.toString()).length, rebuildsBefore);
    });

    test('keeps watching sources when a config edit makes output overlap the site', () async {
      minimalSite();
      final (:port, :out, :err, stop: _, run: _) = await startDev(siteDir.path);

      writeFile('trellis_site.yaml', 'outputDir: .\n');
      await until(() => 'Built '.allMatches(out.toString()).length == 2, 'the config rebuild\n$out$err');
      minimalSite();
      writeHome('Recovered');
      await until(() async => (await get(port, '/')).body.contains('<h1>Recovered</h1>'), 'recovery\n$out$err');
    });
  });
}
