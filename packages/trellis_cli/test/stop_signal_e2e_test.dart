/// `trellis dev` and `trellis serve`, run as real processes, shut down cleanly on SIGTERM (`kill`, a process manager,
/// an IDE stop button) and not only on Ctrl-C. Without a SIGTERM handler the VM dies before cleanup runs and
/// `trellis dev` leaves its `trellis_dev_*` build folder in the system temp dir.
@Tags(['e2e'])
@TestOn('!windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '_e2e_server.dart';
import '_workspace_root.dart';

void main() {
  late String entryPoint;
  late Directory root;

  setUpAll(() async {
    entryPoint = p.join((await findWorkspaceRoot()).path, 'packages', 'trellis_cli', 'bin', 'trellis.dart');
  });

  setUp(() {
    root = Directory.systemTemp.createTempSync('trellis_stop_signal_e2e_');
    addTearDown(() => root.deleteSync(recursive: true));
  });

  File write(String relative, String content) => File(p.join(root.path, relative))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  /// Boots `trellis <args> --port <port>` in [workingDirectory] with `TMPDIR` set to [tmpDir], waits for its
  /// `Serving` line, sends SIGTERM and expects exit code 0.
  Future<void> runUntilSigterm(List<String> args, {required String workingDirectory, required String tmpDir}) async {
    final booted = await bootServer(
      label: 'trellis ${args.first}',
      start: (port) => Process.start(
        Platform.resolvedExecutable,
        ['run', entryPoint, ...args, '--port', '$port'],
        workingDirectory: workingDirectory,
        environment: {'TMPDIR': tmpDir},
      ),
      isReady: _acceptsConnections,
    );
    addTearDown(() => stopServer(booted.process));

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!booted.output.toString().contains('Serving http://localhost:${booted.port}')) {
      if (DateTime.now().isAfter(deadline)) fail('No "Serving" line from trellis ${args.first}:\n${booted.output}');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    expect(booted.process.kill(ProcessSignal.sigterm), isTrue);
    final exitCode = await booted.process.exitCode.timeout(
      const Duration(seconds: 15),
      onTimeout: () => fail('trellis ${args.first} did not exit after SIGTERM:\n${booted.output}'),
    );
    expect(exitCode, 0, reason: 'trellis ${args.first} output:\n${booted.output}');
  }

  test('trellis dev stops on SIGTERM with exit code 0 and removes its temp build', () async {
    final site = Directory(p.join(root.path, 'site'))..createSync();
    final tmpDir = Directory(p.join(root.path, 'tmp'))..createSync();
    write('site/trellis_site.yaml', 'title: Test Site\nbaseUrl: https://example.com\n');
    write('site/content/_index.md', '---\ntitle: Home\n---\nHello.\n');
    const layout = '''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">Title</title></head>
<body><h1 tl:text="\${page.title}">Title</h1></body>
</html>
''';
    write('site/layouts/_default/list.html', layout);
    write('site/layouts/home.html', layout);

    await runUntilSigterm(['dev'], workingDirectory: site.path, tmpDir: tmpDir.path);

    final leftovers = tmpDir.listSync().map((e) => p.basename(e.path)).where((name) => name.startsWith('trellis_dev_'));
    expect(leftovers, isEmpty);
  });

  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    test('trellis dev cleans up after ${signal.name} during its initial build', () async {
      final site = Directory(p.join(root.path, 'site'))..createSync();
      final tmpDir = Directory(p.join(root.path, 'tmp'))..createSync();
      write('site/trellis_site.yaml', 'title: Test Site\nbaseUrl: https://example.com\n');
      write('site/content/_index.md', '---\ntitle: Home\n---\nHello.\n');
      write('site/layouts/home.html', '<!DOCTYPE html><html><body>Home</body></html>');
      final staticDir = Directory(p.join(site.path, 'static'))..createSync();
      // Leave time to deliver the signal before the initial build finishes.
      for (var i = 0; i < 1000; i++) {
        File(p.join(staticDir.path, '$i.txt')).writeAsStringSync('Preview asset');
      }

      final port = await allocateFreePort();
      final process = await Process.start(
        Platform.resolvedExecutable,
        ['run', entryPoint, 'dev', '--port', '$port'],
        workingDirectory: site.path,
        environment: {'TMPDIR': tmpDir.path},
      );
      addTearDown(() => stopServer(process));
      final errors = process.stderr.transform(utf8.decoder).join();
      final output = <String>[];
      final finished = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
        output.add(line);
        if (line == 'Building site...') process.kill(signal);
      });

      expect(await process.exitCode.timeout(const Duration(seconds: 30)), 0, reason: await errors);
      await finished;
      expect(output, contains('Building site...'));
      expect(output, isNot(contains(startsWith('Serving '))));
      expect(tmpDir.listSync().map((entry) => p.basename(entry.path)), isNot(contains(startsWith('trellis_dev_'))));
    });
  }

  test('trellis serve stops on SIGTERM with exit code 0', () async {
    final tmpDir = Directory(p.join(root.path, 'tmp'))..createSync();
    write('output/index.html', '<!DOCTYPE html><html><body>Built</body></html>');

    await runUntilSigterm(
      ['serve', '--output', p.join(root.path, 'output')],
      workingDirectory: root.path,
      tmpDir: tmpDir.path,
    );
  });
}

/// Polls until something accepts TCP connections on [port]. The first attempt includes `dart run` compiling the CLI.
Future<bool> _acceptsConnections(int port) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect(e2eLoopback, port, timeout: const Duration(milliseconds: 300));
      await socket.close();
      return true;
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
  return false;
}
