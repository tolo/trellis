/// End-to-end integration test for the Relic starter template lifecycle.
///
/// Generates a Relic project with the CLI, injects local
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

import '_csp_browser.dart';
import '_e2e_server.dart';
import '_ui_scaffold_e2e.dart';
import '_workspace_root.dart';

/// Numeric loopback host every client connects to; the Relic template binds `anyIPv4`, which covers it.
final String _host = e2eLoopback.address;

void main() {
  if (BrowserProbe.locateChrome() == null) requireChromeInCi('CSP browser proofs');
  testUiScaffold(UiScaffold.relic);
  group('Relic starter E2E', () {
    late Directory projectDir;
    late int port;
    late String originalServerSource;
    Process? serverProcess;

    setUpAll(() async {
      final tempDir = await Directory.systemTemp.createTemp('trellis_relic_e2e_');
      const projectName = 'e2e_relic_app';
      projectDir = Directory('${tempDir.path}/$projectName');
      final workspace = await findWorkspaceRoot();
      final cli = '${workspace.path}/packages/trellis_cli/bin/trellis.dart';
      final created = await Process.run(Platform.resolvedExecutable, [
        'run',
        cli,
        'create',
        projectName,
        '--template',
        'relic',
      ], workingDirectory: tempDir.path);
      expect(created.exitCode, 0, reason: 'trellis create failed:\n${created.stdout}\n${created.stderr}');

      final pubspecFile = File('${projectDir.path}/pubspec.yaml');
      await pubspecFile.writeAsString(workspaceDependencyOverrides(workspace), mode: FileMode.append);

      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: projectDir.path);
      expect(pubGet.exitCode, 0, reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}');

      final analyze = await Process.run('dart', ['analyze', '--fatal-infos'], workingDirectory: projectDir.path);
      expect(analyze.exitCode, 0, reason: 'dart analyze failed:\n${analyze.stdout}\n${analyze.stderr}');

      originalServerSource = await File('${projectDir.path}/bin/server.dart').readAsString();
      final booted = await _bootRelic(projectDir, originalServerSource);
      serverProcess = booted.process;
      port = booted.port;
    });

    tearDownAll(() async {
      await stopServer(serverProcess);
      await projectDir.parent.delete(recursive: true);
    });

    test('pubspec.yaml exists and references relic', () {
      final pubspec = File('${projectDir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('relic:'));
      expect(pubspec, contains('trellis_relic:'));
    });

    test('Relic reload startup modes', () async {
      final prod = Uri.parse('http://$_host:$port/');
      await _expectReloadRoutes(prod, enabled: false);

      for (final mode in ['--dev', 'DEV=true']) {
        final server = await _bootRelic(
          projectDir,
          originalServerSource,
          devFlag: mode == '--dev',
          devEnvironment: mode == 'DEV=true',
        );
        try {
          await _expectReloadRoutes(Uri.parse('http://$_host:${server.port}/'), enabled: true);
        } finally {
          await stopServer(server.process);
        }
      }
    });

    test('strict CSP pages and htmx interactions', () async {
      await expectStrictCspApp(Uri.parse('http://$_host:$port/'), csrf: true);
    }, skip: BrowserProbe.locateChrome() == null ? 'Chrome not installed' : false);

    test('Relic browser reloads CSS and JS under strict CSP', () async {
      final server = await _bootRelic(projectDir, originalServerSource, devFlag: true);
      addTearDown(() => stopServer(server.process));
      final base = Uri.parse('http://$_host:${server.port}/');
      await expectStrictCspApp(base, csrf: true);
      await expectBrowserReload(base, projectDir, assets: ['styles.css', 'js/csrf.js'], observeEvents: true);
      expect((await _get(base.resolve('/about').toString())).statusCode, 200, reason: 'Dev server stayed up');
    }, skip: BrowserProbe.locateChrome() == null ? 'Chrome not installed' : false);

    test('GET / returns 200', () async {
      final res = await _get('http://$_host:$port/');
      expect(res.statusCode, 200);
      expect(res.body, contains('<!DOCTYPE html>'));
    });

    test('GET /about returns 200', () async {
      final res = await _get('http://$_host:$port/about');
      expect(res.statusCode, 200);
      expect(res.body, contains('About This App'));
      expect(res.body, contains('<!DOCTYPE html>'));
    });

    test('GET /about returns fragment for HTMX navigation', () async {
      final res = await _get('http://$_host:$port/about', headers: {'HX-Request': 'true'});
      expect(res.statusCode, 200);
      expect(res.body, contains('About This App'));
      expect(res.body, isNot(contains('<!DOCTYPE html>')));
    });

    test('POST /counter/increment with valid CSRF token returns 200', () async {
      final getRes = await _get('http://$_host:$port/');
      final cookieValue = _extractCsrfCookieValue(getRes.setCookieHeader);
      expect(cookieValue, isNotNull, reason: '__csrf cookie should be set on GET /');
      // The cookie is `rawToken.hmac`; only rawToken goes in the form field.
      final rawToken = cookieValue!.split('.').first;
      expect(getRes.body, contains('<meta name="csrf-token" content="$rawToken">'));

      final postRes = await _post(
        'http://$_host:$port/counter/increment',
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
        'http://$_host:$port/counter/increment',
        body: '',
        headers: {'Content-Type': 'application/x-www-form-urlencoded', 'HX-Request': 'true'},
      );
      expect(postRes.statusCode, 403);
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<BootedServer> _bootRelic(Directory project, String source, {bool devFlag = false, bool devEnvironment = false}) {
  final entryPoint = File('${project.path}/bin/server.dart');
  final environment = Map.of(Platform.environment)..remove('DEV');
  if (devEnvironment) environment['DEV'] = 'true';
  return bootServer(
    label: 'Relic server',
    start: (port) async {
      // Always patch the pristine source so retries never keep a previous port.
      final patched = source.replaceFirst('port: 8080', 'port: $port');
      expect(patched, isNot(source), reason: 'Relic bind-patch pattern');
      await entryPoint.writeAsString(patched);
      return Process.start(
        Platform.resolvedExecutable,
        ['run', 'bin/server.dart', if (devFlag) '--dev'],
        workingDirectory: project.path,
        environment: environment,
        includeParentEnvironment: false,
      );
    },
    isReady: (port) => _waitForServer(_host, port),
  );
}

Future<void> _expectReloadRoutes(Uri origin, {required bool enabled}) async {
  final client = HttpClient();
  try {
    final page = await (await client.getUrl(origin)).close();
    expect(page.statusCode, 200);
    expect(page.headers.value('content-security-policy'), contains("script-src 'self'; style-src 'self'"));
    final html = await page.transform(utf8.decoder).join();
    const source = 'src="/_dev/reload.js"';
    expect(html, enabled ? contains(source) : isNot(contains(source)));

    final script = await (await client.getUrl(origin.resolve('/_dev/reload.js'))).close();
    expect(script.statusCode, enabled ? 200 : 404);
    if (enabled) expect(script.headers.contentType?.mimeType, 'text/javascript');
    await script.drain<void>();

    final sse = await (await client.getUrl(origin.resolve('/_dev/reload'))).close().timeout(const Duration(seconds: 5));
    expect(sse.statusCode, enabled ? 200 : 404);
    if (enabled) {
      expect(sse.headers.contentType?.mimeType, 'text/event-stream');
    } else {
      await sse.drain<void>();
    }
  } finally {
    client.close(force: true);
  }
}

typedef _Response = ({int statusCode, String? setCookieHeader, String body});

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
    return (statusCode: res.statusCode, setCookieHeader: res.headers['set-cookie']?.join(', '), body: body);
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
    return (statusCode: res.statusCode, setCookieHeader: res.headers['set-cookie']?.join(', '), body: responseBody);
  } finally {
    client.close();
  }
}

/// Extracts the `__csrf` cookie value (`rawToken.hmac`) from joined `Set-Cookie` headers.
String? _extractCsrfCookieValue(String? setCookieHeader) {
  if (setCookieHeader == null) return null;
  for (final segment in setCookieHeader.split(',')) {
    final cookiePart = segment.trim().split(';').first.trim();
    if (cookiePart.startsWith('__csrf=')) return cookiePart.substring('__csrf='.length);
  }
  return null;
}
