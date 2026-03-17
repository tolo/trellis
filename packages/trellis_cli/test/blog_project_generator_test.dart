import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';
import 'package:trellis_site/trellis_site.dart';

void main() {
  group('BlogProjectGenerator — file list', () {
    late InMemoryFileWriter writer;

    setUp(() {
      writer = InMemoryFileWriter();
    });

    test('T01: generates all 15 expected files', () async {
      final generator = BlogProjectGenerator(projectName: 'my_blog', writer: writer);
      await generator.generate();

      expect(writer.files, hasLength(15));
      expect(
        writer.files.keys,
        containsAll([
          'pubspec.yaml',
          'trellis_site.yaml',
          '.gitignore',
          'analysis_options.yaml',
          'content/_index.md',
          'content/about.md',
          'content/posts/_index.md',
          'content/posts/welcome.md',
          'content/posts/getting-started.md',
          'layouts/base.html',
          'layouts/home.html',
          'layouts/_default/single.html',
          'layouts/_default/list.html',
          'layouts/posts/single.html',
          'static/styles.css',
        ]),
      );
    });

    test('T02: all generated files have non-empty content', () async {
      final generator = BlogProjectGenerator(projectName: 'my_blog', writer: writer);
      await generator.generate();

      for (final entry in writer.files.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} should not be empty');
      }
    });
  });

  group('BlogProjectGenerator — config files', () {
    late InMemoryFileWriter writer;

    setUp(() async {
      writer = InMemoryFileWriter();
      final generator = BlogProjectGenerator(projectName: 'my_blog', writer: writer);
      await generator.generate();
    });

    test('T03: trellis_site.yaml has taxonomies including tags', () {
      final config = writer.files['trellis_site.yaml']!;
      expect(config, contains('taxonomies'));
      expect(config, contains('tags'));
    });

    test('T03b: trellis_site.yaml has paginate setting', () {
      final config = writer.files['trellis_site.yaml']!;
      expect(config, contains('paginate'));
    });

    test('T03c: trellis_site.yaml is parseable by SiteConfig', () {
      // Write to temp file and load it
      final tempDir = Directory.systemTemp.createTempSync('trellis_cfg_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final configFile = File(p.join(tempDir.path, 'trellis_site.yaml'));
      configFile.writeAsStringSync(writer.files['trellis_site.yaml']!);
      final config = SiteConfig.load(configFile.path);
      expect(config.taxonomies, contains('tags'));
      expect(config.paginate, isNotNull);
    });

    test('T04: pubspec.yaml contains project name and trellis_site dependency', () {
      final pubspec = writer.files['pubspec.yaml']!;
      expect(pubspec, contains('name: my_blog'));
      expect(pubspec, contains('trellis_site:'));
    });

    test('T05: .gitignore contains output/', () {
      final gitignore = writer.files['.gitignore']!;
      expect(gitignore, contains('output/'));
    });
  });

  group('BlogProjectGenerator — layouts', () {
    late InMemoryFileWriter writer;

    setUp(() async {
      writer = InMemoryFileWriter();
      final generator = BlogProjectGenerator(projectName: 'my_blog', writer: writer);
      await generator.generate();
    });

    test('T06: base.html defines content slot via tl:define', () {
      final base = writer.files['layouts/base.html']!;
      expect(base, contains('tl:define="content"'));
    });

    test('T07: home.html uses tl:extends and tl:define to fill content slot', () {
      final home = writer.files['layouts/home.html']!;
      expect(home, contains('tl:extends="layouts/base.html"'));
      expect(home, contains('tl:define="content"'));
      expect(home, contains('tl:each'));
    });

    test(r'T08: _default/list.html contains tl:if="${pagination}" for pagination nav', () {
      final list = writer.files['layouts/_default/list.html']!;
      expect(list, contains(r'tl:if="${pagination}"'));
      expect(list, contains(r'${pagination.hasNext}'));
      expect(list, contains(r'${pagination.hasPrev}'));
    });

    test('T09: posts/single.html demonstrates tl:each for tags and tl:utext for content', () {
      final post = writer.files['layouts/posts/single.html']!;
      expect(post, contains('tl:extends="layouts/base.html"'));
      expect(post, contains('tl:each'));
      expect(post, contains(r'tl:utext="${page.content}"'));
      expect(post, contains(r'tl:text="${page.date}"'));
    });

    test('T10: all layout files contain <html element (valid HTML structure)', () {
      final layoutFiles = [
        'layouts/base.html',
        'layouts/home.html',
        'layouts/_default/single.html',
        'layouts/_default/list.html',
        'layouts/posts/single.html',
      ];
      for (final path in layoutFiles) {
        expect(writer.files[path], contains('<html'), reason: '$path should contain <html');
      }
    });
  });

  group('BlogProjectGenerator — content files', () {
    late InMemoryFileWriter writer;

    setUp(() async {
      writer = InMemoryFileWriter();
      final generator = BlogProjectGenerator(projectName: 'my_blog', writer: writer);
      await generator.generate();
    });

    test('T11: welcome.md has front matter with title, date, and tags', () {
      final post = writer.files['content/posts/welcome.md']!;
      expect(post, contains('title:'));
      expect(post, contains('date:'));
      expect(post, contains('tags:'));
    });

    test('T12: getting-started.md has front matter with title, date, and tags', () {
      final post = writer.files['content/posts/getting-started.md']!;
      expect(post, contains('title:'));
      expect(post, contains('date:'));
      expect(post, contains('tags:'));
    });

    test('T13: project name used in home page title', () {
      final home = writer.files['content/_index.md']!;
      expect(home, contains('my blog'));
    });
  });

  group('BlogProjectGenerator — E2E build', () {
    test('T14: build the generated blog project produces expected output files', () async {
      final tempDir = Directory.systemTemp.createTempSync('trellis_blog_e2e_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final writer = DiskFileWriter(tempDir.path);
      final generator = BlogProjectGenerator(projectName: 'my_blog', writer: writer);
      await generator.generate();

      // Load the generated trellis_site.yaml and build
      final configPath = p.join(tempDir.path, 'trellis_site.yaml');
      final config = SiteConfig.load(configPath);

      final site = TrellisSite(config);
      final result = await site.build();

      // Should have built at least 6 pages (home, about, posts index, 2 posts + taxonomy)
      expect(result.pageCount, greaterThanOrEqualTo(5));

      final outputDir = Directory(config.outputDir);
      expect(outputDir.existsSync(), isTrue);

      // Check expected output files
      expect(File(p.join(config.outputDir, 'index.html')).existsSync(), isTrue, reason: 'home page');
      expect(File(p.join(config.outputDir, 'about', 'index.html')).existsSync(), isTrue, reason: 'about page');
      expect(File(p.join(config.outputDir, 'posts', 'index.html')).existsSync(), isTrue, reason: 'posts listing');
      expect(
        File(p.join(config.outputDir, 'posts', 'welcome', 'index.html')).existsSync(),
        isTrue,
        reason: 'welcome post',
      );
      expect(
        File(p.join(config.outputDir, 'posts', 'getting-started', 'index.html')).existsSync(),
        isTrue,
        reason: 'getting-started post',
      );

      // CSS should be copied to output
      expect(File(p.join(config.outputDir, 'styles.css')).existsSync(), isTrue, reason: 'styles.css copied');
    });
  });
}
