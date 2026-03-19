/// End-to-end integration test for the generated starter app lifecycle.
///
/// Generates a project via [ProjectGenerator], injects local workspace
/// dependency overrides, runs `dart pub get` and `dart analyze`, boots the
/// server, smoke-tests key routes, and verifies CSRF + XSS behaviour.
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

/// Port used for the generated app server; chosen to avoid collisions with 8080.
const _kPort = 19080;

void main() {
  group('Generated app E2E', () {
    late Directory projectDir;
    Process? serverProcess;

    setUpAll(() async {
      // ── 1. Generate project ────────────────────────────────────────────
      final tempDir = await Directory.systemTemp.createTemp('trellis_e2e_');
      const projectName = 'e2e_test_app';
      final appDir = Directory('${tempDir.path}/$projectName');
      await appDir.create();

      final writer = DiskFileWriter(appDir.path);
      final generator = ProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();
      projectDir = appDir;

      // ── 2. Inject dependency_overrides for local workspace packages ────
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
''';
      await pubspecFile.writeAsString(pubspecContent + overrides);

      // ── 3. Patch server port to avoid collision with default 8080 ──────
      final serverFile = File('${projectDir.path}/bin/server.dart');
      final serverContent = (await serverFile.readAsString()).replaceFirst(
        "await shelf_io.serve(handler, 'localhost', 8080)",
        "await shelf_io.serve(handler, 'localhost', $_kPort)",
      );
      await serverFile.writeAsString(serverContent);

      // ── 4. dart pub get ────────────────────────────────────────────────
      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: projectDir.path);
      expect(pubGet.exitCode, 0, reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}');

      // ── 5. dart analyze ────────────────────────────────────────────────
      final analyze = await Process.run('dart', ['analyze', '--fatal-infos'], workingDirectory: projectDir.path);
      expect(analyze.exitCode, 0, reason: 'dart analyze failed:\n${analyze.stdout}\n${analyze.stderr}');

      // ── 6. Boot server ─────────────────────────────────────────────────
      serverProcess = await Process.start('dart', ['run', 'bin/server.dart'], workingDirectory: projectDir.path);

      final started = await _waitForServer('localhost', _kPort);
      expect(started, isTrue, reason: 'Server did not start within timeout');
    });

    tearDownAll(() async {
      serverProcess?.kill();
      await serverProcess?.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
      await projectDir.parent.delete(recursive: true);
    });

    test('GET / returns 200', () async {
      final res = await _get('http://localhost:$_kPort/');
      expect(res.statusCode, 200);
    });

    test('GET /about returns 200', () async {
      final res = await _get('http://localhost:$_kPort/about');
      expect(res.statusCode, 200);
      expect(res.body, contains('About This App'));
      expect(res.body, contains('<!DOCTYPE html>'));
    });

    test('GET /about returns fragment for HTMX navigation', () async {
      final res = await _get('http://localhost:$_kPort/about', headers: {'HX-Request': 'true'});
      expect(res.statusCode, 200);
      expect(res.body, contains('About This App'));
      expect(res.body, isNot(contains('<!DOCTYPE html>')));
    });

    test('POST /counter/increment with valid CSRF token returns 200', () async {
      // Obtain a CSRF cookie from an initial GET.
      final getRes = await _get('http://localhost:$_kPort/');
      expect(getRes.statusCode, 200);

      final cookieValue = _extractCsrfCookieValue(getRes.setCookieHeader);
      expect(cookieValue, isNotNull, reason: '__csrf cookie should be set on GET /');

      // The cookie is `rawToken.hmac`; only rawToken goes in the form field.
      final rawToken = cookieValue!.split('.').first;

      final postRes = await _post(
        'http://localhost:$_kPort/counter/increment',
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

    test('POST /counter/increment without CSRF token returns 403', () async {
      final postRes = await _post(
        'http://localhost:$_kPort/counter/increment',
        body: '',
        headers: {'Content-Type': 'application/x-www-form-urlencoded', 'HX-Request': 'true'},
      );
      expect(postRes.statusCode, 403);
    });

    test('security headers include the generated CSP policy', () async {
      final uri = Uri.parse('http://localhost:$_kPort/');
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        expect(response.headers.value('content-security-policy'), contains('https://cdn.jsdelivr.net'));
      } finally {
        client.close();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}

typedef _Response = ({int statusCode, String? setCookieHeader, String body});

/// Polls [host]:[port] until a TCP connection succeeds or [timeout] elapses.
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

/// Issues an HTTP GET and returns status, Set-Cookie header, and body.
Future<_Response> _get(String url, {Map<String, String> headers = const {}}) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    headers.forEach(req.headers.set);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    // HttpHeaders returns List<String>? for multi-value headers; join for consistent handling.
    final setCookie = res.headers['set-cookie']?.join(', ');
    return (statusCode: res.statusCode, setCookieHeader: setCookie, body: body);
  } finally {
    client.close();
  }
}

/// Issues an HTTP POST and returns status, Set-Cookie header, and body.
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

/// Extracts the `__csrf` cookie value from a `Set-Cookie` header string.
///
/// The header may contain multiple cookies separated by commas. Returns the
/// value portion (everything after `__csrf=` up to the first `;`).
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
