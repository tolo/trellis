import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

void main() {
  test('writes the three assets, rewrites divergent files and fails naming an unwritable path', () async {
    final temp = Directory.systemTemp.createTempSync('trellis-ui-materialize-');
    addTearDown(() => temp.deleteSync(recursive: true));

    final target = p.join(temp.path, 'trellis-ui');
    Future<ProcessResult> run(String path) =>
        Process.run(Platform.resolvedExecutable, ['run', 'bin/materialize.dart', path]);

    final initial = await run(target);
    expect(initial.exitCode, 0, reason: '${initial.stderr}');

    void expectEmbeddedAssets() {
      const names = ['trellis-ui.css', 'trellis-ui.js', 'htmx-indicator.css'];
      expect(Directory(target).listSync().map((file) => p.basename(file.path)), unorderedEquals(names));
      for (final name in names) {
        final digest = sha256.convert(File(p.join(target, name)).readAsBytesSync());
        expect('"$digest"', trellisUiRespond('/trellis-ui/$name')!.headers['etag'], reason: name);
      }
    }

    expectEmbeddedAssets();
    File(p.join(target, 'trellis-ui.js')).writeAsStringSync('stale');
    final repair = await run(target);
    expect(repair.exitCode, 0, reason: '${repair.stderr}');
    expectEmbeddedAssets();

    final blocked = p.join(temp.path, 'blocked');
    File(blocked).createSync();
    final failure = await run(blocked);
    expect(failure.exitCode, isNonZero);
    expect(failure.stderr, contains(blocked));
  });
}
