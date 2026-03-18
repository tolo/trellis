import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

late String _fixturesDir;

/// Returns the absolute path to a markdown test fixture.
String fixture(String name) => p.join(_fixturesDir, name);

/// Creates a minimal [Page] with the given [rawContent] for test use.
Page makePageWithContent(String rawContent, {Map<String, dynamic>? frontMatter}) => Page(
  sourcePath: 'test.md',
  url: '/test/',
  section: '',
  kind: PageKind.single,
  isDraft: false,
  isBundle: false,
  bundleAssets: [],
  rawContent: rawContent,
  frontMatter: frontMatter ?? {},
);

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _fixturesDir = p.join(packageRoot, 'test', 'test_fixtures', 'markdown');
  });

  group('MarkdownRenderer', () {
    late MarkdownRenderer renderer;

    setUp(() => renderer = const MarkdownRenderer());

    group('basic rendering', () {
      test('renders Markdown paragraph to <p> tag', () {
        final page = makePageWithContent('Hello world.');
        renderer.render(page);
        expect(page.content, contains('<p>Hello world.</p>'));
      });

      test('renders heading to <h2> with id', () {
        final page = makePageWithContent('## Getting Started\n\nSome text.');
        renderer.render(page);
        expect(page.content, contains('<h2'));
        expect(page.content, contains('id="getting-started"'));
        expect(page.content, contains('Getting Started'));
      });

      test('renders strong/bold', () {
        final page = makePageWithContent('**bold** text');
        renderer.render(page);
        expect(page.content, contains('<strong>bold</strong>'));
      });

      test('renders inline code', () {
        final page = makePageWithContent('Use `dart pub get`.');
        renderer.render(page);
        expect(page.content, contains('<code>dart pub get</code>'));
      });

      test('content ends with newline', () {
        final page = makePageWithContent('Hello.');
        renderer.render(page);
        expect(page.content, endsWith('\n'));
      });
    });

    group('GFM extensions', () {
      test('renders GFM table', () {
        final page = makePageWithContent('| A | B |\n|---|---|\n| 1 | 2 |');
        renderer.render(page);
        expect(page.content, contains('<table>'));
        expect(page.content, contains('<th>A</th>'));
        expect(page.content, contains('<td>1</td>'));
      });

      test('renders task list checkboxes', () {
        final page = makePageWithContent('- [x] Done\n- [ ] Pending');
        renderer.render(page);
        expect(page.content, contains('<input type="checkbox"'));
        expect(page.content, contains('checked'));
      });

      test('renders strikethrough', () {
        final page = makePageWithContent('~~crossed out~~');
        renderer.render(page);
        expect(page.content, contains('<del>crossed out</del>'));
      });

      test('renders footnote', () {
        final page = makePageWithContent('Text with footnote.[^1]\n\n[^1]: The footnote text.');
        renderer.render(page);
        expect(page.content, contains('footnote'));
      });

      test('renders GitHub alert block', () {
        final page = makePageWithContent('> [!NOTE]\n> This is a note.');
        renderer.render(page);
        // GitHub alerts render as div.markdown-alert with a title paragraph
        expect(page.content, contains('markdown-alert'));
        expect(page.content, contains('This is a note.'));
      });
    });

    group('empty content', () {
      test('empty rawContent: content stays empty', () {
        final page = makePageWithContent('');
        renderer.render(page);
        expect(page.content, isEmpty);
      });

      test('empty rawContent: summary stays empty', () {
        final page = makePageWithContent('');
        renderer.render(page);
        expect(page.summary, isEmpty);
      });

      test('empty rawContent: toc stays empty', () {
        final page = makePageWithContent('');
        renderer.render(page);
        expect(page.toc, isEmpty);
      });
    });

    group('TOC extraction', () {
      test('extracts h2 heading to toc', () {
        final page = makePageWithContent('## Getting Started\n\nText.');
        renderer.render(page);
        expect(page.toc, hasLength(1));
        expect(page.toc[0].id, equals('getting-started'));
        expect(page.toc[0].text, equals('Getting Started'));
        expect(page.toc[0].level, equals(2));
      });

      test('extracts multiple headings in document order', () {
        final page = makePageWithContent('## First\n\n### Sub\n\n## Second\n\nText.');
        renderer.render(page);
        expect(page.toc, hasLength(3));
        expect(page.toc[0].level, equals(2));
        expect(page.toc[1].level, equals(3));
        expect(page.toc[2].level, equals(2));
      });

      test('h1 is NOT included in toc', () {
        final page = makePageWithContent('# Title\n\nText.');
        renderer.render(page);
        expect(page.toc, isEmpty);
      });

      test('heading with inline code: text is stripped', () {
        final page = makePageWithContent('## The `render()` Method\n\nText.');
        renderer.render(page);
        expect(page.toc, hasLength(1));
        // TocEntry.text has HTML stripped
        expect(page.toc[0].text, equals('The render() Method'));
        expect(page.toc[0].text, isNot(contains('<code>')));
      });

      test('only headings content: toc populated, summary empty', () {
        final page = makePageWithContent('## Alpha\n\n## Beta\n\n## Gamma');
        renderer.render(page);
        expect(page.toc, hasLength(3));
        expect(page.summary, isEmpty);
      });
    });

    group('summary extraction', () {
      test('summary is first paragraph when no front matter summary', () {
        final page = makePageWithContent('First paragraph.\n\nSecond paragraph.');
        renderer.render(page);
        expect(page.summary, equals('First paragraph.'));
      });

      test('summary uses front matter summary field when present', () {
        final page = makePageWithContent('First paragraph.', frontMatter: {'summary': 'Explicit summary.'});
        renderer.render(page);
        expect(page.summary, equals('Explicit summary.'));
      });

      test('front matter summary takes precedence over first paragraph', () {
        final page = makePageWithContent(
          'Long first paragraph that should not be used.',
          frontMatter: {'summary': 'Short explicit summary.'},
        );
        renderer.render(page);
        expect(page.summary, equals('Short explicit summary.'));
      });

      test('non-String front matter summary treated as absent', () {
        final page = makePageWithContent('First paragraph.', frontMatter: {'summary': 42});
        renderer.render(page);
        expect(page.summary, equals('First paragraph.'));
      });

      test('empty string front matter summary treated as absent', () {
        final page = makePageWithContent('First paragraph.', frontMatter: {'summary': ''});
        renderer.render(page);
        expect(page.summary, equals('First paragraph.'));
      });

      test('no paragraph: summary is empty string', () {
        final page = makePageWithContent('## Heading Only');
        renderer.render(page);
        expect(page.summary, isEmpty);
      });
    });
  });
}
