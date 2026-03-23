import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

void main() {
  group('SkinMode.parse', () {
    test('parses light', () => expect(SkinMode.parse('light'), SkinMode.light));
    test('parses dark', () => expect(SkinMode.parse('dark'), SkinMode.dark));
    test('parses auto', () => expect(SkinMode.parse('auto'), SkinMode.auto));

    test('unknown value throws ArgumentError with clear message', () {
      expect(
        () => SkinMode.parse('foo'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            "Unknown skin 'foo'. Available: light, dark, auto",
          ),
        ),
      );
    });
  });

  group('ThemeSassGenerator — skin mode resolution', () {
    late Directory tempDir;
    late String themeDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_skin_test_');
      themeDir = p.join(tempDir.path, 'themes', 'my-theme');
      Directory(p.join(themeDir, 'sass', '_skins')).createSync(recursive: true);
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('skin: light resolves to SkinMode.light', () {
      final config = _generate(tempDir.path, themeDir, 'light');
      expect(config.skinMode, SkinMode.light);
    });

    test('skin: dark resolves to SkinMode.dark', () {
      final config = _generate(tempDir.path, themeDir, 'dark');
      expect(config.skinMode, SkinMode.dark);
    });

    test('skin: auto resolves to SkinMode.auto', () {
      final config = _generate(tempDir.path, themeDir, 'auto');
      expect(config.skinMode, SkinMode.auto);
    });

    test('invalid skin value throws ArgumentError', () {
      expect(() => SkinMode.parse('invalid'), throwsA(isA<ArgumentError>()));
    });
  });
}

ThemeBuildConfig _generate(String siteDir, String? themeDir, String skin) {
  const gen = ThemeSassGenerator();
  return gen.generate(
    mergedParams: {'skin': skin},
    paramTypes: {'skin': 'enum'},
    siteDir: siteDir,
    themeDir: themeDir,
  );
}
