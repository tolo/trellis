// Tests for the internal link-integrity checker (tool/link_check.dart).
//
// Two layers:
//  - Unit: call `checkLinks()` directly against temp-dir fixtures to assert the
//    exact broken/OK classification and resolution semantics.
//  - CLI: run the tool as a subprocess to prove exit codes and the
//    `page -> target (reason)` reporting a CI gate depends on.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/link_check.dart';

/// Creates a temp output tree from a map of `relative/path.html` -> contents.
/// Directories are created as needed. Returns the temp dir; caller deletes it.
Directory _fixture(Map<String, String> files) {
  final dir = Directory.systemTemp.createTempSync('link_check_test_');
  files.forEach((rel, contents) {
    final file = File(p.join(dir.path, p.joinAll(p.posix.split(rel))));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  });
  return dir;
}

String _page(String body) => '<!doctype html><html><head></head><body>$body</body></html>';

void main() {
  group('checkLinks (root-served)', () {
    test('a fully-resolving tree exits with zero findings', () {
      final dir = _fixture({
        'index.html': _page('<a href="/docs/">Docs</a><img src="/img/logo.png">'),
        'docs/index.html': _page('<a href="/">Home</a>'),
        'img/logo.png': 'PNG',
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = checkLinks(dir.path);

      expect(result.broken, isEmpty);
      expect(result.pagesChecked, 2);
      expect(result.refsChecked, 3);
    });

    test('a dangling internal link is reported with its source page and target', () {
      final dir = _fixture({'index.html': _page('<a href="/missing/">Gone</a>')});
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = checkLinks(dir.path);

      expect(result.broken, hasLength(1));
      final broken = result.broken.single;
      // Source page names the file the ref was found on.
      expect(broken.toString(), contains('index.html'));
      // Target names the offending ref.
      expect(broken.toString(), contains('/missing/'));
    });

    test('external URLs and pure in-page anchors are never findings', () {
      final dir = _fixture({
        'index.html': _page(
          '<a href="https://example.com/x">ext</a>'
          '<a href="http://example.com">ext</a>'
          '<a href="//cdn.example.com/x.js">proto-rel</a>'
          '<a href="mailto:a@b.c">mail</a>'
          '<a href="tel:+123">tel</a>'
          '<img src="data:image/png;base64,AAAA">'
          '<a href="#section">anchor</a>',
        ),
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = checkLinks(dir.path);

      // None of the above are internal, so none are checked or reported.
      expect(result.broken, isEmpty);
      expect(result.refsChecked, 0);
    });

    test('query and fragment are stripped before resolution', () {
      final dir = _fixture({'index.html': _page('<a href="/docs/?x=1#frag">Docs</a>'), 'docs/index.html': _page('ok')});
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(checkLinks(dir.path).broken, isEmpty);
    });

    test('relative links resolve against the current page directory', () {
      final dir = _fixture({
        'docs/index.html': _page('<a href="../">Up</a><a href="./guide/">Guide</a>'),
        'index.html': _page('root'),
        'docs/guide/index.html': _page('guide'),
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(checkLinks(dir.path).broken, isEmpty);
    });

    test('a file ref with an extension resolves to that exact file, not index.html', () {
      final dir = _fixture({'index.html': _page('<a href="/sitemap.xml">map</a>'), 'sitemap.xml': '<xml/>'});
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(checkLinks(dir.path).broken, isEmpty);
    });

    test('first URL of each srcset candidate is checked', () {
      final dir = _fixture({
        'index.html': _page('<img srcset="/img/a.png 1x, /img/b.png 2x">'),
        'img/a.png': 'A',
        // b.png intentionally missing.
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = checkLinks(dir.path);
      expect(result.broken, hasLength(1));
      expect(result.broken.single.toString(), contains('/img/b.png'));
    });

    test('a root-absolute ref with ../ segments escaping the output root is reported broken '
        'even when the target file exists outside the tree', () {
      final dir = _fixture({'index.html': _page('<a href="/../secret.html">Escape</a>')});
      addTearDown(() => dir.deleteSync(recursive: true));

      // The referenced file genuinely exists — just outside the output root —
      // proving the checker rejects the escape rather than finding it by luck.
      final secretFile = File(p.join(dir.parent.path, 'secret.html'));
      secretFile.writeAsStringSync('should never be reachable via the output tree');
      addTearDown(() => secretFile.deleteSync());

      final result = checkLinks(dir.path);

      expect(result.broken, hasLength(1));
      expect(result.broken.single.toString(), contains('/../secret.html'));
    });

    test('a missing asset named only by data-dark is reported', () {
      // The docs landing page swaps theme screenshots client-side: the light
      // variant is the img's src, the dark variant reaches the browser only as
      // data-dark. Without data attributes in scope the dark file could go
      // missing and ship a live 404 with the checker still green.
      final dir = _fixture({
        'index.html': _page(
          '<img src="/themes/arbor/light.png" data-light="/themes/arbor/light.png" '
          'data-dark="/themes/arbor/dark.png" alt="Arbor">',
        ),
        'themes/arbor/light.png': 'PNG',
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = checkLinks(dir.path);

      expect(result.broken, hasLength(1));
      expect(result.broken.single.toString(), contains('/themes/arbor/dark.png'));
    });

    test('resolving data-light/data-dark assets are counted, not reported', () {
      final dir = _fixture({
        'index.html': _page(
          '<img src="/themes/arbor/light.png" data-light="/themes/arbor/light.png" '
          'data-dark="/themes/arbor/dark.png" alt="Arbor">',
        ),
        'themes/arbor/light.png': 'PNG',
        'themes/arbor/dark.png': 'PNG',
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = checkLinks(dir.path);

      expect(result.broken, isEmpty);
      // src + data-light + data-dark.
      expect(result.refsChecked, 3);
    });

    test('non-asset data attributes stay out of scope', () {
      // Most data-* attributes carry state, not URLs; treating them as
      // references would turn every widget flag into a spurious broken link.
      final dir = _fixture({'index.html': _page('<div data-docs-sidebar="/not/a/link" data-skin="auto"></div>')});
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = checkLinks(dir.path);

      expect(result.broken, isEmpty);
      expect(result.refsChecked, 0);
    });
  });

  group('checkLinks (--base-path /trellis/)', () {
    test('a prefixed ref resolving under the sub-path is OK', () {
      final dir = _fixture({'index.html': _page('<a href="/trellis/docs/">Docs</a>'), 'docs/index.html': _page('ok')});
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = checkLinks(dir.path, basePath: '/trellis/');
      expect(result.broken, isEmpty);
    });

    test('a root-absolute ref missing the prefix is BROKEN (escaped the sub-path)', () {
      final dir = _fixture({
        // /docs/ exists on disk, but the ref did not pick up the /trellis/ prefix.
        'index.html': _page('<a href="/docs/">Docs</a>'),
        'docs/index.html': _page('ok'),
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = checkLinks(dir.path, basePath: '/trellis/');
      expect(result.broken, hasLength(1));
      expect(result.broken.single.toString(), contains('/docs/'));
      expect(result.broken.single.reason, contains('base-path'));
    });

    test('a prefixed ref to a missing file is still reported broken', () {
      final dir = _fixture({'index.html': _page('<a href="/trellis/missing/">Gone</a>')});
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(checkLinks(dir.path, basePath: '/trellis/').broken, hasLength(1));
    });

    test('the base root itself (/trellis/) resolves to index.html', () {
      final dir = _fixture({'index.html': _page('<a href="/trellis/">Home</a>')});
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(checkLinks(dir.path, basePath: '/trellis/').broken, isEmpty);
    });
  });

  group('CLI end-to-end', () {
    late String toolPath;
    setUpAll(() {
      toolPath = p.join(Directory.current.path, 'tool', 'link_check.dart');
    });

    test('exits 0 and prints a summary on a clean tree', () async {
      final dir = _fixture({'index.html': _page('<a href="/docs/">Docs</a>'), 'docs/index.html': _page('ok')});
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = await Process.run('dart', ['run', toolPath, dir.path]);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('OK'));
      expect(result.stdout, contains('0 broken'));
    });

    test('exits 1 and names source + target on a broken tree', () async {
      final dir = _fixture({'index.html': _page('<a href="/missing/">Gone</a>')});
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = await Process.run('dart', ['run', toolPath, dir.path]);
      expect(result.exitCode, 1);
      final out = '${result.stdout}${result.stderr}';
      expect(out, contains('index.html'));
      expect(out, contains('/missing/'));
    });

    test('exits 1 under --base-path when a ref escapes the sub-path', () async {
      final dir = _fixture({'index.html': _page('<a href="/docs/">Docs</a>'), 'docs/index.html': _page('ok')});
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = await Process.run('dart', ['run', toolPath, dir.path, '--base-path', '/trellis/']);
      expect(result.exitCode, 1);
    });

    test('exits 0 under --base-path when refs carry the prefix', () async {
      final dir = _fixture({'index.html': _page('<a href="/trellis/docs/">Docs</a>'), 'docs/index.html': _page('ok')});
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = await Process.run('dart', ['run', toolPath, dir.path, '--base-path', '/trellis/']);
      expect(result.exitCode, 0);
    });

    test('exits 2 on a missing output directory', () async {
      final result = await Process.run('dart', ['run', toolPath, '/no/such/dir/xyz']);
      expect(result.exitCode, 2);
    });

    test('--help exits 0', () async {
      final result = await Process.run('dart', ['run', toolPath, '--help']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('Usage:'));
    });
  });
}
