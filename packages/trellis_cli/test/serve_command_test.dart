import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  late Directory tempDir;
  late String originalDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('trellis_serve_cmd_');
    originalDir = Directory.current.path;
    Directory.current = tempDir;
  });

  tearDown(() {
    Directory.current = originalDir;
    tempDir.deleteSync(recursive: true);
  });

  /// Creates a minimal output directory suitable for serving.
  Directory minimalOutput({String name = 'output'}) {
    final outDir = Directory(p.join(tempDir.path, name))..createSync();
    File(p.join(outDir.path, 'index.html')).writeAsStringSync('<html><body>Hello</body></html>');
    return outDir;
  }

  /// Finds a free port by binding to port 0 and returning the assigned port.
  Future<int> freePort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  group('ServeCommand', () {
    // T08: --help exits 0
    test('T08: --help exits 0', () async {
      final cli = TrellisCli();
      final result = await cli.run(['serve', '--help']);
      expect(result, 0);
    });

    // T09: non-existent output dir → exits 1, message contains "does not exist" and "trellis build"
    test('T09: non-existent output dir exits 1', () async {
      final cli = TrellisCli();
      final result = await cli.run(['serve', '--output', 'nonexistent_dir']);
      expect(result, 1);
    });

    // T10: invalid port (not a number) → exits 1
    test('T10: invalid port string exits 1', () async {
      minimalOutput();
      final cli = TrellisCli();
      final result = await cli.run(['serve', '--port', 'abc']);
      expect(result, 1);
    });

    // T11: port 0 → exits 1 (out of range)
    test('T11: port 0 exits 1', () async {
      minimalOutput();
      final cli = TrellisCli();
      final result = await cli.run(['serve', '--port', '0']);
      expect(result, 1);
    });

    // T12: port 65536 → exits 1 (out of range)
    test('T12: port 65536 exits 1', () async {
      minimalOutput();
      final cli = TrellisCli();
      final result = await cli.run(['serve', '--port', '65536']);
      expect(result, 1);
    });

    // T13: valid output dir + random port → server responds 200 to GET /
    test('T13: serves valid output dir on available port', () async {
      minimalOutput();
      final port = await freePort();
      final stopCompleter = Completer<void>();
      final cli = TrellisCli(serveStopSignal: stopCompleter.future);

      final serveFuture = cli.run(['serve', '--port', '$port']);

      // Give the server a moment to start
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final client = HttpClient();
      try {
        final request = await client.get('localhost', port, '/');
        final response = await request.close();
        expect(response.statusCode, 200);
      } finally {
        client.close(force: true);
        stopCompleter.complete();
      }

      final exitCode = await serveFuture;
      expect(exitCode, 0);
    });

    // T14: --port flag with specific port → server starts on that port
    test('T14: --port flag uses specified port', () async {
      minimalOutput();
      final port = await freePort();
      final stopCompleter = Completer<void>();
      final cli = TrellisCli(serveStopSignal: stopCompleter.future);

      final serveFuture = cli.run(['serve', '--port', '$port']);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      final client = HttpClient();
      try {
        final request = await client.get('localhost', port, '/');
        final response = await request.close();
        expect(response.statusCode, 200);
      } finally {
        client.close(force: true);
        stopCompleter.complete();
      }

      final exitCode = await serveFuture;
      expect(exitCode, 0);
    });

    // T15: clean URL — /about/ → output/about/index.html returns 200
    test('T15: clean URL /about/ serves about/index.html', () async {
      final outDir = minimalOutput();
      final aboutDir = Directory(p.join(outDir.path, 'about'))..createSync();
      File(p.join(aboutDir.path, 'index.html')).writeAsStringSync('<html><body>About</body></html>');
      final port = await freePort();
      final stopCompleter = Completer<void>();
      final cli = TrellisCli(serveStopSignal: stopCompleter.future);

      final serveFuture = cli.run(['serve', '--port', '$port']);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      final client = HttpClient();
      try {
        final request = await client.get('localhost', port, '/about/');
        final response = await request.close();
        expect(response.statusCode, 200);
      } finally {
        client.close(force: true);
        stopCompleter.complete();
      }

      final exitCode = await serveFuture;
      expect(exitCode, 0);
    });

    // -p shorthand
    test('short flag -p sets port', () async {
      minimalOutput();
      final port = await freePort();
      final stopCompleter = Completer<void>();
      final cli = TrellisCli(serveStopSignal: stopCompleter.future);

      final serveFuture = cli.run(['serve', '-p', '$port']);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      final client = HttpClient();
      try {
        final request = await client.get('localhost', port, '/');
        final response = await request.close();
        expect(response.statusCode, 200);
      } finally {
        client.close(force: true);
        stopCompleter.complete();
      }

      final exitCode = await serveFuture;
      expect(exitCode, 0);
    });
  });
}
