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
        'templates/partials/nav.html',
        'templates/partials/htmx.html',
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
}
