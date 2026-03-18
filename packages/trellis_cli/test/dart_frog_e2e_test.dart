/// End-to-end integration test for the Dart Frog starter template lifecycle.
///
/// Generates a Dart Frog project via [DartFrogProjectGenerator], injects local
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
  group('Dart Frog starter E2E', () {
    late Directory projectDir;

    setUpAll(() async {
      // ── 1. Generate project ────────────────────────────────────────────
      final tempDir = await Directory.systemTemp.createTemp('trellis_df_e2e_');
      const projectName = 'e2e_dart_frog_app';
      final appDir = Directory('${tempDir.path}/$projectName');
      await appDir.create();

      final writer = DiskFileWriter(appDir.path);
      final generator = DartFrogProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();
      projectDir = appDir;

      // ── 2. Inject dependency_overrides for local workspace packages ────
      final workspaceRoot = _findWorkspaceRoot().path;
      final pubspecFile = File('${projectDir.path}/pubspec.yaml');
      final pubspecContent = await pubspecFile.readAsString();
      final overrides = '''
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

      // ── 3. dart pub get ────────────────────────────────────────────────
      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: projectDir.path);
      expect(pubGet.exitCode, 0, reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}');

      // ── 4. dart analyze ────────────────────────────────────────────────
      final analyze = await Process.run('dart', ['analyze', '--fatal-infos'], workingDirectory: projectDir.path);
      expect(analyze.exitCode, 0, reason: 'dart analyze failed:\n${analyze.stdout}\n${analyze.stderr}');
    });

    tearDownAll(() async {
      await projectDir.parent.delete(recursive: true);
    });

    test('pubspec.yaml exists and references dart_frog', () {
      final pubspec = File('${projectDir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('dart_frog:'));
      expect(pubspec, contains('trellis_dart_frog:'));
    });

    test('dart_frog.yaml exists', () {
      expect(File('${projectDir.path}/dart_frog.yaml').existsSync(), isTrue);
    });

    test('routes/_middleware.dart exists', () {
      expect(File('${projectDir.path}/routes/_middleware.dart').existsSync(), isTrue);
    });

    test('routes/index.dart exists', () {
      expect(File('${projectDir.path}/routes/index.dart').existsSync(), isTrue);
    });

    test('routes/todos/index.dart exists', () {
      expect(File('${projectDir.path}/routes/todos/index.dart').existsSync(), isTrue);
    });

    test('templates/layouts/base.html exists', () {
      expect(File('${projectDir.path}/templates/layouts/base.html').existsSync(), isTrue);
    });

    test('templates/pages/index.html exists', () {
      expect(File('${projectDir.path}/templates/pages/index.html').existsSync(), isTrue);
    });

    test('templates/partials/nav.html exists', () {
      expect(File('${projectDir.path}/templates/partials/nav.html').existsSync(), isTrue);
    });

    test('templates/partials/todo_list.html exists', () {
      expect(File('${projectDir.path}/templates/partials/todo_list.html').existsSync(), isTrue);
    });

    test('public/styles.css exists', () {
      expect(File('${projectDir.path}/public/styles.css').existsSync(), isTrue);
    });

    test('analysis_options.yaml exists', () {
      expect(File('${projectDir.path}/analysis_options.yaml').existsSync(), isTrue);
    });

    test('generated Dart files pass analysis', () async {
      // This assertion is satisfied by the dart analyze in setUpAll;
      // if we reach this test, analysis passed.
      expect(true, isTrue);
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Finds the workspace root by searching upward for `packages/trellis/`.
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
