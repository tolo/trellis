/// End-to-end integration test for the Relic starter template lifecycle.
///
/// Generates a Relic project via [RelicProjectGenerator], injects local
/// workspace dependency overrides, runs `dart pub get` and `dart analyze`, then
/// verifies all expected files exist.
///
/// Tagged [e2e] so that fast unit-test runs can exclude it:
///   dart test --exclude-tags=e2e
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  group('Relic starter E2E', () {
    late Directory projectDir;

    setUpAll(() async {
      final tempDir = await Directory.systemTemp.createTemp('trellis_relic_e2e_');
      const projectName = 'e2e_relic_app';
      final appDir = Directory('${tempDir.path}/$projectName');
      await appDir.create();

      final writer = DiskFileWriter(appDir.path);
      final generator = RelicProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();
      projectDir = appDir;

      final workspaceRoot = _findWorkspaceRoot().path;
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
    });

    tearDownAll(() async {
      await projectDir.parent.delete(recursive: true);
    });

    test('pubspec.yaml exists and references relic', () {
      final pubspec = File('${projectDir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('relic:'));
      expect(pubspec, contains('trellis_relic:'));
    });

    test('bin/server.dart exists', () {
      expect(File('${projectDir.path}/bin/server.dart').existsSync(), isTrue);
    });

    test('lib/handlers.dart exists', () {
      expect(File('${projectDir.path}/lib/handlers.dart').existsSync(), isTrue);
    });

    test('templates/base.html exists', () {
      expect(File('${projectDir.path}/templates/base.html').existsSync(), isTrue);
    });

    test('templates/index.html exists', () {
      expect(File('${projectDir.path}/templates/index.html').existsSync(), isTrue);
    });

    test('templates/about.html exists', () {
      expect(File('${projectDir.path}/templates/about.html').existsSync(), isTrue);
    });

    test('static/styles.css exists', () {
      expect(File('${projectDir.path}/static/styles.css').existsSync(), isTrue);
    });

    test('analysis_options.yaml exists', () {
      expect(File('${projectDir.path}/analysis_options.yaml').existsSync(), isTrue);
    });

    test('generated server configures CSP for HTMX CDN script', () {
      final server = File('${projectDir.path}/bin/server.dart').readAsStringSync();
      expect(server, contains('CspBuilder'));
      expect(server, contains('https://cdn.jsdelivr.net'));
      expect(server, contains('trellisSecurityHeaders(csp: csp)'));
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Directory _findWorkspaceRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory('${dir.path}/packages/trellis').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find workspace root (looked for packages/trellis/)');
    }
    dir = parent;
  }
}
