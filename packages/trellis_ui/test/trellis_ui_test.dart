import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

void main() {
  test('unknown suite names fail with the engine exceptions', () {
    final engine = Trellis(loader: CompositeLoader([MapLoader({}), TrellisUiLoader()]));
    expect(
      () => engine.render('<div tl:replace="~{trellis-ui/button :: nonexistent}"></div>', {}),
      throwsA(isA<FragmentNotFoundException>()),
    );
    expect(
      () => engine.render('<div tl:replace="~{trellis-ui/nonexistent :: button}"></div>', {}),
      throwsA(isA<TemplateNotFoundException>()),
    );
    expect(TrellisUiLoader().loadSync('trellis-ui/button.html'), TrellisUiLoader().loadSync('trellis-ui/button'));
  });

  test('respond serves bytes, content type and ETag and answers 304', () {
    for (final name in ['trellis-ui.css', 'trellis-ui.js', 'htmx-indicator.css']) {
      final response = trellisUiRespond('/trellis-ui/$name')!;
      expect(response.statusCode, 200);
      expect(response.body, isNotEmpty);
      expect(
        response.headers['content-type'],
        name.endsWith('.css') ? 'text/css; charset=utf-8' : 'text/javascript; charset=utf-8',
      );
      final digest = sha256.convert(response.body).toString();
      expect(response.headers['etag'], '"$digest"');
      for (final condition in ['"$digest"', 'W/"$digest"', '"other", "$digest"', '*']) {
        final conditional = trellisUiRespond('/trellis-ui/$name', ifNoneMatch: condition)!;
        expect(conditional.statusCode, 304);
        expect(conditional.body, isEmpty);
        expect(conditional.headers['etag'], response.headers['etag']);
      }
      expect(trellisUiRespond('/trellis-ui/$name', ifNoneMatch: '"other"')!.statusCode, 200);
    }
  });

  test('respond ignores paths outside the suite', () {
    for (final path in ['/other.css', '/trellis-ui/nope.css', '/trellis-ui/../trellis-ui.css', '/trellis-ui.css']) {
      expect(trellisUiRespond(path), isNull, reason: path);
    }
  });

  test('materialize overwrites divergent files, creates the directory and names the path on failure', () {
    final temp = Directory.systemTemp.createTempSync('suite_materialize_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final target = Directory('${temp.path}/assets');
    materializeTrellisUi(target);
    File('${target.path}/trellis-ui.css').writeAsStringSync('stale');
    File('${target.path}/trellis-ui.js').writeAsStringSync('hand edit');
    materializeTrellisUi(target);
    for (final name in ['trellis-ui.css', 'trellis-ui.js', 'htmx-indicator.css']) {
      final file = File('${target.path}/$name');
      expect(file.readAsBytesSync(), trellisUiRespond('/trellis-ui/$name')!.body);
      file.setLastModifiedSync(DateTime.utc(2000));
      final stamp = file.lastModifiedSync();
      materializeTrellisUi(target);
      expect(file.lastModifiedSync(), stamp, reason: 'equal files must not be rewritten');
    }
    final blocked = File('${temp.path}/blocked')..writeAsStringSync('not a directory');
    expect(
      () => materializeTrellisUi(Directory('${blocked.path}/assets')),
      throwsA(isA<FileSystemException>().having((e) => '$e', 'path', contains(blocked.path))),
    );
  });
}
