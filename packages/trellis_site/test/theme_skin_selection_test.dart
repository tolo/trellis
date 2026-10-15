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
          isA<ArgumentError>().having((e) => e.message, 'message', "Unknown skin 'foo'. Available: light, dark, auto"),
        ),
      );
    });
  });

  group('ThemeSassGenerator — skin validation', () {
    late Directory tempDir;
    late String themeDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trellis_skin_test_');
      themeDir = p.join(tempDir.path, 'themes', 'my-theme');
      Directory(p.join(themeDir, 'sass', '_skins')).createSync(recursive: true);
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    for (final skin in ['light', 'dark', 'auto']) {
      test('skin: $skin is accepted', () {
        expect(() => _generate(tempDir.path, themeDir, skin), returnsNormally);
      });
    }

    test('an unknown skin value is rejected before any theme compile', () {
      expect(
        () => _generate(tempDir.path, themeDir, 'invalid'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains("Unknown skin 'invalid'"))),
      );
    });
  });
}

ThemeBuildConfig _generate(String siteDir, String? themeDir, String skin) {
  const gen = ThemeSassGenerator();
  return gen.generate(mergedParams: {'skin': skin}, paramTypes: {'skin': 'enum'}, siteDir: siteDir, themeDir: themeDir);
}
