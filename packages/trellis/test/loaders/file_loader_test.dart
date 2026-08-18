import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

/// Why the unwatchable-directory test cannot run here, or `null` when it can: only Linux takes the
/// per-directory watch path, and root ignores the directory permissions the test relies on to make the
/// OS refuse a watch.
final String? _unwatchableDirSkip = !Platform.isLinux
    ? 'per-directory watching, and this failure mode, are Linux-only'
    : Process.runSync('id', ['-u']).stdout.toString().trim() == '0'
    ? 'running as root — directory permissions do not stop root from watching'
    : null;

/// Exit code the fixture never produces itself, standing in for "still running when we gave up".
const _fixtureTimedOut = -1;

/// Absolute path of the `trellis` package root, so a fixture path resolves regardless of the
/// directory `dart test` was invoked from (the package dir under melos, the workspace root by hand).
Future<String> _packageRoot() async {
  final libUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis/trellis.dart'));
  return libUri == null ? Directory.current.path : File.fromUri(libUri).parent.parent.path;
}

/// Captures `dart:io` [stderr] writes during [body] — the loader's watch-failure warning has no
/// injectable sink, so `IOOverrides` is the seam.
Future<String> _captureStderr(Future<void> Function() body) async {
  final buffer = StringBuffer();
  await IOOverrides.runZoned(body, stderr: () => _BufferStdout(buffer));
  return buffer.toString();
}

class _BufferStdout implements Stdout {
  _BufferStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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

      test('listTemplates omits symlinks load() would reject', () {
        // listTemplates() is the discovery half of load(): warmUpAll() and trellis_dev's validator
        // load every name it returns, so a name that load() rejects turns into a spurious failure.
        final outside = Directory('${tempDir.parent.path}/trellis_outside_${tempDir.path.hashCode}');
        outside.createSync();
        addTearDown(() => outside.deleteSync(recursive: true));
        File('${outside.path}/secret.html').writeAsStringSync('SECRET');

        Link('${tempDir.path}/escaping_file.html').createSync('${outside.path}/secret.html');
        Link('${tempDir.path}/escaping_dir').createSync(outside.path);

        expect(loader.listTemplates(), ['explicit', 'page', 'sub/nested']);
        expect(() => loader.load('escaping_file'), throwsA(isA<TemplateSecurityException>()));
        expect(() => loader.load('escaping_dir/secret'), throwsA(isA<TemplateSecurityException>()));
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

  group('FileSystemLoader devMode', () {
    late Directory tempDir;
    late FileSystemLoader loader;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_devmode_test_');
    });

    tearDown(() async {
      await loader.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('devMode: false — changes returns null', () {
      loader = FileSystemLoader(tempDir.path);
      expect(loader.changes, isNull);
    });

    test('devMode: true — changes returns non-null stream', () {
      loader = FileSystemLoader(tempDir.path, devMode: true);
      expect(loader.changes, isNotNull);
    });

    test('modifying .html file emits event', () async {
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Original</p>');
      loader = FileSystemLoader(tempDir.path, devMode: true);

      final future = loader.changes!.first.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Modified</p>');

      await expectLater(future, completes);
    });

    test('creating new .html file emits event', () async {
      loader = FileSystemLoader(tempDir.path, devMode: true);

      final future = loader.changes!.first.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      File('${tempDir.path}/new_page.html').writeAsStringSync('<p>New</p>');

      await expectLater(future, completes);
    });

    test('deleting .html file emits event', () async {
      final file = File('${tempDir.path}/to_delete.html');
      file.writeAsStringSync('<p>Delete me</p>');
      loader = FileSystemLoader(tempDir.path, devMode: true);

      final future = loader.changes!.first.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      file.deleteSync();

      await expectLater(future, completes);
    });

    test('modifying .css file does NOT emit', () async {
      final cssFile = File('${tempDir.path}/style.css');
      cssFile.writeAsStringSync('body {}');
      loader = FileSystemLoader(tempDir.path, devMode: true);

      var emitted = false;
      final sub = loader.changes!.listen((_) => emitted = true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cssFile.writeAsStringSync('body { color: red; }');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(emitted, isFalse);
      await sub.cancel();
    });

    test('close() cancels subscription', () async {
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Hello</p>');
      loader = FileSystemLoader(tempDir.path, devMode: true);

      var emitted = false;
      final sub = loader.changes!.listen((_) => emitted = true);
      await loader.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      File('${tempDir.path}/page.html').writeAsStringSync('<p>Changed</p>');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(emitted, isFalse);
      await sub.cancel();
    });

    test('double close() does not throw', () async {
      loader = FileSystemLoader(tempDir.path, devMode: true);
      await loader.close();
      await loader.close();
    });

    // Nested watching is the platform gap TD-013 closed: dart:io's `recursive: true` is a no-op on
    // Linux (inotify), so the loader watches each directory itself there. These three tests are the
    // regression guard and must pass on every OS.
    test('nested subdirectory file change detected', () async {
      final subDir = Directory('${tempDir.path}/deep/nested');
      subDir.createSync(recursive: true);
      File('${subDir.path}/page.html').writeAsStringSync('<p>Nested</p>');
      loader = FileSystemLoader(tempDir.path, devMode: true);

      final future = loader.changes!.first.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      File('${subDir.path}/page.html').writeAsStringSync('<p>Updated</p>');

      await expectLater(future, completes);
    });

    test('subdirectory created after watching starts is watched', () async {
      loader = FileSystemLoader(tempDir.path, devMode: true);

      // The new subtree itself is a change (it arrives carrying a template)…
      final created = loader.changes!.first.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final lateDir = Directory('${tempDir.path}/late/deep')..createSync(recursive: true);
      final lateFile = File('${lateDir.path}/page.html')..writeAsStringSync('<p>Late</p>');
      await expectLater(created, completes);

      // …and edits inside it keep being reported, i.e. it really is watched, not just scanned once.
      final edited = loader.changes!.first.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      lateFile.writeAsStringSync('<p>Updated</p>');

      await expectLater(edited, completes);
    });

    test('unwatchable directory warns once instead of failing silently', () async {
      // A watch the OS refuses (here: an unreadable directory; in the wild: the inotify limit) caps
      // hot reload for everything below it. Silence is what made TD-013 expensive, so it must warn.
      final blocked = Directory('${tempDir.path}/blocked')..createSync();
      File('${blocked.path}/page.html').writeAsStringSync('<p>Blocked</p>');
      Process.runSync('chmod', ['000', blocked.path]);
      addTearDown(() => Process.runSync('chmod', ['755', blocked.path]));

      final warning = await _captureStderr(() async {
        loader = FileSystemLoader(tempDir.path, devMode: true);
        // The watch error surfaces asynchronously, on the stream rather than from the constructor.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      expect(warning, contains('could not watch template directory'));
      expect(warning, contains('blocked'));
      expect(warning, contains('max_user_watches'));
    }, skip: _unwatchableDirSkip);

    test('close() releases every watch, not just the base one', () async {
      // Proven out of process: a live watch keeps the VM alive, so a subscription `close()` missed
      // shows up as a fixture that never exits. In-process the leak is invisible — `close()` drops the
      // controller, so a leaked watch has nothing to emit into.
      Directory('${tempDir.path}/deep/nested').createSync(recursive: true);
      File('${tempDir.path}/deep/nested/page.html').writeAsStringSync('<p>Nested</p>');
      loader = FileSystemLoader(tempDir.path); // devMode: false — the fixture owns the watching.

      final fixture = await Process.start('dart', [
        'run',
        'test/loaders/close_releases_watches_fixture.dart',
        tempDir.path,
      ], workingDirectory: await _packageRoot());
      final stdoutText = fixture.stdout.transform(const SystemEncoding().decoder).join();
      final stderrText = fixture.stderr.transform(const SystemEncoding().decoder).join();

      final exitCode = await fixture.exitCode.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          fixture.kill();
          return _fixtureTimedOut;
        },
      );
      expect(
        exitCode,
        0,
        reason: exitCode == _fixtureTimedOut
            ? 'fixture never exited — a watch outlived close() and kept the VM alive'
            : 'fixture exited $exitCode:\n${await stderrText}',
      );
      expect(await stdoutText, contains('closed'));
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('close() stops nested-directory events too', () async {
      final subDir = Directory('${tempDir.path}/deep/nested')..createSync(recursive: true);
      final nestedFile = File('${subDir.path}/page.html')..writeAsStringSync('<p>Nested</p>');
      loader = FileSystemLoader(tempDir.path, devMode: true);

      var emitted = false;
      final sub = loader.changes!.listen((_) => emitted = true);
      await loader.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      nestedFile.writeAsStringSync('<p>Changed</p>');
      File('${tempDir.path}/root.html').writeAsStringSync('<p>Root</p>');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(emitted, isFalse);
      await sub.cancel();
    });
  });
}
