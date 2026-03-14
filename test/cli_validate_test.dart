import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('trellis:validate CLI', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_validate_cli_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('valid templates exit 0', () async {
      File('${tempDir.path}/home.html').writeAsStringSync('<p tl:text="\${name}">x</p>');

      final result = await Process.run('dart', [
        'run',
        'trellis:validate',
        '--dir',
        tempDir.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0);
      expect(result.stderr, isEmpty);
    });

    test('validation errors exit 1', () async {
      final file = File('${tempDir.path}/broken.html');
      file.writeAsStringSync('<p tl:text=""></p>');

      final result = await Process.run('dart', [
        'run',
        'trellis:validate',
        '--dir',
        tempDir.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 1);
      expect(result.stderr, contains(file.path));
      expect(result.stderr, contains('error'));
      expect(result.stderr, contains('tl:text'));
    });

    test('warnings only still exit 0', () async {
      final file = File('${tempDir.path}/warning.html');
      file.writeAsStringSync('<p tl:textt="\${name}">x</p>');

      final result = await Process.run('dart', [
        'run',
        'trellis:validate',
        '--dir',
        tempDir.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0);
      expect(result.stderr, contains(file.path));
      expect(result.stderr, contains('warning'));
    });

    test('custom prefix is supported', () async {
      File('${tempDir.path}/custom.html').writeAsStringSync('<p data-tl-text="\${name}">x</p>');

      final result = await Process.run('dart', [
        'run',
        'trellis:validate',
        '--dir',
        tempDir.path,
        '--prefix',
        'data-tl',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0);
      expect(result.stderr, isEmpty);
    });
  });
}
