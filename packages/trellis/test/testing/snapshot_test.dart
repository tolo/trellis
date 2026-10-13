import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis/testing.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('trellis_test_goldens_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  String goldenPath(String name) => '${tempDir.path}/$name';

  group('compareOrCreateGolden', () {
    test('first run: creates golden file and passes', () {
      final path = goldenPath('first_run.html');
      expect(File(path).existsSync(), isFalse);
      // Should not throw
      compareOrCreateGolden('<h1>Hello</h1>\n', path, createMissing: true);
      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsStringSync(), equals('<h1>Hello</h1>\n'));
    });

    // On CI a created golden would be compared against itself and discarded, so a deleted golden must fail.
    test('missing golden with createMissing false (the CI default): fails and writes nothing', () {
      final path = goldenPath('deleted.html');
      expect(
        () => compareOrCreateGolden('<h1>Hello</h1>\n', path, createMissing: false),
        throwsA(isA<TestFailure>().having((e) => e.message, 'message', contains('Golden file missing: $path'))),
      );
      expect(File(path).existsSync(), isFalse);
    });

    test('match: passes when golden matches rendered output', () {
      final path = goldenPath('match.html');
      File(path).writeAsStringSync('<h1>Hello</h1>\n');
      // Should not throw
      compareOrCreateGolden('<h1>Hello</h1>\n', path);
    });

    test('mismatch: throws on diff', () {
      final path = goldenPath('mismatch.html');
      File(path).writeAsStringSync('<h1>Old Title</h1>\n');
      expect(() => compareOrCreateGolden('<h1>New Title</h1>\n', path), throwsException);
    });

    test('mismatch diff includes expected/actual markers', () {
      final path = goldenPath('diff.html');
      File(path).writeAsStringSync('<h1>Old</h1>\n');
      try {
        compareOrCreateGolden('<h1>New</h1>\n', path);
        fail('Should have thrown');
      } on Exception catch (e) {
        final msg = e.toString();
        expect(msg, contains('---'));
        expect(msg, contains('+++'));
        expect(msg, contains('Old'));
        expect(msg, contains('New'));
      }
    });

    test('mismatch diff includes file path', () {
      final path = goldenPath('path_in_diff.html');
      File(path).writeAsStringSync('<p>A</p>\n');
      try {
        compareOrCreateGolden('<p>B</p>\n', path);
        fail('Should have thrown');
      } on Exception catch (e) {
        expect(e.toString(), contains(path));
      }
    });

    test('mismatch diff includes TRELLIS_UPDATE_GOLDENS hint', () {
      final path = goldenPath('hint.html');
      File(path).writeAsStringSync('<p>A</p>\n');
      try {
        compareOrCreateGolden('<p>B</p>\n', path);
        fail('Should have thrown');
      } on Exception catch (e) {
        expect(e.toString(), contains('TRELLIS_UPDATE_GOLDENS'));
      }
    });

    test('update mode: overwrites golden file and passes', () {
      final path = goldenPath('update.html');
      File(path).writeAsStringSync('<h1>Old</h1>\n');
      // Pass update: true to simulate TRELLIS_UPDATE_GOLDENS=true
      compareOrCreateGolden('<h1>New</h1>\n', path, update: true);
      expect(File(path).readAsStringSync(), equals('<h1>New</h1>\n'));
    });

    test('creates parent directories if needed', () {
      final path = '${tempDir.path}/nested/deep/golden.html';
      compareOrCreateGolden('<p>Hello</p>\n', path, createMissing: true);
      expect(File(path).existsSync(), isTrue);
    });

    test('empty golden file is valid', () {
      final path = goldenPath('empty.html');
      File(path).writeAsStringSync('');
      // Should not throw when actual also empty
      compareOrCreateGolden('', path);
    });
  });

  group('normalizeHtml', () {
    test('produces consistent output', () {
      final html = '<h1>Hello</h1><p>World</p>';
      final normalized = normalizeHtml(html);
      expect(normalized, endsWith('\n'));
    });

    test('round-trip is idempotent', () {
      final html = '<h1>Hello</h1><p>World</p>';
      final once = normalizeHtml(html);
      final twice = normalizeHtml(once);
      expect(twice, equals(once));
    });

    test('appends trailing newline if not present', () {
      final normalized = normalizeHtml('<p>No newline</p>');
      expect(normalized, endsWith('\n'));
    });

    test('does not double-append newline', () {
      final normalized = normalizeHtml('<p>Has newline</p>\n');
      expect(normalized.endsWith('\n\n'), isFalse);
    });
  });

  // The wrappers' tests write their goldens first: creating a missing golden depends on the environment (not on CI),
  // and that behaviour is covered by the compareOrCreateGolden tests above.
  group('expectSnapshot', () {
    test('passes when output matches golden', () async {
      final engine = testEngine(templates: {'page': '<h1 tl:text="\${title}">Default</h1>'});
      final path = goldenPath('es_match.html');
      File(path).writeAsStringSync('<h1>Hello</h1>\n');
      await expectSnapshot(engine, 'page', {'title': 'Hello'}, goldenFile: path);
    });

    test('throws on mismatch', () async {
      final engine = testEngine(templates: {'page': '<h1 tl:text="\${title}">Default</h1>'});
      final path = goldenPath('es_mismatch.html');
      File(path).writeAsStringSync('<h1>First</h1>\n');
      await expectLater(expectSnapshot(engine, 'page', {'title': 'Second'}, goldenFile: path), throwsException);
    });

    test('fragment snapshot renders only specified fragment', () async {
      final engine = testEngine(
        templates: {'page': '<div><p tl:fragment="greeting" tl:text="\${msg}">x</p><footer>ignore</footer></div>'},
      );
      final path = goldenPath('es_fragment.html');
      File(path).writeAsStringSync('<p>Hi</p>\n');
      await expectSnapshot(engine, 'page', {'msg': 'Hi'}, goldenFile: path, fragment: 'greeting');
    });
  });

  group('expectSnapshotFromSource', () {
    test('passes when output matches golden', () {
      final engine = testEngine(templates: {});
      final path = goldenPath('source_match.html');
      File(path).writeAsStringSync('<h1>Hello</h1>\n');
      expectSnapshotFromSource(engine, '<h1 tl:text="\${title}">Default</h1>', {'title': 'Hello'}, goldenFile: path);
    });

    test('throws on mismatch', () {
      final engine = testEngine(templates: {});
      final path = goldenPath('source_mismatch.html');
      File(path).writeAsStringSync('<h1>First</h1>\n');
      expect(
        () => expectSnapshotFromSource(engine, '<h1 tl:text="\${title}">Default</h1>', {
          'title': 'Second',
        }, goldenFile: path),
        throwsException,
      );
    });

    test('fragment snapshot renders only specified fragment', () {
      final engine = testEngine(templates: {});
      final path = goldenPath('fragment_source.html');
      File(path).writeAsStringSync('<p>Hi</p>\n');
      const source = '<div><p tl:fragment="greeting" tl:text="\${msg}">x</p><footer>ignore</footer></div>';
      expectSnapshotFromSource(engine, source, {'msg': 'Hi'}, goldenFile: path, fragment: 'greeting');
    });
  });
}
