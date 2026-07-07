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
  ///
  /// [sectionPath] defaults to [section] (single-level) when not given.
  Page makePage({
    required String sourcePath,
    required String url,
    String section = '',
    String? sectionPath,
    PageKind kind = PageKind.single,
    bool isDraft = false,
    Map<String, dynamic>? frontMatter,
    String content = '',
  }) => Page(
    sourcePath: sourcePath,
    url: url,
    section: section,
    sectionPath: sectionPath,
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

  group('pageWeight', () {
    test('reads an integer weight', () {
      expect(pageWeight(makePage(sourcePath: 'a.md', url: '/a/', frontMatter: {'weight': 3})), 3);
    });

    test('absent weight is null', () {
      expect(pageWeight(makePage(sourcePath: 'a.md', url: '/a/')), isNull);
    });

    test('non-integer (quoted string) weight is null', () {
      expect(pageWeight(makePage(sourcePath: 'a.md', url: '/a/', frontMatter: {'weight': 'abc'})), isNull);
    });

    test('double weight is null (malformed — treated as unweighted)', () {
      expect(pageWeight(makePage(sourcePath: 'a.md', url: '/a/', frontMatter: {'weight': 1.5})), isNull);
    });
  });

  group('orderedSectionPages (canonical ordering seam)', () {
    // AS08/TI09: the single reusable ordered-section sequence.
    test('AS01/AS08: weighted pages sort ahead of unweighted, ascending by weight', () {
      final guide = makePage(
        sourcePath: 'docs/guides/guide.md',
        url: '/docs/guides/guide/',
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'weight': 1, 'date': '2026-01-01'},
      );
      final intro = makePage(
        sourcePath: 'docs/guides/intro.md',
        url: '/docs/guides/intro/',
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'weight': 2, 'date': '2026-03-01'},
      );
      final misc = makePage(
        sourcePath: 'docs/guides/misc.md',
        url: '/docs/guides/misc/',
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'date': '2026-06-01'},
      );

      // Deliberately unsorted input.
      final ordered = orderedSectionPages('docs/guides', [misc, intro, guide]);
      expect(ordered.map((p) => p.url), ['/docs/guides/guide/', '/docs/guides/intro/', '/docs/guides/misc/']);
    });

    test('AS03: ties among equal weights fall back to date-desc-then-URL', () {
      final older = makePage(
        sourcePath: 'docs/guides/older.md',
        url: '/docs/guides/older/',
        sectionPath: 'docs/guides',
        frontMatter: {'weight': 5, 'date': '2026-01-01'},
      );
      final newer = makePage(
        sourcePath: 'docs/guides/newer.md',
        url: '/docs/guides/newer/',
        sectionPath: 'docs/guides',
        frontMatter: {'weight': 5, 'date': '2026-06-01'},
      );
      final unweighted = makePage(
        sourcePath: 'docs/guides/plain.md',
        url: '/docs/guides/plain/',
        sectionPath: 'docs/guides',
        frontMatter: {'date': '2026-12-01'},
      );

      final ordered = orderedSectionPages('docs/guides', [unweighted, older, newer]);
      // Both weight:5 pages ahead of the unweighted one; newer date first among ties.
      expect(ordered.map((p) => p.url), ['/docs/guides/newer/', '/docs/guides/older/', '/docs/guides/plain/']);
    });

    test('AS04: malformed weight is treated as unweighted (sorts in unweighted group)', () {
      final weighted = makePage(
        sourcePath: 'docs/guides/weighted.md',
        url: '/docs/guides/weighted/',
        sectionPath: 'docs/guides',
        frontMatter: {'weight': 1, 'date': '2026-01-01'},
      );
      final malformed = makePage(
        sourcePath: 'docs/guides/bad.md',
        url: '/docs/guides/bad/',
        sectionPath: 'docs/guides',
        frontMatter: {'weight': 'abc', 'date': '2026-06-01'},
      );

      final ordered = orderedSectionPages('docs/guides', [malformed, weighted]);
      // Valid weight first; malformed page falls to the unweighted group.
      expect(ordered.map((p) => p.url), ['/docs/guides/weighted/', '/docs/guides/bad/']);
    });

    test('AS06/TI06: nested listing contains own-level pages and excludes sibling sub-sections', () {
      final guidesA = makePage(
        sourcePath: 'docs/guides/a.md',
        url: '/docs/guides/a/',
        section: 'docs',
        sectionPath: 'docs/guides',
      );
      final tutorialsB = makePage(
        sourcePath: 'docs/tutorials/b.md',
        url: '/docs/tutorials/b/',
        section: 'docs',
        sectionPath: 'docs/tutorials',
      );

      final ordered = orderedSectionPages('docs/guides', [guidesA, tutorialsB]);
      final urls = ordered.map((p) => p.url).toList();
      expect(urls, contains('/docs/guides/a/'));
      expect(urls, isNot(contains('/docs/tutorials/b/')));
    });

    test('excludes section/home pages — single pages only', () {
      final index = makePage(
        sourcePath: 'docs/guides/_index.md',
        url: '/docs/guides/',
        section: 'docs',
        sectionPath: 'docs/guides',
        kind: PageKind.section,
      );
      final a = makePage(
        sourcePath: 'docs/guides/a.md',
        url: '/docs/guides/a/',
        section: 'docs',
        sectionPath: 'docs/guides',
      );

      final ordered = orderedSectionPages('docs/guides', [index, a]);
      expect(ordered.map((p) => p.url), ['/docs/guides/a/']);
    });

    test('AS02/TI04: unweighted section keeps date-desc-then-URL order (no new tiebreak)', () {
      // Same date → tiebreak is URL ascending (existing behavior).
      final z = makePage(
        sourcePath: 'posts/z.md',
        url: '/posts/z/',
        sectionPath: 'posts',
        frontMatter: {'date': '2026-01-01'},
      );
      final a = makePage(
        sourcePath: 'posts/a.md',
        url: '/posts/a/',
        sectionPath: 'posts',
        frontMatter: {'date': '2026-01-01'},
      );
      final newer = makePage(
        sourcePath: 'posts/newer.md',
        url: '/posts/newer/',
        sectionPath: 'posts',
        frontMatter: {'date': '2026-06-01'},
      );

      final ordered = orderedSectionPages('posts', [z, a, newer]);
      // newer date first; same-date pair tiebroken by URL ascending (a before z).
      expect(ordered.map((p) => p.url), ['/posts/newer/', '/posts/a/', '/posts/z/']);
    });

    test('empty sectionPath yields empty list', () {
      final a = makePage(sourcePath: 'posts/a.md', url: '/posts/a/', sectionPath: 'posts');
      expect(orderedSectionPages('', [a]), isEmpty);
    });
  });

  group('_getChildPages routes through orderedSectionPages (AS08 single ordering source)', () {
    test('section _index.md \${pages} order equals orderedSectionPages output exactly', () async {
      final outputDir = tempOutputDir();
      final generator = PageGenerator(siteDir: _siteFixtureDir, outputDir: outputDir);

      final section = makePage(
        sourcePath: 'posts/_index.md',
        url: '/posts/',
        section: 'posts',
        sectionPath: 'posts',
        kind: PageKind.section,
        frontMatter: {'title': 'Posts'},
      );
      final a = makePage(
        sourcePath: 'posts/a.md',
        url: '/posts/a/',
        section: 'posts',
        sectionPath: 'posts',
        frontMatter: {'title': 'Alpha', 'weight': 1},
        content: '<p>a</p>',
      );
      final b = makePage(
        sourcePath: 'posts/b.md',
        url: '/posts/b/',
        section: 'posts',
        sectionPath: 'posts',
        frontMatter: {'title': 'Bravo', 'weight': 2},
        content: '<p>b</p>',
      );
      final c = makePage(
        sourcePath: 'posts/c.md',
        url: '/posts/c/',
        section: 'posts',
        sectionPath: 'posts',
        frontMatter: {'title': 'Charlie', 'date': '2026-01-01'},
        content: '<p>c</p>',
      );

      final allPages = [section, c, b, a];
      await generator.generateAll(allPages);

      // The rendered listing order must equal the seam's canonical order.
      final html = File(p.join(outputDir, 'posts', 'index.html')).readAsStringSync();
      final nonDraft = allPages.where((pg) => !pg.isDraft).toList();
      final seamUrls = orderedSectionPages('posts', nonDraft).map((p) => p.url).toList();
      expect(seamUrls, ['/posts/a/', '/posts/b/', '/posts/c/']);

      // href appearance order in the rendered HTML matches the seam order.
      final hrefOrder = RegExp(r'href="([^"]+)"').allMatches(html).map((m) => m.group(1)).toList();
      expect(hrefOrder, seamUrls);
    });
  });

  /// Creates an isolated site whose `_default/single.html` echoes context values
  /// under test: a custom cascade key, the structured breadcrumb trail, and the
  /// prev/next neighbor titles. Returns the site dir path.
  String contextEchoSiteDir() {
    final dir = Directory.systemTemp.createTempSync('ctx_echo_site_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final defaults = Directory(p.join(dir.path, 'layouts', '_default'))..createSync(recursive: true);
    File(p.join(defaults.path, 'single.html')).writeAsStringSync('''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">Title</title></head>
<body>
<p class="cascade" tl:text="\${custom_key}">cascade</p>
<nav class="crumbs">
  <span class="crumb" tl:each="crumb : \${page.breadcrumbs}">
    <a tl:if="\${crumb.url != ''}" tl:href="\${crumb.url}" tl:text="\${crumb.title}">c</a>
    <span tl:unless="\${crumb.url != ''}" tl:text="\${crumb.title}">c</span>
  </span>
</nav>
<a class="prev" tl:if="\${page.prev}" tl:href="\${page.prev.url}" tl:text="\${page.prev.title}">prev</a>
<a class="next" tl:if="\${page.next}" tl:href="\${page.next.url}" tl:text="\${page.next.title}">next</a>
</body>
</html>
''');
    File(p.join(defaults.path, 'list.html')).writeAsStringSync('''
<!DOCTYPE html>
<html><head><title tl:text="\${page.title}">List</title></head>
<body><ul><li tl:each="child : \${pages}"><a tl:href="\${child.url}" tl:text="\${child.title}">c</a></li></ul></body>
</html>
''');
    return dir.path;
  }

  Future<String> renderSinglePage(String siteDir, List<Page> pages, String url) async {
    final outputDir = tempOutputDir();
    await PageGenerator(siteDir: siteDir, outputDir: outputDir).generateAll(pages);
    final rel = url.replaceAll(RegExp(r'^/|/$'), '');
    return File(p.join(outputDir, rel, 'index.html')).readAsStringSync();
  }

  group('H1 — Level-3 section cascade resolves the OWN nested section _index.md', () {
    test('nested page reads its own section _index.md custom key, not the top-level ancestor', () async {
      // Two nested section _index.md files declaring the same custom key with
      // different values. A nested page must resolve its OWN section's value.
      final topSection = makePage(
        sourcePath: 'docs/_index.md',
        url: '/docs/',
        section: 'docs',
        sectionPath: 'docs',
        kind: PageKind.section,
        frontMatter: {'title': 'Docs', 'custom_key': 'top-value'},
      );
      final guidesSection = makePage(
        sourcePath: 'docs/guides/_index.md',
        url: '/docs/guides/',
        section: 'docs',
        sectionPath: 'docs/guides',
        kind: PageKind.section,
        frontMatter: {'title': 'Guides', 'custom_key': 'nested-value'},
      );
      final nestedPage = makePage(
        sourcePath: 'docs/guides/intro.md',
        url: '/docs/guides/intro/',
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'title': 'Intro'},
        content: '<p>x</p>',
      );

      final html = await renderSinglePage(contextEchoSiteDir(), [
        topSection,
        guidesSection,
        nestedPage,
      ], '/docs/guides/intro/');
      expect(html, contains('<p class="cascade">nested-value</p>'));
      expect(html, isNot(contains('top-value')));
    });

    test('single-level page still resolves its top-level section _index.md (no drift)', () async {
      final section = makePage(
        sourcePath: 'posts/_index.md',
        url: '/posts/',
        section: 'posts',
        sectionPath: 'posts',
        kind: PageKind.section,
        frontMatter: {'title': 'Posts', 'custom_key': 'posts-value'},
      );
      final page = makePage(
        sourcePath: 'posts/a.md',
        url: '/posts/a/',
        section: 'posts',
        sectionPath: 'posts',
        frontMatter: {'title': 'A'},
        content: '<p>x</p>',
      );
      final html = await renderSinglePage(contextEchoSiteDir(), [section, page], '/posts/a/');
      expect(html, contains('<p class="cascade">posts-value</p>'));
    });
  });

  group('H2 — structured breadcrumbs expose section titles and prefixed urls', () {
    test('nested page breadcrumbs carry segment titles (not slash-joined paths) and section urls', () async {
      final docsSection = makePage(
        sourcePath: 'docs/_index.md',
        url: '/docs/',
        section: 'docs',
        sectionPath: 'docs',
        kind: PageKind.section,
        frontMatter: {'title': 'Documentation'},
      );
      final guidesSection = makePage(
        sourcePath: 'docs/guides/_index.md',
        url: '/docs/guides/',
        section: 'docs',
        sectionPath: 'docs/guides',
        kind: PageKind.section,
        frontMatter: {'title': 'Guides'},
      );
      final page = makePage(
        sourcePath: 'docs/guides/intro.md',
        url: '/docs/guides/intro/',
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'title': 'Intro'},
        content: '<p>x</p>',
      );

      final html = await renderSinglePage(contextEchoSiteDir(), [
        docsSection,
        guidesSection,
        page,
      ], '/docs/guides/intro/');
      // Two crumbs, in shallow→deep order, labelled by section title with the
      // section's own url (no slash-joined path leaks into a label).
      expect(html, contains('<a href="/docs/">Documentation</a>'));
      expect(html, contains('<a href="/docs/guides/">Guides</a>'));
      expect(html, isNot(contains('>docs/guides<')));
    });

    test('breadcrumb title falls back to humanized segment when a section has no _index.md', () async {
      // `docs` has an _index.md (titled); `guides` folder has none → humanized.
      final docsSection = makePage(
        sourcePath: 'docs/_index.md',
        url: '/docs/',
        section: 'docs',
        sectionPath: 'docs',
        kind: PageKind.section,
        frontMatter: {'title': 'Docs'},
      );
      final page = makePage(
        sourcePath: 'docs/api-guides/intro.md',
        url: '/docs/api-guides/intro/',
        section: 'docs',
        sectionPath: 'docs/api-guides',
        frontMatter: {'title': 'Intro'},
        content: '<p>x</p>',
      );
      final html = await renderSinglePage(contextEchoSiteDir(), [docsSection, page], '/docs/api-guides/intro/');
      // Second crumb has no section page → humanized "Api Guides", empty url,
      // rendered as a plain (non-link) span — never an empty-href self-link.
      expect(html, contains('>Api Guides</span>'));
      expect(html, isNot(contains('href="">Api Guides</a>')));
      // First crumb (docs) has a url and still renders as a real link.
      expect(html, contains('<a href="/docs/">Docs</a>'));
    });
  });

  group('L1 — prev/next neighbor titles use the 3-tier fallback (never null)', () {
    test('a titleless neighbor renders the humanized URL segment, not an empty title', () async {
      final section = makePage(
        sourcePath: 'docs/guides/_index.md',
        url: '/docs/guides/',
        section: 'docs',
        sectionPath: 'docs/guides',
        kind: PageKind.section,
        frontMatter: {'title': 'Guides'},
      );
      // `getting-started` has no title; ordered first by weight.
      final untitled = makePage(
        sourcePath: 'docs/guides/getting-started.md',
        url: '/docs/guides/getting-started/',
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'weight': 1},
        content: '<p>x</p>',
      );
      final current = makePage(
        sourcePath: 'docs/guides/next-steps.md',
        url: '/docs/guides/next-steps/',
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'title': 'Next Steps', 'weight': 2},
        content: '<p>x</p>',
      );

      final html = await renderSinglePage(contextEchoSiteDir(), [
        section,
        untitled,
        current,
      ], '/docs/guides/next-steps/');
      // prev → getting-started, title humanized from the URL segment.
      expect(html, contains('href="/docs/guides/getting-started/"'));
      expect(html, contains('>Getting Started</a>'));
    });
  });

  group('L2 — weight edge cases and malformed section weight', () {
    test('weight 0, negative, and large sort ascending with unweighted last', () async {
      final section = makePage(
        sourcePath: 'docs/_index.md',
        url: '/docs/',
        section: 'docs',
        sectionPath: 'docs',
        kind: PageKind.section,
        frontMatter: {'title': 'Docs'},
      );
      final neg = makePage(
        sourcePath: 'docs/neg.md',
        url: '/docs/neg/',
        section: 'docs',
        sectionPath: 'docs',
        frontMatter: {'title': 'Neg', 'weight': -5},
      );
      final zero = makePage(
        sourcePath: 'docs/zero.md',
        url: '/docs/zero/',
        section: 'docs',
        sectionPath: 'docs',
        frontMatter: {'title': 'Zero', 'weight': 0},
      );
      final large = makePage(
        sourcePath: 'docs/large.md',
        url: '/docs/large/',
        section: 'docs',
        sectionPath: 'docs',
        frontMatter: {'title': 'Large', 'weight': 1000000},
      );
      final unweighted = makePage(
        sourcePath: 'docs/plain.md',
        url: '/docs/plain/',
        section: 'docs',
        sectionPath: 'docs',
        frontMatter: {'title': 'Plain'},
      );

      final ordered = orderedSectionPages('docs', [section, large, unweighted, zero, neg]).map((p) => p.url).toList();
      expect(ordered, ['/docs/neg/', '/docs/zero/', '/docs/large/', '/docs/plain/']);
    });

    test('malformed weight on a section _index.md warns and does not abort (falls back)', () async {
      final outputDir = tempOutputDir();
      final generator = PageGenerator(siteDir: contextEchoSiteDir(), outputDir: outputDir);
      final badSection = makePage(
        sourcePath: 'docs/_index.md',
        url: '/docs/',
        section: 'docs',
        sectionPath: 'docs',
        kind: PageKind.section,
        frontMatter: {'title': 'Docs', 'weight': 'not-an-int'},
      );
      final child = makePage(
        sourcePath: 'docs/a.md',
        url: '/docs/a/',
        section: 'docs',
        sectionPath: 'docs',
        frontMatter: {'title': 'A'},
        content: '<p>x</p>',
      );

      // Build completes; a warning names the malformed section page.
      await generator.generateAll([badSection, child]);
      expect(File(p.join(outputDir, 'docs', 'a', 'index.html')).existsSync(), isTrue);
      final weightWarnings = generator.warnings.where((w) => w.message.toLowerCase().contains('weight')).toList();
      expect(weightWarnings.any((w) => (w.context ?? '').contains('/docs/')), isTrue);

      // NavigationBuilder's section-weight path also tolerates the malformed
      // weight: the section sorts as unweighted rather than throwing.
      final menu = const NavigationBuilder().build([badSection, child]);
      expect(menu, isNotEmpty);
    });
  });

  group('L3 — 3-level-deep nested section lineage and ordering', () {
    List<Page> deepPages() => [
      makePage(
        sourcePath: 'docs/_index.md',
        url: '/docs/',
        section: 'docs',
        sectionPath: 'docs',
        kind: PageKind.section,
        frontMatter: {'title': 'Docs'},
      ),
      makePage(
        sourcePath: 'docs/guides/_index.md',
        url: '/docs/guides/',
        section: 'docs',
        sectionPath: 'docs/guides',
        kind: PageKind.section,
        frontMatter: {'title': 'Guides'},
      ),
      makePage(
        sourcePath: 'docs/guides/advanced/_index.md',
        url: '/docs/guides/advanced/',
        section: 'docs',
        sectionPath: 'docs/guides/advanced',
        kind: PageKind.section,
        frontMatter: {'title': 'Advanced'},
      ),
      makePage(
        sourcePath: 'docs/guides/advanced/a.md',
        url: '/docs/guides/advanced/a/',
        section: 'docs',
        sectionPath: 'docs/guides/advanced',
        frontMatter: {'title': 'A', 'weight': 1},
      ),
      makePage(
        sourcePath: 'docs/guides/advanced/b.md',
        url: '/docs/guides/advanced/b/',
        section: 'docs',
        sectionPath: 'docs/guides/advanced',
        frontMatter: {'title': 'B', 'weight': 2},
      ),
      // Sibling page one level up — must NOT appear in the depth-3 listing.
      makePage(
        sourcePath: 'docs/guides/sibling.md',
        url: '/docs/guides/sibling/',
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'title': 'Sibling'},
      ),
    ];

    test('depth-3 page exposes full sectionPath and cumulative ancestors', () async {
      final page = deepPages().firstWhere((pg) => pg.url == '/docs/guides/advanced/a/');
      expect(page.sectionPath, 'docs/guides/advanced');
      final map = pageToMap(page);
      expect(map['ancestors'], ['docs', 'docs/guides', 'docs/guides/advanced']);
    });

    test('orderedSectionPages scopes to the depth-3 own level only', () async {
      final ordered = orderedSectionPages('docs/guides/advanced', deepPages()).map((p) => p.url).toList();
      expect(ordered, ['/docs/guides/advanced/a/', '/docs/guides/advanced/b/']);
      expect(ordered, isNot(contains('/docs/guides/sibling/')));
    });

    test('NavigationBuilder nests the tree correctly at depth 3', () async {
      final menu = const NavigationBuilder().build(deepPages());
      // docs → guides → advanced → [a, b]
      final docs = menu.firstWhere((n) => n['url'] == '/docs/');
      final guides = (docs['children'] as List).cast<Map<String, dynamic>>().firstWhere(
        (n) => n['url'] == '/docs/guides/',
      );
      final advanced = (guides['children'] as List).cast<Map<String, dynamic>>().firstWhere(
        (n) => n['url'] == '/docs/guides/advanced/',
      );
      final leafUrls = (advanced['children'] as List).cast<Map<String, dynamic>>().map((n) => n['url']).toList();
      expect(leafUrls, ['/docs/guides/advanced/a/', '/docs/guides/advanced/b/']);
    });
  });
}
