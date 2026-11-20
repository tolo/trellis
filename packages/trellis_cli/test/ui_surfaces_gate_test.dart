@Tags(['ui-gate', 'visual'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

import '../../../tool/ui_gate/checks.dart';
import '../../../tool/ui_gate/manifest.dart';
import '../../../tool/ui_gate/release_policy.dart';
import '_workspace_root.dart';

const _routes = {
  'admin': {'admin': '/contacts'},
  'shelf': {'shelf-home': '/', 'shelf-ui': '/ui'},
  'relic': {'relic-home': '/', 'relic-ui': '/ui'},
  'dart_frog': {'dart-frog-home': '/', 'dart-frog-ui': '/ui'},
};

void main() {
  test('the launcher prints Serving first, serves under the strict policy and stops its server', () async {
    final root = await findWorkspaceRoot();
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    for (final entry in _routes.entries) {
      final surface = entry.key;
      final app = await Process.start(Platform.resolvedExecutable, [
        'run',
        'tool/serve_ui_surface.dart',
        surface,
      ], workingDirectory: root.path);
      final errors = StringBuffer();
      final stderr = app.stderr.transform(utf8.decoder).listen(errors.write);
      late final Uri base;
      try {
        final line = await app.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 30), onTimeout: () => fail('$surface launch timed out: $errors'));
        expect(line, matches(r'^Serving http://127\.0\.0\.1:\d+$'), reason: surface);
        base = Uri.parse(line.substring('Serving '.length));
        for (final route in entry.value.values) {
          final response = await (await client.getUrl(base.resolve(route))).close();
          final html = await utf8.decodeStream(response);
          expect(response.statusCode, HttpStatus.ok, reason: '$surface $route');
          final directives = response.headers.value('content-security-policy')?.split('; ');
          expect(directives, containsAll(strictPolicy.split('; ')), reason: '$surface $route');
          expect(directives, isNot(contains(contains('unsafe-inline'))), reason: '$surface $route');
          expect(
            html,
            contains(
              surface == 'admin'
                  ? 'Contact directory'
                  : route == '/'
                  ? 'counter-increment'
                  : 'components-dialog',
            ),
            reason: '$surface $route',
          );
        }
        for (final path in trellisUiAssetPaths) {
          final response = await (await client.getUrl(base.resolve(path))).close();
          final bytes = await response.expand((chunk) => chunk).toList();
          final embedded = trellisUiRespond(path)!;
          expect(response.statusCode, HttpStatus.ok, reason: '$surface $path');
          expect(response.headers.value(HttpHeaders.etagHeader), embedded.headers['etag'], reason: '$surface $path');
          expect(bytes, embedded.body, reason: '$surface $path');
        }
      } finally {
        app.kill();
        try {
          expect(await app.exitCode.timeout(const Duration(seconds: 5)), 0, reason: '$surface cleanup: $errors');
        } finally {
          await stderr.cancel();
        }
      }
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, base.port);
      await socket.close();
      print('$surface served ${entry.value.values.join(', ')}, verified embedded assets, and released its port');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('every surface passes every automated item in both browsers', () async {
    final root = await findWorkspaceRoot();
    final policy = ComponentReleasePolicy.read(root);
    final subject = Directory.fromUri(root.uri.resolve('dev/ui-gate/apps/'));
    final scratchRoot = Directory.fromUri(root.uri.resolve('.agent_temp/'))..createSync(recursive: true);
    final records = scratchRoot.createTempSync('app-gate-records-');
    addTearDown(() => records.delete(recursive: true));
    final names = _routes.values.expand((routes) => routes.keys).toSet();
    final manifests = Directory.fromUri(subject.uri.resolve('manifests/'));
    expect(
      manifests
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.yaml'))
          .map((file) => file.uri.pathSegments.last.replaceFirst(RegExp(r'\.yaml$'), '')),
      unorderedEquals(names),
    );

    Future<void> verify(MapEntry<String, Map<String, String>> entry) async {
      final surface = entry.key;
      final expected = <String, List<int>>{};
      for (final route in entry.value.entries) {
        final manifest = GateManifest.load(File.fromUri(manifests.uri.resolve('${route.key}.yaml')));
        expect(manifest.page, route.value, reason: route.key);
        final record = File.fromUri(subject.uri.resolve('records/${route.key}.json'));
        final bytes = record.readAsBytesSync();
        expected[route.key] = bytes;
        final previous = jsonDecode(utf8.decode(bytes)) as Map;
        final items = previous['items'] as Map;
        // A run that exits before writing must leave a different record.
        File.fromUri(records.uri.resolve('${route.key}.json')).writeAsStringSync(
          jsonEncode({
            'items': {for (final item in manualItems) item: items[item]},
          }),
        );
      }
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'tool/ui_gate.dart',
        '--serve',
        'dart run tool/serve_ui_surface.dart $surface',
        '--manifests',
        manifests.path,
        '--records',
        records.path,
        '--baselines',
        Directory.fromUri(subject.uri.resolve('baselines/')).path,
        ...entry.value.keys,
      ], workingDirectory: root.path);
      print('$surface -> exit=${result.exitCode}\n${result.stdout}${result.stderr}');
      expect(result.exitCode, 0, reason: surface);
      for (final name in entry.value.keys) {
        final bytes = File.fromUri(records.uri.resolve('$name.json')).readAsBytesSync();
        final record = jsonDecode(utf8.decode(bytes)) as Map;
        expect(policy.recordIssues(name, record, app: true), isEmpty, reason: name);
        if (name == 'admin') {
          final items = record['items'] as Map;
          for (final item in ['strict-csp', 'wcag-axe']) {
            final browsers = (items[item] as Map)['browsers'] as Map;
            for (final browser in ['chrome', 'firefox']) {
              expect((browsers[browser] as Map)['status'], 'pass', reason: 'admin $item in $browser');
            }
          }
        }
        expect(bytes, expected[name], reason: '$name automated rerun preserves checked-in evidence and manual results');
      }
    }

    final apps = _routes.entries.toList();
    for (var i = 0; i < apps.length; i += 2) {
      await Future.wait(apps.skip(i).take(2).map(verify), eagerError: false);
    }
    print('${names.length} surfaces pass ${automatedItems.length} automated items with Chrome and Firefox evidence');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
