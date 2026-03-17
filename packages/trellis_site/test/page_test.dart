import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

void main() {
  group('TocEntry', () {
    test('constructs with required fields', () {
      const entry = TocEntry(id: 'intro', text: 'Introduction', level: 2);
      expect(entry.id, 'intro');
      expect(entry.text, 'Introduction');
      expect(entry.level, 2);
    });

    test('toString includes all fields', () {
      const entry = TocEntry(id: 'intro', text: 'Introduction', level: 2);
      expect(entry.toString(), contains('intro'));
      expect(entry.toString(), contains('Introduction'));
      expect(entry.toString(), contains('2'));
    });
  });

  group('PageKind', () {
    test('has single, section, home values', () {
      expect(PageKind.values, contains(PageKind.single));
      expect(PageKind.values, contains(PageKind.section));
      expect(PageKind.values, contains(PageKind.home));
      expect(PageKind.values.length, 3);
    });
  });

  group('Page', () {
    test('constructs with required fields and default mutable fields', () {
      final page = Page(
        sourcePath: 'about.md',
        url: '/about/',
        section: '',
        kind: PageKind.single,
        isDraft: false,
        isBundle: false,
        bundleAssets: [],
      );

      expect(page.sourcePath, 'about.md');
      expect(page.url, '/about/');
      expect(page.section, '');
      expect(page.kind, PageKind.single);
      expect(page.isDraft, false);
      expect(page.isBundle, false);
      expect(page.bundleAssets, isEmpty);

      // Default mutable fields
      expect(page.frontMatter, isEmpty);
      expect(page.rawContent, '');
      expect(page.content, '');
      expect(page.summary, '');
      expect(page.toc, isEmpty);
    });

    test('mutable fields can be set after construction', () {
      final page = Page(
        sourcePath: 'about.md',
        url: '/about/',
        section: '',
        kind: PageKind.single,
        isDraft: false,
        isBundle: false,
        bundleAssets: [],
      );

      page.frontMatter = {'title': 'About'};
      page.rawContent = '# About\nHello';
      page.content = '<h1>About</h1><p>Hello</p>';
      page.summary = 'Hello';
      page.toc = [TocEntry(id: 'about', text: 'About', level: 1)];

      expect(page.frontMatter['title'], 'About');
      expect(page.rawContent, contains('# About'));
      expect(page.content, contains('<h1>About</h1>'));
      expect(page.summary, 'Hello');
      expect(page.toc.length, 1);
    });

    test('optional constructor params override defaults', () {
      final page = Page(
        sourcePath: 'draft.md',
        url: '/draft/',
        section: '',
        kind: PageKind.single,
        isDraft: true,
        isBundle: false,
        bundleAssets: [],
        frontMatter: {'title': 'Draft'},
        rawContent: 'Draft content',
      );

      expect(page.isDraft, true);
      expect(page.frontMatter['title'], 'Draft');
      expect(page.rawContent, 'Draft content');
    });

    test('toString includes key fields', () {
      final page = Page(
        sourcePath: 'posts/hello.md',
        url: '/posts/hello/',
        section: 'posts',
        kind: PageKind.single,
        isDraft: false,
        isBundle: false,
        bundleAssets: [],
      );

      final str = page.toString();
      expect(str, contains('posts/hello.md'));
      expect(str, contains('/posts/hello/'));
      expect(str, contains('posts'));
      expect(str, contains('single'));
    });

    test('bundle page with assets', () {
      final page = Page(
        sourcePath: 'posts/my-trip/index.md',
        url: '/posts/my-trip/',
        section: 'posts',
        kind: PageKind.single,
        isDraft: false,
        isBundle: true,
        bundleAssets: ['posts/my-trip/photo.jpg'],
      );

      expect(page.isBundle, true);
      expect(page.bundleAssets, ['posts/my-trip/photo.jpg']);
    });
  });
}
