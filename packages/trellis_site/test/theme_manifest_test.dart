import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

late String _fixtureDir;

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _fixtureDir = p.join(packageRoot, 'test', 'test_fixtures');
  });

  String validThemeDir() => p.join(_fixtureDir, 'themes', 'valid_theme');
  String minimalThemeDir() => p.join(_fixtureDir, 'themes', 'minimal_theme');
  String malformedThemeDir() => p.join(_fixtureDir, 'themes', 'malformed_theme');

  group('ThemeManifestException', () {
    test('toString includes message', () {
      const ex = ThemeManifestException('Theme not found');
      expect(ex.toString(), contains('Theme not found'));
    });

    test('toString includes themeDir when provided', () {
      const ex = ThemeManifestException('Theme not found', themeDir: '/themes/verdant');
      expect(ex.toString(), contains('/themes/verdant'));
    });

    test('toString works without themeDir', () {
      const ex = ThemeManifestException('Theme not found');
      expect(ex.toString(), startsWith('ThemeManifestException: Theme not found'));
    });
  });

  group('ThemeManifest.load() — valid manifest', () {
    test('parses name and version', () {
      final manifest = ThemeManifest.load(validThemeDir());
      expect(manifest.name, equals('valid-theme'));
      expect(manifest.version, equals('1.0.0'));
    });

    test('parses author and description', () {
      final manifest = ThemeManifest.load(validThemeDir());
      expect(manifest.author, equals('Test Author'));
      expect(manifest.description, equals('A test theme'));
    });

    test('parses min_trellis_version', () {
      final manifest = ThemeManifest.load(validThemeDir());
      expect(manifest.minTrellisVersion, equals('0.8.0'));
    });

    test('parses screenshots list', () {
      final manifest = ThemeManifest.load(validThemeDir());
      expect(manifest.screenshots, equals(['screenshots/light.png']));
    });

    test('parses features list', () {
      final manifest = ThemeManifest.load(validThemeDir());
      expect(manifest.features, containsAll(['blog', 'dark-mode']));
    });

    test('parses string param with type, default, and description', () {
      final manifest = ThemeManifest.load(validThemeDir());
      final param = manifest.params['primary_color']!;
      expect(param.type, equals('color'));
      expect(param.defaultValue, equals('#2563eb'));
      expect(param.description, equals('Brand accent color'));
    });

    test('parses enum param with values list', () {
      final manifest = ThemeManifest.load(validThemeDir());
      final param = manifest.params['skin']!;
      expect(param.type, equals('enum'));
      expect(param.defaultValue, equals('auto'));
      expect(param.enumValues, equals(['light', 'dark', 'auto']));
    });

    test('enum param has enumValues, other params do not', () {
      final manifest = ThemeManifest.load(validThemeDir());
      expect(manifest.params['skin']!.enumValues, isNotNull);
      expect(manifest.params['primary_color']!.enumValues, isNull);
    });

    test('parses boolean param', () {
      final manifest = ThemeManifest.load(validThemeDir());
      final param = manifest.params['show_powered_by']!;
      expect(param.type, equals('boolean'));
      expect(param.defaultValue, equals(true));
    });

    test('parses list param with empty default', () {
      final manifest = ThemeManifest.load(validThemeDir());
      final param = manifest.params['nav_links']!;
      expect(param.type, equals('list'));
      expect(param.defaultValue, equals([]));
    });

    test('parses map param with nested defaults', () {
      final manifest = ThemeManifest.load(validThemeDir());
      final param = manifest.params['social']!;
      expect(param.type, equals('map'));
      expect(param.defaultValue, isA<Map<String, dynamic>>());
      expect((param.defaultValue as Map)['github'], equals(''));
    });

    test('themeDir is the canonicalized directory', () {
      final manifest = ThemeManifest.load(validThemeDir());
      expect(manifest.themeDir, equals(p.canonicalize(validThemeDir())));
    });

    test('defaultParams getter returns correct defaults map', () {
      final manifest = ThemeManifest.load(validThemeDir());
      final defaults = manifest.defaultParams;
      expect(defaults['skin'], equals('auto'));
      expect(defaults['primary_color'], equals('#2563eb'));
      expect(defaults['show_powered_by'], equals(true));
      expect(defaults['nav_links'], equals([]));
    });
  });

  group('ThemeManifest.load() — minimal manifest', () {
    test('parses name and version only', () {
      final manifest = ThemeManifest.load(minimalThemeDir());
      expect(manifest.name, equals('minimal'));
      expect(manifest.version, equals('0.1.0'));
    });

    test('optional fields default to null or empty', () {
      final manifest = ThemeManifest.load(minimalThemeDir());
      expect(manifest.author, isNull);
      expect(manifest.description, isNull);
      expect(manifest.minTrellisVersion, isNull);
      expect(manifest.screenshots, isEmpty);
      expect(manifest.features, isEmpty);
      expect(manifest.params, isEmpty);
    });

    test('defaultParams is empty for manifest with no params', () {
      final manifest = ThemeManifest.load(minimalThemeDir());
      expect(manifest.defaultParams, isEmpty);
    });
  });

  group('ThemeManifest.load() — error cases', () {
    test('missing theme directory throws ThemeManifestException with "not found"', () {
      expect(
        () => ThemeManifest.load('/no/such/theme/dir'),
        throwsA(
          isA<ThemeManifestException>().having(
            (e) => e.message,
            'message',
            contains('not found'),
          ),
        ),
      );
    });

    test('missing theme.yaml throws ThemeManifestException', () {
      final tempDir = Directory.systemTemp.createTempSync('theme_no_yaml_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      expect(
        () => ThemeManifest.load(tempDir.path),
        throwsA(
          isA<ThemeManifestException>().having(
            (e) => e.message,
            'message',
            contains('manifest not found'),
          ),
        ),
      );
    });

    test('malformed YAML throws ThemeManifestException with "Invalid YAML"', () {
      expect(
        () => ThemeManifest.load(malformedThemeDir()),
        throwsA(
          isA<ThemeManifestException>().having(
            (e) => e.message,
            'message',
            contains('Invalid YAML'),
          ),
        ),
      );
    });

    test('missing name field throws ThemeManifestException', () {
      final tempDir = Directory.systemTemp.createTempSync('theme_no_name_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File(p.join(tempDir.path, 'theme.yaml')).writeAsStringSync('version: 1.0.0\n');

      expect(
        () => ThemeManifest.load(tempDir.path),
        throwsA(
          isA<ThemeManifestException>().having(
            (e) => e.message,
            'message',
            contains('missing required field: name'),
          ),
        ),
      );
    });

    test('missing version field throws ThemeManifestException', () {
      final tempDir = Directory.systemTemp.createTempSync('theme_no_version_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File(p.join(tempDir.path, 'theme.yaml')).writeAsStringSync('name: my-theme\n');

      expect(
        () => ThemeManifest.load(tempDir.path),
        throwsA(
          isA<ThemeManifestException>().having(
            (e) => e.message,
            'message',
            contains('missing required field: version'),
          ),
        ),
      );
    });

    test('param without explicit type defaults to string', () {
      final tempDir = Directory.systemTemp.createTempSync('theme_param_type_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File(p.join(tempDir.path, 'theme.yaml')).writeAsStringSync('''
name: test
version: 1.0.0
params:
  my_param:
    default: hello
''');

      final manifest = ThemeManifest.load(tempDir.path);
      expect(manifest.params['my_param']!.type, equals('string'));
    });

    test('empty params section produces empty params map', () {
      final tempDir = Directory.systemTemp.createTempSync('theme_empty_params_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File(p.join(tempDir.path, 'theme.yaml')).writeAsStringSync('''
name: test
version: 1.0.0
params:
''');

      final manifest = ThemeManifest.load(tempDir.path);
      expect(manifest.params, isEmpty);
    });

    test('no params section produces empty params map', () {
      final manifest = ThemeManifest.load(minimalThemeDir());
      expect(manifest.params, isEmpty);
    });
  });
}
