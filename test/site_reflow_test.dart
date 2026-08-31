/// The docs site's own pages, held to the reflow contract the themes are held to.
///
/// `theme_contract_test.dart` sweeps `themes/*/example`; until this file, nothing
/// swept `site/`, and no other rendered check looked at it either. That is how a
/// WCAG 1.4.10 reflow failure reached 0.11's flagship page: `site/static/gallery.css`
/// declared `minmax(340px, 1fr)`, a hard grid-track floor that overflowed a 320px
/// viewport (`scrollWidth 356 / clientWidth 320`), in a stylesheet no theme build
/// ever loads — so the whole gate stayed green (TD-039).
///
/// Widths, colour schemes and the pass criterion come from `reflow_sweep.dart`,
/// shared with the theme sweep, so the site cannot be held to a weaker bar than
/// the themes by anyone editing one file and not the other.
///
/// **Both deploy shapes are built and swept.** Production is the path-prefixed
/// build (`pathPrefix` in `site/trellis_site.yaml`, currently `/trellis/`);
/// `deploy-docs-site.yml` also builds and link-checks a root-served variant as a
/// portability guard, and `tool/serve_docs.sh` previews that one. The two differ
/// in every emitted URL, and a URL is a layout input here: a stylesheet link that
/// does not survive the prefix renders an unstyled page whose boxes are nothing
/// like the styled ones. Neither mode can show that about the other.
///
/// A measurement of an *unstyled* page passes trivially, so this sweep is only
/// worth anything if the built assets resolve. That is gated next door rather
/// than here: `site_migration_contract_test.dart` runs `tool/link_check.dart`
/// over the same two builds and fails on any unresolved link or asset.
///
/// Untagged on purpose: `ci.yml` runs the root suite as `dart test
/// --exclude-tags=visual`, so a `visual` tag would silently drop this from the
/// gate (TD-035).
@Timeout(Duration(minutes: 15))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'browser_reflow_probe.dart';
import 'reflow_sweep.dart';

void main() {
  final root = Directory.current.path;
  final siteDir = p.join(root, 'site');
  final configuredPrefix =
      (loadYaml(File(p.join(siteDir, 'trellis_site.yaml')).readAsStringSync()) as YamlMap)['pathPrefix'] as String? ??
      '';

  // The two shapes the site is deployed in, with the production prefix read from
  // the site's own config so a changed `pathPrefix` is swept as deployed rather
  // than as written here.
  final modes = <(String, String)>[('root-served', ''), ('path-prefixed', configuredPrefix)];

  final workspace = Directory.systemTemp.createTempSync('site_reflow_');
  final servedRoots = <String, String>{};
  BrowserProbe? probe;

  setUpAll(() async {
    for (final (label, prefix) in modes) {
      // A path-prefixed build emits `/trellis/…` URLs while writing files at
      // unprefixed disk paths, so it only resolves when served *under* that
      // prefix. Building into <served>/trellis makes the origin root match the
      // deploy; serving the output directly would 404 every stylesheet and
      // measure an unstyled page.
      final served = Directory(p.join(workspace.path, label))..createSync(recursive: true);
      final output = p.joinAll([served.path, ..._segments(prefix)]);
      final build = await Process.run('dart', [
        'run',
        p.join(root, 'packages', 'trellis_cli', 'bin', 'trellis.dart'),
        'build',
        '--path-prefix',
        prefix,
        '--output',
        output,
      ], workingDirectory: siteDir);
      expect(build.exitCode, 0, reason: '$label: ${build.stdout}${build.stderr}');
      expect('${build.stdout}${build.stderr}', isNot(contains('warning')), reason: label);
      servedRoots[label] = served.path;
    }
    if (BrowserProbe.locateChrome() != null) probe = await BrowserProbe.launch();
  });

  tearDownAll(() async {
    await probe?.close();
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  for (final (label, prefix) in modes) {
    group(label, () {
      test('the sweep covers every page the site publishes', () {
        // A sweep whose page set quietly shrank still reports green, which is the
        // failure mode this whole file exists to close. The floor is the site's
        // own Markdown count rather than a number written here, and the named
        // page is the one 0.11 shipped overflowing.
        final pages = builtPages(servedRoots[label]!);
        final authored = Directory(
          p.join(siteDir, 'content'),
        ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.md')).length;
        expect(pages.length, greaterThanOrEqualTo(authored), reason: '$label: $authored Markdown files under content/');
        expect(pages, contains(p.joinAll([..._segments(prefix), 'docs', 'themes', 'gallery', 'index.html'])));
      });

      test('no page overflows a narrow viewport', () async {
        final browser = probe;
        if (browser == null) {
          requireChromeInCi('docs site ($label) narrow-viewport reflow');
          markTestSkipped('no Chrome/Chromium found – narrow-viewport reflow not measured');
          return;
        }
        final servedRoot = servedRoots[label]!;
        await expectNoOverflow(
          browser,
          servedRoot: servedRoot,
          pages: builtPages(servedRoot),
          viewports: narrowViewports,
          label: 'site $label',
        );
      });

      test("no page overflows just above the site's own breakpoints", () async {
        final browser = probe;
        if (browser == null) {
          requireChromeInCi('docs site ($label) breakpoint-band reflow');
          markTestSkipped('no Chrome/Chromium found – breakpoint-band reflow not measured');
          return;
        }
        final servedRoot = servedRoots[label]!;
        // Every sheet the built site serves, not just the theme's compiled one:
        // `site/static/gallery.css` carries breakpoints (981px, 700px) that exist
        // in no theme, and it is the file the 0.11 defect shipped in.
        final probeWidths = breakpointProbeWidths(
          Directory(servedRoot).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.css')),
        );
        // Without this, a sheet the width parser cannot read shrinks the sweep to
        // the fixed narrow widths and still reports green.
        expect(probeWidths, isNotEmpty, reason: '$label: no @media width breakpoints parsed out of the served sheets');
        await expectNoOverflow(
          browser,
          servedRoot: servedRoot,
          pages: _bandPages(servedRoot),
          viewports: {...narrowViewports, for (final width in probeWidths) width: 900},
          label: 'site $label breakpoint bands',
        );
      });
    });
  }
}

/// The non-empty path segments of a `pathPrefix`, e.g. `/trellis/` → `['trellis']`.
Iterable<String> _segments(String prefix) => prefix.split('/').where((segment) => segment.isNotEmpty);

/// Every generated page is swept at the breakpoint bands. Re-layout on an
/// already-loaded page is cheap, and a page selected by shape or stylesheet set
/// cannot represent page-specific content that widens its own layout.
List<String> _bandPages(String servedRoot) => builtPages(servedRoot);
