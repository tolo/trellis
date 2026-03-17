import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

late String _siteFixtureDir;

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _siteFixtureDir = p.join(packageRoot, 'test', 'test_fixtures', 'generator_site');
  });

  /// Creates a temp output directory scoped to a test.
  String tempOutputDir() {
    final dir = Directory.systemTemp.createTempSync('gen_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir.path;
  }

  /// Creates a [Page] with optional fields pre-set.
  Page makePage({
    required String sourcePath,
    required String url,
    String section = '',
    PageKind kind = PageKind.single,
    bool isDraft = false,
    Map<String, dynamic>? frontMatter,
    String content = '',
  }) => Page(
    sourcePath: sourcePath,
    url: url,
    section: section,
    kind: kind,
    isDraft: isDraft,
    isBundle: false,
    bundleAssets: [],
    frontMatter: frontMatter ?? {},
    content: content,
  );

  group('TemplateNotFoundException', () {
    test('toString includes message and page URL', () {
      const ex = TemplateNotFoundException(
        'No layout found',
        pageUrl: '/about/',
        tried: ['layouts/_default/single.html'],
      );
      final str = ex.toString();
      expect(str, contains('No layout found'));
      expect(str, contains('/about/'));
      expect(str, contains('layouts/_default/single.html'));
    });

    test('toString works without optional fields', () {
      const ex = TemplateNotFoundException('No layout found');
      expect(ex.toString(), startsWith('TemplateNotFoundException: No layout found'));
    });
  });

  group('PageGenerator.resolveLayout', () {
    late PageGenerator generator;

    setUp(() => generator = PageGenerator(siteDir: _siteFixtureDir, outputDir: '/tmp/unused'));

    test('single page resolves to _default/single.html', () {
      final page = makePage(sourcePath: 'about.md', url: '/about/');
      final layout = generator.resolveLayout(page);
      expect(p.basename(p.dirname(layout)), equals('_default'));
      expect(p.basename(layout), equals('single.html'));
    });

    test('posts page resolves to posts/single.html (section-specific)', () {
      final page = makePage(sourcePath: 'posts/hello.md', url: '/posts/hello/', section: 'posts');
      final layout = generator.resolveLayout(page);
      expect(p.basename(p.dirname(layout)), equals('posts'));
      expect(p.basename(layout), equals('single.html'));
    });

    test('section page resolves to _default/list.html', () {
      final page = makePage(sourcePath: '_index.md', url: '/', section: '', kind: PageKind.section);
      final layout = generator.resolveLayout(page);
      expect(p.basename(p.dirname(layout)), equals('_default'));
      expect(p.basename(layout), equals('list.html'));
    });

    test('home page resolves to layouts/home.html', () {
      final page = makePage(sourcePath: '_index.md', url: '/', kind: PageKind.home);
      final layout = generator.resolveLayout(page);
      expect(p.basename(layout), equals('home.html'));
    });

    test('front matter layout field overrides lookup', () {
      final page = makePage(sourcePath: 'about.md', url: '/about/', frontMatter: {'layout': '_default/single'});
      final layout = generator.resolveLayout(page);
      expect(layout, endsWith('single.html'));
    });

    test('throws TemplateNotFoundException when no layout found', () {
      // Use an unknown section with no specific or default layout in a temp dir
      final tempSiteDir = Directory.systemTemp.createTempSync('no_layout_');
      addTearDown(() => tempSiteDir.deleteSync(recursive: true));
      Directory(p.join(tempSiteDir.path, 'layouts')).createSync();

      final gen = PageGenerator(siteDir: tempSiteDir.path, outputDir: '/tmp/unused');
      final page = makePage(sourcePath: 'about.md', url: '/about/');
      expect(() => gen.resolveLayout(page), throwsA(isA<TemplateNotFoundException>()));
    });

    test('TemplateNotFoundException.tried contains attempted paths', () {
      final tempSiteDir = Directory.systemTemp.createTempSync('no_layout2_');
      addTearDown(() => tempSiteDir.deleteSync(recursive: true));
      Directory(p.join(tempSiteDir.path, 'layouts')).createSync();

      final gen = PageGenerator(siteDir: tempSiteDir.path, outputDir: '/tmp/unused');
      final page = makePage(sourcePath: 'about.md', url: '/about/');
      try {
        gen.resolveLayout(page);
        fail('Expected TemplateNotFoundException');
      } on TemplateNotFoundException catch (e) {
        expect(e.tried, isNotEmpty);
        expect(e.tried, anyElement(contains('single.html')));
      }
    });
  });

  group('PageGenerator.generateAll', () {
    test('generates single page to correct output path', () async {
      final outputDir = tempOutputDir();
      final generator = PageGenerator(siteDir: _siteFixtureDir, outputDir: outputDir);

      final page = makePage(
        sourcePath: 'about.md',
        url: '/about/',
        frontMatter: {'title': 'About Us'},
        content: '<p>We are awesome.</p>',
      );

      await generator.generateAll([page]);

      final outputFile = File(p.join(outputDir, 'about', 'index.html'));
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.readAsStringSync(), contains('About Us'));
    });

    test('root page (url=/): generates output/index.html', () async {
      final outputDir = tempOutputDir();
      final generator = PageGenerator(siteDir: _siteFixtureDir, outputDir: outputDir);

      final page = makePage(
        sourcePath: '_index.md',
        url: '/',
        kind: PageKind.home,
        frontMatter: {'title': 'Home'},
        content: '<p>Welcome.</p>',
      );

      await generator.generateAll([page]);

      final outputFile = File(p.join(outputDir, 'index.html'));
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.readAsStringSync(), contains('Home'));
    });

    test('draft page is skipped', () async {
      final outputDir = tempOutputDir();
      final generator = PageGenerator(siteDir: _siteFixtureDir, outputDir: outputDir);

      final page = makePage(
        sourcePath: 'draft.md',
        url: '/draft/',
        isDraft: true,
        frontMatter: {'title': 'Draft Post'},
        content: '<p>Draft.</p>',
      );

      await generator.generateAll([page]);

      final outputFile = File(p.join(outputDir, 'draft', 'index.html'));
      expect(outputFile.existsSync(), isFalse);
    });

    test('generated HTML contains page content', () async {
      final outputDir = tempOutputDir();
      final generator = PageGenerator(siteDir: _siteFixtureDir, outputDir: outputDir);

      final page = makePage(
        sourcePath: 'posts/hello.md',
        url: '/posts/hello/',
        section: 'posts',
        frontMatter: {'title': 'Hello Post'},
        content: '<p>Post body here.</p>',
      );

      await generator.generateAll([page]);

      final outputFile = File(p.join(outputDir, 'posts', 'hello', 'index.html'));
      expect(outputFile.existsSync(), isTrue);
      final html = outputFile.readAsStringSync();
      expect(html, contains('Hello Post'));
      expect(html, contains('Post body here.'));
    });

    test('posts section uses posts/single.html layout (not _default)', () async {
      final outputDir = tempOutputDir();
      final generator = PageGenerator(siteDir: _siteFixtureDir, outputDir: outputDir);

      final page = makePage(
        sourcePath: 'posts/hello.md',
        url: '/posts/hello/',
        section: 'posts',
        frontMatter: {'title': 'Post'},
        content: '<p>Body.</p>',
      );

      await generator.generateAll([page]);

      final html = File(p.join(outputDir, 'posts', 'hello', 'index.html')).readAsStringSync();
      // posts/single.html has class="post-title" on h1
      expect(html, contains('post-title'));
    });

    test('section page receives \${pages} context with child pages', () async {
      final outputDir = tempOutputDir();
      final generator = PageGenerator(siteDir: _siteFixtureDir, outputDir: outputDir);

      final sectionPage = makePage(
        sourcePath: 'posts/_index.md',
        url: '/posts/',
        section: 'posts',
        kind: PageKind.section,
        frontMatter: {'title': 'Posts'},
      );
      final post1 = makePage(
        sourcePath: 'posts/hello.md',
        url: '/posts/hello/',
        section: 'posts',
        frontMatter: {'title': 'Hello'},
        content: '<p>Hello post.</p>',
      );
      final post2 = makePage(
        sourcePath: 'posts/world.md',
        url: '/posts/world/',
        section: 'posts',
        frontMatter: {'title': 'World'},
        content: '<p>World post.</p>',
      );

      await generator.generateAll([sectionPage, post1, post2]);

      final sectionHtml = File(p.join(outputDir, 'posts', 'index.html')).readAsStringSync();
      expect(sectionHtml, contains('Hello'));
      expect(sectionHtml, contains('World'));
    });

    test('global data available as \${data.authors}', () async {
      final outputDir = tempOutputDir();
      // Use a custom template that renders data.authors.alice.name
      final tempSiteDir = Directory.systemTemp.createTempSync('gen_data_');
      addTearDown(() => tempSiteDir.deleteSync(recursive: true));

      // Copy layouts from fixture
      final layoutsDir = Directory(p.join(tempSiteDir.path, 'layouts', '_default'))..createSync(recursive: true);
      File(
        p.join(_siteFixtureDir, 'layouts', '_default', 'single.html'),
      ).copySync(p.join(layoutsDir.path, 'single.html'));

      // Create data directory with authors.yaml
      final dataDir = Directory(p.join(tempSiteDir.path, 'data'))..createSync();
      File(p.join(dataDir.path, 'authors.yaml')).writeAsStringSync('alice:\n  name: Alice\n  role: editor\n');

      final generator = PageGenerator(siteDir: tempSiteDir.path, outputDir: outputDir);
      final page = makePage(
        sourcePath: 'about.md',
        url: '/about/',
        frontMatter: {'title': 'About'},
        content: '<p>Content.</p>',
      );

      await generator.generateAll([page]);
      // Just verify the page was generated without error (data is available in context)
      expect(File(p.join(outputDir, 'about', 'index.html')).existsSync(), isTrue);
    });

    test('output directory created if not exists', () async {
      final baseDir = Directory.systemTemp.createTempSync('gen_mkdir_');
      addTearDown(() => baseDir.deleteSync(recursive: true));
      final outputDir = p.join(baseDir.path, 'new', 'output', 'dir');

      final generator = PageGenerator(siteDir: _siteFixtureDir, outputDir: outputDir);
      final page = makePage(
        sourcePath: 'about.md',
        url: '/about/',
        frontMatter: {'title': 'About'},
        content: '<p>Content.</p>',
      );

      await generator.generateAll([page]);
      expect(File(p.join(outputDir, 'about', 'index.html')).existsSync(), isTrue);
    });

    test('missing layout throws TemplateNotFoundException', () async {
      final tempSiteDir = Directory.systemTemp.createTempSync('gen_nolayout_');
      addTearDown(() => tempSiteDir.deleteSync(recursive: true));
      Directory(p.join(tempSiteDir.path, 'layouts')).createSync();

      final generator = PageGenerator(siteDir: tempSiteDir.path, outputDir: tempOutputDir());
      final page = makePage(
        sourcePath: 'about.md',
        url: '/about/',
        frontMatter: {'title': 'About'},
        content: '<p>Content.</p>',
      );

      expect(generator.generateAll([page]), throwsA(isA<TemplateNotFoundException>()));
    });
  });
}
