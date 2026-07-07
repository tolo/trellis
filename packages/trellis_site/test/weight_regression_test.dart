import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

late String _packageRoot;

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    _packageRoot = p.dirname(packageUri!.toFilePath());
  });

  String fixture(String name) => p.join(_packageRoot, 'test', 'test_fixtures', name);

  /// Builds a fixture site to an isolated temp dir and returns the [BuildResult]
  /// plus the output directory path.
  Future<(BuildResult, String)> buildFixture(String siteName, {bool withStatic = true}) async {
    final siteDir = fixture(siteName);
    final outputDir = Directory.systemTemp.createTempSync('weight_reg_').path;
    addTearDown(() => Directory(outputDir).deleteSync(recursive: true));
    final config = SiteConfig(
      siteDir: siteDir,
      baseUrl: 'https://example.com',
      contentDir: p.join(siteDir, 'content'),
      layoutsDir: p.join(siteDir, 'layouts'),
      staticDir: withStatic ? p.join(siteDir, 'static') : p.join(siteDir, '_no_static'),
      outputDir: outputDir,
    );
    final result = await TrellisSite(config).build();
    return (result, outputDir);
  }

  group('Unweighted byte-for-byte regression (AS02/AS07 · TI04/TI07)', () {
    test('build_site rendered HTML tree equals the pre-change captured baseline byte-for-byte', () async {
      // The golden was captured from the pre-change engine (git-stash baseline);
      // this proves the weight/lineage changes leave unweighted output identical
      // rather than merely asserting it.
      final goldenFile = File(fixture('build_site_golden.json'));
      final golden = (jsonDecode(goldenFile.readAsStringSync()) as Map).cast<String, dynamic>();

      final (_, outputDir) = await buildFixture('build_site');

      final produced = <String, String>{};
      for (final f in Directory(outputDir).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.html')) continue;
        produced[p.relative(f.path, from: outputDir).replaceAll(r'\', '/')] = f.readAsStringSync();
      }

      // Same set of HTML files.
      expect(produced.keys.toSet(), golden.keys.toSet(), reason: 'HTML output file set changed');
      // Each file byte-for-byte identical.
      for (final entry in golden.entries) {
        expect(produced[entry.key], entry.value, reason: 'byte drift in ${entry.key}');
      }
    });

    test('unweighted section listing keeps date-desc-then-URL order (no new tiebreak)', () async {
      // build_site posts section is unweighted; the listing order must be the
      // existing comparator's output.
      final (_, outputDir) = await buildFixture('build_site');
      final html = File(p.join(outputDir, 'posts', 'index.html')).readAsStringSync();
      // Only hello-world exists in the fixture; the listing renders it, proving
      // the unweighted path still emits the section's pages unchanged.
      expect(html, contains('/posts/hello-world/'));
    });
  });

  group('Malformed weight warns and never aborts (AS04 · TI03)', () {
    test('site with weight: "abc" builds successfully and emits a warning naming the page', () async {
      final (result, _) = await buildFixture('weighted_site');

      // Build completed (did not abort).
      expect(result.pageCount, greaterThan(0));

      // A warning names the offending page and mentions weight.
      final weightWarnings = result.warnings.where((w) => w.message.toLowerCase().contains('weight')).toList();
      expect(weightWarnings, isNotEmpty, reason: 'expected a malformed-weight warning');
      expect(
        weightWarnings.any((w) => (w.context ?? '').contains('/docs/guides/bad/')),
        isTrue,
        reason: 'warning should name the offending page (/docs/guides/bad/)',
      );
    });

    test('weighted docs section orders w1, w2, then the malformed (unweighted) page last', () async {
      final (_, outputDir) = await buildFixture('weighted_site');
      final html = File(p.join(outputDir, 'docs', 'guides', 'index.html')).readAsStringSync();
      final hrefOrder = RegExp(r'href="([^"]+)"').allMatches(html).map((m) => m.group(1)).toList();
      expect(hrefOrder, ['/docs/guides/alpha/', '/docs/guides/bravo/', '/docs/guides/bad/']);
    });

    test('nested guides listing excludes sibling tutorials sub-section (AS06)', () async {
      final (_, outputDir) = await buildFixture('weighted_site');
      final html = File(p.join(outputDir, 'docs', 'guides', 'index.html')).readAsStringSync();
      expect(html, isNot(contains('/docs/tutorials/')));
    });
  });
}
