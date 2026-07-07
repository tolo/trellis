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

  /// Builds the `build_site` fixture to an isolated temp dir with feeds + search
  /// enabled, optionally under a [pathPrefix]. Returns the output directory.
  Future<String> buildBuildSite({String pathPrefix = ''}) async {
    final siteDir = fixture('build_site');
    final outputDir = Directory.systemTemp.createTempSync('path_prefix_').path;
    addTearDown(() => Directory(outputDir).deleteSync(recursive: true));
    final config = SiteConfig(
      siteDir: siteDir,
      title: 'Test Site',
      baseUrl: 'https://example.com',
      pathPrefix: pathPrefix,
      description: 'A test site',
      contentDir: p.join(siteDir, 'content'),
      layoutsDir: p.join(siteDir, 'layouts'),
      staticDir: p.join(siteDir, 'static'),
      outputDir: outputDir,
      params: const {'author': 'Test Author'},
      feeds: const FeedConfig(atom: true, rss: true),
      searchConfig: const SearchConfig(enabled: true),
    );
    await TrellisSite(config).build();
    return outputDir;
  }

  /// Snapshots every file under [dir] into a path→contents map (forward slashes).
  Map<String, String> snapshot(String dir) {
    final out = <String, String>{};
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
      out[p.relative(f.path, from: dir).replaceAll(r'\', '/')] = f.readAsStringSync();
    }
    return out;
  }

  // --- TI01 / S03 / S04: SiteConfig.normalizePathPrefix ------------------------

  group('SiteConfig.normalizePathPrefix (TI01 · S04)', () {
    test('all slash variants of a sub-path normalize to the same /trellis/ (S04)', () {
      for (final input in ['trellis', '/trellis', 'trellis/', '/trellis/']) {
        expect(SiteConfig.normalizePathPrefix(input), '/trellis/', reason: "input '$input'");
      }
    });

    test('nested sub-path normalizes with leading + single trailing slash', () {
      for (final input in ['a/b', '/a/b', 'a/b/', '/a/b/']) {
        expect(SiteConfig.normalizePathPrefix(input), '/a/b/', reason: "input '$input'");
      }
    });

    test("root-equivalent values '', '/', and null normalize to the no-prefix state (S04)", () {
      expect(SiteConfig.normalizePathPrefix(''), '');
      expect(SiteConfig.normalizePathPrefix('/'), '');
      expect(SiteConfig.normalizePathPrefix('   '), '');
      expect(SiteConfig.normalizePathPrefix(null), '');
    });

    test('a scheme-bearing value throws SiteConfigException naming pathPrefix + the value (S03)', () {
      expect(
        () => SiteConfig.normalizePathPrefix('http://example.com'),
        throwsA(
          isA<SiteConfigException>()
              .having((e) => e.message, 'message', contains('pathPrefix'))
              .having((e) => e.message, 'message', contains('http://example.com')),
        ),
      );
    });

    test('a protocol-relative value throws SiteConfigException naming pathPrefix (S03)', () {
      expect(
        () => SiteConfig.normalizePathPrefix('//cdn.example.com/x'),
        throwsA(isA<SiteConfigException>().having((e) => e.message, 'message', contains('pathPrefix'))),
      );
    });

    test('a non-string value throws SiteConfigException naming pathPrefix + the value (S03)', () {
      expect(
        () => SiteConfig.normalizePathPrefix(42),
        throwsA(
          isA<SiteConfigException>()
              .having((e) => e.message, 'message', contains('pathPrefix'))
              .having((e) => e.message, 'message', contains('42')),
        ),
      );
    });

    test('a nested multi-segment sub-path normalizes to /docs/v1/ (M5 accepted case)', () {
      expect(SiteConfig.normalizePathPrefix('docs/v1'), '/docs/v1/');
    });

    test('a value containing whitespace throws SiteConfigException naming pathPrefix (M5)', () {
      expect(
        () => SiteConfig.normalizePathPrefix('tre llis'),
        throwsA(isA<SiteConfigException>().having((e) => e.message, 'message', contains('pathPrefix'))),
      );
    });

    test('a value containing a raw colon throws SiteConfigException naming pathPrefix (M5)', () {
      expect(
        () => SiteConfig.normalizePathPrefix('trellis:8080'),
        throwsA(isA<SiteConfigException>().having((e) => e.message, 'message', contains('pathPrefix'))),
      );
    });

    test('a leading "." dot segment throws SiteConfigException naming pathPrefix (M5)', () {
      expect(
        () => SiteConfig.normalizePathPrefix('./trellis'),
        throwsA(isA<SiteConfigException>().having((e) => e.message, 'message', contains('pathPrefix'))),
      );
    });

    test('an interior ".." dot segment throws SiteConfigException naming pathPrefix (M5)', () {
      expect(
        () => SiteConfig.normalizePathPrefix('a/../b'),
        throwsA(isA<SiteConfigException>().having((e) => e.message, 'message', contains('pathPrefix'))),
      );
    });

    test('an interior empty segment ("//") throws SiteConfigException naming pathPrefix (M5)', () {
      expect(
        () => SiteConfig.normalizePathPrefix('a//b'),
        throwsA(isA<SiteConfigException>().having((e) => e.message, 'message', contains('pathPrefix'))),
      );
    });
  });

  group('SiteConfig.load() pathPrefix parsing (TI01)', () {
    test('pathPrefix YAML key loads and normalizes to canonical form', () {
      final tempDir = Directory.systemTemp.createTempSync('cfg_prefix_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync('pathPrefix: trellis\n');

      final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
      expect(config.pathPrefix, '/trellis/');
    });

    test('absent pathPrefix key defaults to the no-prefix state', () {
      final tempDir = Directory.systemTemp.createTempSync('cfg_prefix_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync('title: No Prefix\n');

      final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
      expect(config.pathPrefix, '');
    });

    test('malformed pathPrefix throws SiteConfigException carrying the config path (S03)', () {
      final tempDir = Directory.systemTemp.createTempSync('cfg_prefix_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final cfgPath = p.join(tempDir.path, 'trellis_site.yaml');
      File(cfgPath).writeAsStringSync('pathPrefix: http://evil.example.com\n');

      expect(
        () => SiteConfig.load(cfgPath),
        throwsA(
          isA<SiteConfigException>()
              .having((e) => e.message, 'message', contains('pathPrefix'))
              .having((e) => e.configPath, 'configPath', isNotNull),
        ),
      );
    });

    test('malformed pathPrefix aborts before any output is written (S03)', () {
      // A malformed prefix is rejected at config load — before TrellisSite is
      // ever constructed — so a half-applied site can never reach the output dir.
      final tempDir = Directory.systemTemp.createTempSync('cfg_prefix_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      Directory(p.join(tempDir.path, 'content')).createSync(recursive: true);
      final cfgPath = p.join(tempDir.path, 'trellis_site.yaml');
      File(cfgPath).writeAsStringSync('pathPrefix: http://evil.example.com\n');

      expect(() => SiteConfig.load(cfgPath), throwsA(isA<SiteConfigException>()));
      // No output directory was created — nothing was written.
      expect(Directory(p.join(tempDir.path, 'output')).existsSync(), isFalse);
    });
  });

  // --- TI02 / S01 / S05: deriveUrl + applyPathPrefix ---------------------------

  group('deriveUrl with pathPrefix (TI02 · S01)', () {
    test('a page defaulting to /docs/intro/ yields /trellis/docs/intro/', () {
      expect(deriveUrl('docs/intro.md', pathPrefix: '/trellis/'), '/trellis/docs/intro/');
    });

    test('section and bundle URLs are prefixed', () {
      expect(deriveUrl('posts/_index.md', pathPrefix: '/trellis/'), '/trellis/posts/');
      expect(deriveUrl('posts/my-trip/index.md', pathPrefix: '/trellis/'), '/trellis/posts/my-trip/');
    });

    test('root (_index.md) yields /trellis/', () {
      expect(deriveUrl('_index.md', pathPrefix: '/trellis/'), '/trellis/');
    });

    test('empty prefix is a literal no-op — output identical to the default call', () {
      for (final src in [
        'about.md',
        'posts/hello-world.md',
        'posts/_index.md',
        '_index.md',
        'posts/my-trip/index.md',
      ]) {
        expect(deriveUrl(src, pathPrefix: ''), deriveUrl(src), reason: "no-op drift for '$src'");
      }
    });
  });

  group('applyPathPrefix — external/absolute URLs untouched (TI02 · S05)', () {
    test('root-absolute internal path is prefixed', () {
      expect(applyPathPrefix('/docs/intro/', '/trellis/'), '/trellis/docs/intro/');
    });

    test('absolute external https URL passes through verbatim (S05)', () {
      expect(applyPathPrefix('https://pub.dev/packages/trellis', '/trellis/'), 'https://pub.dev/packages/trellis');
    });

    test('protocol-relative //host URL passes through verbatim (S05)', () {
      expect(applyPathPrefix('//cdn.example.com/lib.js', '/trellis/'), '//cdn.example.com/lib.js');
    });

    test('empty prefix returns the URL unchanged (no-op)', () {
      expect(applyPathPrefix('/docs/intro/', ''), '/docs/intro/');
      expect(applyPathPrefix('https://x.test/', ''), 'https://x.test/');
    });
  });

  group('Prefix flows into every engine-emitted URL (TI02 · S01)', () {
    test('page.url and search-index url both carry the prefix', () async {
      final outputDir = await buildBuildSite(pathPrefix: '/trellis/');

      // page.url flows into the home menu (tl:href="${p.url}") as a prefixed link,
      // while the file itself is written at the unprefixed on-disk path (the host
      // serves the artifact root under the prefix — see stripPathPrefix).
      final home = File(p.join(outputDir, 'index.html')).readAsStringSync();
      expect(home, contains('href="/trellis/posts/hello-world/"'));
      expect(home, contains('href="/trellis/about/"'));

      // search-index url fields carry the prefix.
      final searchJson = File(p.join(outputDir, 'search-index.json')).readAsStringSync();
      final entries = (jsonDecode(searchJson) as List).cast<Map<String, dynamic>>();
      final urls = entries.map((e) => e['url'] as String).toList();
      expect(urls, everyElement(startsWith('/trellis/')));
      expect(urls, contains('/trellis/about/'));
    });
  });

  // --- TI03: sitemap + feeds prefixed exactly once -----------------------------

  group('Sitemap and feeds are prefixed exactly once (TI03)', () {
    test('sitemap <loc> is https://example.com/trellis/... (prefix appears once)', () async {
      final outputDir = await buildBuildSite(pathPrefix: '/trellis/');
      final xml = File(p.join(outputDir, 'sitemap.xml')).readAsStringSync();

      expect(xml, contains('<loc>https://example.com/trellis/about/</loc>'));
      expect(xml, contains('<loc>https://example.com/trellis/posts/hello-world/</loc>'));
      // Prefix must not be doubled.
      expect(xml, isNot(contains('/trellis/trellis/')));
      expect(xml, isNot(contains('example.com/about/'))); // unprefixed leak
    });

    test('atom + rss entry links are https://example.com/trellis/... (prefix once)', () async {
      final outputDir = await buildBuildSite(pathPrefix: '/trellis/');
      final atom = File(p.join(outputDir, 'feed.xml')).readAsStringSync();
      final rss = File(p.join(outputDir, 'rss.xml')).readAsStringSync();

      expect(atom, contains('https://example.com/trellis/posts/hello-world/'));
      expect(rss, contains('https://example.com/trellis/posts/hello-world/'));
      expect(atom, isNot(contains('/trellis/trellis/')));
      expect(rss, isNot(contains('/trellis/trellis/')));
    });
  });

  // --- TI04: ${site.pathPrefix} theme-author mechanism -------------------------

  group('\${site.pathPrefix} literal-asset mechanism (TI04 · S06)', () {
    Future<String> buildLiteralAssetSite({required String pathPrefix}) async {
      final tempDir = Directory.systemTemp.createTempSync('prefix_asset_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final contentDir = p.join(tempDir.path, 'content');
      Directory(contentDir).createSync(recursive: true);
      File(p.join(contentDir, '_index.md')).writeAsStringSync('---\ntitle: Home\n---\nHome.\n');

      final layoutsDir = p.join(tempDir.path, 'layouts');
      Directory(layoutsDir).createSync(recursive: true);
      // A hand-written literal asset ref opted into the prefix via ${site.pathPrefix}.
      // tl:href evaluates a full expression, so a literal path is concatenated
      // onto the prefix (the documented theme-author mechanism).
      File(p.join(layoutsDir, 'home.html')).writeAsStringSync(
        '<!DOCTYPE html><html><head>'
        "<link rel=\"stylesheet\" tl:href=\"\${site.pathPrefix} + 'css/main.css'\">"
        '</head><body tl:text="\${page.title}">x</body></html>',
      );

      final outputDir = p.join(tempDir.path, 'output');
      final config = SiteConfig(
        siteDir: tempDir.path,
        pathPrefix: pathPrefix,
        contentDir: contentDir,
        layoutsDir: layoutsDir,
        outputDir: outputDir,
      );
      await TrellisSite(config).build();
      return outputDir;
    }

    test('a layout using \${site.pathPrefix} for a literal href emits /trellis/css/main.css (S06)', () async {
      final outputDir = await buildLiteralAssetSite(pathPrefix: '/trellis/');
      final html = File(p.join(outputDir, 'index.html')).readAsStringSync();
      expect(html, contains('href="/trellis/css/main.css"'));
    });

    test('with no prefix, \${site.pathPrefix} renders empty so the literal href stays root-absolute', () async {
      final outputDir = await buildLiteralAssetSite(pathPrefix: '');
      final html = File(p.join(outputDir, 'index.html')).readAsStringSync();
      expect(html, contains('href="css/main.css"'));
    });
  });

  // --- TI05: no-prefix build is byte-for-byte unchanged ------------------------

  group('No-prefix build is byte-for-byte unchanged (TI05 · S02)', () {
    test('default build matches the pre-change captured baseline byte-for-byte', () async {
      // The golden was captured from the pre-pathPrefix engine (the S01-inclusive
      // working tree) with feeds + search enabled, covering the full artifact set:
      // HTML tree, sitemap.xml, feed.xml, rss.xml, search-index.json, static.
      final golden = (jsonDecode(File(fixture('pathprefix_regression_golden.json')).readAsStringSync()) as Map)
          .cast<String, dynamic>();

      final outputDir = await buildBuildSite(); // no pathPrefix
      final produced = snapshot(outputDir);

      expect(produced.keys.toSet(), golden.keys.toSet(), reason: 'output file set changed');
      for (final entry in golden.entries) {
        expect(produced[entry.key], entry.value, reason: 'byte drift in ${entry.key}');
      }
    });
  });

  // --- Output file layout is prefix-independent (deploy correctness) -----------
  //
  // The path-prefix belongs in the *emitted URLs*, not the on-disk layout: the
  // host (e.g. GitHub Project Pages) mounts the artifact root under the prefix,
  // so files must stay at their unprefixed paths while links carry the prefix.
  // A prefixed build that nested pages under output/<prefix>/ (while sitemap,
  // feeds, search-index and static assets stayed at the root) would be
  // un-deployable. See stripPathPrefix.

  group('Output file layout is prefix-independent (deploy correctness)', () {
    test('prefixed build writes files at unprefixed paths while emitting prefixed URLs', () async {
      final plain = snapshot(await buildBuildSite());
      final prefixed = snapshot(await buildBuildSite(pathPrefix: '/trellis/'));

      // The set of output file locations is identical with and without a prefix:
      // no page is nested under a `trellis/` directory.
      expect(
        prefixed.keys.toSet(),
        plain.keys.toSet(),
        reason: 'prefixed build produced a different output-file layout',
      );
      expect(
        prefixed.keys.where((k) => k.startsWith('trellis/')),
        isEmpty,
        reason: 'no output file should be nested under the prefix directory',
      );

      // The canonical pages exist at their unprefixed on-disk locations.
      expect(prefixed.keys, containsAll(<String>['index.html', 'about/index.html']));

      // Yet the emitted links carry the prefix: the home/list pages reference
      // child pages via the prefixed ${p.url}.
      final anyPrefixedLink = prefixed.entries.any(
        (e) => e.key.endsWith('index.html') && e.value.contains('href="/trellis/'),
      );
      expect(anyPrefixedLink, isTrue, reason: 'emitted page links should carry the /trellis/ prefix');

      // Sitemap lives at the artifact root (not nested) and its <loc> carries the
      // prefix exactly once.
      expect(prefixed.containsKey('sitemap.xml'), isTrue);
      expect(prefixed['sitemap.xml'], contains('<loc>https://example.com/trellis/'));
      expect(prefixed['sitemap.xml'], isNot(contains('/trellis/trellis/')));

      // search-index url fields carry the prefix, and the file is at the root.
      expect(prefixed.containsKey('search-index.json'), isTrue);
      expect(prefixed['search-index.json'], contains('/trellis/'));
    });
  });

  // --- Content/asset link prefixing (expected SSG behavior) --------------------
  //
  // Hand-written root-absolute links (Markdown content, theme literals) and
  // static-asset references get the prefix applied to the emitted HTML, while
  // relative links and code examples are left untouched and engine URLs (already
  // prefixed) are not double-prefixed. See applyPathPrefixToLinks.

  group('applyPathPrefixToLinks', () {
    test('prefixes root-absolute internal href/src, leaves everything else alone', () {
      const html =
          '<a href="/docs/guide/">g</a>'
          '<a href="/">home</a>'
          '<link href="/css/main.css">'
          '<script src="/prism/core.js"></script>'
          '<a href="../rel/">rel</a>'
          '<a href="#frag">anchor</a>'
          '<a href="//cdn.example.com/x">proto</a>'
          '<a href="https://pub.dev/packages/trellis">ext</a>';
      final out = applyPathPrefixToLinks(html, '/trellis/');

      expect(out, contains('href="/trellis/docs/guide/"'));
      expect(out, contains('href="/trellis/"')); // '/' → '/trellis/'
      expect(out, contains('href="/trellis/css/main.css"'));
      expect(out, contains('src="/trellis/prism/core.js"'));
      // Untouched:
      expect(out, contains('href="../rel/"'));
      expect(out, contains('href="#frag"'));
      expect(out, contains('href="//cdn.example.com/x"'));
      expect(out, contains('href="https://pub.dev/packages/trellis"'));
    });

    test('does not double-prefix already-prefixed (engine-derived) URLs', () {
      const html = '<a href="/trellis/docs/">already</a><a href="/trellis/">home</a>';
      final out = applyPathPrefixToLinks(html, '/trellis/');
      expect(out, isNot(contains('/trellis/trellis/')));
      expect(out, contains('href="/trellis/docs/"'));
      expect(out, contains('href="/trellis/"'));
    });

    test('a sibling path that only shares a prefix segment is still prefixed', () {
      // /trellisish/ does NOT start with the prefix boundary '/trellis/'.
      final out = applyPathPrefixToLinks('<a href="/trellisish/">x</a>', '/trellis/');
      expect(out, contains('href="/trellis/trellisish/"'));
    });

    test('code examples with LITERAL quotes (real markdown output) are not rewritten', () {
      // package:markdown escapes <, >, & inside code but leaves the attribute
      // quote " LITERAL, so a URL SHOWN in an inline/fenced code example must not
      // be prefixed — otherwise the docs teach the reader the wrong (hardcoded) path.
      const inline = '<p>Use <code>&lt;link href="/css/main.css"&gt;</code> in your head.</p>';
      expect(applyPathPrefixToLinks(inline, '/trellis/'), equals(inline), reason: 'inline code untouched');

      const fenced = '<pre><code class="language-html">&lt;a href="/docs/"&gt;x&lt;/a&gt;\n</code></pre>';
      expect(applyPathPrefixToLinks(fenced, '/trellis/'), equals(fenced), reason: 'fenced code untouched');

      // A REAL link outside code IS still prefixed, even right after a code region.
      final out = applyPathPrefixToLinks('$inline<a href="/docs/next/">next</a>', '/trellis/');
      expect(out, contains('<code>&lt;link href="/css/main.css"&gt;</code>'), reason: 'code region preserved');
      expect(out, contains('<a href="/trellis/docs/next/">'), reason: 'real link after code prefixed');
    });

    test('fully-escaped code (href=&quot;/x&quot;) is also untouched', () {
      const html = '<pre><code>&lt;a href=&quot;/docs/&quot;&gt;&lt;/a&gt;</code></pre>';
      expect(applyPathPrefixToLinks(html, '/trellis/'), equals(html));
    });

    test('empty prefix is a literal no-op', () {
      const html = '<a href="/docs/">g</a><link href="/css/main.css">';
      expect(applyPathPrefixToLinks(html, ''), equals(html));
    });
  });
}
