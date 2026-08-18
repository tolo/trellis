import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

void main() {
  group('ThemeConfig', () {
    test('const constructor stores all fields', () {
      const config = ThemeConfig(name: 'verdant', ref: 'v1.0.0', params: {'skin': 'dark'});
      expect(config.name, equals('verdant'));
      expect(config.ref, equals('v1.0.0'));
      expect(config.params, equals({'skin': 'dark'}));
    });

    test('ref defaults to null', () {
      const config = ThemeConfig(name: 'verdant');
      expect(config.ref, isNull);
    });

    test('params defaults to empty map', () {
      const config = ThemeConfig(name: 'verdant');
      expect(config.params, isEmpty);
    });
  });

  group('SiteConfig.load() — theme config parsing', () {
    SiteConfig loadFromYaml(String yaml) {
      final tempDir = Directory.systemTemp.createTempSync('theme_cfg_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final configFile = File(p.join(tempDir.path, 'trellis_site.yaml'))..writeAsStringSync(yaml);
      return SiteConfig.load(configFile.path);
    }

    test('theme: and theme_params: populate themeConfig', () {
      final config = loadFromYaml('''
theme: verdant
theme_params:
  primary_color: "#e11d48"
  skin: dark
''');
      expect(config.themeConfig, isNotNull);
      expect(config.themeConfig!.name, equals('verdant'));
      expect(config.themeConfig!.params['primary_color'], equals('#e11d48'));
      expect(config.themeConfig!.params['skin'], equals('dark'));
    });

    test('no theme: produces null themeConfig', () {
      final config = loadFromYaml('title: No Theme\n');
      expect(config.themeConfig, isNull);
    });

    test('theme_ref: parsed as String', () {
      final config = loadFromYaml('theme: verdant\ntheme_ref: v1.2.0\n');
      expect(config.themeConfig!.ref, equals('v1.2.0'));
    });

    test('theme_params: with nested maps converts to plain Map', () {
      final config = loadFromYaml('''
theme: verdant
theme_params:
  social:
    github: tolo
    twitter: ""
''');
      final social = config.themeConfig!.params['social'] as Map<String, dynamic>;
      expect(social['github'], equals('tolo'));
      expect(social, isA<Map<String, dynamic>>());
    });

    test('theme: as non-string throws SiteConfigException', () {
      expect(() => loadFromYaml('theme: 123\n'), throwsA(isA<SiteConfigException>()));
    });

    test('theme: as empty string throws SiteConfigException', () {
      expect(() => loadFromYaml("theme: ''\n"), throwsA(isA<SiteConfigException>()));
    });

    test('theme_params: absent produces empty params map', () {
      final config = loadFromYaml('theme: verdant\n');
      expect(config.themeConfig!.params, isEmpty);
    });

    test('SiteConfig factory constructor preserves themeConfig', () {
      const themeConfig = ThemeConfig(name: 'verdant');
      final config = SiteConfig(siteDir: '/my/site', themeConfig: themeConfig);
      expect(config.themeConfig, equals(themeConfig));
    });

    test('SiteConfig factory constructor defaults themeConfig to null', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.themeConfig, isNull);
    });
  });
}
