import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_site/trellis_site.dart';

/// Tests for S02 — the hierarchical `${site.menu}` navigation tree.
///
/// Unit tests drive [NavigationBuilder.build] directly with constructed pages
/// (fast, precise assertions on tree shape/order/title/exclusion). Integration
/// tests run a full build of the `menu_site` fixture to prove `${site.menu}`
/// rides the shared site params onto every page kind (single, section, home,
/// taxonomy virtual), and a `build_site` build proves the menu-unused
/// byte-for-byte regression.
void main() {
  late String packageRoot;

  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    packageRoot = p.dirname(packageUri!.toFilePath());
  });

  String fixture(String name) => p.join(packageRoot, 'test', 'test_fixtures', name);

  Page makePage({
    required String url,
    required PageKind kind,
    String section = '',
    String? sectionPath,
    bool isDraft = false,
    Map<String, dynamic>? frontMatter,
  }) => Page(
    sourcePath: url,
    url: url,
    section: section,
    sectionPath: sectionPath ?? section,
    kind: kind,
    isDraft: isDraft,
    isBundle: false,
    bundleAssets: const [],
    frontMatter: frontMatter ?? <String, dynamic>{},
  );

  /// Recursively finds the first node whose `url` equals [url], or null.
  Map<String, dynamic>? findByUrl(List<dynamic> nodes, String url) {
    for (final node in nodes.cast<Map<String, dynamic>>()) {
      if (node['url'] == url) return node;
      final child = findByUrl(node['children'] as List<dynamic>, url);
      if (child != null) return child;
    }
    return null;
  }

  /// Every `url` present anywhere in the tree (flattened).
  Set<String> allUrls(List<dynamic> nodes) {
    final urls = <String>{};
    for (final node in nodes.cast<Map<String, dynamic>>()) {
      urls.add(node['url'] as String);
      urls.addAll(allUrls(node['children'] as List<dynamic>));
    }
    return urls;
  }

  // A shared page set: docs → guides → {a(w1), b(w2)} plus a top-level blog post.
  List<Page> nestedWeightedPages() => [
    makePage(url: '/', kind: PageKind.home),
    makePage(
      url: '/docs/',
      kind: PageKind.section,
      section: 'docs',
      sectionPath: 'docs',
      frontMatter: {'title': 'Docs'},
    ),
    makePage(
      url: '/docs/guides/',
      kind: PageKind.section,
      section: 'docs',
      sectionPath: 'docs/guides',
      frontMatter: {'title': 'Guides'},
    ),
    makePage(
      url: '/docs/guides/a/',
      kind: PageKind.single,
      section: 'docs',
      sectionPath: 'docs/guides',
      frontMatter: {'title': 'Alpha', 'weight': 1},
    ),
    makePage(
      url: '/docs/guides/b/',
      kind: PageKind.single,
      section: 'docs',
      sectionPath: 'docs/guides',
      frontMatter: {'title': 'Bravo', 'weight': 2},
    ),
    makePage(
      url: '/blog/post/',
      kind: PageKind.single,
      section: 'blog',
      sectionPath: 'blog',
      frontMatter: {'title': 'Post'},
    ),
  ];

  group('S01/TI01 — nested weight-ordered tree', () {
    test('docs→guides branch children are [a, b] in ascending weight (via orderedSectionPages)', () {
      final tree = const NavigationBuilder().build(nestedWeightedPages());

      // docs node exists with a guides child.
      final docs = findByUrl(tree, '/docs/')!;
      expect(docs['title'], 'Docs');
      final guides = findByUrl([docs], '/docs/guides/')!;
      expect(guides['title'], 'Guides');

      // guides children are a then b — canonical weight order, not a re-sort.
      final childUrls = (guides['children'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((c) => c['url'])
          .toList();
      expect(childUrls, ['/docs/guides/a/', '/docs/guides/b/']);
    });

    test('every node exposes exactly title, url, children keys', () {
      final tree = const NavigationBuilder().build(nestedWeightedPages());
      void checkShape(List<dynamic> nodes) {
        for (final node in nodes.cast<Map<String, dynamic>>()) {
          expect(node.keys.toSet(), {'title', 'url', 'children'}, reason: 'node shape must be {title,url,children}');
          expect(node['title'], isA<String>());
          expect(node['url'], isA<String>());
          expect(node['children'], isA<List<dynamic>>());
          checkShape(node['children'] as List<dynamic>);
        }
      }

      checkShape(tree);
    });

    test('ordering matches orderedSectionPages verbatim (no builder-local sort)', () {
      final pages = nestedWeightedPages();
      final tree = const NavigationBuilder().build(pages);
      // The single-source seam applied to the eligible set.
      final eligible = pages.where((pg) => !pg.isDraft).toList();
      final canonical = orderedSectionPages('docs/guides', eligible).map((pg) => pg.url).toList();
      final guidesChildren = (findByUrl(tree, '/docs/guides/')!['children'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((c) => c['url'] as String)
          .toList();
      expect(guidesChildren, canonical);
    });
  });

  group('S02/TI03 — active trail resolvable from node.url vs page.url', () {
    test('node with url == /docs/guides/a/ and its docs+guides ancestors are all present as urls', () {
      final tree = const NavigationBuilder().build(nestedWeightedPages());
      const pageUrl = '/docs/guides/a/';

      // The active node is identifiable purely by url match.
      expect(findByUrl(tree, pageUrl), isNotNull);
      // Ancestor trail urls are present for a template to mark active-trail.
      expect(findByUrl(tree, '/docs/'), isNotNull);
      expect(findByUrl(tree, '/docs/guides/'), isNotNull);
    });

    test('no node carries an active/activeTrail flag (shape is title/url/children only)', () {
      final tree = const NavigationBuilder().build(nestedWeightedPages());
      bool anyActiveKey(List<dynamic> nodes) => nodes.cast<Map<String, dynamic>>().any(
        (n) => n.containsKey('active') || n.containsKey('activeTrail') || anyActiveKey(n['children'] as List<dynamic>),
      );
      expect(anyActiveKey(tree), isFalse);
    });
  });

  group('S03/TI04 — draft and menu_exclude pages absent', () {
    List<Page> pagesWithExclusions({bool draftC = true}) => [
      makePage(
        url: '/docs/',
        kind: PageKind.section,
        section: 'docs',
        sectionPath: 'docs',
        frontMatter: {'title': 'Docs'},
      ),
      makePage(
        url: '/docs/guides/',
        kind: PageKind.section,
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'title': 'Guides'},
      ),
      makePage(
        url: '/docs/guides/a/',
        kind: PageKind.single,
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'title': 'Alpha'},
      ),
      makePage(
        url: '/docs/guides/c/',
        kind: PageKind.single,
        section: 'docs',
        sectionPath: 'docs/guides',
        isDraft: draftC,
        frontMatter: {'title': 'Charlie', 'draft': draftC},
      ),
      makePage(
        url: '/docs/guides/d/',
        kind: PageKind.single,
        section: 'docs',
        sectionPath: 'docs/guides',
        frontMatter: {'title': 'Delta', 'menu_exclude': true},
      ),
    ];

    test('draft:true page (c) and menu_exclude:true page (d) appear nowhere', () {
      final tree = const NavigationBuilder().build(pagesWithExclusions());
      final urls = allUrls(tree);
      expect(urls, isNot(contains('/docs/guides/c/')), reason: 'draft page must be absent');
      expect(urls, isNot(contains('/docs/guides/d/')), reason: 'menu_exclude page must be absent');
      expect(urls, contains('/docs/guides/a/'), reason: 'non-excluded page stays');
    });

    test('with includeDrafts semantics (c no longer draft) c reappears but d stays excluded', () {
      // Simulate the post-includeDrafts state: isDraft cleared on c.
      final tree = const NavigationBuilder().build(pagesWithExclusions(draftC: false));
      final urls = allUrls(tree);
      expect(urls, contains('/docs/guides/c/'), reason: 'un-drafted page reappears');
      expect(
        urls,
        isNot(contains('/docs/guides/d/')),
        reason: 'menu_exclude is independent of draft state — stays excluded',
      );
    });
  });

  group('S04/S05/TI05 — title fallback and empty tree', () {
    test('empty page set yields [] (never null)', () {
      expect(const NavigationBuilder().build(const []), isEmpty);
    });

    test('fully-excluded content yields []', () {
      final pages = [
        makePage(
          url: '/x/',
          kind: PageKind.single,
          section: 'x',
          sectionPath: 'x',
          isDraft: true,
          frontMatter: {'draft': true},
        ),
      ];
      expect(const NavigationBuilder().build(pages), isEmpty);
    });

    test('page with no menu_title and no title yields humanized slug "Getting Started"', () {
      final pages = [
        makePage(url: '/docs/getting-started/', kind: PageKind.single, section: 'docs', sectionPath: 'docs'),
      ];
      final tree = const NavigationBuilder().build(pages);
      final node = findByUrl(tree, '/docs/getting-started/')!;
      expect(node['title'], 'Getting Started');
    });

    test('menu_title overrides front-matter title (3-tier precedence, tier 1)', () {
      final pages = [
        makePage(
          url: '/blog/post/',
          kind: PageKind.single,
          section: 'blog',
          sectionPath: 'blog',
          frontMatter: {'title': 'Real Title', 'menu_title': 'Menu Label'},
        ),
      ];
      final tree = const NavigationBuilder().build(pages);
      expect(findByUrl(tree, '/blog/post/')!['title'], 'Menu Label');
    });

    test('section-folder node with no title humanizes its folder segment', () {
      final pages = [
        makePage(
          url: '/docs/',
          kind: PageKind.section,
          section: 'docs',
          sectionPath: 'docs',
          frontMatter: {'title': 'Docs'},
        ),
        // guides section page has no title.
        makePage(url: '/docs/guides/', kind: PageKind.section, section: 'docs', sectionPath: 'docs/guides'),
        makePage(
          url: '/docs/guides/a/',
          kind: PageKind.single,
          section: 'docs',
          sectionPath: 'docs/guides',
          frontMatter: {'title': 'A'},
        ),
      ];
      final tree = const NavigationBuilder().build(pages);
      expect(findByUrl(tree, '/docs/guides/')!['title'], 'Guides');
    });

    test('humanizeSegment replaces - and _ and title-cases each word', () {
      expect(humanizeSegment('getting-started'), 'Getting Started');
      expect(humanizeSegment('api_reference'), 'Api Reference');
      expect(humanizeSegment('multi_word-slug'), 'Multi Word Slug');
      expect(humanizeSegment(''), '');
    });
  });

  group('Edge cases — no _index section node, excluded-section hoisting', () {
    test('section folder with no _index.md still yields a synthesized node (humanized folder title)', () {
      final pages = [
        // notes/ has no _index.md; only a nested page.
        makePage(
          url: '/notes/note/',
          kind: PageKind.single,
          section: 'notes',
          sectionPath: 'notes',
          frontMatter: {'title': 'A Note'},
        ),
      ];
      final tree = const NavigationBuilder().build(pages);
      // A synthesized "Notes" section node exists with url '' and the note as a child.
      final notes = tree.cast<Map<String, dynamic>>().singleWhere((n) => n['title'] == 'Notes');
      expect(notes['url'], '');
      final noteChild = (notes['children'] as List<dynamic>).cast<Map<String, dynamic>>().single;
      expect(noteChild['url'], '/notes/note/');
    });

    test('menu_exclude:true section page with surviving children drops the node and hoists children to parent', () {
      final pages = [
        makePage(
          url: '/docs/',
          kind: PageKind.section,
          section: 'docs',
          sectionPath: 'docs',
          frontMatter: {'title': 'Docs'},
        ),
        // tutorials section page opts out but has a surviving child.
        makePage(
          url: '/docs/tutorials/',
          kind: PageKind.section,
          section: 'docs',
          sectionPath: 'docs/tutorials',
          frontMatter: {'title': 'Tutorials', 'menu_exclude': true},
        ),
        makePage(
          url: '/docs/tutorials/t1/',
          kind: PageKind.single,
          section: 'docs',
          sectionPath: 'docs/tutorials',
          frontMatter: {'title': 'Tutorial One'},
        ),
      ];
      final tree = const NavigationBuilder().build(pages);
      // The tutorials section node itself is gone.
      expect(allUrls(tree), isNot(contains('/docs/tutorials/')));
      // Its surviving child is hoisted to the docs level (docs is tutorials' parent).
      final docsChildUrls = (findByUrl(tree, '/docs/')!['children'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((c) => c['url'])
          .toList();
      expect(docsChildUrls, contains('/docs/tutorials/t1/'));
    });
  });

  group('S02/TI02 — \${site.menu} present on every page render (full build)', () {
    Future<String> buildMenuSiteAndRead(String relativeHtmlPath) async {
      final siteDir = fixture('menu_site');
      final loaded = SiteConfig.load(p.join(siteDir, 'trellis_site.yaml'));
      final outputDir = Directory.systemTemp.createTempSync('menu_site_').path;
      addTearDown(() => Directory(outputDir).deleteSync(recursive: true));
      final config = SiteConfig(
        siteDir: siteDir,
        baseUrl: 'https://example.com',
        contentDir: p.join(siteDir, 'content'),
        layoutsDir: p.join(siteDir, 'layouts'),
        staticDir: p.join(siteDir, 'static'),
        outputDir: outputDir,
        taxonomies: loaded.taxonomies,
      );
      await TrellisSite(config).build();
      return File(p.join(outputDir, relativeHtmlPath)).readAsStringSync();
    }

    test('single page (PageKind.single) exposes a non-null menu list', () async {
      final html = await buildMenuSiteAndRead(p.join('docs', 'guides', 'a', 'index.html'));
      expect(html, contains('MENU-PRESENT'));
      expect(html, contains('/docs/guides/a/'));
    });

    test('section page (PageKind.section) exposes a non-null menu list', () async {
      final html = await buildMenuSiteAndRead(p.join('docs', 'index.html'));
      expect(html, contains('MENU-PRESENT'));
    });

    test('home page (PageKind.home) exposes a non-null menu list', () async {
      final html = await buildMenuSiteAndRead('index.html');
      expect(html, contains('MENU-PRESENT'));
    });

    test('taxonomy virtual page exposes a non-null menu list', () async {
      final termHtml = await buildMenuSiteAndRead(p.join('tags', 'dart', 'index.html'));
      expect(termHtml, contains('MENU-PRESENT'), reason: 'taxonomy term page must carry site.menu');
      final listHtml = await buildMenuSiteAndRead(p.join('tags', 'index.html'));
      expect(listHtml, contains('MENU-PRESENT'), reason: 'taxonomy listing page must carry site.menu');
    });

    test(
      'rendered tree nests docs→guides→[a,b,getting-started] in weight order and excludes draft/menu_exclude',
      () async {
        final html = await buildMenuSiteAndRead('index.html');
        final hrefs = RegExp(r'href="([^"]*)"').allMatches(html).map((m) => m.group(1)).toList();
        // Weight order among guides own-level pages.
        final ia = hrefs.indexOf('/docs/guides/a/');
        final ib = hrefs.indexOf('/docs/guides/b/');
        final ig = hrefs.indexOf('/docs/guides/getting-started/');
        expect([ia, ib, ig], everyElement(greaterThanOrEqualTo(0)));
        expect(ia < ib && ib < ig, isTrue, reason: 'weight order a(1) < b(2) < getting-started(3)');
        // Draft (c) and menu_exclude (d) are absent.
        expect(html, isNot(contains('/docs/guides/c/')));
        expect(html, isNot(contains('/docs/guides/d/')));
        // Taxonomy 'tags' section is not a menu node (menu mirrors real content).
        expect(html, isNot(contains('href="/tags/"')));
      },
    );
  });

  group('S06/TI06 — menu-unused site byte-for-byte regression', () {
    test('build_site output (pages + feeds + sitemap + pagination + taxonomy) equals pre-S02 golden', () async {
      final golden = (jsonDecode(File(fixture('menu_unused_regression_golden.json')).readAsStringSync()) as Map)
          .cast<String, dynamic>();

      final siteDir = fixture('build_site');
      final outputDir = Directory.systemTemp.createTempSync('menu_reg_').path;
      addTearDown(() => Directory(outputDir).deleteSync(recursive: true));
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

  group('arbor sidebar guards — empty-url menu node renders a label, not an empty-href link', () {
    // Mirrors the sidebar link/label guards in `themes/arbor/layouts/base.html`
    // (levels n1/n2/n3). Keep the tl:if/tl:unless idiom in sync with the theme:
    // guards must use `${nX.url != ''}` — a bare `${nX.url}` is truthy for ''
    // per Thymeleaf semantics and would render `<a href="">`.
    const sidebarTemplate = '''
<ul class="sidebar-tree">
  <li tl:each="n1 : \${site.menu}">
    <a class="sidebar-link" tl:if="\${n1.url != ''}" tl:href="\${n1.url}" tl:text="\${n1.title}">L1</a>
    <span class="sidebar-label" tl:unless="\${n1.url != ''}" tl:text="\${n1.title}">L1</span>
    <ul tl:if="\${n1.children}">
      <li tl:each="n2 : \${n1.children}">
        <a class="sidebar-link" tl:if="\${n2.url != ''}" tl:href="\${n2.url}" tl:text="\${n2.title}">L2</a>
        <span class="sidebar-label" tl:unless="\${n2.url != ''}" tl:text="\${n2.title}">L2</span>
        <ul tl:if="\${n2.children}">
          <li tl:each="n3 : \${n2.children}">
            <a class="sidebar-link" tl:if="\${n3.url != ''}" tl:href="\${n3.url}" tl:text="\${n3.title}">L3</a>
            <span class="sidebar-label" tl:unless="\${n3.url != ''}" tl:text="\${n3.title}">L3</span>
          </li>
        </ul>
      </li>
    </ul>
  </li>
</ul>
''';

    test('synthesized no-_index section nodes (url \'\') render as plain labels; linked nodes keep hrefs', () {
      // notes/ and notes/drafts/ have no _index.md → NavigationBuilder
      // synthesizes their nodes with url '' (navigation_builder.dart).
      final pages = [
        makePage(
          url: '/notes/drafts/n1/',
          kind: PageKind.single,
          section: 'notes',
          sectionPath: 'notes/drafts',
          frontMatter: {'title': 'A Note'},
        ),
        makePage(
          url: '/docs/',
          kind: PageKind.section,
          section: 'docs',
          sectionPath: 'docs',
          frontMatter: {'title': 'Docs'},
        ),
      ];
      final tree = const NavigationBuilder().build(pages);
      // Precondition: the synthesized ancestors really carry empty urls.
      final notes = tree.cast<Map<String, dynamic>>().singleWhere((n) => n['title'] == 'Notes');
      expect(notes['url'], '');
      expect((notes['children'] as List<dynamic>).cast<Map<String, dynamic>>().single['url'], '');

      final html = Trellis(loader: MapLoader({})).render(sidebarTemplate, {
        'site': {'menu': tree},
      });

      // Empty-url nodes at levels 1 and 2 become plain labels.
      expect(html, contains('<span class="sidebar-label">Notes</span>'));
      expect(html, contains('<span class="sidebar-label">Drafts</span>'));
      expect(html, isNot(contains('href=""')), reason: 'no empty-href link may ever render');
      expect(html, isNot(contains('>Notes</a>')));
      expect(html, isNot(contains('>Drafts</a>')));

      // Nodes with a url still render as real links, never as labels.
      expect(html, contains('href="/notes/drafts/n1/"'));
      expect(html, contains('>A Note</a>'));
      expect(html, contains('href="/docs/"'));
      expect(html, isNot(contains('<span class="sidebar-label">Docs</span>')));
    });
  });

  group('sibling section ordering by weight', () {
    // Two top-level sections whose weight order is the reverse of their lexical
    // order, each with one child page.
    List<Page> twoSections({int? zebraWeight, int? alphaWeight}) => [
      makePage(url: '/', kind: PageKind.home),
      makePage(
        url: '/zebra/',
        kind: PageKind.section,
        sectionPath: 'zebra',
        frontMatter: {'title': 'Zebra', 'weight': ?zebraWeight},
      ),
      makePage(url: '/zebra/p/', kind: PageKind.single, sectionPath: 'zebra', frontMatter: {'title': 'ZP'}),
      makePage(
        url: '/alpha/',
        kind: PageKind.section,
        sectionPath: 'alpha',
        frontMatter: {'title': 'Alpha', 'weight': ?alphaWeight},
      ),
      makePage(url: '/alpha/p/', kind: PageKind.single, sectionPath: 'alpha', frontMatter: {'title': 'AP'}),
    ];

    List<String> topSectionUrls(List<Map<String, dynamic>> tree) =>
        tree.map((n) => n['url'] as String).where((u) => u.isNotEmpty).toList();

    test('weighted sibling sections order by ascending weight, not lexically', () {
      // Zebra weight 1, Alpha weight 2 → Zebra first (weight), though lexically Alpha < Zebra.
      final tree = const NavigationBuilder().build(twoSections(zebraWeight: 1, alphaWeight: 2));
      expect(topSectionUrls(tree), ['/zebra/', '/alpha/']);
    });

    test('unweighted sibling sections keep lexical order (backward-compatible)', () {
      final tree = const NavigationBuilder().build(twoSections());
      expect(topSectionUrls(tree), ['/alpha/', '/zebra/']);
    });

    test('a weighted section sorts ahead of an unweighted sibling', () {
      // Only Alpha weighted → Alpha first despite Zebra being unweighted.
      final tree = const NavigationBuilder().build(twoSections(alphaWeight: 5));
      expect(topSectionUrls(tree), ['/alpha/', '/zebra/']);
      // And with only Zebra weighted, Zebra leads even though Alpha < Zebra lexically.
      final tree2 = const NavigationBuilder().build(twoSections(zebraWeight: 5));
      expect(topSectionUrls(tree2), ['/zebra/', '/alpha/']);
    });
  });
}
