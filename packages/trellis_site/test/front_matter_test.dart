import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

late String _fixturesDir;

/// Returns the absolute path to a front_matter test fixture.
String fixture(String name) => p.join(_fixturesDir, name);

/// Creates a minimal [Page] with the given [sourcePath] for test use.
Page makePage(String sourcePath) => Page(
  sourcePath: sourcePath,
  url: '/$sourcePath/',
  section: '',
  kind: PageKind.single,
  isDraft: false,
  isBundle: false,
  bundleAssets: [],
);

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _fixturesDir = p.join(packageRoot, 'test', 'test_fixtures', 'front_matter');
  });

  group('FrontMatterException', () {
    test('toString with path and line', () {
      const ex = FrontMatterException('bad YAML', path: '/tmp/foo.md', line: 3);
      expect(ex.toString(), equals('FrontMatterException at /tmp/foo.md:line 3: bad YAML'));
    });

    test('toString with path only', () {
      const ex = FrontMatterException('bad YAML', path: '/tmp/foo.md');
      expect(ex.toString(), equals('FrontMatterException at /tmp/foo.md: bad YAML'));
    });

    test('toString with no location info', () {
      const ex = FrontMatterException('bad YAML');
      expect(ex.toString(), equals('FrontMatterException: bad YAML'));
    });
  });

  group('_extractFrontMatter (unit via FrontMatterParser)', () {
    late FrontMatterParser parser;
    late String contentDir;

    setUp(() {
      parser = const FrontMatterParser();
      contentDir = _fixturesDir;
    });

    test('basic front matter extraction', () {
      final page = makePage('with_front_matter.md');
      parser.parse(page, contentDir);

      expect(page.frontMatter['title'], equals('Hello World'));
      expect(page.frontMatter['draft'], equals(false));
      expect(page.rawContent, contains('# Hello World'));
      expect(page.rawContent, isNot(contains('---')));
    });

    test('no front matter — rawContent is full file', () {
      final page = makePage('no_front_matter.md');
      parser.parse(page, contentDir);

      expect(page.frontMatter, isEmpty);
      expect(page.rawContent, contains('# No Front Matter'));
      expect(page.isDraft, isFalse);
    });

    test('content only (no delimiter) — rawContent is full file', () {
      final page = makePage('content_only_no_delimiter.md');
      parser.parse(page, contentDir);

      expect(page.frontMatter, isEmpty);
      expect(page.rawContent, startsWith('# Heading'));
    });

    test('empty front matter block — empty map, body preserved', () {
      final page = makePage('empty_front_matter.md');
      parser.parse(page, contentDir);

      expect(page.frontMatter, isEmpty);
      expect(page.rawContent, contains('Content after empty front matter.'));
    });

    test('draft: true sets isDraft = true', () {
      final page = makePage('draft_page.md');
      parser.parse(page, contentDir);

      expect(page.isDraft, isTrue);
      expect(page.frontMatter['draft'], isTrue);
    });

    test('draft: false sets isDraft = false', () {
      final page = makePage('with_front_matter.md');
      parser.parse(page, contentDir);

      expect(page.isDraft, isFalse);
    });

    test('missing draft field leaves isDraft = false', () {
      final page = makePage('no_front_matter.md');
      parser.parse(page, contentDir);

      expect(page.isDraft, isFalse);
    });

    test('date parsed as String (yaml 3.x behavior)', () {
      final page = makePage('with_front_matter.md');
      parser.parse(page, contentDir);

      // package:yaml 3.x returns bare dates as strings (YAML 1.2 core schema).
      expect(page.frontMatter['date'], isA<String>());
      expect(page.frontMatter['date'], equals('2026-03-15'));
    });

    test('tags parsed as List<dynamic>', () {
      final page = makePage('with_front_matter.md');
      parser.parse(page, contentDir);

      final tags = page.frontMatter['tags'];
      expect(tags, isA<List<dynamic>>());
      expect(tags, containsAll(['dart', 'web']));
    });

    test('tags are NOT YamlList', () {
      final page = makePage('with_front_matter.md');
      parser.parse(page, contentDir);

      expect(page.frontMatter['tags'], isNot(isA<YamlList>()));
    });

    test('frontMatter is NOT YamlMap', () {
      final page = makePage('with_front_matter.md');
      parser.parse(page, contentDir);

      expect(page.frontMatter, isNot(isA<YamlMap>()));
    });

    test('nested map converted to Map<String, dynamic>', () {
      final page = makePage('with_date_and_tags.md');
      parser.parse(page, contentDir);

      final author = page.frontMatter['author'];
      expect(author, isA<Map<String, dynamic>>());
      expect(author, isNot(isA<YamlMap>()));
      expect((author as Map<String, dynamic>)['name'], equals('Alice'));
    });

    test('malformed YAML throws FrontMatterException', () {
      final page = makePage('invalid_yaml.md');
      expect(() => parser.parse(page, contentDir), throwsA(isA<FrontMatterException>()));
    });

    test('FrontMatterException for invalid YAML has path info', () {
      final page = makePage('invalid_yaml.md');
      try {
        parser.parse(page, contentDir);
        fail('Expected FrontMatterException');
      } on FrontMatterException catch (e) {
        expect(e.message, isNotEmpty);
        expect(e.path, isNotNull);
        expect(e.path, contains('invalid_yaml.md'));
      }
    });

    test('rawContent does not contain front matter block', () {
      final page = makePage('with_front_matter.md');
      parser.parse(page, contentDir);

      expect(page.rawContent, isNot(contains('title: Hello World')));
      expect(page.rawContent, isNot(startsWith('---')));
    });

    test('rawContent starts with content after closing delimiter newline', () {
      final page = makePage('draft_page.md');
      parser.parse(page, contentDir);

      // rawContent should start with the content line (empty line stripped by delimiter)
      expect(page.rawContent, startsWith('Draft content.'));
    });

    test('Windows line endings (CRLF) handled correctly', () {
      // Simulate a Windows-style file by writing a temp fixture with \r\n endings.
      final tempDir = Directory.systemTemp.createTempSync('fm_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      const crlf = '\r\n';
      final content =
          '---$crlf'
          'title: CRLF Post$crlf'
          'draft: true$crlf'
          '---$crlf'
          'Body content.$crlf';
      File('${tempDir.path}/crlf.md').writeAsStringSync(content);

      final page = makePage('crlf.md');
      parser.parse(page, tempDir.path);

      expect(page.frontMatter['title'], equals('CRLF Post'));
      expect(page.isDraft, isTrue);
      expect(page.rawContent, contains('Body content.'));
      expect(page.rawContent, isNot(contains('---')));
    });
  });

  group('FrontMatterParser integration', () {
    late FrontMatterParser parser;

    setUp(() => parser = const FrontMatterParser());

    test('parse() with full front matter fixture', () {
      final page = makePage('with_front_matter.md');
      parser.parse(page, _fixturesDir);

      expect(page.frontMatter['title'], equals('Hello World'));
      expect(page.frontMatter['date'], equals('2026-03-15')); // yaml 3.x: dates as strings
      expect(page.frontMatter['tags'], isA<List<dynamic>>());
      expect(page.rawContent, contains('# Hello World'));
      expect(page.rawContent, contains('Content here.'));
      expect(page.isDraft, isFalse);
    });

    test('parse() with no_front_matter.md', () {
      final page = makePage('no_front_matter.md');
      parser.parse(page, _fixturesDir);

      expect(page.frontMatter, isEmpty);
      expect(page.rawContent, contains('# No Front Matter'));
      expect(page.isDraft, isFalse);
    });

    test('parse() with draft_page.md sets isDraft = true', () {
      final page = makePage('draft_page.md');
      parser.parse(page, _fixturesDir);

      expect(page.isDraft, isTrue);
    });

    test('parse() with non-existent file throws FrontMatterException', () {
      final page = makePage('does_not_exist.md');
      expect(() => parser.parse(page, _fixturesDir), throwsA(isA<FrontMatterException>()));
    });

    test('parse() with invalid_yaml.md throws FrontMatterException with path', () {
      final page = makePage('invalid_yaml.md');
      try {
        parser.parse(page, _fixturesDir);
        fail('Expected FrontMatterException');
      } on FrontMatterException catch (e) {
        expect(e.message, isNotEmpty);
        expect(e.path, isNotNull);
        expect(e.toString(), contains('FrontMatterException'));
      }
    });

    test('parse() with with_date_and_tags.md — nested types converted', () {
      final page = makePage('with_date_and_tags.md');
      parser.parse(page, _fixturesDir);

      expect(page.frontMatter['tags'], isA<List<dynamic>>());
      expect(page.frontMatter['categories'], isA<List<dynamic>>());
      expect(page.frontMatter['author'], isA<Map<String, dynamic>>());
    });
  });
}
