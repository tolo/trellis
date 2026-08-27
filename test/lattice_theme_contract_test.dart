import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';
import 'package:yaml/yaml.dart';

void main() {
  final themeDir = p.join(Directory.current.path, 'themes', 'lattice');

  test('S01/TI01 manifest exposes the exact standard, docs, and Lattice contract', () {
    final manifest = ThemeManifest.load(themeDir);
    const standardParams = {
      'skin',
      'primary_color',
      'accent_color',
      'text_color',
      'muted_color',
      'bg_color',
      'surface_color',
      'border_color',
      'font_family',
      'heading_font_family',
      'code_font_family',
      'max_width',
      'border_radius',
      'nav_links',
      'social_links',
      'footer_text',
      'show_powered_by',
      'show_rss_link',
    };
    const docsParams = {'show_sidebar', 'show_toc', 'show_prev_next', 'show_search', 'toc_title', 'sidebar_title'};
    const latticeParams = {
      'logo',
      'favicon',
      'excerpt_length',
      'hero_eyebrow',
      'hero_headlines',
      'hero_lede',
      'hero_cta_primary_label',
      'hero_cta_primary_url',
      'hero_cta_secondary_label',
      'hero_cta_secondary_url',
      'terminal_card_lines',
      'show_terminal_card',
      'show_code_showcase',
      'show_why_grid',
      'show_demo',
      'show_themes_showcase',
      'show_cta',
      'cta_title',
      'cta_body',
      'cta_commands',
    };

    expect(manifest.name, 'lattice');
    expect(manifest.minTrellisVersion, '0.10.0');
    expect(manifest.features.where({'docs', 'landing', 'blog'}.contains), ['docs']);
    expect(manifest.params.keys.toSet(), standardParams.union(docsParams).union(latticeParams));
    expect(manifest.params['excerpt_length']!.defaultValue, 160);
    expect(manifest.params['logo']!.defaultValue, isNull);
    expect(manifest.params['favicon']!.defaultValue, 'favicon.svg');
    expect(manifest.screenshots, ['screenshots/light.png', 'screenshots/dark.png']);

    final headlines = manifest.params['hero_headlines']!.defaultValue as List<dynamic>;
    for (final dynamic headline in headlines) {
      expect((headline as Map<String, dynamic>).keys.toSet(), {'prefix', 'emphasis', 'suffix'});
      expect(headline.values, everyElement(isA<String>()));
    }

    final terminal = manifest.params['terminal_card_lines']!.defaultValue as List<dynamic>;
    expect(terminal, hasLength(5));
    for (final dynamic line in terminal) {
      expect((line as Map<String, dynamic>).keys.toSet(), {'prefix', 'text', 'kind'});
      expect(line['kind'], anyOf('command', 'output'));
    }

    // `trellis create` (never `trellis new`) is a real command, so it is pinned where a real command
    // belongs — the bundled example — now that the theme default is a content-neutral placeholder.
    final example = File(p.join(themeDir, 'example', 'trellis_site.yaml')).readAsStringSync();
    expect(example, contains('trellis create'));
    expect(example, isNot(contains('trellis new')));
  });

  test('S03/TI05 showcase screenshot tails are prefix-relative and joined exactly once', () {
    final data = File(p.join(themeDir, 'data', 'lattice.yaml')).readAsStringSync();
    final paths = RegExp(r'screenshot_(?:light|dark):\s*"([^"]+)"').allMatches(data).map((m) => m.group(1)!);
    expect(paths, isNotEmpty);
    for (final path in paths) {
      expect(path, isNot(startsWith('/')));
      expect(path, startsWith('showcase/'));
      expect(File(p.join(themeDir, 'static', path)).existsSync(), isTrue, reason: path);
    }
    final home = File(p.join(themeDir, 'layouts', 'home.html')).readAsStringSync();
    expect(home, contains(r'${assetBase} + ${card.screenshot_light}'));
    expect(home, contains(r'${assetBase} + ${card.screenshot_dark}'));
    expect(home, contains(r'${data.lattice.showcase.link_label}'));
    expect(home, contains(r'${data.lattice.showcase.link_url}'));
  });

  test('S02-S05/TI03 bridged overrides preserve shared geometry and dark palette ownership', () {
    String compile(String prelude) {
      final tempDir = Directory.systemTemp.createTempSync('lattice_skin_contract_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final wrapper = File(p.join(tempDir.path, 'main.scss'))
        ..writeAsStringSync(
          '$prelude\n'
          '@import "${p.join(themeDir, 'sass', 'main.scss')}";\n',
        );
      return TrellisCss.compileSass(wrapper.path, silenceImportDeprecation: true);
    }

    const sharedOverrides = r'''
$trellis-heading-font-family: Georgia, serif;
$trellis-max-width: 900px;
$trellis-border-radius: 0;
''';
    final light = compile(r'$trellis-primary-color: #7A4FBF;' + sharedOverrides);
    final dark = compile('@import "${p.join(themeDir, 'sass', '_skins', '_dark.scss')}";\n$sharedOverrides');

    for (final css in [light, dark]) {
      expect(css, contains('--display: Georgia, serif'));
      expect(css, contains('--content-width: 900px'));
      expect(css, contains('--radius: 0'));
      expect(css, isNot(contains('--display: "')));
      expect(css, isNot(contains('--content-width: "')));
    }
    expect(light.toLowerCase(), contains('--leaf: #7a4fbf'));
    expect(dark.toLowerCase(), contains('--leaf: #6fbf8b'));
    expect(dark, contains('--on-leaf: #0d1710'));
    expect(dark, contains('--syntax-keyword: #b48bd9'));
  });

  test('S04-S06/TI06 progressive enhancement avoids innerHTML and obeys reduced motion', () {
    final script = File(p.join(themeDir, 'static', 'js', 'lattice.js')).readAsStringSync();
    final styles = File(p.join(themeDir, 'sass', 'main.scss')).readAsStringSync();
    final home = File(p.join(themeDir, 'layouts', 'home.html')).readAsStringSync();
    expect(script, isNot(contains('innerHTML')));
    expect(script, contains("matchMedia('(prefers-reduced-motion: reduce)')"));
    expect(script, contains('document.createTextNode'));
    expect(script, contains('localStorage.setItem'));
    expect(script, contains('document.hidden'));
    expect(script, contains('document.fonts.ready.then(fitHeadline)'));
    expect(script, contains("headline.style.setProperty('--headline-fit-scale'"));
    expect(script, contains("headline.classList.add('is-fading')"));
    expect(script, contains('}, 500)'));
    expect(styles, contains('height: calc(var(--h1-size) * 1.08 * 2)'));
    expect(styles, isNot(contains('min-height: 145px')));
    expect(styles, contains('h1.fit-1'));
    expect(styles, contains('h1.fit-2'));
    expect(styles, contains('h1.fit-3'));
    expect(styles, contains('overflow: hidden'));
    expect(home, contains('<h1 id="headline" data-headline>'));
    expect(styles, contains('@media (min-width: 1180px)'));
    expect(styles, contains('@media (max-width: 1199px)'));
    expect(styles, contains('@media (max-width: 900px)'));
  });

  test('owner spacing polish keeps terminal groups legible and centers the closing card', () {
    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);
    expect(css, matches(RegExp(r'\.window-bar span\s*\{[^}]*margin-left:\s*8px', dotAll: true)));
    expect(
      css,
      matches(
        RegExp(
          r'\.terminal-line\[data-kind=output\]\s*\+\s*'
          r'\.terminal-line\[data-kind=command\]\s*\{[^}]*margin-top:\s*26px',
          dotAll: true,
        ),
      ),
    );
    expect(css, matches(RegExp(r'main > section\s*\{[^}]*padding-block:\s*84px', dotAll: true)));
    expect(
      css,
      matches(
        RegExp(
          r'@media \(max-width: 700px\)\s*\{.*?'
          r'main > section\s*\{[^}]*padding-block:\s*64px',
          dotAll: true,
        ),
      ),
    );
    final closingRule = RegExp(r'\.closing-section\s*\{([^}]*)\}').firstMatch(css);
    expect(closingRule, isNotNull);
    expect(closingRule!.group(1), isNot(contains('padding')));
  });

  test('subpage shell provides spacing, utility type, and compact navigation', () async {
    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);
    expect(css, matches(RegExp(r'\.docs-shell\s*\{[^}]*padding-block:\s*64px 96px', dotAll: true)));
    expect(
      css,
      matches(
        RegExp(
          r'\.doc > h1\s*\{[^}]*font-family:\s*var\(--body\)[^}]*font-size:\s*clamp\(34px, 3\.2vw, 46px\)',
          dotAll: true,
        ),
      ),
    );
    expect(css, isNot(matches(RegExp(r'^h1\s*\{', multiLine: true))));
    expect(css, matches(RegExp(r'\.breadcrumb ul\s*\{[^}]*display:\s*flex', dotAll: true)));
    expect(
      css,
      matches(
        RegExp(
          r'@media \(max-width: 700px\)\s*\{.*?'
          r'\.docs-shell\s*\{[^}]*padding-block:\s*32px 64px',
          dotAll: true,
        ),
      ),
    );

    final base = File(p.join(themeDir, 'layouts', 'base.html')).readAsStringSync();
    expect(base, contains('class="sidebar-disclosure" open data-docs-sidebar'));

    final result = await _runNodeHarness('lattice', p.join(themeDir, 'static', 'js', 'lattice.js'));
    if (result == null) return;
    expect((result['motion']! as Map<String, dynamic>)['sidebar'], {
      'initial': true,
      'afterCrossing': false,
      'afterReturn': true,
      'listenerCount': 1,
    });
    expect((result['sidebarMobile']! as Map<String, dynamic>)['sidebar'], {
      'initial': false,
      'afterCrossing': true,
      'afterReturn': false,
      'listenerCount': 1,
    });
  });

  test('S04/TI06 headline waits for the interval and stays static with reduced motion', () async {
    final result = await _runNodeHarness('lattice', p.join(themeDir, 'static', 'js', 'lattice.js'));
    if (result == null) return;

    final motion = result['motion']! as Map<String, dynamic>;
    expect(motion['immediate'], 'Server first');
    expect(motion['atFadeStart'], {'text': 'Server first', 'fading': true});
    expect(motion['afterFade'], {'text': 'Client second', 'fading': false});
    expect(motion['intervalDelay'], 6500);
    expect(motion['intervalCount'], 1);
    expect(motion['fadeDelay'], 500);
    expect(motion['timeoutCount'], 1);

    final reducedMotion = result['reducedMotion']! as Map<String, dynamic>;
    expect(reducedMotion['immediate'], 'Server first');
    expect(reducedMotion['atFadeStart'], {'text': 'Server first', 'fading': false});
    expect(reducedMotion['afterFade'], {'text': 'Server first', 'fading': false});
    expect(reducedMotion['intervalCount'], 0);
    expect(reducedMotion['timeoutCount'], 0);

    final empty = result['empty']! as Map<String, dynamic>;
    final single = result['single']! as Map<String, dynamic>;
    expect(empty['immediate'], 'Server first');
    expect(empty['intervalCount'], 0);
    expect(single['immediate'], 'Server first');
    expect(single['intervalCount'], 0);

    final long = result['long']! as Map<String, dynamic>;
    expect(long['fontReadyHandlerCount'], 1);
    for (final stageName in ['beforeFonts', 'afterFonts']) {
      final stage = long[stageName]! as Map<String, dynamic>;
      expect(stage['contentHeight'] as int, lessThanOrEqualTo(stage['slotHeight'] as int), reason: stageName);
      expect(stage['scale'], isNotEmpty, reason: stageName);
    }
  });

  test('S01-S07/TI08 bridged example builds cleanly with complete rendered pages', () async {
    final config = SiteConfig.load(p.join(themeDir, 'example', 'trellis_site.yaml'));
    final result = await TrellisSite(config).build();
    expect(result.warnings, isEmpty);
    expect(result.pageCount, 5);

    final bridge = result.themeBuildConfig!;
    final tempDir = Directory.systemTemp.createTempSync('lattice_sass_contract_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final wrapper = File(p.join(tempDir.path, 'main.scss'))
      ..writeAsStringSync(
        '@import "${p.join(bridge.buildDir, '_theme_params.scss')}";\n'
        '@import "${p.join(themeDir, 'sass', 'main.scss')}";\n',
      );
    final css = TrellisCss.compileSass(wrapper.path, loadPaths: bridge.sassLoadPaths, silenceImportDeprecation: true);
    final cssFile = File(p.join(config.outputDir, 'css', 'main.css'))..parent.createSync(recursive: true);
    cssFile.writeAsStringSync(css);
    expect(css, contains('--body: Instrument Sans, -apple-system, sans-serif'));
    expect(css, contains('--content-width: 1056px'));
    expect(css, isNot(contains('--body: "')));
    expect(css, isNot(contains('--content-width: "')));

    final output = p.join(themeDir, 'example', 'output');
    final pages = Directory(
      output,
    ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.html'));
    expect(pages, isNotEmpty);
    for (final page in pages) {
      final source = page.readAsStringSync();
      final document = html_parser.parse(source);
      expect(document.querySelector('body')!.children.first.classes, contains('skip-to-content'), reason: page.path);
      expect(document.querySelector('main'), isNotNull, reason: page.path);
      expect(document.querySelector('footer'), isNotNull, reason: page.path);
      expect(document.querySelector('.footer-inner > p:empty'), isNull, reason: page.path);
      final directiveAttributes = document
          .querySelectorAll('*')
          .expand<String>((element) => element.attributes.keys.map((attribute) => attribute.toString()))
          .where((attribute) => attribute.startsWith('tl:'));
      expect(directiveAttributes, isEmpty, reason: page.path);
      if (page.path.endsWith('heading-less/index.html')) {
        expect(source, isNot(contains(r'${')), reason: page.path);
        expect(document.querySelector('.docs-toc'), isNull, reason: page.path);
      }
    }
    _expectShowcaseSources(File(p.join(output, 'index.html')).readAsStringSync(), dark: false);
  });

  test('S03-S05/TI08 sub-path build prefixes URLs once without nesting output', () async {
    final tempDir = Directory.systemTemp.createTempSync('lattice_subpath_contract_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
    Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
    Link(p.join(tempDir.path, 'themes', 'lattice')).createSync(themeDir);
    final sourceConfig = File(p.join(themeDir, 'example', 'trellis_site.yaml')).readAsStringSync();
    File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync('$sourceConfig\npathPrefix: /trellis/\n');

    final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
    final result = await TrellisSite(config).build();
    expect(result.warnings, isEmpty);
    expect(result.pageCount, 5);
    expect(Directory(p.join(config.outputDir, 'trellis')).existsSync(), isFalse);

    final htmlFiles = Directory(
      config.outputDir,
    ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.html'));
    for (final file in htmlFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('/trellis/trellis/')), reason: file.path);
      final document = html_parser.parse(source);
      final directiveAttributes = document
          .querySelectorAll('*')
          .expand<String>((element) => element.attributes.keys.map((attribute) => attribute.toString()))
          .where((attribute) => attribute.startsWith('tl:'));
      expect(directiveAttributes, isEmpty, reason: file.path);
    }
    final home = File(p.join(config.outputDir, 'index.html')).readAsStringSync();
    _expectShowcaseSources(home, dark: false);
    expect(home, contains('src="/trellis/showcase/docs-light.svg"'));
    expect(home, contains('data-dark="/trellis/showcase/docs-dark.svg"'));
    expect(home, contains('src="/trellis/js/lattice.js"'));
  });

  test('forced skins select showcase sources server-side at root and sub-path', () async {
    final sourceConfig = File(p.join(themeDir, 'example', 'trellis_site.yaml')).readAsStringSync();
    for (final skin in ['light', 'dark']) {
      for (final prefix in ['', '/trellis/']) {
        final tempDir = Directory.systemTemp.createTempSync('lattice_forced_skin_contract_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        _copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
        Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
        Link(p.join(tempDir.path, 'themes', 'lattice')).createSync(themeDir);
        var configSource = sourceConfig.replaceFirst('skin: auto', 'skin: $skin');
        if (prefix.isNotEmpty) configSource = '$configSource\npathPrefix: $prefix\n';
        File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync(configSource);

        final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
        final result = await TrellisSite(config).build();
        expect(result.warnings, isEmpty, reason: '$skin $prefix');
        final home = File(p.join(config.outputDir, 'index.html')).readAsStringSync();
        _expectShowcaseSources(home, dark: skin == 'dark');
        expect(home, isNot(contains('data-lattice-theme-toggle')), reason: '$skin $prefix');
        expect(home, isNot(contains('localStorage')), reason: '$skin $prefix');
        expect(home, isNot(contains('/trellis/trellis/')), reason: '$skin $prefix');
      }
    }
  });

  test('TI02 and TI09 documented local assets exist', () {
    for (final asset in [
      'static/js/lattice.js',
      'static/js/search.js',
      'static/fonts/fraunces-latin.woff2',
      'static/fonts/fraunces-latin-ext.woff2',
      'static/fonts/fraunces-italic-latin.woff2',
      'static/fonts/instrument-sans-latin.woff2',
      'static/fonts/instrument-sans-latin-ext.woff2',
      'static/fonts/spline-sans-mono-latin.woff2',
      'static/fonts/spline-sans-mono-latin-ext.woff2',
      'static/fonts/OFL-Fraunces.txt',
      'static/fonts/OFL-Instrument-Sans.txt',
      'static/fonts/OFL-Spline-Sans-Mono.txt',
      'static/trellis-logo.png',
      'static/trellis-mark.png',
      'screenshots/light.png',
      'screenshots/dark.png',
    ]) {
      expect(File(p.join(themeDir, asset)).existsSync(), isTrue, reason: asset);
    }

    final canonicalLogo = File(p.join(Directory.current.path, 'assets', 'logo-small-with-text.png')).readAsBytesSync();
    final themeLogo = File(p.join(themeDir, 'static', 'trellis-logo.png')).readAsBytesSync();
    expect(themeLogo, canonicalLogo, reason: 'the Trellis top bar must use the compact canonical wordmark bytes');
    expect(themeLogo.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(_readUint32(themeLogo, 16), 512);
    expect(_readUint32(themeLogo, 20), 173);

    final canonicalMark = File(p.join(Directory.current.path, 'assets', 'logo-small.png')).readAsBytesSync();
    final mark = File(p.join(themeDir, 'static', 'trellis-mark.png')).readAsBytesSync();
    expect(mark, canonicalMark, reason: 'the Trellis favicon must use the compact canonical mark bytes');
    expect(mark.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(_readUint32(mark, 16), 256);
    expect(_readUint32(mark, 20), 256);
    // Font payload ships to every deployed site, so it is budgeted. Each file carries only the
    // axes the theme renders: Fraunces keeps opsz (optical sizing moves it at display sizes),
    // everything else is wght-only. Re-adding the unused axes triples the set.
    // 275KB against 268,024 B shipped leaves room for a small glyph addition while still failing
    // on the two regressions this cap exists to catch: a full-axis Fraunces upright (+~53KB) or a
    // latin-ext companion for the italic (+~35KB).
    final fontDir = Directory(p.join(themeDir, 'static', 'fonts'));
    final fontBytes = fontDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.woff2'))
        .fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(fontBytes, lessThanOrEqualTo(275 * 1024), reason: '\$fontBytes bytes');
    expect(
      File(p.join(fontDir.path, 'fraunces-latin.woff2')).lengthSync(),
      lessThanOrEqualTo(70 * 1024),
      reason: 'Fraunces must keep opsz+wght only, not SOFT/WONK',
    );

    for (final screenshot in ['screenshots/light.png', 'screenshots/dark.png']) {
      final bytes = File(p.join(themeDir, screenshot)).readAsBytesSync();
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10], reason: screenshot);
      expect(_readUint32(bytes, 16), 1280, reason: screenshot);
      expect(_readUint32(bytes, 20), 800, reason: screenshot);
    }

    final siteConfig = SiteConfig.load(p.join(Directory.current.path, 'site', 'trellis_site.yaml'));
    expect(siteConfig.themeConfig?.params['logo'], 'trellis-logo.png');
    expect(siteConfig.themeConfig?.params['favicon'], 'trellis-mark.png');

    final manifest = ThemeManifest.load(themeDir);
    final readme = File(p.join(themeDir, 'README.md')).readAsStringSync();
    for (final param in manifest.params.keys) {
      expect(readme, contains('`$param`'), reason: param);
    }
    expect(File(p.join(themeDir, 'VENDORED.md')).readAsStringSync(), contains('static/favicon.svg'));

    final base = File(p.join(themeDir, 'layouts', 'base.html')).readAsStringSync();
    final list = File(p.join(themeDir, 'layouts', '_default', 'list.html')).readAsStringSync();
    expect(base, contains(r'${#lists.size(theme.social_links)} > 0'));
    expect(base, contains(r"${assetBase} + ${theme.logo}"));
    expect(base, contains(r"${assetBase} + ${theme.favicon}"));
    expect(base, isNot(contains('M5 28 27 6')));
    expect(list, contains(r'${#lists.size(pages)} > 0'));
    expect(list, contains(r'${#lists.size(pages)} == 0'));
  });

  test('L1 no client-side highlighter ships; the panes carry their tokens (ADR-010)', () async {
    final script = File(p.join(themeDir, 'static', 'js', 'lattice.js')).readAsStringSync();
    // ADR-010: "No client-side highlighter ships in any official theme." The tokenizer keyed off
    // this attribute, so its absence is what keeps the constraint from quietly returning.
    expect(script, isNot(contains('data-lattice-code')));
    expect(script, isNot(contains('t-tag')));
    expect(script, isNot(contains('t-expr')));

    final home = File(p.join(themeDir, 'layouts', 'home.html')).readAsStringSync();
    for (final binding in [
      r'tl:utext="${data.lattice.code_showcase.template_html}"',
      r'tl:utext="${data.lattice.code_showcase.output_html}"',
      r'tl:utext="${data.lattice.demo.template_html}"',
    ]) {
      expect(home, contains(binding), reason: binding);
    }

    final config = SiteConfig.load(p.join(themeDir, 'example', 'trellis_site.yaml'));
    await TrellisSite(config).build();
    final document = html_parser.parse(File(p.join(config.outputDir, 'index.html')).readAsStringSync());
    final panes = document.querySelectorAll('.pane pre code, .demo-source pre code');
    expect(panes, hasLength(3));
    for (final pane in panes) {
      // Server-rendered token spans: coloured with JavaScript off, which the tokenizer never was.
      expect(pane.querySelectorAll('span.t-tag'), isNotEmpty, reason: pane.outerHtml);
      expect(pane.querySelectorAll('span.t-dim'), isNotEmpty, reason: pane.outerHtml);
      // The panes hold HTML *as content* and reach the page through tl:utext, so anything the author
      // failed to escape becomes live markup. Nothing but token spans may exist inside a pane.
      expect(pane.text, contains('<article'));
      for (final node in pane.querySelectorAll('*')) {
        expect(node.localName, 'span', reason: 'pane source became markup: ${node.outerHtml}');
        expect(node.classes.single, startsWith('t-'), reason: node.outerHtml);
      }
    }
    expect(panes.first.text, contains(r'tl:each="post : ${posts}"'));
  });

  test('L2 a partial data override drops the unsupplied home sections instead of emptying them', () async {
    final tempDir = Directory.systemTemp.createTempSync('lattice_partial_data_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
    Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
    Link(p.join(tempDir.path, 'themes', 'lattice')).createSync(themeDir);
    File(
      p.join(tempDir.path, 'trellis_site.yaml'),
    ).writeAsStringSync(File(p.join(themeDir, 'example', 'trellis_site.yaml')).readAsStringSync());
    // Only one of the four blocks. data/<stem>.yaml replaces the theme file whole, so the other
    // three have no data at all while their show_* params stay at their default true.
    Directory(p.join(tempDir.path, 'data')).createSync(recursive: true);
    File(p.join(tempDir.path, 'data', 'lattice.yaml')).writeAsStringSync('''
showcase:
  title: Our designs
  body: Pick one.
  link_label: ""
  link_url: ""
  cards:
    - name: One
      description: A design.
      config: "theme: one"
      accent: green
      screenshot_light: "showcase/docs-light.svg"
      screenshot_dark: "showcase/docs-dark.svg"
      alt: "One design"
''');

    final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
    final result = await TrellisSite(config).build();
    expect(result.warnings, isEmpty);

    final document = html_parser.parse(File(p.join(config.outputDir, 'index.html')).readAsStringSync());
    expect(document.querySelector('#lattice-showcase-title'), isNotNull);
    for (final id in ['lattice-code-title', 'lattice-why-title', 'lattice-demo-title']) {
      expect(document.querySelector('#$id'), isNull, reason: id);
    }
    for (final section in document.querySelectorAll('section[aria-labelledby]')) {
      final target = section.attributes['aria-labelledby']!;
      expect(document.querySelector('#$target'), isNotNull, reason: 'dangling aria-labelledby="$target"');
    }
    expect(document.querySelectorAll('h2').where((h) => h.text.trim().isEmpty), isEmpty);
    expect(document.querySelectorAll('code').where((c) => c.text.trim().isEmpty), isEmpty);
    expect(document.querySelectorAll('.why-cell'), isEmpty);
  });

  test('L3 theme defaults ship a shape, not a product pitch or a release number', () {
    final manifest = ThemeManifest.load(themeDir);
    final defaults = manifest.params.values.map((param) => param.defaultValue).toList();
    final data = loadYaml(File(p.join(themeDir, 'data', 'lattice.yaml')).readAsStringSync());
    // A third party who installs Lattice and overrides nothing must not publish Trellis's pitch, so
    // no default may name the SDK, its language, or its ecosystem. Nor may one carry a release
    // number: theme.yaml is outside tool/version_lockstep.sh, so it would advertise 0.11.0 forever.
    final banned = RegExp(r'\b(trellis|dart|htmx|shelf|pub\.dev|github\.com)\b|\d+\.\d+\.\d+', caseSensitive: false);
    for (final copy in [
      ..._flattenStrings(defaults),
      ..._flattenStrings([data]),
    ]) {
      expect(banned.firstMatch(copy)?.group(0), isNull, reason: copy);
    }
    // …while the Trellis site keeps saying all of it.
    final site = File(p.join(Directory.current.path, 'site', 'trellis_site.yaml')).readAsStringSync();
    expect(site, contains('dart pub add trellis'));
  });

  test('L4/L13 every code token clears WCAG AA and covers what the site emits', () async {
    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);
    for (final (skin, selector) in [('light', ':root'), ('dark', r'\[data-skin="?dark"?\]')]) {
      final props = _customProperties(css, selector);
      final surface = props['--card']!;
      for (final entry in props.entries.where((e) => e.key.startsWith('--syntax-') || e.key == '--ink-soft')) {
        final ratio = _contrastRatio(entry.value, surface);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$skin ${entry.key} ${entry.value} on $surface is ${ratio.toStringAsFixed(2)}:1',
        );
      }
    }

    final styled = RegExp(r'\.(hljs-[A-Za-z_-]+)').allMatches(css).map((m) => m.group(1)!).toSet();
    // The migration from arbor to lattice dropped most of the token map; these six are the classes
    // the site emits that used to fall through to the plain body colour.
    expect(
      styled,
      containsAll(<String>['hljs-number', 'hljs-class', 'hljs-title', 'hljs-meta', 'hljs-built_in', 'hljs-subst']),
    );

    final tempDir = Directory.systemTemp.createTempSync('lattice_hljs_coverage_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final build = await Process.run('dart', <String>[
      'run',
      p.join(Directory.current.path, 'packages', 'trellis_cli', 'bin', 'trellis.dart'),
      'build',
      '--output',
      tempDir.path,
    ], workingDirectory: p.join(Directory.current.path, 'site'));
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');

    final emitted = <String>{};
    for (final file in Directory(tempDir.path).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.html')) continue;
      emitted.addAll(RegExp('class="(hljs-[A-Za-z_-]+)"').allMatches(file.readAsStringSync()).map((m) => m.group(1)!));
    }
    expect(emitted, isNotEmpty);
    expect(emitted.difference(styled), isEmpty, reason: 'unstyled classes the site emits');
  });

  test('L5/L6 controls JavaScript cannot back are not rendered as live affordances', () async {
    final base = File(p.join(themeDir, 'layouts', 'base.html')).readAsStringSync();
    final home = File(p.join(themeDir, 'layouts', 'home.html')).readAsStringSync();
    final script = File(p.join(themeDir, 'static', 'js', 'lattice.js')).readAsStringSync();
    expect(script, contains('themeToggle.hidden = false'));
    // The Clipboard API is undefined outside a secure context, so the button must not appear there.
    expect(script, contains('window.isSecureContext'));
    expect(script, contains('copyButtons[copyIndex].hidden = false'));
    // A denied permission rejects; without a rejection handler that is an unhandled rejection and a
    // button stuck on "Copy" with nothing on the clipboard.
    expect(script, contains("button.textContent = 'Copy failed'"));

    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);
    // .mode-toggle sets display:inline-flex, which outranks the UA [hidden] rule on its own.
    expect(css, matches(RegExp(r'\[hidden\]\s*\{[^}]*display:\s*none\s*!important', dotAll: true)));

    final config = SiteConfig.load(p.join(themeDir, 'example', 'trellis_site.yaml'));
    await TrellisSite(config).build();
    final document = html_parser.parse(File(p.join(config.outputDir, 'index.html')).readAsStringSync());
    final toggle = document.querySelector('[data-lattice-theme-toggle]');
    expect(toggle, isNotNull);
    expect(toggle!.attributes.containsKey('hidden'), isTrue, reason: toggle.outerHtml);
    final copyButtons = document.querySelectorAll('[data-copy-command]');
    expect(copyButtons, isNotEmpty);
    for (final button in copyButtons) {
      expect(button.attributes.containsKey('hidden'), isTrue, reason: button.outerHtml);
    }
    expect(base, contains('hidden'));
    expect(home, contains('aria-label="Copy command"'));
  });

  test('L7/L8/L9/L12 sticky-header offsets, capped mobile contents, unscaled no-JS headline', () async {
    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);
    final script = File(p.join(themeDir, 'static', 'js', 'lattice.js')).readAsStringSync();
    final home = File(p.join(themeDir, 'layouts', 'home.html')).readAsStringSync();

    // L7 — .site-header is sticky; without both offsets an anchor target lands behind it.
    expect(css, matches(RegExp(r'html\s*\{[^}]*scroll-padding-top:\s*5rem', dotAll: true)));
    expect(css, matches(RegExp(r'h1,\s*h2,\s*h3,\s*h4,\s*h5,\s*h6\s*\{[^}]*scroll-margin-top:\s*5rem', dotAll: true)));

    // L8 — the inline contents list only appears below 980px and must not run the page height.
    expect(
      css,
      matches(RegExp(r'@media\s*\(max-width: 980px\)\s*\{.*?\.toc-inline\s*\{[^}]*max-height:\s*46vh', dotAll: true)),
    );
    expect(
      css,
      matches(RegExp(r'@media\s*\(max-width: 980px\)\s*\{.*?\.toc-inline\s*\{[^}]*overflow-y:\s*auto', dotAll: true)),
    );

    // L9 — the server-rendered slot grows with its content; only JavaScript locks and shrinks it.
    // A fixed height on the bare .headline-slot is what forced the pre-shrunk no-JS headline.
    final slotRules = RegExp(r'\.headline-slot\s*\{([^}]*)\}').allMatches(css).toList();
    expect(slotRules, hasLength(2), reason: 'base rule plus the narrow-viewport override');
    for (final rule in slotRules) {
      expect(rule.group(1), contains('min-height:'), reason: rule.group(0));
      expect(rule.group(1), isNot(matches(RegExp(r'(?<!min-)height:'))), reason: rule.group(0));
    }
    expect(css, matches(RegExp(r'\.headline-slot\.is-fitted\s*\{[^}]*overflow:\s*hidden', dotAll: true)));
    expect(css, isNot(contains('fit-initial')));
    expect(home, isNot(contains('fit-initial')));
    expect(script, contains("headlineSlot.classList.add('is-fitted')"));

    // L10/L11 — empty menu levels emit no list; the motion preference is tracked, not sampled once.
    final base = File(p.join(themeDir, 'layouts', 'base.html')).readAsStringSync();
    expect(base, contains(r'${#lists.size(n1.children)} > 0'));
    expect(base, contains(r'${#lists.size(n2.children)} > 0'));
    expect(script, contains("reducedMotion.addEventListener('change', syncMotion)"));
    expect(script, contains('window.clearInterval(cycleTimer)'));

    // L12 — classes that tl:define drops before they reach the output, and the !important they forced.
    for (final layout in ['home.html', p.join('_default', 'single.html'), p.join('_default', 'list.html')]) {
      final source = File(p.join(themeDir, 'layouts', layout)).readAsStringSync();
      expect(source, isNot(contains('docs-main-region')), reason: layout);
      expect(source, isNot(contains('class="home"')), reason: layout);
    }
    expect(css, isNot(contains('#main-content')));
    expect(RegExp(r'\.hero-section\s*\{([^}]*)\}').firstMatch(css)!.group(1), isNot(contains('!important')));

    final config = SiteConfig.load(p.join(themeDir, 'example', 'trellis_site.yaml'));
    await TrellisSite(config).build();
    for (final file in Directory(config.outputDir).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.html')) continue;
      final document = html_parser.parse(file.readAsStringSync());
      // An empty <ul> is announced as a list with no items on every docs page.
      final empty = document.querySelectorAll('ul.sidebar-subtree').where((ul) => ul.children.isEmpty);
      expect(empty, isEmpty, reason: file.path);
    }
  });

  test('L14 no rule asks a family for a weight its @font-face range cannot draw', () {
    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);

    // Declared weight range per vendored family, and the custom property each family answers to.
    // Merged across a family's faces: an <em> may pick the italic face, so the union is what the
    // family can actually draw. (Fraunces italic is pinned to 500; a heavier <em> synthesises.)
    final ranges = <String, List<int>>{};
    for (final face in _leafRules(css).where((rule) => rule.$2.contains('src:'))) {
      final family = _unquote(RegExp(r'font-family:\s*([^;]+)').firstMatch(face.$2)!.group(1)!);
      final weights = RegExp(r'font-weight:\s*(\d+)(?:\s+(\d+))?').firstMatch(face.$2)!;
      final low = int.parse(weights.group(1)!);
      final high = int.parse(weights.group(2) ?? weights.group(1)!);
      final current = ranges[family];
      ranges[family] = current == null ? [low, high] : [math.min(current.first, low), math.max(current.last, high)];
    }
    expect(ranges, hasLength(3));

    final root = _leafRules(css).firstWhere((rule) => _selector(rule.$1) == ':root').$2;
    final families = {
      for (final match in RegExp(r'(--(?:body|display|mono)):\s*([^;,]+)').allMatches(root))
        match.group(1)!: _unquote(match.group(2)!),
    };
    for (final family in families.values) {
      expect(ranges.keys, contains(family));
    }

    // A rule that names no family inherits the document's, set on body.
    final bodyRule = _leafRules(css).firstWhere((rule) => _selector(rule.$1) == 'body').$2;
    final fallback = families[RegExp(r'font:[^;]*var\((--[a-z]+)\)').firstMatch(bodyRule)!.group(1)!]!;

    for (final (selector, body) in _leafRules(css)) {
      if (body.contains('src:')) continue;
      final variable = RegExp(r'font(?:-family)?:[^;]*var\((--[a-z]+)\)').firstMatch(body)?.group(1);
      final family = families[variable] ?? fallback;
      final requested = <int>[
        ...RegExp(r'font-weight:\s*(\d+)\s*;').allMatches(body).map((m) => int.parse(m.group(1)!)),
        ...RegExp(r'font:\s*(\d{3})\s').allMatches(body).map((m) => int.parse(m.group(1)!)),
      ];
      for (final weight in requested) {
        final range = ranges[family]!;
        expect(
          weight,
          inInclusiveRange(range.first, range.last),
          reason: '$selector asks $family for $weight; the shipped face covers ${range.first}-${range.last}',
        );
      }
    }
  });
}

/// Declaration blocks in compiled CSS, skipping at-rule wrappers (whose bodies contain `{`).
Iterable<(String, String)> _leafRules(String css) =>
    RegExp(r'([^{}]+)\{([^{}]*)\}').allMatches(css).map((m) => (m.group(1)!, m.group(2)!));

String _unquote(String value) => value.trim().replaceAll('"', '').split(',').first.trim();

/// The rule's own selector: a leading `@charset`/at-rule opener shares the regex's first group.
String _selector(String raw) => raw.split(RegExp(r'[;}]')).last.trim();

/// Flattens nested YAML/param structures to the plain strings a visitor would read.
Iterable<String> _flattenStrings(Object? value) sync* {
  if (value is String) {
    yield value;
  } else if (value is List) {
    for (final dynamic item in value) {
      yield* _flattenStrings(item);
    }
  } else if (value is Map) {
    for (final dynamic item in value.values) {
      yield* _flattenStrings(item);
    }
  }
}

/// Custom properties declared by the first block matching [selectorPattern] in compiled CSS.
Map<String, String> _customProperties(String css, String selectorPattern) {
  final block = RegExp('$selectorPattern[^{]*\\{([^}]*)\\}').firstMatch(css);
  expect(block, isNotNull, reason: selectorPattern);
  return {
    for (final match in RegExp(r'(--[a-z-]+):\s*(#[0-9a-fA-F]{3,8})').allMatches(block!.group(1)!))
      match.group(1)!: match.group(2)!,
  };
}

double _relativeLuminance(String hex) {
  final value = hex.replaceFirst('#', '');
  final expanded = value.length == 3 ? value.split('').map((c) => '$c$c').join() : value;
  double channel(int offset) {
    final raw = int.parse(expanded.substring(offset, offset + 2), radix: 16) / 255;
    return raw <= 0.03928 ? raw / 12.92 : math.pow((raw + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4);
}

double _contrastRatio(String foreground, String background) {
  final a = _relativeLuminance(foreground);
  final b = _relativeLuminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

int _readUint32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];

Future<Map<String, dynamic>?> _runNodeHarness(String mode, String scriptPath) async {
  try {
    final harnessPath = p.join(Directory.current.path, 'test', 'theme_client_behavior_harness.js');
    final result = await Process.run('node', [harnessPath, mode, scriptPath]);
    expect(result.exitCode, 0, reason: 'theme client harness failed: ${result.stderr}');
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  } on ProcessException {
    markTestSkipped('system node not found – theme client behavioral harness skipped');
    return null;
  }
}

void _expectShowcaseSources(String source, {required bool dark}) {
  final images = html_parser.parse(source).querySelectorAll('.theme-card img[data-light][data-dark]');
  expect(images, isNotEmpty);
  for (final image in images) {
    final expected = image.attributes[dark ? 'data-dark' : 'data-light'];
    expect(image.attributes['src'], expected);
    expect(expected, startsWith('/'));
  }
}

void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final target = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      _copyDirectory(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}
