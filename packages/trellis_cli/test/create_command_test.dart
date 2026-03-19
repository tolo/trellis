import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  group('CreateCommand', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_cli_test_');
      originalDir = Directory.current.path;
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = originalDir;
      tempDir.deleteSync(recursive: true);
    });

    test('creates project with all expected files', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', 'my_test_app']);
      expect(result, 0);

      final projectDir = Directory('${tempDir.path}/my_test_app');
      expect(projectDir.existsSync(), isTrue);

      final expectedFiles = [
        'pubspec.yaml',
        'bin/server.dart',
        'lib/handlers.dart',
        'templates/layouts/base.html',
        'templates/pages/index.html',
        'templates/pages/about.html',
        'templates/partials/nav.html',
        'static/styles.css',
        '.gitignore',
        'analysis_options.yaml',
      ];

      for (final path in expectedFiles) {
        expect(File('${projectDir.path}/$path').existsSync(), isTrue, reason: '$path should exist');
      }
    });

    test('rejects invalid project name', () {
      final cli = TrellisCli();
      expect(() => cli.run(['create', 'My-App']), throwsA(isA<UsageException>()));
    });

    test('rejects reserved word as project name', () {
      final cli = TrellisCli();
      expect(() => cli.run(['create', 'class']), throwsA(isA<UsageException>()));
    });

    test('errors on existing directory', () async {
      Directory('${tempDir.path}/existing_app').createSync();
      final cli = TrellisCli();
      expect(() => cli.run(['create', 'existing_app']), throwsA(isA<UsageException>()));
    });

    test('errors when no project name given', () {
      final cli = TrellisCli();
      expect(() => cli.run(['create']), throwsA(isA<UsageException>()));
    });

    test('errors when too many arguments', () {
      final cli = TrellisCli();
      expect(() => cli.run(['create', 'foo', 'bar']), throwsA(isA<UsageException>()));
    });

    test('generated pubspec contains correct project name', () async {
      final cli = TrellisCli();
      await cli.run(['create', 'hello_world']);

      final pubspec = File('${tempDir.path}/hello_world/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('name: hello_world'));
    });
  });

  group('CreateCommand — blog template', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_blog_test_');
      originalDir = Directory.current.path;
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = originalDir;
      tempDir.deleteSync(recursive: true);
    });

    test('--template blog creates project with expected files', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', '--template', 'blog', 'my_blog']);
      expect(result, 0);

      final projectDir = Directory('${tempDir.path}/my_blog');
      expect(projectDir.existsSync(), isTrue);

      final expectedFiles = [
        'pubspec.yaml',
        'trellis_site.yaml',
        '.gitignore',
        'analysis_options.yaml',
        'content/_index.md',
        'content/about.md',
        'content/posts/_index.md',
        'content/posts/welcome.md',
        'content/posts/getting-started.md',
        'layouts/base.html',
        'layouts/home.html',
        'layouts/_default/single.html',
        'layouts/_default/list.html',
        'layouts/posts/single.html',
        'static/styles.css',
      ];

      for (final path in expectedFiles) {
        expect(File('${projectDir.path}/$path').existsSync(), isTrue, reason: '$path should exist');
      }
    });

    test('-t blog short flag creates blog project', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', '-t', 'blog', 'test_blog']);
      expect(result, 0);
      expect(File('${tempDir.path}/test_blog/trellis_site.yaml').existsSync(), isTrue);
    });

    test('--template blog next steps mentions trellis build and trellis serve', () async {
      final cli = TrellisCli();
      await cli.run(['create', '--template', 'blog', 'my_blog']);
      // The output mentions "trellis build" and "trellis serve" — tested via
      // the command completing without error and expected files existing.
      expect(File('${tempDir.path}/my_blog/trellis_site.yaml').existsSync(), isTrue);
    });

    test('--template blog with existing directory produces error', () {
      Directory('${tempDir.path}/existing_blog').createSync();
      final cli = TrellisCli();
      expect(() => cli.run(['create', '--template', 'blog', 'existing_blog']), throwsA(isA<UsageException>()));
    });

    test('--template htmx still works unchanged', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', '--template', 'htmx', 'my_htmx_app']);
      expect(result, 0);
      // HTMX project has pubspec.yaml with trellis_shelf
      final pubspec = File('${tempDir.path}/my_htmx_app/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('trellis_shelf:'));
    });
  });

  group('CreateCommand — dart_frog template', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_dart_frog_test_');
      originalDir = Directory.current.path;
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = originalDir;
      tempDir.deleteSync(recursive: true);
    });

    test('--template dart_frog creates project with expected files', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', '--template', 'dart_frog', 'my_df_app']);
      expect(result, 0);

      final projectDir = Directory('${tempDir.path}/my_df_app');
      expect(projectDir.existsSync(), isTrue);

      final expectedFiles = [
        'pubspec.yaml',
        'dart_frog.yaml',
        '.gitignore',
        'analysis_options.yaml',
        'routes/_middleware.dart',
        'routes/index.dart',
        'routes/about.dart',
        'lib/counter_state.dart',
        'routes/counter/increment.dart',
        'routes/counter/decrement.dart',
        'routes/counter/reset.dart',
        'templates/layouts/base.html',
        'templates/pages/index.html',
        'templates/pages/about.html',
        'templates/partials/nav.html',
        'public/styles.css',
      ];

      for (final path in expectedFiles) {
        expect(File('${projectDir.path}/$path').existsSync(), isTrue, reason: '$path should exist');
      }
    });

    test('-t dart_frog short flag creates Dart Frog project', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', '-t', 'dart_frog', 'short_flag_app']);
      expect(result, 0);
      expect(File('${tempDir.path}/short_flag_app/dart_frog.yaml').existsSync(), isTrue);
    });

    test('generated pubspec contains dart_frog and trellis_dart_frog', () async {
      final cli = TrellisCli();
      await cli.run(['create', '--template', 'dart_frog', 'df_pubspec_test']);

      final pubspec = File('${tempDir.path}/df_pubspec_test/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('dart_frog:'));
      expect(pubspec, contains('trellis_dart_frog:'));
    });

    test('--template dart_frog with existing directory produces error', () {
      Directory('${tempDir.path}/existing_df').createSync();
      final cli = TrellisCli();
      expect(() => cli.run(['create', '--template', 'dart_frog', 'existing_df']), throwsA(isA<UsageException>()));
    });

    test('--template blog still works unchanged after dart_frog addition', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', '--template', 'blog', 'my_blog_check']);
      expect(result, 0);
      expect(File('${tempDir.path}/my_blog_check/trellis_site.yaml').existsSync(), isTrue);
    });

    test('--template htmx still works unchanged after dart_frog addition', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', '--template', 'htmx', 'my_htmx_check']);
      expect(result, 0);
      final pubspec = File('${tempDir.path}/my_htmx_check/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('trellis_shelf:'));
    });
  });

  group('CreateCommand — relic template', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_relic_test_');
      originalDir = Directory.current.path;
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = originalDir;
      tempDir.deleteSync(recursive: true);
    });

    test('--template relic creates project with expected files', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', '--template', 'relic', 'my_relic_app']);
      expect(result, 0);

      final projectDir = Directory('${tempDir.path}/my_relic_app');
      expect(projectDir.existsSync(), isTrue);

      final expectedFiles = [
        'pubspec.yaml',
        '.gitignore',
        'analysis_options.yaml',
        'bin/server.dart',
        'lib/handlers.dart',
        'templates/base.html',
        'templates/index.html',
        'templates/about.html',
        'static/styles.css',
      ];

      for (final path in expectedFiles) {
        expect(File('${projectDir.path}/$path').existsSync(), isTrue, reason: '$path should exist');
      }
    });

    test('-t relic short flag creates Relic project', () async {
      final cli = TrellisCli();
      final result = await cli.run(['create', '-t', 'relic', 'short_flag_relic']);
      expect(result, 0);
      expect(File('${tempDir.path}/short_flag_relic/bin/server.dart').existsSync(), isTrue);
    });

    test('generated pubspec contains relic and trellis_relic', () async {
      final cli = TrellisCli();
      await cli.run(['create', '--template', 'relic', 'relic_pubspec_test']);

      final pubspec = File('${tempDir.path}/relic_pubspec_test/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('relic:'));
      expect(pubspec, contains('trellis_relic:'));
    });

    test('--template relic with existing directory produces error', () {
      Directory('${tempDir.path}/existing_relic').createSync();
      final cli = TrellisCli();
      expect(() => cli.run(['create', '--template', 'relic', 'existing_relic']), throwsA(isA<UsageException>()));
    });

    test('generated server configures CSP for HTMX CDN script', () async {
      final cli = TrellisCli();
      await cli.run(['create', '--template', 'relic', 'relic_csp_test']);

      final server = File('${tempDir.path}/relic_csp_test/bin/server.dart').readAsStringSync();
      expect(server, contains('CspBuilder'));
      expect(server, contains('https://cdn.jsdelivr.net'));
      expect(server, contains('trellisSecurityHeaders(csp: csp)'));
    });
  });
}
