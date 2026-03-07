import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('close()', () {
    test('Trellis with MapLoader (devMode: false) — close() completes', () async {
      final engine = Trellis(loader: MapLoader({'test': '<p>hello</p>'}), devMode: false);
      await engine.close();
    });

    test('Trellis with MapLoader (devMode: true) — close() completes', () async {
      final engine = Trellis(loader: MapLoader({}), devMode: true);
      await engine.close();
    });

    test('Trellis with FileSystemLoader (devMode: true) — closes cleanly', () async {
      final tempDir = Directory.systemTemp.createTempSync('trellis_close_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final engine = Trellis(loader: FileSystemLoader(tempDir.path, devMode: true), devMode: true);
      await engine.close();
    });

    test('engine.close() delegates to FileSystemLoader.close() — changes stream emits done', () async {
      final tempDir = Directory.systemTemp.createTempSync('trellis_close_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final loader = FileSystemLoader(tempDir.path, devMode: true);
      final engine = Trellis(loader: loader, devMode: true);

      expect(loader.changes, isNotNull);

      final done = Completer<void>();
      loader.changes!.listen((_) {}, onDone: done.complete);

      await engine.close();

      await done.future.timeout(const Duration(seconds: 1));
    });

    test('double engine.close() does not throw', () async {
      final tempDir = Directory.systemTemp.createTempSync('trellis_close_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final engine = Trellis(loader: FileSystemLoader(tempDir.path, devMode: true), devMode: true);

      await engine.close();
      await engine.close();
    });
  });
}
