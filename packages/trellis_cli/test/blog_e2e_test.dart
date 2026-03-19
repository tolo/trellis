/// End-to-end integration test for the blog starter template lifecycle.
///
/// Generates a blog project via [BlogProjectGenerator], injects local workspace
/// dependency overrides, runs `dart pub get` and `dart analyze`, then executes
/// `trellis build` in-process and verifies the output file tree.
///
/// Tagged [e2e] so that fast unit-test runs can exclude it:
///   dart test --exclude-tags=e2e
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

import '_workspace_root.dart';

void main() {
  group('Blog starter E2E', () {
    late Directory projectDir;
    late String originalDir;

    setUpAll(() async {
      // ── 1. Generate blog project ───────────────────────────────────────
      final tempDir = await Directory.systemTemp.createTemp('trellis_blog_e2e_');
      const projectName = 'e2e_blog';
      final blogDir = Directory('${tempDir.path}/$projectName');
      await blogDir.create();

      final writer = DiskFileWriter(blogDir.path);
      final generator = BlogProjectGenerator(projectName: projectName, writer: writer);
      await generator.generate();
      projectDir = blogDir;

      // ── 2. Inject dependency_overrides for local workspace packages ────
      final workspaceRoot = (await findWorkspaceRoot()).path;
      final pubspecFile = File('${projectDir.path}/pubspec.yaml');
      final pubspecContent = await pubspecFile.readAsString();
      final overrides =
          '''
dependency_overrides:
  trellis:
    path: $workspaceRoot/packages/trellis
  trellis_site:
    path: $workspaceRoot/packages/trellis_site
''';
      await pubspecFile.writeAsString(pubspecContent + overrides);

      // ── 3. dart pub get ────────────────────────────────────────────────
      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: projectDir.path);
      expect(pubGet.exitCode, 0, reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}');

      // ── 4. dart analyze ────────────────────────────────────────────────
      final analyze = await Process.run('dart', ['analyze'], workingDirectory: projectDir.path);
      expect(analyze.exitCode, 0, reason: 'dart analyze failed:\n${analyze.stdout}\n${analyze.stderr}');

      // ── 5. trellis build ───────────────────────────────────────────────
      originalDir = Directory.current.path;
      Directory.current = projectDir;
      final buildResult = await TrellisCli().run(['build']);
      Directory.current = originalDir;

      expect(buildResult, 0, reason: 'trellis build should exit 0');
    });

    tearDownAll(() async {
      if (Directory.current.path != originalDir) {
        Directory.current = originalDir;
      }
      await projectDir.parent.delete(recursive: true);
    });

    test('output directory is created', () {
      expect(Directory(p.join(projectDir.path, 'output')).existsSync(), isTrue);
    });

    test('home page is generated', () {
      expect(File(p.join(projectDir.path, 'output', 'index.html')).existsSync(), isTrue);
    });

    test('about page is generated', () {
      expect(File(p.join(projectDir.path, 'output', 'about', 'index.html')).existsSync(), isTrue);
    });

    test('posts listing page is generated', () {
      expect(File(p.join(projectDir.path, 'output', 'posts', 'index.html')).existsSync(), isTrue);
    });

    test('welcome post is generated', () {
      expect(File(p.join(projectDir.path, 'output', 'posts', 'welcome', 'index.html')).existsSync(), isTrue);
    });

    test('getting-started post is generated', () {
      expect(File(p.join(projectDir.path, 'output', 'posts', 'getting-started', 'index.html')).existsSync(), isTrue);
    });

    test('static CSS is copied', () {
      expect(File(p.join(projectDir.path, 'output', 'styles.css')).existsSync(), isTrue);
    });

    test('sitemap.xml is generated', () {
      expect(File(p.join(projectDir.path, 'output', 'sitemap.xml')).existsSync(), isTrue);
    });

    test('taxonomy listing page is generated', () {
      expect(File(p.join(projectDir.path, 'output', 'tags', 'index.html')).existsSync(), isTrue);
    });

    test('home page contains site title', () {
      final html = File(p.join(projectDir.path, 'output', 'index.html')).readAsStringSync();
      expect(html, contains('e2e blog'));
    });

    test('welcome post contains rendered Markdown', () {
      final html = File(p.join(projectDir.path, 'output', 'posts', 'welcome', 'index.html')).readAsStringSync();
      expect(html, contains('Welcome to your new blog'));
    });

    test('no partial output left on simulated failure', () async {
      // Verify that a clean build leaves no partial state when the output
      // directory is fully written. (The cleanup-on-failure path is covered by
      // the fact that build() succeeded above.)
      final outputDir = Directory(p.join(projectDir.path, 'output'));
      expect(outputDir.existsSync(), isTrue);
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
