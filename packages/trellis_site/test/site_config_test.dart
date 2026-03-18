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

  String buildSiteConfig() => p.join(_fixtureDir, 'build_site', 'trellis_site.yaml');

  group('SiteConfigException', () {
    test('toString includes message', () {
      const ex = SiteConfigException('Not found');
      expect(ex.toString(), contains('Not found'));
    });

    test('toString includes configPath when provided', () {
      const ex = SiteConfigException('Not found', configPath: '/my/site.yaml');
      expect(ex.toString(), contains('/my/site.yaml'));
    });

    test('toString works without configPath', () {
      const ex = SiteConfigException('Not found');
      expect(ex.toString(), startsWith('SiteConfigException: Not found'));
    });
  });

  group('SiteConfig factory constructor', () {
    test('resolves relative contentDir to absolute', () {
      final config = SiteConfig(siteDir: '/my/site', contentDir: 'content');
      expect(config.contentDir, equals('/my/site/content'));
    });

    test('preserves absolute contentDir', () {
      final config = SiteConfig(siteDir: '/my/site', contentDir: '/absolute/content');
      expect(config.contentDir, equals('/absolute/content'));
    });

    test('defaults contentDir to siteDir/content', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.contentDir, equals('/my/site/content'));
    });

    test('defaults outputDir to siteDir/output', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.outputDir, equals('/my/site/output'));
    });

    test('defaults layoutsDir to siteDir/layouts', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.layoutsDir, equals('/my/site/layouts'));
    });

    test('defaults staticDir to siteDir/static', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.staticDir, equals('/my/site/static'));
    });

    test('defaults dataDir to siteDir/data', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.dataDir, equals('/my/site/data'));
    });

    test('paginate defaults to null', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.paginate, isNull);
    });

    test('taxonomies defaults to empty list', () {
      final config = SiteConfig(siteDir: '/my/site');
      expect(config.taxonomies, isEmpty);
    });
  });

  group('SiteConfig.load()', () {
    test('loads valid config with all fields', () {
      final config = SiteConfig.load(buildSiteConfig());
      expect(config.title, equals('Test Site'));
      expect(config.baseUrl, equals('https://example.com'));
      expect(config.description, equals('A test site'));
    });

    test('resolves relative directory fields to absolute paths', () {
      final config = SiteConfig.load(buildSiteConfig());
      final siteDir = p.dirname(p.canonicalize(buildSiteConfig()));
      expect(config.contentDir, equals(p.join(siteDir, 'content')));
      expect(config.layoutsDir, equals(p.join(siteDir, 'layouts')));
      expect(config.outputDir, equals(p.join(siteDir, 'output')));
    });

    test('siteDir is the config file parent directory', () {
      final config = SiteConfig.load(buildSiteConfig());
      final expected = p.dirname(p.canonicalize(buildSiteConfig()));
      expect(config.siteDir, equals(expected));
    });

    test('params parsed as Map<String, dynamic>', () {
      final config = SiteConfig.load(buildSiteConfig());
      expect(config.params, isA<Map<String, dynamic>>());
      expect(config.params['author'], equals('Test Author'));
    });

    test('missing config file throws SiteConfigException', () {
      expect(() => SiteConfig.load('/no/such/file/trellis_site.yaml'), throwsA(isA<SiteConfigException>()));
    });

    test('SiteConfigException includes the config path', () {
      try {
        SiteConfig.load('/no/such/file/trellis_site.yaml');
        fail('Expected SiteConfigException');
      } on SiteConfigException catch (e) {
        expect(e.configPath, isNotNull);
        expect(e.toString(), contains('trellis_site.yaml'));
      }
    });

    test('empty YAML file uses defaults', () {
      final tempDir = Directory.systemTemp.createTempSync('site_cfg_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final configFile = File(p.join(tempDir.path, 'trellis_site.yaml'))..writeAsStringSync('');

      final config = SiteConfig.load(configFile.path);
      expect(config.title, equals(''));
      expect(config.taxonomies, isEmpty);
      expect(config.paginate, isNull);
    });

    test('invalid YAML throws SiteConfigException', () {
      final tempDir = Directory.systemTemp.createTempSync('site_cfg_invalid_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final configFile = File(p.join(tempDir.path, 'trellis_site.yaml'))
        ..writeAsStringSync(': invalid: yaml: here\n  bad indent');

      expect(() => SiteConfig.load(configFile.path), throwsA(isA<SiteConfigException>()));
    });

    test('taxonomies parsed as List<String>', () {
      final tempDir = Directory.systemTemp.createTempSync('site_cfg_tax_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final configFile = File(p.join(tempDir.path, 'trellis_site.yaml'))
        ..writeAsStringSync('taxonomies:\n  - tags\n  - categories\n');

      final config = SiteConfig.load(configFile.path);
      expect(config.taxonomies, equals(['tags', 'categories']));
    });

    test('paginate parsed as int', () {
      final tempDir = Directory.systemTemp.createTempSync('site_cfg_pag_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final configFile = File(p.join(tempDir.path, 'trellis_site.yaml'))..writeAsStringSync('paginate: 10\n');

      final config = SiteConfig.load(configFile.path);
      expect(config.paginate, equals(10));
    });

    test('missing optional fields use defaults', () {
      final tempDir = Directory.systemTemp.createTempSync('site_cfg_min_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final configFile = File(p.join(tempDir.path, 'trellis_site.yaml'))..writeAsStringSync('title: Minimal\n');

      final config = SiteConfig.load(configFile.path);
      expect(config.title, equals('Minimal'));
      expect(config.baseUrl, equals(''));
      expect(config.description, equals(''));
      expect(config.params, isEmpty);
      expect(config.taxonomies, isEmpty);
      expect(config.paginate, isNull);
    });
  });
}
