import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('loader template discovery', () {
    test('FileSystemLoader lists templates recursively without extension', () {
      final tempDir = Directory.systemTemp.createTempSync('trellis_list_templates_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File('${tempDir.path}/home.html').writeAsStringSync('<p>Home</p>');
      File('${tempDir.path}/ignore.txt').writeAsStringSync('ignore');
      Directory('${tempDir.path}/sub').createSync();
      File('${tempDir.path}/sub/about.html').writeAsStringSync('<p>About</p>');

      final loader = FileSystemLoader(tempDir.path);

      expect(loader.listTemplates(), ['home', 'sub/about']);
    });

    test('MapLoader returns stored keys', () {
      final loader = MapLoader({'home': '<p>Home</p>', 'about': '<p>About</p>'});

      expect(loader.listTemplates().toSet(), {'home', 'about'});
    });
  });

  group('warmUp', () {
    test('loads templates into cache and does not double count existing entries', () async {
      final engine = Trellis(loader: MapLoader({'home': '<p>Home</p>', 'about': '<p>About</p>'}));

      final result = await engine.warmUp(['home', 'about', 'home']);

      expect(result, const WarmUpResult(loaded: 2));
      expect(engine.cacheStats.size, 2);
    });

    test('reports partial failures', () async {
      final engine = Trellis(loader: MapLoader({'home': '<p>Home</p>'}));

      final result = await engine.warmUp(['home', 'missing']);

      expect(result.loaded, 1);
      expect(result.failed, hasLength(1));
      expect(result.failed.first.$1, 'missing');
      expect(result.failed.first.$2, isA<TemplateNotFoundException>());
    });

    test('throws when cache is disabled', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);

      expect(() => engine.warmUp(['home']), throwsA(isA<StateError>()));
    });

    test('counts evictions when warm-up exceeds cache size', () async {
      final engine = Trellis(loader: MapLoader({'a': '<p>A</p>', 'b': '<p>B</p>', 'c': '<p>C</p>'}), maxCacheSize: 2);

      final result = await engine.warmUp(['a', 'b', 'c']);

      expect(result.loaded, 3);
      expect(result.evicted, 1);
      expect(engine.cacheStats.size, 2);
    });
  });

  group('warmUpAll', () {
    test('discovers templates from MapLoader', () async {
      final engine = Trellis(loader: MapLoader({'home': '<p>Home</p>', 'about': '<p>About</p>'}));

      final result = await engine.warmUpAll();

      expect(result.loaded, 2);
      expect(engine.cacheStats.size, 2);
    });

    test('discovers templates from FileSystemLoader', () async {
      final tempDir = Directory.systemTemp.createTempSync('trellis_warm_up_all_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File('${tempDir.path}/home.html').writeAsStringSync('<p>Home</p>');
      Directory('${tempDir.path}/sub').createSync();
      File('${tempDir.path}/sub/about.html').writeAsStringSync('<p>About</p>');

      final engine = Trellis(loader: FileSystemLoader(tempDir.path));

      final result = await engine.warmUpAll();

      expect(result.loaded, 2);
      expect(engine.cacheStats.size, 2);
    });

    test('throws on unsupported loader', () {
      final engine = Trellis(
        loader: CompositeLoader([
          MapLoader({'home': '<p>Home</p>'}),
        ]),
      );

      expect(engine.warmUpAll, throwsA(isA<UnsupportedError>()));
    });
  });
}
