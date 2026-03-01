import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('FileSystemLoader', () {
    late Directory tempDir;
    late FileSystemLoader loader;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_test_');
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Hello</p>');
      File('${tempDir.path}/explicit.html').writeAsStringSync('<p>Explicit</p>');
      Directory('${tempDir.path}/sub').createSync();
      File('${tempDir.path}/sub/nested.html').writeAsStringSync('<p>Nested</p>');
      loader = FileSystemLoader(tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('normal load', () {
      test('loads template by name (auto-appends extension)', () async {
        final content = await loader.load('page');
        expect(content, '<p>Hello</p>');
      });

      test('loads template with explicit extension', () async {
        final content = await loader.load('explicit.html');
        expect(content, '<p>Explicit</p>');
      });

      test('loadSync returns content', () {
        final content = loader.loadSync('page');
        expect(content, '<p>Hello</p>');
      });

      test('loads nested template', () async {
        final content = await loader.load('sub/nested');
        expect(content, '<p>Nested</p>');
      });
    });

    group('not found', () {
      test('load throws TemplateNotFoundException', () {
        expect(() => loader.load('nonexistent'), throwsA(isA<TemplateNotFoundException>()));
      });

      test('loadSync throws TemplateNotFoundException', () {
        expect(() => loader.loadSync('nonexistent'), throwsA(isA<TemplateNotFoundException>()));
      });
    });

    group('constructor', () {
      test('nonexistent basePath throws TemplateException', () {
        expect(() => FileSystemLoader('nonexistent_dir_that_does_not_exist/'), throwsA(isA<TemplateException>()));
      });
    });

    group('security', () {
      test('rejects absolute path', () {
        expect(() => loader.load('/etc/passwd'), throwsA(isA<TemplateSecurityException>()));
      });

      test('rejects path traversal with ..', () {
        expect(() => loader.load('../secret'), throwsA(isA<TemplateSecurityException>()));
      });

      test('rejects double traversal', () {
        expect(() => loader.load('sub/../../secret'), throwsA(isA<TemplateSecurityException>()));
      });

      test('loadSync rejects absolute path', () {
        expect(() => loader.loadSync('/etc/passwd'), throwsA(isA<TemplateSecurityException>()));
      });

      test('loadSync rejects traversal', () {
        expect(() => loader.loadSync('../secret'), throwsA(isA<TemplateSecurityException>()));
      });

      test('symlink escape rejected', () {
        // Create a file outside the base directory.
        final outsideFile = File('${tempDir.parent.path}/outside_secret.html');
        outsideFile.writeAsStringSync('SECRET');
        addTearDown(outsideFile.deleteSync);

        // Create a symlink inside basePath that points outside.
        final link = Link('${tempDir.path}/escape.html');
        link.createSync(outsideFile.path);

        expect(() => loader.load('escape'), throwsA(isA<TemplateSecurityException>()));
      });

      test('rejects prefix-collision sibling escape', () {
        final parent = tempDir.parent;
        final siblingBase = Directory('${parent.path}/trellis_base2_${DateTime.now().microsecondsSinceEpoch}');
        siblingBase.createSync();
        addTearDown(() => siblingBase.deleteSync(recursive: true));

        final outsideFile = File('${siblingBase.path}/secret.html');
        outsideFile.writeAsStringSync('SECRET');
        addTearDown(outsideFile.deleteSync);

        final link = Link('${tempDir.path}/escape_prefix.html');
        link.createSync(outsideFile.path);
        addTearDown(link.deleteSync);

        expect(() => loader.load('escape_prefix'), throwsA(isA<TemplateSecurityException>()));
      });
    });
  });
}
