import 'dart:io';
import 'dart:isolate';

import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

/// Renders a fenced block through Markdown (so the input is *real* rendered code
/// — escaped entities, literal `"`), then highlights it. Mirrors the production
/// path (`MarkdownRenderer.render`).
String highlightFence(CodeHighlighter hl, String lang, String code) {
  final md_ = md.markdownToHtml('```$lang\n$code\n```\n', extensionSet: md.ExtensionSet.gitHubWeb);
  return hl.highlightHtml(md_);
}

void main() {
  const hl = CodeHighlighter();

  group('HighlightConfig.fromYaml', () {
    test('null map (no highlight: block) defaults enabled to true', () {
      expect(HighlightConfig.fromYaml(null).enabled, isTrue);
    });

    test('empty map (highlight: block with no keys) keeps enabled true', () {
      expect(HighlightConfig.fromYaml(const {}).enabled, isTrue);
    });

    test('enabled: false honored', () {
      expect(HighlightConfig.fromYaml(const {'enabled': false}).enabled, isFalse);
    });

    test('enabled: true honored', () {
      expect(HighlightConfig.fromYaml(const {'enabled': true}).enabled, isTrue);
    });
  });

  group('CodeHighlighter — recognized languages produce hljs-* spans', () {
    // Each snippet must tokenize to at least one .hljs-* span. Covers the
    // Trellis-required language set (ADR-010 research §2).
    const snippets = <String, String>{
      'dart': 'void main() => print("hi");',
      'html': '<a href="/x">link</a>',
      'css': 'a { color: red; }',
      'scss': r'$c: red; a { color: $c; }',
      'javascript': 'const x = 1;',
      'typescript': 'const x: number = 1;',
      'json': '{"a": 1}',
      'yaml': 'key: value',
      'bash': 'echo "hello"',
      'markdown': '# Heading',
      'python': 'def f():\n    return 1',
      'java': 'class A { int x = 1; }',
      'sql': 'SELECT * FROM t;',
    };

    for (final entry in snippets.entries) {
      test('${entry.key} → hljs-* spans, class preserved', () {
        final out = highlightFence(hl, entry.key, entry.value);
        expect(out, contains('class="hljs-'), reason: '${entry.key} produced no hljs spans');
        expect(out, contains('class="language-${entry.key}"'), reason: '${entry.key} lost its language class');
      });
    }

    test('aliases resolve to their grammar (js, ts, yml, sh, md, py)', () {
      // Snippets chosen to tokenize under each alias's grammar.
      const aliasSnippets = <String, String>{
        'js': 'const x = 1;',
        'ts': 'const x: number = 1;',
        'yml': 'key: value',
        'sh': 'echo "hi"',
        'md': '# Heading',
        'py': 'def f():\n    return 1',
      };
      aliasSnippets.forEach((alias, code) {
        final out = highlightFence(hl, alias, code);
        expect(out, contains('class="hljs-'), reason: 'alias "$alias" did not highlight');
      });
    });
  });

  group('CodeHighlighter — non-highlighted blocks left plain', () {
    test('unknown language (cobol-9000) → no hljs spans, class preserved, byte-identical', () {
      final rendered = md.markdownToHtml('```cobol-9000\nMOVE X TO Y.\n```\n', extensionSet: md.ExtensionSet.gitHubWeb);
      final out = hl.highlightHtml(rendered);
      expect(out, isNot(contains('hljs-')));
      expect(out, contains('class="language-cobol-9000"'));
      expect(out, equals(rendered));
    });

    test('fenceless block (no language) → untouched', () {
      final rendered = md.markdownToHtml('```\nplain text\n```\n', extensionSet: md.ExtensionSet.gitHubWeb);
      final out = hl.highlightHtml(rendered);
      expect(out, isNot(contains('hljs-')));
      expect(out, equals(rendered));
    });

    test('html with no language- class at all is returned unchanged', () {
      const html = '<p>Just a <strong>paragraph</strong>.</p>';
      expect(hl.highlightHtml(html), equals(html));
    });
  });

  group('CodeHighlighter — multiple blocks in one document', () {
    test('two recognized blocks are both highlighted; each keeps its own language', () {
      final rendered = md.markdownToHtml(
        '```dart\nvoid main() {}\n```\n\nBetween.\n\n```json\n{"a": 1}\n```\n',
        extensionSet: md.ExtensionSet.gitHubWeb,
      );
      final out = hl.highlightHtml(rendered);
      // Both blocks highlighted (descending-offset splice must not corrupt the
      // earlier block when the later one is replaced first).
      expect(out, contains('class="language-dart"'));
      expect(out, contains('class="language-json"'));
      // Prose between the two blocks is preserved verbatim.
      expect(out, contains('<p>Between.</p>'));
      // Each block carries hljs spans and its source survives.
      expect(RegExp('class="hljs-').allMatches(out).length, greaterThanOrEqualTo(2));
      expect(out, contains('main'));
    });

    test('a recognized block next to an unknown block: only the known one is highlighted', () {
      final rendered = md.markdownToHtml(
        '```dart\nvoid main() {}\n```\n\n```cobol-9000\nMOVE X.\n```\n',
        extensionSet: md.ExtensionSet.gitHubWeb,
      );
      final out = hl.highlightHtml(rendered);
      expect(out, contains('class="language-dart"'));
      expect(out, contains('class="language-cobol-9000"'));
      expect(out, contains('class="hljs-'));
      // The unknown block's source is untouched (no spans injected there).
      expect(out, contains('MOVE X.'));
    });
  });

  group('CodeHighlighter — never throws on a recognized-language block (M1 guard)', () {
    test('highlightHtml returns without throwing across the supported language set', () {
      const langs = [
        'dart',
        'html',
        'css',
        'scss',
        'javascript',
        'typescript',
        'json',
        'yaml',
        'bash',
        'markdown',
        'python',
        'java',
        'sql',
      ];
      for (final lang in langs) {
        // Edge-y inputs: empty, whitespace, unbalanced delimiters, control-ish text.
        for (final code in ['', '   ', '"unterminated', '<<<>>>', '\\', ')(}{]']) {
          final rendered = md.markdownToHtml('```$lang\n$code\n```\n', extensionSet: md.ExtensionSet.gitHubWeb);
          expect(() => hl.highlightHtml(rendered), returnsNormally, reason: '$lang / "$code" threw');
        }
      }
    });
  });

  group('CodeHighlighter — special characters round-trip (S05)', () {
    test('< > & render as entities, " renders literally, no double-escape, no broken spans', () {
      // Real markdown-rendered code (literal quotes), per LEARNINGS.
      final rendered = md.markdownToHtml(
        '```html\n<a href="/x">A & B</a>\n```\n',
        extensionSet: md.ExtensionSet.gitHubWeb,
      );
      final out = hl.highlightHtml(rendered);

      // < and > survive as entities; & stays &amp;.
      expect(out, contains('&lt;'));
      expect(out, contains('&amp;'));
      // The attribute quote is literal, never &quot;.
      expect(out, contains('"/x"'));
      expect(out, isNot(contains('&quot;')));
      // No double-escaping: an escaped ampersand entity must not itself re-escape.
      expect(out, isNot(contains('&amp;lt;')));
      expect(out, isNot(contains('&amp;amp;')));
      // Highlighted, and the block still round-trips its language class.
      expect(out, contains('class="hljs-'));
      expect(out, contains('class="language-html"'));
    });
  });

  group('CodeHighlighter — fragment fidelity (non-code markup byte-identical)', () {
    test('mixed <p>/<ul>/<a>/<br /> markup preserved; no html/head/body wrapper injected', () {
      const source = 'Line one  \nline two.\n\n- item [link](/l)\n\n```dart\nvoid main() {}\n```\n\nAfter.\n';
      final rendered = md.markdownToHtml(source, extensionSet: md.ExtensionSet.gitHubWeb);
      final out = hl.highlightHtml(rendered);

      // Code got highlighted…
      expect(out, contains('class="hljs-'));
      // …but every byte of non-code markup is untouched. Compare by replacing the
      // (single) code block's inner region in both strings and asserting equality.
      String stripCodeInner(String html) =>
          html.replaceAll(RegExp(r'(<code class="language-dart">).*?(</code>)', dotAll: true), r'$1$2');
      expect(stripCodeInner(out), equals(stripCodeInner(rendered)));

      // No document wrapper leaked in from a full-document re-serialize.
      expect(out, isNot(contains('<html')));
      expect(out, isNot(contains('<head')));
      expect(out, isNot(contains('<body')));
      // Spot-check the void element and link survive verbatim.
      expect(out, contains('<br />'));
      expect(out, contains('<a href="/l">link</a>'));
    });
  });

  group('pubspec declares the build-time highlighting dependencies (TI02)', () {
    test('highlight: ^0.7.0 and html: are declared', () async {
      final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
      final packageRoot = p.dirname(packageUri!.toFilePath());
      final pubspec = File(p.join(packageRoot, 'pubspec.yaml')).readAsStringSync();
      expect(pubspec, contains('highlight: ^0.7.0'));
      expect(pubspec, contains(RegExp(r'^\s+html:', multiLine: true)));
    });
  });
}
