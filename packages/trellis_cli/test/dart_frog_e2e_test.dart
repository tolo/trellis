/// End-to-end integration test for the Dart Frog starter template lifecycle.
///
/// Generates a Dart Frog project via [DartFrogProjectGenerator], injects local
/// workspace dependency overrides, runs `dart pub get` and `dart analyze`,
/// boots `dart_frog dev`, and smoke-tests the core routes.
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

const _port = 19081;
const _vmServicePort = 19181;

void main() {
  group('Dart Frog starter E2E', () {
    late Directory projectDir;
    Process? serverProcess;
    final outputBuffer = StringBuffer();

    setUpAll(() async {
      await _killListenersOnPort(_port);

      final tempDir = await Directory.systemTemp.createTemp('trellis_df_e2e_');
      const projectName = 'e2e_dart_frog_app';
      final appDir = Directory('${tempDir.path}/$projectName');
      await appDir.create();

      final writer = DiskFileWriter(appDir.path);
      final generator = DartFrogProjectGenerator(projectName: projectName, writer: writer);
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
  trellis_shelf:
    path: $workspaceRoot/packages/trellis_shelf
  trellis_dev:
    path: $workspaceRoot/packages/trellis_dev
  trellis_dart_frog:
    path: $workspaceRoot/packages/trellis_dart_frog
''';
      await pubspecFile.writeAsString(pubspecContent + overrides);

      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: projectDir.path);
      expect(pubGet.exitCode, 0, reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}');

      final analyze = await Process.run('dart', ['analyze', '--fatal-infos'], workingDirectory: projectDir.path);
      expect(analyze.exitCode, 0, reason: 'dart analyze failed:\n${analyze.stdout}\n${analyze.stderr}');

      final home = Platform.environment['HOME'];
      final dartFrogExecutable = home != null ? '$home/.pub-cache/bin/dart_frog' : 'dart_frog';

      if (!File(dartFrogExecutable).existsSync()) {
        final activate = await Process.run('dart', ['pub', 'global', 'activate', 'dart_frog_cli', '1.2.6']);
        expect(
          activate.exitCode,
          0,
          reason: 'dart_frog CLI activation failed:\n${activate.stdout}\n${activate.stderr}',
        );
      }

      serverProcess = await Process.start(dartFrogExecutable, [
        'dev',
        '--port',
        '$_port',
        '--dart-vm-service-port',
        '$_vmServicePort',
      ], workingDirectory: projectDir.path);
      serverProcess!.stdout.transform(utf8.decoder).listen(outputBuffer.write);
      serverProcess!.stderr.transform(utf8.decoder).listen(outputBuffer.write);

      final started = await _waitForHttpOk(
        'http://localhost:$_port/',
        timeout: const Duration(seconds: 45),
        bodyContains: 'Dart Frog',
      );
      expect(started, isTrue, reason: 'dart_frog dev did not become ready within timeout\n$outputBuffer');
    });

    tearDownAll(() async {
      serverProcess?.kill();
      await serverProcess?.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
      await _killListenersOnPort(_port);
      await projectDir.parent.delete(recursive: true);
    });

    test('pubspec.yaml exists and references dart_frog', () {
      final pubspec = File('${projectDir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('dart_frog:'));
      expect(pubspec, contains('trellis_dart_frog:'));
    });

    test('generated shared state lives under lib/', () {
      expect(File('${projectDir.path}/lib/counter_state.dart').existsSync(), isTrue);
      expect(File('${projectDir.path}/routes/counter/_state.dart').existsSync(), isFalse);
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

    test('POST /counter/increment with valid CSRF token returns 200', () async {
      final getRes = await _get('http://localhost:$_port/');
      expect(getRes.statusCode, 200);

      final cookieValue = _extractCsrfCookieValue(getRes.setCookieHeader);
      expect(cookieValue, isNotNull, reason: '__csrf cookie should be set on GET /');

      final rawToken = cookieValue!.split('.').first;
      final postRes = await _post(
        'http://localhost:$_port/counter/increment',
        body: '_csrf=$rawToken',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'HX-Request': 'true',
          'Cookie': '__csrf=$cookieValue',
        },
      );
      expect(postRes.statusCode, 200);
      expect(postRes.body, contains('counter-value'));
      expect(postRes.body, contains('>1<'));
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}

typedef _Response = ({int statusCode, String? setCookieHeader, String body});

Future<bool> _waitForHttpOk(String url, {Duration timeout = const Duration(seconds: 20), String? bodyContains}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final response = await _get(url);
      if (response.statusCode == 200 && (bodyContains == null || response.body.contains(bodyContains))) {
        return true;
      }
    } catch (_) {
      // Retry until timeout.
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
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
    final setCookie = res.headers['set-cookie']?.join(', ');
    return (statusCode: res.statusCode, setCookieHeader: setCookie, body: body);
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
    final setCookie = res.headers['set-cookie']?.join(', ');
    return (statusCode: res.statusCode, setCookieHeader: setCookie, body: responseBody);
  } finally {
    client.close();
  }
}

String? _extractCsrfCookieValue(String? setCookieHeader) {
  if (setCookieHeader == null) return null;
  for (final segment in setCookieHeader.split(',')) {
    final cookiePart = segment.trim().split(';').first.trim();
    if (cookiePart.startsWith('__csrf=')) {
      return cookiePart.substring('__csrf='.length);
    }
  }
  return null;
}

Future<void> _killListenersOnPort(int port) async {
  final result = await Process.run('lsof', ['-t', '-iTCP:$port', '-sTCP:LISTEN']);
  if (result.exitCode != 0) {
    return;
  }

  final pids = '${result.stdout}'.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toSet();

  for (final pid in pids) {
    await Process.run('kill', [pid]);
  }
}
