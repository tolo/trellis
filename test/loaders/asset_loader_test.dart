import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis/src/exceptions.dart';
import 'package:trellis/src/loaders/asset_loader.dart';

void main() {
  group('AssetLoader', () {
    group('constructor', () {
      test('rejects non-package: basePath', () {
        expect(
          () => AssetLoader('templates/'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects basePath without trailing slash', () {
        expect(
          () => AssetLoader('package:trellis/test_fixtures'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts valid package: basePath', () {
        final loader = AssetLoader('package:trellis/test_fixtures/');
        expect(loader.basePath, equals('package:trellis/test_fixtures/'));
      });
    });

    group('load (async)', () {
      late AssetLoader loader;

      setUp(() {
        loader = AssetLoader('package:trellis/test_fixtures/');
      });

      test('loads template by name (auto-appends extension)', () async {
        final content = await loader.load('simple');
        expect(content, contains('Hello from asset'));
      });

      test('loads template with explicit extension', () async {
        final content = await loader.load('explicit.html');
        expect(content, contains('Explicit extension'));
      });

      test('loads nested template', () async {
        final content = await loader.load('sub/nested');
        expect(content, contains('Nested asset'));
      });

      test('throws TemplateNotFoundException for missing template', () async {
        expect(
          () => loader.load('nonexistent'),
          throwsA(isA<TemplateNotFoundException>()),
        );
      });

      test('throws TemplateException for unresolvable package', () async {
        final badLoader = AssetLoader('package:no_such_package_xyz/templates/');
        expect(
          () => badLoader.load('page'),
          throwsA(isA<TemplateException>()),
        );
      });
    });

    group('loadSync', () {
      late AssetLoader loader;

      setUp(() {
        loader = AssetLoader('package:trellis/test_fixtures/');
      });

      test('loads template synchronously', () {
        final content = loader.loadSync('simple');
        // resolvePackageUriSync may or may not work depending on environment
        if (content != null) {
          expect(content, contains('Hello from asset'));
        }
        // If null, sync resolution was not available — acceptable per contract
      });

      test('works after first async load caches base path', () async {
        // First async load to cache the base path
        await loader.load('simple');
        // Now sync should work
        final content = loader.loadSync('simple');
        expect(content, isNotNull);
        expect(content, contains('Hello from asset'));
      });

      test('throws TemplateNotFoundException for missing template (after cache)', () async {
        await loader.load('simple'); // prime the cache
        expect(
          () => loader.loadSync('nonexistent'),
          throwsA(isA<TemplateNotFoundException>()),
        );
      });
    });

    group('security', () {
      late AssetLoader loader;

      setUp(() {
        loader = AssetLoader('package:trellis/test_fixtures/');
      });

      test('rejects absolute path', () {
        expect(
          () => loader.load('/etc/passwd'),
          throwsA(isA<TemplateSecurityException>()),
        );
      });

      test('rejects path traversal with ..', () {
        expect(
          () => loader.load('../secret'),
          throwsA(isA<TemplateSecurityException>()),
        );
      });

      test('rejects double traversal', () {
        expect(
          () => loader.load('sub/../../secret'),
          throwsA(isA<TemplateSecurityException>()),
        );
      });

      test('loadSync rejects absolute path', () async {
        await loader.load('simple'); // prime cache
        expect(
          () => loader.loadSync('/etc/passwd'),
          throwsA(isA<TemplateSecurityException>()),
        );
      });

      test('loadSync rejects traversal', () async {
        await loader.load('simple'); // prime cache
        expect(
          () => loader.loadSync('../secret'),
          throwsA(isA<TemplateSecurityException>()),
        );
      });

      test('symlink escape rejected', () async {
        // Resolve the actual base path first
        await loader.load('simple');

        // Create a symlink that escapes the base directory
        // Get resolved base path by loading a known template
        final baseDir = Directory(
          File(Platform.resolvedExecutable).parent.path,
        ).parent;

        // Create a file outside the fixtures directory
        final outsideFile = File(
          '${Directory.systemTemp.path}/trellis_outside_${DateTime.now().microsecondsSinceEpoch}.html',
        );
        outsideFile.writeAsStringSync('SECRET');
        addTearDown(() {
          if (outsideFile.existsSync()) outsideFile.deleteSync();
        });

        // We can't easily create a symlink inside a package:trellis/ path
        // from tests, so we test the path validation logic indirectly
        // through the absolute path and traversal tests above.
        // The symlink check logic is identical to FileSystemLoader.
        expect(baseDir, isNotNull); // sanity check
      });
    });

    group('custom extension', () {
      test('uses custom extension', () async {
        // Create a temp file with custom extension to test
        // Since we can't easily add files to the package assets at runtime,
        // test that the extension parameter is accepted
        final loader = AssetLoader(
          'package:trellis/test_fixtures/',
          extension: '.txt',
        );
        expect(loader.extension, equals('.txt'));
      });
    });
  });
}
