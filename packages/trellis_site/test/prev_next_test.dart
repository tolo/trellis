import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

/// Tests for S08 — in-section `${page.prev}`/`${page.next}` neighbor references.
///
/// Neighbor resolution reuses S01's canonical `orderedSectionPages` seam (the
/// same ordering source S02's `NavigationBuilder` and the list `${pages}` use);
/// S08 holds no comparator or lineage filter of its own. These tests prove the
/// neighbor math (index math, boundary absence, weight-not-date order), that
/// prev/next attach only to single doc pages (never list/section/home/taxonomy),
/// that only the existing side renders in a guarded region, and that a
/// prev/next-unused site is byte-for-byte unchanged (FR1 backward-compat).
void main() {
  late String packageRoot;

  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    packageRoot = p.dirname(packageUri!.toFilePath());
  });

  String fixture(String name) => p.join(packageRoot, 'test', 'test_fixtures', name);

  String tempOutputDir() {
    final dir = Directory.systemTemp.createTempSync('prevnext_out_');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir.path;
  }

  Page makePage({
    required String sourcePath,
    required String url,
    String section = '',
    String? sectionPath,
    PageKind kind = PageKind.single,
    bool isDraft = false,
    Map<String, dynamic>? frontMatter,
  }) => Page(
    sourcePath: sourcePath,
    url: url,
    section: section,
    sectionPath: sectionPath,
    kind: kind,
    isDraft: isDraft,
    isBundle: false,
    bundleAssets: const [],
    frontMatter: frontMatter ?? {},
  );

  /// Creates an isolated site dir whose `_default/single.html` and
  /// `_default/list.html` echo the prev/next contract so rendered output can be
  /// asserted. The single template mirrors the arbor `_default/single.html`
  /// prev/next region: a `tl:if`-guarded nav where each side renders only when
  /// its neighbor exists (the region markup itself is S04's; here it proves the
  /// S08 data drives the guards). Returns the site dir path.
  String prevNextSiteDir() {
    final dir = Directory.systemTemp.createTempSync('prevnext_site_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final defaults = Directory(p.join(dir.path, 'layouts', '_default'))..createSync(recursive: true);
    File(p.join(defaults.path, 'single.html')).writeAsStringSync('''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">Title</title></head>
<body>
<h1 tl:text="\${page.title}">Title</h1>
<nav class="page-nav" tl:if="\${page.prev} or \${page.next}">
  <a class="page-nav-prev" tl:if="\${page.prev}" tl:href="\${page.prev.url}">
    <span tl:text="\${page.prev.title}">Previous</span>
  </a>
  <a class="page-nav-next" tl:if="\${page.next}" tl:href="\${page.next.url}">
    <span tl:text="\${page.next.title}">Next</span>
  </a>
</nav>
</body>
</html>
''');
    File(p.join(defaults.path, 'list.html')).writeAsStringSync('''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">List</title></head>
<body>
<h1 tl:text="\${page.title}">List</h1>
<nav class="page-nav" tl:if="\${page.prev} or \${page.next}">has-neighbors</nav>
<ul>
  <li tl:each="child : \${pages}"><a tl:href="\${child.url}" tl:text="\${child.title}">child</a></li>
</ul>
</body>
</html>
''');
    File(p.join(dir.path, 'layouts', 'home.html')).writeAsStringSync('''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">Home</title></head>
<body>
<h1 tl:text="\${page.title}">Home</h1>
<nav class="page-nav" tl:if="\${page.prev} or \${page.next}">has-neighbors</nav>
</body>
</html>
''');
    return dir.path;
  }

  /// The three-page guides section [a(1), b(2), c(3)] whose canonical S01 order
  /// is [a, b, c] (weight ascending), plus the section `_index.md`.
  List<Page> guidesSection() => [
    makePage(
      sourcePath: 'docs/guides/_index.md',
      url: '/docs/guides/',
      section: 'docs',
      sectionPath: 'docs/guides',
      kind: PageKind.section,
      frontMatter: {'title': 'Guides'},
    ),
    makePage(
      sourcePath: 'docs/guides/a.md',
      url: '/docs/guides/a/',
      section: 'docs',
      sectionPath: 'docs/guides',
      frontMatter: {'title': 'A', 'weight': 1},
    ),
    makePage(
      sourcePath: 'docs/guides/b.md',
      url: '/docs/guides/b/',
      section: 'docs',
      sectionPath: 'docs/guides',
      frontMatter: {'title': 'B', 'weight': 2},
    ),
    makePage(
      sourcePath: 'docs/guides/c.md',
      url: '/docs/guides/c/',
      section: 'docs',
      sectionPath: 'docs/guides',
      frontMatter: {'title': 'C', 'weight': 3},
    ),
  ];

  Future<String> renderSingle(String siteDir, List<Page> pages, String url) async {
    final outputDir = tempOutputDir();
    await PageGenerator(siteDir: siteDir, outputDir: outputDir).generateAll(pages);
    final rel = url.replaceAll(RegExp(r'^/|/$'), '');
    return File(p.join(outputDir, rel, 'index.html')).readAsStringSync();
  }

  // --- S01 [TI01,TI02] Middle page exposes both neighbors in section order ----

  group('S01/TI01 — middle page exposes both neighbors in section order', () {
    test('b exposes prev=a{url,title} and next=c{url,title}', () async {
      final siteDir = prevNextSiteDir();
      final html = await renderSingle(siteDir, guidesSection(), '/docs/guides/b/');
      // prev side → a
      expect(html, contains('href="/docs/guides/a/"'));
      expect(html, contains('>A</span>'));
      // next side → c
      expect(html, contains('href="/docs/guides/c/"'));
      expect(html, contains('>C</span>'));
    });
  });

  // --- S02 [TI01] First page has no prev; last page has no next --------------

  group('S02/TI01 — boundaries handled by absence', () {
    test('first page a exposes next=b but no prev (no \${...} leak)', () async {
      final siteDir = prevNextSiteDir();
      final html = await renderSingle(siteDir, guidesSection(), '/docs/guides/a/');
      // next → b
      expect(html, contains('href="/docs/guides/b/"'));
      expect(html, contains('>B</span>'));
      // no prev side rendered
      expect(html, isNot(contains('page-nav-prev')));
      // no unresolved expression leaked to output
      expect(html, isNot(contains(r'${')));
    });

    test('last page c exposes prev=b but no next (no \${...} leak)', () async {
      final siteDir = prevNextSiteDir();
      final html = await renderSingle(siteDir, guidesSection(), '/docs/guides/c/');
      // prev → b
      expect(html, contains('href="/docs/guides/b/"'));
      expect(html, contains('>B</span>'));
      // no next side rendered
      expect(html, isNot(contains('page-nav-next')));
      expect(html, isNot(contains(r'${')));
    });
  });

  // --- S03 [TI01] Single-page section yields neither neighbor ----------------

  group('S03/TI01 — single-page section yields neither neighbor', () {
    test('solo page builds and renders with no prev/next region', () async {
      final siteDir = prevNextSiteDir();
      final pages = [
        makePage(
          sourcePath: 'docs/guides/_index.md',
          url: '/docs/guides/',
          section: 'docs',
          sectionPath: 'docs/guides',
          kind: PageKind.section,
          frontMatter: {'title': 'Guides'},
        ),
        makePage(
          sourcePath: 'docs/guides/solo.md',
          url: '/docs/guides/solo/',
          section: 'docs',
          sectionPath: 'docs/guides',
          frontMatter: {'title': 'Solo', 'weight': 1},
        ),
      ];
      final html = await renderSingle(siteDir, pages, '/docs/guides/solo/');
      // The guarded nav collapses entirely — no prev/next links at all.
      expect(html, isNot(contains('class="page-nav"')));
      expect(html, isNot(contains(r'${')));
      // Page still rendered.
      expect(html, contains('>Solo</h1>'));
    });
  });

  // --- S04 [TI01,TI02] Weighted neighbor order matches S01, not date order ----

  group('S04/TI01 — weighted order matches S01, not date order', () {
    test('a.next is b by weight even though b is newer (date-desc would flip)', () async {
      final siteDir = prevNextSiteDir();
      // authored weight order [a(1), b(2)] is the REVERSE of date-desc (b newer).
      final pages = [
        makePage(
          sourcePath: 'docs/guides/_index.md',
          url: '/docs/guides/',
          section: 'docs',
          sectionPath: 'docs/guides',
          kind: PageKind.section,
          frontMatter: {'title': 'Guides'},
        ),
        makePage(
          sourcePath: 'docs/guides/a.md',
          url: '/docs/guides/a/',
          section: 'docs',
          sectionPath: 'docs/guides',
          frontMatter: {'title': 'A', 'weight': 1, 'date': '2020-01-01'},
        ),
        makePage(
          sourcePath: 'docs/guides/b.md',
          url: '/docs/guides/b/',
          section: 'docs',
          sectionPath: 'docs/guides',
          frontMatter: {'title': 'B', 'weight': 2, 'date': '2024-01-01'},
        ),
      ];
      final html = await renderSingle(siteDir, pages, '/docs/guides/a/');
      // Weight order → a.next = b. A date-desc sort would make b first (b.next=a),
      // leaving a with no next; the presence of a next=b proves S01 weight order.
      expect(html, contains('href="/docs/guides/b/"'));
      expect(html, contains('>B</span>'));
      expect(html, isNot(contains('page-nav-prev')));
    });

    test('neighbor order matches orderedSectionPages seam exactly', () {
      final pages = guidesSection();
      final ordered = orderedSectionPages('docs/guides', pages).map((pg) => pg.url).toList();
      expect(ordered, ['/docs/guides/a/', '/docs/guides/b/', '/docs/guides/c/']);
    });
  });

  // --- S05 [TI02] Only existing neighbor link renders in the guarded region ---

  group('S05/TI02 — only existing neighbor side renders', () {
    test('first page renders only the next link, prev side omitted', () async {
      final siteDir = prevNextSiteDir();
      final html = await renderSingle(siteDir, guidesSection(), '/docs/guides/a/');
      // The region is present (next exists) but the prev anchor is absent —
      // not an empty/placeholder anchor.
      expect(html, contains('class="page-nav"'));
      expect(html, contains('page-nav-next'));
      expect(html, isNot(contains('page-nav-prev')));
    });
  });

  // --- TI02 — list/section/home/taxonomy pages receive NO neighbor keys ------

  group('TI02 — prev/next attach to single pages only', () {
    test('section list page exposes neither prev nor next', () async {
      final siteDir = prevNextSiteDir();
      final outputDir = tempOutputDir();
      await PageGenerator(siteDir: siteDir, outputDir: outputDir).generateAll(guidesSection());
      final html = File(p.join(outputDir, 'docs', 'guides', 'index.html')).readAsStringSync();
      // The list template's neighbor guard collapses — no 'has-neighbors' text.
      expect(html, isNot(contains('has-neighbors')));
      expect(html, isNot(contains(r'${')));
    });

    test('home page exposes neither prev nor next', () async {
      final siteDir = prevNextSiteDir();
      final outputDir = tempOutputDir();
      final pages = [
        makePage(sourcePath: '_index.md', url: '/', kind: PageKind.home, frontMatter: {'title': 'Home'}),
        makePage(
          sourcePath: 'docs/guides/a.md',
          url: '/docs/guides/a/',
          section: 'docs',
          sectionPath: 'docs/guides',
          frontMatter: {'title': 'A', 'weight': 1},
        ),
        makePage(
          sourcePath: 'docs/guides/b.md',
          url: '/docs/guides/b/',
          section: 'docs',
          sectionPath: 'docs/guides',
          frontMatter: {'title': 'B', 'weight': 2},
        ),
      ];
      await PageGenerator(siteDir: siteDir, outputDir: outputDir).generateAll(pages);
      final html = File(p.join(outputDir, 'index.html')).readAsStringSync();
      expect(html, isNot(contains('has-neighbors')));
      expect(html, isNot(contains(r'${')));
    });

    test('taxonomy term page (single-kind list page) exposes neither prev nor next', () async {
      final siteDir = prevNextSiteDir();
      final outputDir = tempOutputDir();
      // A taxonomy term page is PageKind.single but flagged as a list page via
      // frontMatter['termName']; it must NOT receive neighbor keys.
      final termPage = makePage(
        sourcePath: '_taxonomy/tags/dart.md',
        url: '/tags/dart/',
        section: 'tags',
        sectionPath: 'tags',
        frontMatter: {'title': 'dart', 'taxonomyName': 'tags', 'termName': 'dart', 'pages': const <dynamic>[]},
      );
      // A sibling single page in the same sectionPath, so an erroneous own-sort
      // WOULD find a neighbor if the term page were treated as a single doc page.
      final sibling = makePage(
        sourcePath: '_taxonomy/tags/flutter.md',
        url: '/tags/flutter/',
        section: 'tags',
        sectionPath: 'tags',
        frontMatter: {'title': 'flutter', 'taxonomyName': 'tags', 'termName': 'flutter', 'pages': const <dynamic>[]},
      );
      await PageGenerator(siteDir: siteDir, outputDir: outputDir).generateAll([termPage, sibling]);
      final html = File(p.join(outputDir, 'tags', 'dart', 'index.html')).readAsStringSync();
      expect(html, isNot(contains('has-neighbors')));
      expect(html, isNot(contains(r'${')));
    });
  });

  // --- S06 [TI03] Prev/next-unused site is byte-for-byte unchanged -----------

  group('S06/TI03 — prev/next-unused site byte-for-byte regression', () {
    test('build_site output equals the pre-S08 captured baseline byte-for-byte', () async {
      // The golden was captured from the pre-S08 engine (S08 injection disabled)
      // via a git-clean baseline build of the same fixture; this proves attaching
      // prev/next keys to single-page maps perturbs no emitted bytes when the
      // templates do not reference ${page.prev}/${page.next} (FR1 invariant).
      final golden = (jsonDecode(File(fixture('prevnext_unused_regression_golden.json')).readAsStringSync()) as Map)
          .cast<String, dynamic>();

      final siteDir = fixture('build_site');
      final outputDir = tempOutputDir();
      final config = SiteConfig(
        siteDir: siteDir,
        baseUrl: 'https://example.com',
        contentDir: p.join(siteDir, 'content'),
        layoutsDir: p.join(siteDir, 'layouts'),
        staticDir: p.join(siteDir, 'static'),
        outputDir: outputDir,
      );
      await TrellisSite(config).build();

      final produced = <String, String>{};
      for (final f in Directory(outputDir).listSync(recursive: true).whereType<File>()) {
        produced[p.relative(f.path, from: outputDir).replaceAll(r'\', '/')] = f.readAsStringSync();
      }

      expect(produced.keys.toSet(), golden.keys.toSet(), reason: 'output file set changed');
      for (final entry in golden.entries) {
        expect(produced[entry.key], entry.value, reason: 'byte drift in ${entry.key}');
      }
    });
  });
}
