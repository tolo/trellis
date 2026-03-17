import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

late String _shortcodeSiteDir;

/// Creates a temporary site directory with the given shortcode templates and
/// returns the [ShortcodeProcessor] bound to it.
({ShortcodeProcessor processor, String siteDir}) _buildSite(Map<String, String> shortcodeTemplates) {
  final tmpDir = Directory.systemTemp.createTempSync('trellis_sc_').path;
  addTearDown(() => Directory(tmpDir).deleteSync(recursive: true));

  final shortcodesDir = Directory(p.join(tmpDir, 'layouts', 'shortcodes'))..createSync(recursive: true);
  for (final entry in shortcodeTemplates.entries) {
    File(p.join(shortcodesDir.path, '${entry.key}.html')).writeAsStringSync(entry.value);
  }

  final processor = ShortcodeProcessor(siteDir: tmpDir);
  return (processor: processor, siteDir: tmpDir);
}

/// Creates a [Page] with the given [rawContent] for unit tests.
Page _makePage(String rawContent) => Page(
      sourcePath: 'test/page.md',
      url: '/test/',
      section: 'test',
      kind: PageKind.single,
      isDraft: false,
      isBundle: false,
      bundleAssets: const [],
      rawContent: rawContent,
    );

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _shortcodeSiteDir = p.join(packageRoot, 'test', 'test_fixtures', 'shortcode_site');
  });

  // -------------------------------------------------------------------------
  // Self-closing shortcodes
  // -------------------------------------------------------------------------

  group('ShortcodeProcessor — self-closing shortcodes', () {
    test('basic self-closing shortcode replaced with rendered HTML', () {
      final (:processor, :siteDir) = _buildSite({
        'youtube': '<iframe tl:attr="src=\'https://youtube.com/embed/\' + \${id}"></iframe>',
      });
      final page = _makePage('{{% youtube id="abc123" %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('youtube.com/embed/abc123'));
      expect(page.rawContent, isNot(contains('{{% youtube')));
    });

    test('multiple named params passed correctly', () {
      final (:processor, :siteDir) = _buildSite({
        'embed': '<a tl:attr="href=\${url}" tl:text="\${title}">link</a>',
      });
      final page = _makePage('{{% embed url="https://example.com" title="Hello World" %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('https://example.com'));
      expect(page.rawContent, contains('Hello World'));
    });

    test('single-quoted params parsed correctly', () {
      final (:processor, :siteDir) = _buildSite({
        'note': '<aside tl:text="\${type}">note</aside>',
      });
      final page = _makePage("{{% note type='info' %}}");
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('info'));
    });

    test('no-params shortcode renders with empty context', () {
      final (:processor, :siteDir) = _buildSite({'divider': '<hr />'});
      final page = _makePage('{{% divider %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('<hr'));
      expect(page.rawContent, isNot(contains('{{% divider')));
    });

    test('multiple shortcodes in same content each resolved', () {
      final (:processor, :siteDir) = _buildSite({'badge': '<span tl:text="\${label}">x</span>'});
      final page = _makePage('{{% badge label="A" %}} and {{% badge label="B" %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('>A<'));
      expect(page.rawContent, contains('>B<'));
    });

    test('shortcode surrounded by text — text preserved', () {
      final (:processor, :siteDir) = _buildSite({'hr': '<hr />'});
      final page = _makePage('Before\n{{% hr %}}\nAfter');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('Before'));
      expect(page.rawContent, contains('After'));
      expect(page.rawContent, contains('<hr'));
    });

    test('shortcode name with underscore', () {
      final (:processor, :siteDir) = _buildSite({'code_block': '<pre tl:text="\${lang}">x</pre>'});
      final page = _makePage('{{% code_block lang="dart" %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('dart'));
    });

    test('param value with spaces', () {
      final (:processor, :siteDir) = _buildSite({'note': '<p tl:text="\${title}">x</p>'});
      final page = _makePage('{{% note title="Hello World" %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('Hello World'));
    });

    test("param value with single quote inside double quotes (it's here)", () {
      final (:processor, :siteDir) = _buildSite({'note': '<p tl:text="\${title}">x</p>'});
      final page = _makePage('{{% note title="it\'s here" %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains("it's here"));
    });

    test('multiple identical shortcodes rendered independently', () {
      final (:processor, :siteDir) = _buildSite({'sep': '<hr class="sep">'});
      final page = _makePage('{{% sep %}}\n{{% sep %}}');
      processor.processPreMarkdown(page);
      // Each shortcode should have been replaced — check neither raw tag remains
      expect(page.rawContent, isNot(contains('{{% sep')));
      // Both rendered — count occurrences of the output
      expect('class="sep"'.allMatches(page.rawContent).length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // Content shortcodes
  // -------------------------------------------------------------------------

  group('ShortcodeProcessor — content shortcodes', () {
    test('inner content rendered as Markdown and available as \${content}', () {
      final (:processor, :siteDir) = _buildSite({
        'callout': '<div tl:utext="\${content}">x</div>',
      });
      final page = _makePage('{{% callout %}}\n**bold text**\n{{% /callout %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('<strong>bold text</strong>'));
    });

    test('named params passed alongside inner content', () {
      final (:processor, :siteDir) = _buildSite({
        'callout': '<div tl:attr="class=\${type}" tl:utext="\${content}">x</div>',
      });
      final page = _makePage('{{% callout type="warning" %}}\nHello\n{{% /callout %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('class="warning"'));
      expect(page.rawContent, contains('Hello'));
    });

    test('inner content with multiple paragraphs (blank lines)', () {
      final (:processor, :siteDir) = _buildSite({'box': '<div tl:utext="\${content}">x</div>'});
      final page = _makePage('{{% box %}}\nPara one.\n\nPara two.\n{{% /box %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('Para one'));
      expect(page.rawContent, contains('Para two'));
    });

    test('empty inner content yields empty \${content}', () {
      final (:processor, :siteDir) = _buildSite({'box': '<div tl:utext="\${content}">x</div>'});
      final page = _makePage('{{% box %}}  {{% /box %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('<div'));
    });

    test('content shortcode and self-closing in same document both processed', () {
      final (:processor, :siteDir) = _buildSite({
        'callout': '<div tl:utext="\${content}">x</div>',
        'hr': '<hr />',
      });
      final page = _makePage('{{% callout %}}\nHello\n{{% /callout %}}\n{{% hr %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('Hello'));
      expect(page.rawContent, contains('<hr'));
    });

    test('inner content leading/trailing whitespace trimmed', () {
      final (:processor, :siteDir) = _buildSite({'box': '<div tl:utext="\${content}">x</div>'});
      // Extra blank lines should be trimmed before Markdown rendering
      final page = _makePage('{{% box %}}\n\n  Hello  \n\n{{% /box %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('Hello'));
    });
  });

  // -------------------------------------------------------------------------
  // HTML comment shortcodes (post-Markdown)
  // -------------------------------------------------------------------------

  group('ShortcodeProcessor — HTML comment shortcodes', () {
    test('basic comment shortcode replaced after Markdown rendering', () {
      final (:processor, :siteDir) = _buildSite({
        'badge': '<span tl:text="\${label}">x</span>',
      });
      final page = _makePage('');
      page.content = '<p>Some text.</p>\n<!-- tl:badge label="new" -->\n<p>More.</p>';
      processor.processPostMarkdown(page);
      expect(page.content, contains('>new<'));
      expect(page.content, isNot(contains('<!-- tl:badge')));
    });

    test('multiple params in comment shortcode', () {
      final (:processor, :siteDir) = _buildSite({
        'link': '<a tl:attr="href=\${url}" tl:text="\${label}">x</a>',
      });
      final page = _makePage('');
      page.content = '<!-- tl:link url="https://example.com" label="Click" -->';
      processor.processPostMarkdown(page);
      expect(page.content, contains('https://example.com'));
      expect(page.content, contains('Click'));
    });

    test('HTML comment shortcodes not processed before Markdown', () {
      // processPreMarkdown should leave HTML comments alone
      final (:processor, :siteDir) = _buildSite({'badge': '<span>badge</span>'});
      final page = _makePage('<!-- tl:badge -->\nSome text');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('<!-- tl:badge -->'));
    });
  });

  // -------------------------------------------------------------------------
  // Template resolution
  // -------------------------------------------------------------------------

  group('ShortcodeProcessor — template resolution', () {
    test('missing template emits BuildWarning, preserves raw shortcode text', () {
      final (:processor, :siteDir) = _buildSite({}); // no templates
      final page = _makePage('{{% missing %}}');
      processor.processPreMarkdown(page);
      // Raw text preserved
      expect(page.rawContent, contains('{{% missing %}}'));
      // Warning emitted
      expect(processor.warnings, hasLength(1));
      expect(processor.warnings[0].message, contains('missing'));
    });

    test('warning includes template path as context', () {
      final (:processor, :siteDir) = _buildSite({});
      final page = _makePage('{{% unknown %}}');
      processor.processPreMarkdown(page);
      expect(processor.warnings[0].context, contains('unknown'));
    });

    test('template with tl:if renders conditionally', () {
      final (:processor, :siteDir) = _buildSite({
        'cond': '<span tl:if="\${show}">visible</span><span tl:unless="\${show}">hidden</span>',
      });
      final page = _makePage('{{% cond show="true" %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('visible'));
    });

    test('template with tl:utext renders unescaped content', () {
      final (:processor, :siteDir) = _buildSite({
        'html': '<div tl:utext="\${body}">x</div>',
      });
      final page = _makePage('{{% html body="<em>hi</em>" %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, contains('<em>hi</em>'));
    });
  });

  // -------------------------------------------------------------------------
  // Error handling
  // -------------------------------------------------------------------------

  group('ShortcodeProcessor — error handling', () {
    test('missing template does not throw, raw text preserved', () {
      final (:processor, :siteDir) = _buildSite({});
      final page = _makePage('text {{% gone %}} more');
      expect(() => processor.processPreMarkdown(page), returnsNormally);
      expect(page.rawContent, contains('{{% gone %}}'));
    });

    test('malformed shortcode (no name) is not matched — left as-is', () {
      final (:processor, :siteDir) = _buildSite({});
      final page = _makePage('{{% %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, equals('{{% %}}'));
      expect(processor.warnings, isEmpty);
    });

    test('unmatched content shortcode opening matches as self-closing if no closing tag', () {
      // Opening without closing → content regex doesn't match, self-closing may match
      final (:processor, :siteDir) = _buildSite({'note': '<aside>note</aside>'});
      final page = _makePage('{{% note %}} no closing tag');
      processor.processPreMarkdown(page);
      // Self-closing pattern matches the opening tag
      expect(page.rawContent, contains('<aside>'));
    });

    test('no shortcodes directory → processPreMarkdown is a no-op', () {
      final tmpDir = Directory.systemTemp.createTempSync('trellis_nosc_').path;
      addTearDown(() => Directory(tmpDir).deleteSync(recursive: true));
      // No layouts/shortcodes/ directory
      final processor = ShortcodeProcessor(siteDir: tmpDir);
      final page = _makePage('{{% youtube id="x" %}}');
      processor.processPreMarkdown(page);
      expect(page.rawContent, equals('{{% youtube id="x" %}}'));
      expect(processor.warnings, isEmpty);
    });

    test('no shortcodes directory → processPostMarkdown is a no-op', () {
      final tmpDir = Directory.systemTemp.createTempSync('trellis_nosc2_').path;
      addTearDown(() => Directory(tmpDir).deleteSync(recursive: true));
      final processor = ShortcodeProcessor(siteDir: tmpDir);
      final page = _makePage('');
      page.content = '<!-- tl:badge label="x" -->';
      processor.processPostMarkdown(page);
      expect(page.content, equals('<!-- tl:badge label="x" -->'));
      expect(processor.warnings, isEmpty);
    });

    test('empty rawContent → processPreMarkdown does nothing', () {
      final (:processor, :siteDir) = _buildSite({});
      final page = _makePage('');
      processor.processPreMarkdown(page);
      expect(page.rawContent, isEmpty);
      expect(processor.warnings, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Pipeline integration
  // -------------------------------------------------------------------------

  group('ShortcodeProcessor — pipeline integration', () {
    test('full build with shortcode in content produces rendered HTML', () async {
      final outputDir = Directory.systemTemp.createTempSync('trellis_sc_build_').path;
      addTearDown(() => Directory(outputDir).deleteSync(recursive: true));

      final config = SiteConfig(
        siteDir: _shortcodeSiteDir,
        contentDir: p.join(_shortcodeSiteDir, 'content'),
        layoutsDir: p.join(_shortcodeSiteDir, 'layouts'),
        outputDir: outputDir,
      );

      final result = await TrellisSite(config).build();
      final html =
          File(p.join(outputDir, 'posts', 'with-shortcodes', 'index.html')).readAsStringSync();

      // The youtube shortcode should be resolved to an iframe
      expect(html, contains('youtube.com/embed/dQw4w9WgXcQ'));
      expect(html, isNot(contains('{{% youtube')));
      expect(result.pageCount, greaterThan(0));
    });

    test('full build with HTML comment shortcode produces rendered HTML', () async {
      final outputDir = Directory.systemTemp.createTempSync('trellis_sc_comment_').path;
      addTearDown(() => Directory(outputDir).deleteSync(recursive: true));

      final config = SiteConfig(
        siteDir: _shortcodeSiteDir,
        contentDir: p.join(_shortcodeSiteDir, 'content'),
        layoutsDir: p.join(_shortcodeSiteDir, 'layouts'),
        outputDir: outputDir,
      );

      await TrellisSite(config).build();
      final html = File(p.join(outputDir, 'posts', 'with-comment-shortcode', 'index.html'))
          .readAsStringSync();

      // The badge shortcode should be rendered
      expect(html, contains('>new<'));
      expect(html, isNot(contains('<!-- tl:badge')));
    });

    test('missing shortcode template in build adds warning to BuildResult', () async {
      final tmpDir = Directory.systemTemp.createTempSync('trellis_sc_warn_').path;
      addTearDown(() => Directory(tmpDir).deleteSync(recursive: true));

      // Create a minimal site with no shortcode templates but content that uses one
      Directory(p.join(tmpDir, 'content')).createSync(recursive: true);
      Directory(p.join(tmpDir, 'layouts', '_default')).createSync(recursive: true);
      Directory(p.join(tmpDir, 'layouts', 'shortcodes')).createSync(recursive: true);
      // Empty shortcodes dir — template is missing

      File(p.join(tmpDir, 'content', 'page.md')).writeAsStringSync(
        '---\ntitle: Page\n---\n\n{{% missing_template %}}\n',
      );
      File(p.join(tmpDir, 'layouts', '_default', 'single.html')).writeAsStringSync(
        '<!DOCTYPE html><html><body tl:utext="\${page.content}"></body></html>',
      );

      final config = SiteConfig(siteDir: tmpDir, outputDir: p.join(tmpDir, 'output'));
      final result = await TrellisSite(config).build();

      expect(result.hasWarnings, isTrue);
      expect(result.warnings.any((w) => w.message.contains('missing_template')), isTrue);
    });

    test('site with no shortcodes directory builds without error', () async {
      // build_site fixture has no layouts/shortcodes/ — should still build fine
      final outputDir = Directory.systemTemp.createTempSync('trellis_sc_nodir_').path;
      addTearDown(() => Directory(outputDir).deleteSync(recursive: true));

      final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
      final packageRoot = p.dirname(packageUri!.toFilePath());
      final buildSiteDir = p.join(packageRoot, 'test', 'test_fixtures', 'build_site');

      final config = SiteConfig(
        siteDir: buildSiteDir,
        contentDir: p.join(buildSiteDir, 'content'),
        layoutsDir: p.join(buildSiteDir, 'layouts'),
        outputDir: outputDir,
      );

      expect(TrellisSite(config).build(), completes);
    });
  });
}
