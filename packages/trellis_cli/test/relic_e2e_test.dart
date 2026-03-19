/// End-to-end integration test for the Relic starter template lifecycle.
///
/// Generates a Relic project via [RelicProjectGenerator], injects local
/// workspace dependency overrides, runs `dart pub get` and `dart analyze`,
/// boots the server, and smoke-tests the core routes.
///
/// Tagged [e2e] so that fast unit-test runs can exclude it:
///   dart test --exclude-tags=e2e
@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

import '_workspace_root.dart';

const _port = 19082;

void main() {
  group('Relic starter E2E', () {
    late Directory projectDir;
    Process? serverProcess;

    setUpAll(() async {
      final tempDir = await Directory.systemTemp.createTemp('trellis_relic_e2e_');
      const projectName = 'e2e_relic_app';
      final appDir = Directory('${tempDir.path}/$projectName');
      await appDir.create();

      final writer = DiskFileWriter(appDir.path);
      final generator = RelicProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();
      projectDir = appDir;

      final workspaceRoot = (await findWorkspaceRoot()).path;
      final pubspecFile = File('${projectDir.path}/pubspec.yaml');
      final pubspecContent = await pubspecFile.readAsString();
      final overrides =
          '''
dependency_overrides:
  trellis:
    path: $workspaceRoot/packages/trellis
  trellis_relic:
    path: $workspaceRoot/packages/trellis_relic
''';
      await pubspecFile.writeAsString(pubspecContent + overrides);

      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: projectDir.path);
      expect(pubGet.exitCode, 0, reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}');

      final analyze = await Process.run('dart', ['analyze', '--fatal-infos'], workingDirectory: projectDir.path);
      expect(analyze.exitCode, 0, reason: 'dart analyze failed:\n${analyze.stdout}\n${analyze.stderr}');

      final serverFile = File('${projectDir.path}/bin/server.dart');
      final serverContent = (await serverFile.readAsString()).replaceFirst('port: 8080', 'port: $_port');
      await serverFile.writeAsString(serverContent);

      serverProcess = await Process.start('dart', ['run', 'bin/server.dart'], workingDirectory: projectDir.path);
      final started = await _waitForServer('localhost', _port);
      expect(started, isTrue, reason: 'Relic server did not start within timeout');
    });

    tearDownAll(() async {
      serverProcess?.kill();
      await serverProcess?.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
      await projectDir.parent.delete(recursive: true);
    });

    test('pubspec.yaml exists and references relic', () {
      final pubspec = File('${projectDir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('relic:'));
      expect(pubspec, contains('trellis_relic:'));
    });

    test('GET / returns 200', () async {
      final res = await _get('http://localhost:$_port/');
      expect(res.statusCode, 200);
      expect(res.body, contains('<!DOCTYPE html>'));
    });

    test('GET /about returns 200', () async {
      final res = await _get('http://localhost:$_port/about');
      expect(res.statusCode, 200);
      expect(res.body, contains('About This App'));
      expect(res.body, contains('<!DOCTYPE html>'));
    });

    test('GET /about returns fragment for HTMX navigation', () async {
      final res = await _get('http://localhost:$_port/about', headers: {'HX-Request': 'true'});
      expect(res.statusCode, 200);
      expect(res.body, contains('About This App'));
      expect(res.body, isNot(contains('<!DOCTYPE html>')));
    });

    test('POST /counter/increment returns 200', () async {
      final res = await _post('http://localhost:$_port/counter/increment', body: '', headers: {'HX-Request': 'true'});
      expect(res.statusCode, 200);
      expect(res.body, contains('counter-value'));
      expect(res.body, contains('>1<'));
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}

typedef _Response = ({int statusCode, String body});

Future<bool> _waitForServer(String host, int port, {Duration timeout = const Duration(seconds: 15)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 300));
      await socket.close();
      return true;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }
  return false;
}

Future<_Response> _get(String url, {Map<String, String> headers = const {}}) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    headers.forEach(req.headers.set);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    return (statusCode: res.statusCode, body: body);
  } finally {
    client.close();
  }
}

Future<_Response> _post(String url, {required String body, Map<String, String> headers = const {}}) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final req = await client.postUrl(uri);
    headers.forEach(req.headers.set);
    req.write(body);
    final res = await req.close();
    final responseBody = await res.transform(utf8.decoder).join();
    return (statusCode: res.statusCode, body: responseBody);
  } finally {
    client.close();
  }
}
