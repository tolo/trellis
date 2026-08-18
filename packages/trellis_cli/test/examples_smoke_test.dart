/// Smoke-tests the materialized example apps checked into `examples/`.
///
/// This guards against drift between the CLI templates and the committed
/// examples by booting each app and exercising its primary routes.
@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '_e2e_server.dart';
import '_workspace_root.dart';

void main() {
  group('Examples smoke test', () {
    late Directory workspaceRoot;

    setUpAll(() async {
      workspaceRoot = await findWorkspaceRoot();

      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: workspaceRoot.path);
      expect(pubGet.exitCode, 0, reason: 'workspace dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}');
    });

    test('all example apps boot and serve their core flows', () async {
      await _runShelfApp(workspaceRoot);
      await _runRelicApp(workspaceRoot);
      await _runDartFrogApp(workspaceRoot);
      await _runTodoApp(workspaceRoot);
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}

/// Boots an example app that reads its port from the `PORT` environment
/// variable (every example except dart_frog_app, which takes a CLI flag).
Future<BootedServer> _bootEnvPortApp(Directory appDir, {required String label, required String bodyContains}) {
  return bootServer(
    label: label,
    start: (port) => Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      workingDirectory: appDir.path,
      environment: {...Platform.environment, 'PORT': '$port'},
    ),
    isReady: (port) => _waitForHttpOk('http://localhost:$port/', bodyContains: bodyContains),
  );
}

Future<void> _runShelfApp(Directory workspaceRoot) async {
  final server = await _bootEnvPortApp(
    Directory('${workspaceRoot.path}/examples/shelf_app'),
    label: 'shelf_app',
    bodyContains: 'Trellis + Shelf',
  );
  final process = server.process;
  final port = server.port;

  try {
    final home = await _get('http://localhost:$port/');
    expect(home.statusCode, 200);

    final about = await _get('http://localhost:$port/about');
    expect(about.statusCode, 200);

    final cookieValue = _extractCsrfCookieValue(home.setCookieHeader);
    expect(cookieValue, isNotNull);

    final rawToken = cookieValue!.split('.').first;
    final increment = await _post(
      'http://localhost:$port/counter/increment',
      body: '_csrf=$rawToken',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'HX-Request': 'true',
        'Cookie': '__csrf=$cookieValue',
      },
    );
    expect(increment.statusCode, 200);
    expect(increment.body, contains('counter-value'));
  } finally {
    await stopServer(process);
  }
}

Future<void> _runRelicApp(Directory workspaceRoot) async {
  final server = await _bootEnvPortApp(
    Directory('${workspaceRoot.path}/examples/relic_app'),
    label: 'relic_app',
    bodyContains: 'Trellis + Relic',
  );
  final process = server.process;
  final port = server.port;

  try {
    final home = await _get('http://localhost:$port/');
    expect(home.statusCode, 200);

    final about = await _get('http://localhost:$port/about');
    expect(about.statusCode, 200);

    final increment = await _post(
      'http://localhost:$port/counter/increment',
      body: '',
      headers: {'HX-Request': 'true'},
    );
    expect(increment.statusCode, 200);
    expect(increment.body, contains('counter-value'));
  } finally {
    await stopServer(process);
  }
}

Future<void> _runDartFrogApp(Directory workspaceRoot) async {
  final homeDir = Platform.environment['HOME'];
  final dartFrogExecutable = homeDir != null ? '$homeDir/.pub-cache/bin/dart_frog' : 'dart_frog';
  if (!File(dartFrogExecutable).existsSync()) {
    final activate = await Process.run('dart', ['pub', 'global', 'activate', 'dart_frog_cli', '1.2.6']);
    expect(activate.exitCode, 0, reason: 'dart_frog CLI activation failed:\n${activate.stdout}\n${activate.stderr}');
  }

  final appDir = Directory('${workspaceRoot.path}/examples/dart_frog_app');
  final server = await bootServer(
    label: 'dart_frog_app',
    start: (port) async {
      final vmServicePort = await allocateFreePort();
      return Process.start(dartFrogExecutable, [
        'dev',
        '--port',
        '$port',
        '--dart-vm-service-port',
        '$vmServicePort',
      ], workingDirectory: appDir.path);
    },
    isReady: (port) => _waitForHttpOk('http://localhost:$port/', bodyContains: 'Trellis + Dart Frog'),
  );
  final process = server.process;
  final port = server.port;

  try {
    final home = await _get('http://localhost:$port/');
    expect(home.statusCode, 200);

    final about = await _get('http://localhost:$port/about');
    expect(about.statusCode, 200);
    expect(about.body, contains('<!DOCTYPE html>'));

    final aboutFragment = await _get('http://localhost:$port/about', headers: {'HX-Request': 'true'});
    expect(aboutFragment.statusCode, 200);
    expect(aboutFragment.body, isNot(contains('<!DOCTYPE html>')));

    final cookieValue = _extractCsrfCookieValue(home.setCookieHeader);
    expect(cookieValue, isNotNull);

    final rawToken = cookieValue!.split('.').first;
    final increment = await _post(
      'http://localhost:$port/counter/increment',
      body: '_csrf=$rawToken',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'HX-Request': 'true',
        'Cookie': '__csrf=$cookieValue',
      },
    );
    expect(increment.statusCode, 200);
    expect(increment.body, contains('counter-value'));
  } finally {
    await stopServer(process);
  }
}

Future<void> _runTodoApp(Directory workspaceRoot) async {
  final server = await _bootEnvPortApp(
    Directory('${workspaceRoot.path}/examples/todo_app'),
    label: 'todo_app',
    bodyContains: 'Trellis Todo',
  );
  final process = server.process;
  final port = server.port;

  try {
    final home = await _get('http://localhost:$port/');
    expect(home.statusCode, 200);

    final selectedList = await _get('http://localhost:$port/lists/2');
    expect(selectedList.statusCode, 200);
    expect(selectedList.body, contains('Personal'));
  } finally {
    await stopServer(process);
  }
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
