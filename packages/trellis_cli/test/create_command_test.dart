import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';
import 'package:trellis_cli/src/templates/htmx_asset.dart';

void main() {
  group('--ui', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('trellis_ui_flag_'));
    tearDown(() => dir.deleteSync(recursive: true));

    for (final template in ['htmx', 'relic', 'dart_frog']) {
      for (final cdn in [false, true]) {
        test('creates the $template scaffold with htmx-cdn=$cdn', () async {
          final cli = TrellisCli(workingDirectory: dir.path);
          expect(
            await cli.run([
              'create',
              'demo',
              '--ui',
              if (template != 'htmx') ...['--template', template],
              if (cdn) '--htmx-cdn',
            ]),
            0,
          );
          final project = '${dir.path}/demo';
          expect(File('$project/pubspec.yaml').readAsLinesSync(), contains('  trellis_ui: ^$cliVersion'));
          final serverPath = template == 'dart_frog' ? 'main.dart' : 'bin/server.dart';
          final server = File('$project/$serverPath').readAsStringSync();
          if (cdn) {
            expect(RegExp(r'scriptSrc: (.+),').firstMatch(server)?.group(1), '"\'self\' $htmxCdnOrigin"');
          } else {
            expect(server, isNot(contains('scriptSrc:')));
          }
        });
      }
    }

    for (final template in ['blog', 'theme']) {
      test('rejects $template before writing a directory', () async {
        final cli = TrellisCli(workingDirectory: dir.path);
        await expectLater(
          cli.run(['create', 'demo', '--template', template, '--ui']),
          throwsA(isA<UsageException>().having((e) => e.message, 'message', contains('htmx, relic and dart_frog'))),
        );
        expect(Directory('${dir.path}/demo').existsSync(), isFalse);
      });
    }

    test('prints the run and preview commands for Dart Frog', () async {
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        await _trellisCliBinPath(),
        'create',
        'demo',
        '--template',
        'dart_frog',
        '--ui',
      ], workingDirectory: dir.path);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('dart pub get\n  dart_frog dev'));
      expect(result.stdout, contains('/ui'));
      expect(result.stdout, contains('dart run trellis_ui:materialize public/trellis-ui'));
    });
  });

  group('htmx-cdn', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('trellis_cdn_'));
    tearDown(() => dir.deleteSync(recursive: true));
    for (final template in ['htmx', 'relic', 'dart_frog']) {
      test('reaches $template generator', () async {
        final cli = TrellisCli(workingDirectory: dir.path);
        expect(await cli.run(['create', 'demo', '--template', template, '--htmx-cdn']), 0);
        final root = '${dir.path}/demo';
        final layout = template == 'relic' ? 'templates/base.html' : 'templates/layouts/base.html';
        expect(File('$root/$layout').readAsStringSync(), contains(htmxScriptTag()));
        expect(File('$root/${template == "dart_frog" ? "public" : "static"}/js/htmx.min.js').existsSync(), isFalse);
      });
    }
    for (final template in ['blog', 'theme']) {
      test('rejects $template without writing a directory', () async {
        final cli = TrellisCli(workingDirectory: dir.path);
        await expectLater(
          cli.run(['create', 'demo', '--template', template, '--htmx-cdn']),
          throwsA(isA<UsageException>().having((e) => e.message, 'message', contains('htmx, relic and dart_frog'))),
        );
        expect(Directory('${dir.path}/demo').existsSync(), isFalse);
      });
    }
  });
  group('CreateCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_cli_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('creates project with all expected files', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
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
      final cli = TrellisCli(workingDirectory: tempDir.path);
      expect(() => cli.run(['create', 'My-App']), throwsA(isA<UsageException>()));
    });

    test('rejects reserved word as project name', () {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      expect(() => cli.run(['create', 'class']), throwsA(isA<UsageException>()));
    });

    test('errors on existing directory', () async {
      Directory('${tempDir.path}/existing_app').createSync();
      final cli = TrellisCli(workingDirectory: tempDir.path);
      expect(() => cli.run(['create', 'existing_app']), throwsA(isA<UsageException>()));
    });

    test('errors when no project name given', () {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      expect(() => cli.run(['create']), throwsA(isA<UsageException>()));
    });

    test('errors when too many arguments', () {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      expect(() => cli.run(['create', 'foo', 'bar']), throwsA(isA<UsageException>()));
    });

    test('generated pubspec contains correct project name', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      await cli.run(['create', 'hello_world']);

      final pubspec = File('${tempDir.path}/hello_world/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('name: hello_world'));
    });
  });

  group('CreateCommand — blog template', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_blog_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('--template blog creates project with expected files', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
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
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['create', '-t', 'blog', 'test_blog']);
      expect(result, 0);
      expect(File('${tempDir.path}/test_blog/trellis_site.yaml').existsSync(), isTrue);
    });

    test('--template blog next steps omit Dart SDK package resolution', () async {
      final binPath = await _trellisCliBinPath();
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        binPath,
        'create',
        '--template',
        'blog',
        'my_blog_output',
      ], workingDirectory: tempDir.path);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('  trellis build'));
      expect(result.stdout, contains('  trellis serve'));
      expect(result.stdout, isNot(contains('dart pub get')));
    });

    test('--template blog with existing directory produces error', () {
      Directory('${tempDir.path}/existing_blog').createSync();
      final cli = TrellisCli(workingDirectory: tempDir.path);
      expect(() => cli.run(['create', '--template', 'blog', 'existing_blog']), throwsA(isA<UsageException>()));
    });

    test('--template htmx still works unchanged', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['create', '--template', 'htmx', 'my_htmx_app']);
      expect(result, 0);
      // HTMX project has pubspec.yaml with trellis_shelf
      final pubspec = File('${tempDir.path}/my_htmx_app/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('trellis_shelf:'));
    });
  });

  group('CreateCommand — dart_frog template', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_dart_frog_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('--template dart_frog creates project with expected files', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
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
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['create', '-t', 'dart_frog', 'short_flag_app']);
      expect(result, 0);
      expect(File('${tempDir.path}/short_flag_app/dart_frog.yaml').existsSync(), isTrue);
    });

    test('generated pubspec contains dart_frog and trellis_dart_frog', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      await cli.run(['create', '--template', 'dart_frog', 'df_pubspec_test']);

      final pubspec = File('${tempDir.path}/df_pubspec_test/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('dart_frog:'));
      expect(pubspec, contains('trellis_dart_frog:'));
    });

    test('--template dart_frog with existing directory produces error', () {
      Directory('${tempDir.path}/existing_df').createSync();
      final cli = TrellisCli(workingDirectory: tempDir.path);
      expect(() => cli.run(['create', '--template', 'dart_frog', 'existing_df']), throwsA(isA<UsageException>()));
    });

    test('--template blog still works unchanged after dart_frog addition', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['create', '--template', 'blog', 'my_blog_check']);
      expect(result, 0);
      expect(File('${tempDir.path}/my_blog_check/trellis_site.yaml').existsSync(), isTrue);
    });

    test('--template htmx still works unchanged after dart_frog addition', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['create', '--template', 'htmx', 'my_htmx_check']);
      expect(result, 0);
      final pubspec = File('${tempDir.path}/my_htmx_check/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('trellis_shelf:'));
    });
  });

  group('CreateCommand — relic template', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_relic_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('--template relic creates project with expected files', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
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
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['create', '-t', 'relic', 'short_flag_relic']);
      expect(result, 0);
      expect(File('${tempDir.path}/short_flag_relic/bin/server.dart').existsSync(), isTrue);
    });

    test('generated pubspec contains relic and trellis_relic', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      await cli.run(['create', '--template', 'relic', 'relic_pubspec_test']);

      final pubspec = File('${tempDir.path}/relic_pubspec_test/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('relic:'));
      expect(pubspec, contains('trellis_relic:'));
    });

    test('--template relic with existing directory produces error', () {
      Directory('${tempDir.path}/existing_relic').createSync();
      final cli = TrellisCli(workingDirectory: tempDir.path);
      expect(() => cli.run(['create', '--template', 'relic', 'existing_relic']), throwsA(isA<UsageException>()));
    });

    test('generated server configures strict CSP for same-origin scripts', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      await cli.run(['create', '--template', 'relic', 'relic_csp_test']);

      final server = File('${tempDir.path}/relic_csp_test/bin/server.dart').readAsStringSync();
      expect(server, contains('CspBuilder'));
      expect(server, isNot(contains('cdn.jsdelivr.net')));
      expect(server, contains('trellisSecurityHeaders(csp: csp)'));
    });
  });
}

Future<String> _trellisCliBinPath() async {
  final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_cli/trellis_cli.dart'));
  if (packageUri == null || packageUri.scheme != 'file') {
    throw StateError('Could not resolve package:trellis_cli/trellis_cli.dart');
  }

  return '${File(packageUri.toFilePath()).parent.parent.path}/bin/trellis.dart';
}
