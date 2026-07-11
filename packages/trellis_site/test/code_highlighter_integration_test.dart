import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

/// Minimal [Page] carrying [rawContent].
Page _page(String rawContent) => Page(
  sourcePath: 'test.md',
  url: '/test/',
  section: '',
  kind: PageKind.single,
  isDraft: false,
  isBundle: false,
  bundleAssets: const [],
  rawContent: rawContent,
);

void main() {
  group('MarkdownRenderer wiring (TI03)', () {
    test('with a highlighter, a dart fence yields hljs-* spans in page.content, class retained', () {
      const renderer = MarkdownRenderer(highlighter: CodeHighlighter());
      final page = _page('Intro.\n\n```dart\nvoid main() {}\n```\n');
      renderer.render(page);

      expect(page.content, contains('class="hljs-'));
      // The <code class="language-dart"> survives alongside the injected spans.
      expect(page.content, contains('<code class="language-dart">'));
      expect(page.content, contains('<span class="hljs-'));
    });

    test('without a highlighter (highlight.enabled: false), a dart fence stays plain (S08)', () {
      const renderer = MarkdownRenderer(); // highlighter == null
      final page = _page('```dart\nvoid main() {}\n```\n');
      renderer.render(page);

      expect(page.content, contains('<code class="language-dart">'));
      expect(page.content, isNot(contains('hljs-')));
    });
  });

  group('ShortcodeProcessor wiring (TI03)', () {
    test('a fenced block inside a content shortcode body is highlighted', () {
      final tmpDir = Directory.systemTemp.createTempSync('trellis_hl_sc_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      Directory(p.join(tmpDir.path, 'layouts', 'shortcodes')).createSync(recursive: true);
      File(
        p.join(tmpDir.path, 'layouts', 'shortcodes', 'callout.html'),
      ).writeAsStringSync('<div class="callout" tl:utext="\${content}">x</div>');

      final processor = ShortcodeProcessor(siteDir: tmpDir.path, highlighter: const CodeHighlighter());
      final page = _page('{{% callout %}}\n```dart\nfinal x = 1;\n```\n{{% /callout %}}');
      processor.processPreMarkdown(page);

      expect(page.rawContent, contains('class="hljs-'));
      expect(page.rawContent, contains('class="language-dart"'));
    });

    test('without a highlighter the shortcode body stays plain', () {
      final tmpDir = Directory.systemTemp.createTempSync('trellis_hl_sc_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      Directory(p.join(tmpDir.path, 'layouts', 'shortcodes')).createSync(recursive: true);
      File(
        p.join(tmpDir.path, 'layouts', 'shortcodes', 'callout.html'),
      ).writeAsStringSync('<div class="callout" tl:utext="\${content}">x</div>');

      final processor = ShortcodeProcessor(siteDir: tmpDir.path); // no highlighter
      final page = _page('{{% callout %}}\n```dart\nfinal x = 1;\n```\n{{% /callout %}}');
      processor.processPreMarkdown(page);

      expect(page.rawContent, contains('class="language-dart"'));
      expect(page.rawContent, isNot(contains('hljs-')));
    });
  });

  group('Highlighting does not collide with the path-prefix pass (TI03)', () {
    test('href="/x" inside highlighted <code> is NOT rewritten; a real prose link IS', () {
      const renderer = MarkdownRenderer(highlighter: CodeHighlighter());
      // A prose link (rewritten) and a code example showing href="/x" (never rewritten).
      final page = _page('See [docs](/guide).\n\n```html\n<a href="/x">x</a>\n```\n');
      renderer.render(page);
      // Sanity: the code was highlighted and shows the literal /x.
      expect(page.content, contains('class="hljs-'));
      expect(page.content, contains('"/x"'));

      // Step-6 pass: applyPathPrefixToLinks skips <pre>/<code>.
      final prefixed = applyPathPrefixToLinks(page.content, '/docs/');
      // The prose link is prefixed…
      expect(prefixed, contains('href="/docs/guide"'));
      // …but the code example's /x is left exactly as authored (never /docs/x).
      expect(prefixed, isNot(contains('/docs/x')));
      expect(prefixed, contains('"/x"'));
    });
  });
}
