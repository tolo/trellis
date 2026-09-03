import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';
import 'package:yaml/yaml.dart';

import 'theme_font_contract.dart';

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
      'show_site_demo',
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
    // How the join is spelled is not the contract — that it emits exactly one leading slash is, and
    // _expectShowcaseSources asserts it on built output at both the root and the sub-path prefix.
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
      // A prefixed asset base already ends in a slash, so joining a root-relative value onto it
      // emits `//` — a protocol-relative URL the browser resolves against a host of that name.
      for (final element in document.querySelectorAll('[src], [href]')) {
        for (final attribute in ['src', 'href']) {
          expect(element.attributes[attribute], isNot(startsWith('//')), reason: '${file.path} ${element.outerHtml}');
        }
      }
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
    // The font payload's budget, floors, axes and glyph coverage are asserted in L14.

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
    // Both identity assets are joined onto the rendered asset base through the leading-slash guard,
    // never onto a raw param — see the built-output `//` assertions in the sub-path build test.
    expect(base, contains(r"${assetBase} + ${logoPath}"));
    expect(base, contains(r"${assetBase} + ${faviconPath}"));
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
      r'tl:utext="${data.lattice.site_demo.markdown_html}"',
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
    // data/<stem>.yaml replaces the theme file whole, so a site that supplies one block leaves the
    // rest with no data at all while their show_* params stay at their default true. A *partial*
    // block is the harder case and the one a block-level guard let through: `code_showcase: {title}`
    // published two empty <code> panes with the build reporting success, and `why: {title}` reached
    // `#lists.size(null) > 0` and killed the build with "Cannot compare Null with int".
    const showcaseCards = '''
  cards:
    - name: One
      description: A design.
      config: "theme: one"
      accent: green
      screenshot_light: "showcase/docs-light.svg"
      screenshot_dark: "showcase/docs-dark.svg"
      alt: "One design"
''';
    const pane = '<span class="t-tag">article</span>';
    // Each fixture pairs a data file with the section ids it must still publish. Every block below
    // is partial in one of the two directions a real override drifts: keys without content, or
    // content without the heading its section is named by.
    final fixtures = <String, (String, Set<String>, String?)>{
      'showcase supplied whole': (
        '''
showcase:
  title: Our designs
  body: Pick one.
  link_label: ""
  link_url: ""
$showcaseCards''',
        {'lattice-showcase-title'},
        null,
      ),
      'code_showcase title only': ('code_showcase:\n  title: T\n', <String>{}, null),
      'demo title and body only': ('demo:\n  title: T\n  body: B\n', <String>{}, null),
      'site_demo title only': ('site_demo:\n  title: T\n', <String>{}, null),
      'site_demo supplied whole and enabled': (
        '''
site_demo:
  title: Source to page
  markdown_html: '$pane'
  page_title: Result
''',
        {'lattice-site-demo-title'},
        '  show_site_demo: true\n',
      ),
      'why title only': ('why:\n  title: T\n', <String>{}, null),
      'showcase title only': ('showcase:\n  title: T\n', <String>{}, null),
      'every block content-only, no headings': (
        '''
code_showcase:
  template_html: '$pane'
  output_html: '$pane'
why:
  cells:
    - title: One
      body: Body.
demo:
  template_html: '$pane'
  prototype_title: P
  rendered_posts:
    - title: One
      body: Body.
showcase:
$showcaseCards''',
        <String>{},
        null,
      ),
    };
    const allSections = {
      'lattice-code-title',
      'lattice-why-title',
      'lattice-demo-title',
      'lattice-site-demo-title',
      'lattice-showcase-title',
    };

    for (final entry in fixtures.entries) {
      final tempDir = Directory.systemTemp.createTempSync('lattice_partial_data_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      _copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
      Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
      Link(p.join(tempDir.path, 'themes', 'lattice')).createSync(themeDir);
      final (data, expectedSections, themeParams) = entry.value;
      final exampleConfig = File(p.join(themeDir, 'example', 'trellis_site.yaml')).readAsStringSync();
      File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync(
        themeParams == null
            ? exampleConfig
            : exampleConfig.replaceFirst('theme_params:\n', 'theme_params:\n$themeParams'),
      );
      Directory(p.join(tempDir.path, 'data')).createSync(recursive: true);
      File(p.join(tempDir.path, 'data', 'lattice.yaml')).writeAsStringSync(data);

      final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
      // A guard that reaches a null comparison throws out of build(), so reaching the assertions
      // below is itself the "no unhandled exception" check.
      final result = await TrellisSite(config).build();
      expect(result.warnings, isEmpty, reason: entry.key);

      final document = html_parser.parse(File(p.join(config.outputDir, 'index.html')).readAsStringSync());
      for (final id in allSections) {
        expect(
          document.querySelector('#$id'),
          expectedSections.contains(id) ? isNotNull : isNull,
          reason: '${entry.key}: $id',
        );
      }
      for (final section in document.querySelectorAll('section[aria-labelledby]')) {
        final target = section.attributes['aria-labelledby']!;
        expect(document.querySelector('#$target'), isNotNull, reason: '${entry.key}: dangling $target');
      }
      if (expectedSections.contains('lattice-site-demo-title')) {
        expect(
          document.querySelector('section[aria-labelledby="lattice-site-demo-title"] code span.t-tag'),
          isNotNull,
          reason: '${entry.key}: S05 requires server-rendered syntax tokens',
        );
      }
      for (final heading in document.querySelectorAll('h2, h3')) {
        expect(heading.text.trim(), isNotEmpty, reason: '${entry.key}: empty ${heading.localName}');
      }
      expect(
        document.querySelectorAll('code').where((c) => c.text.trim().isEmpty),
        isEmpty,
        reason: '${entry.key}: blank code pane',
      );
      if (!expectedSections.contains('lattice-why-title')) {
        expect(document.querySelectorAll('.why-cell'), isEmpty, reason: entry.key);
      }
      if (!expectedSections.contains('lattice-demo-title')) {
        expect(document.querySelectorAll('.demo-post'), isEmpty, reason: entry.key);
      }
      if (!expectedSections.contains('lattice-showcase-title')) {
        expect(document.querySelectorAll('.theme-card'), isEmpty, reason: entry.key);
      }
    }
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
      for (final surface in [props['--paper']!, props['--foot-bg']!]) {
        final ratio = _contrastRatio(props['--footer-link']!, surface);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$skin footer link ${props['--footer-link']} on $surface is ${ratio.toStringAsFixed(2)}:1',
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
    expect(home, contains('aria-label="Copy command"'));

    // The search box is the same class of control and was the one exception: the layout shipped
    // only the results <ul> hidden, and the client marked the shell unavailable on a *fetch
    // failure* — never for "the script never ran". With JavaScript off that rendered a
    // permanently disabled search input in the sidebar, which is worse than no search box.
    final docs = html_parser.parse(
      File(p.join(config.outputDir, 'docs', 'getting-started', 'index.html')).readAsStringSync(),
    );
    final shell = docs.querySelector('.search-shell');
    expect(shell, isNotNull);
    expect(shell!.attributes.containsKey('hidden'), isTrue, reason: shell.outerHtml);
    expect(docs.querySelector('.search-input')!.attributes.containsKey('disabled'), isTrue);
    expect(base, contains('class="search-shell"'));
    final searchScript = File(p.join(themeDir, 'static', 'js', 'search.js')).readAsStringSync();
    // Revealed only on the success path; every failure path returns it to hidden.
    expect(searchScript, contains('shell.hidden = false'));
    expect(searchScript, contains('shell.hidden = true'));
    // The class-toggle mechanism it replaces: a `.search-unavailable { display: none }` rule left
    // behind would silently re-admit a shell that ships visible.
    expect(css, isNot(contains('search-unavailable')));
    expect(searchScript, isNot(contains('search-unavailable')));
  });

  test('search results carry the classes the client builds, styled, capped, and announced', () async {
    final script = File(p.join(themeDir, 'static', 'js', 'search.js')).readAsStringSync();
    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);

    // The client built bare <li><a> with no class at all: results rendered as inline, underlined,
    // unpadded body text in an uncapped list, on the published docs site. The class set is derived
    // from the script rather than hardcoded, so a rename on either side alone fails, and anchored
    // so a longer selector (.search-result-title-DISABLED) cannot satisfy the match.
    final built = RegExp(r"className = '([\w-]+)'").allMatches(script).map((match) => match.group(1)!).toSet();
    expect(built, <String>{
      'search-result',
      'search-result-link',
      'search-result-title',
      'search-result-snippet',
      'search-empty',
    });
    for (final className in built) {
      expect(RegExp('\\.$className(?=[\\s,{:])').hasMatch(css), isTrue, reason: className);
    }

    // A selector that keeps its name and loses its declarations reproduces the finding verbatim, so
    // every rule below is read for the whole value that produces the behaviour, not for a substring.
    for (final rule in ['.search-result-link', '.search-result-title', '.search-result-snippet']) {
      expect(
        _declared(css, rule, 'display'),
        'block',
        reason: '$rule: title and snippet are <span>s and concatenate inline without it',
      );
    }
    // Result links inherited the prose underline and had no hit area of their own (measured 0px).
    expect(_declared(css, '.search-result-link', 'text-decoration'), 'none');
    final padding = _declared(css, '.search-result-link', 'padding');
    expect(padding, isNotNull, reason: '.search-result-link must declare its own hit area');
    expect(int.parse(RegExp(r'^(\d+)px').firstMatch(padding!)!.group(1)!), greaterThanOrEqualTo(4));
    // Title and snippet must be told apart; one colour for both makes the snippet read as more title.
    final titleColour = _declared(css, '.search-result-title', 'color');
    expect(titleColour, isNotNull);
    expect(_declared(css, '.search-result-snippet', 'color'), allOf(isNotNull, isNot(titleColour)));
    // The empty state is a list item like any other and needs its own treatment, or it renders as a
    // line indistinguishable from a result.
    expect(
      ['color', 'font-style', 'padding'].map((prop) => _declared(css, '.search-empty', prop)).whereType<String>(),
      isNotEmpty,
    );

    // MAX_RESULTS results at ~100px each overflow any sidebar, so the list carries its own scroll.
    // The cap is read against the client's own limit rather than pinned; a degenerate 0 — or a cap
    // above the natural height of a full list — leaves the sidebar exactly as it was.
    final maxResults = int.parse(RegExp(r'MAX_RESULTS = (\d+)').firstMatch(script)!.group(1)!);
    final cap = _declared(css, '.search-results', 'max-height');
    expect(cap, isNotNull, reason: '.search-results must cap its height');
    expect(int.parse(RegExp(r'^(\d+)px$').firstMatch(cap!)!.group(1)!), inInclusiveRange(120, maxResults * 40));
    expect(_declared(css, '.search-results', 'overflow-y'), 'auto');

    // Results appear without a focus change, so the region has to announce them.
    final config = SiteConfig.load(p.join(themeDir, 'example', 'trellis_site.yaml'));
    await TrellisSite(config).build();
    final docs = html_parser.parse(
      File(p.join(config.outputDir, 'docs', 'getting-started', 'index.html')).readAsStringSync(),
    );
    expect(docs.querySelector('.search-results')!.attributes['aria-live'], 'polite');
  });

  test('article code blocks wrap rather than becoming an unreachable scrollable region', () {
    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);
    // The SSG emits article <pre> with no tabindex, so a horizontally scrolling one is content a
    // keyboard-only visitor cannot reach (axe scrollable-region-focusable, WCAG 2.1.1). The base
    // `pre` rule is `overflow: auto`; `.prose pre` is what keeps article code out of that state.
    // Whole values: `pre-wrap nowrap` prefix-matches `pre-wrap` and computes to `pre`.
    expect(_declared(css, '.prose pre', 'white-space'), 'pre-wrap');
    expect(_declared(css, '.prose pre', 'overflow-wrap'), 'anywhere');
    expect(_declared(css, '.prose pre', 'overflow'), 'visible');
    // The home-page panes are a different surface and keep the base rule; a fix aimed at article
    // code must not silently rewrap the marketing panes.
    expect(_declared(css, 'pre', 'overflow'), 'auto');
  });

  test('the example advertises commands the CLI actually accepts', () async {
    final params = SiteConfig.load(p.join(themeDir, 'example', 'trellis_site.yaml')).themeConfig!.params;
    final lines = (params['terminal_card_lines']! as List)
        .cast<Map<dynamic, dynamic>>()
        .where((line) => line['kind'] == 'command')
        .map((line) => line['text'].toString());
    // A trailing backslash continues onto the next card line; the card is ~39 mono characters wide.
    final cardCommands = lines.join('\n').replaceAll(RegExp(r'\\\n\s*'), ' ').split('\n');
    final ctaCommands = (params['cta_commands']! as List).map((c) => c.toString()).toList();
    final commands = <String>{...cardCommands, ...ctaCommands};
    // Both surfaces have to carry the install: a Lattice site is `create` *then* `theme add`, and
    // either one alone scaffolds a site on the wrong theme. Asserted per surface, because the two
    // are read independently — the card is what the gallery screenshot shows, the CTA is what a
    // visitor copies.
    for (final surface in {'terminal card': cardCommands, 'cta_commands': ctaCommands}.entries) {
      expect(surface.value.any((c) => c.contains('theme add')), isTrue, reason: surface.key);
      expect(surface.value.any((c) => c.contains('trellis create')), isTrue, reason: surface.key);
    }

    // The hero card is the first thing a gallery visitor reads and it is baked into both
    // screenshots, so the commands are checked against the CLI's own parser rather than a list
    // kept in this file: `trellis create --theme lattice` shipped for a release with no such
    // option. Appending --help makes each run parse-only — nothing is created.
    final cli = p.join(Directory.current.path, 'packages', 'trellis_cli', 'bin', 'trellis.dart');
    final probeDir = Directory.systemTemp.createTempSync('lattice_cli_probe_');
    addTearDown(() => probeDir.deleteSync(recursive: true));
    for (final command in commands) {
      expect(command, startsWith('trellis '), reason: command);
      final args = [...command.split(RegExp(r'\s+')).skip(1), '--help'];
      final result = await Process.run('dart', ['run', cli, ...args], workingDirectory: probeDir.path);
      expect(result.exitCode, 0, reason: '$command\n${result.stdout}${result.stderr}');
    }
    expect(probeDir.listSync(), isEmpty, reason: 'the --help probe must not touch the filesystem');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('L7/L8/L9/L12 sticky-header offsets, capped mobile contents, unscaled no-JS headline', () async {
    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);
    final script = File(p.join(themeDir, 'static', 'js', 'lattice.js')).readAsStringSync();
    final home = File(p.join(themeDir, 'layouts', 'home.html')).readAsStringSync();

    // L7 — .site-header is sticky; without the offset an anchor target lands behind it. The
    // scrollport's padding is the whole offset, and it is the only one: a scroll-margin-top on
    // headings *adds* to it, so headings landed at 10rem while every other target landed at
    // 5rem. Where a target actually ends up is measured in a browser by theme_contract_test's
    // anchor sweep; this pins the idiom, so the heading rule cannot come back beside it.
    expect(
      css,
      matches(
        RegExp(
          r'html\s*\{[^}]*--lattice-masthead-height:\s*48px;[^}]*'
          r'scroll-padding-top:\s*calc\(var\(--lattice-masthead-height\) \+ 2rem\)',
          dotAll: true,
        ),
      ),
    );
    expect(css, matches(RegExp(r'\.nav\s*\{[^}]*height:\s*var\(--lattice-masthead-height\)', dotAll: true)));
    expect(
      css,
      matches(RegExp(r'\.docs-toc\s*\{[^}]*top:\s*calc\(var\(--lattice-masthead-height\) \+ 30px\)', dotAll: true)),
    );
    expect(
      css,
      matches(
        RegExp(r'@media\s*\(max-width: 700px\)\s*\{.*?html\s*\{[^}]*--lattice-masthead-height:\s*56px', dotAll: true),
      ),
    );
    // Comments survive compilation, and the sheet's own note names the property it does not
    // set — so the absence has to be asserted over declarations, not over the source text.
    expect(css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ''), isNot(contains('scroll-margin-top')));

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

  test('L14 the vendored faces are the fonts the stylesheet claims, and draw what the theme emits', () async {
    await expectThemeFontContract(
      themeDir: themeDir,
      compiledCss: TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true),
      // Floors sit about a tenth under the shipped sizes and glyph counts: a face that loses a
      // table, its embedded OFL name records or a third of its glyphs fails, while trimming a few
      // codepoints does not. `axes` is exact, and is what the old `fraunces-latin.woff2 <= 70KB`
      // byte proxy was standing in for - a Fraunces with `opsz` instanced out is a perfectly valid
      // file that renders display text roughly 19% wide.
      faces: const {
        'fraunces-latin.woff2': (minBytes: 62 * 1024, minGlyphs: 225, axes: {'opsz', 'wght'}),
        'fraunces-latin-ext.woff2': (minBytes: 52 * 1024, minGlyphs: 350, axes: {'opsz', 'wght'}),
        // The italic is one instance: wght pinned to 500, opsz kept because the headline drives it.
        'fraunces-italic-latin.woff2': (minBytes: 38 * 1024, minGlyphs: 228, axes: {'opsz'}),
        'instrument-sans-latin.woff2': (minBytes: 26 * 1024, minGlyphs: 223, axes: {'wght'}),
        'instrument-sans-latin-ext.woff2': (minBytes: 9 * 1024, minGlyphs: 150, axes: {'wght'}),
        'spline-sans-mono-latin.woff2': (minBytes: 32 * 1024, minGlyphs: 244, axes: {'wght'}),
        'spline-sans-mono-latin-ext.woff2': (minBytes: 17 * 1024, minGlyphs: 200, axes: {'wght'}),
      },
      // Font payload ships to every deployed site, so it is budgeted. 275KB against 268,024 B
      // shipped leaves room for a small glyph addition while still failing on the two regressions
      // this cap exists to catch: a full-axis Fraunces upright (+~53KB) or a latin-ext companion
      // for the italic (+~35KB).
      maxTotalBytes: 275 * 1024,
      // All seven faces declare a unicode-range, so all seven are asserted against their
      // own cmap and nothing is exempt.
      unicodeRangeExemptions: const {},
      // The docs site runs on this theme, so what its authors type ships to real visitors in
      // these faces. Resolved through the layouts' content host rather than charged to every
      // family: the `→` in the trellis_site page is body prose, which is the one Lattice face
      // that draws it.
      contentPaths: [p.join(Directory.current.path, 'site', 'content')],
      // Every codepoint the theme emits is now drawn by the face that renders it:
      // `.duo-arrow` takes var(--body) for U+2192, and the terminal-card prefixes are
      // ASCII. An exact-list assertion, so a new gap fails here and so does a stale entry.
      // The docs site binds Lattice's params in its own config, and a glyph there
      // reaches real visitors rather than only a screenshot.
      extraConfigPaths: [p.join(Directory.current.path, 'site', 'trellis_site.yaml')],
      knownGaps: const [],
      knownWeightGaps: const [],
    );
  });

  test('terminal-card prefixes stay one column wide so the text column stays flush', () {
    final css = TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true);
    // The mechanism the one-character rule depends on: the prompt has no width of its own and the
    // text is offset from it by exactly one column, so prefix length *is* the text column's origin.
    // Give .terminal-prompt a fixed width and this constraint can be relaxed on purpose.
    expect(_declared(css, '.terminal-prompt', 'width'), isNull);
    expect(_declared(css, '.terminal-text', 'margin-left'), '1ch');

    final sources = <String, List<dynamic>>{
      'theme.yaml default': ThemeManifest.load(themeDir).params['terminal_card_lines']!.defaultValue as List<dynamic>,
      'example':
          SiteConfig.load(p.join(themeDir, 'example', 'trellis_site.yaml')).themeConfig!.params['terminal_card_lines']!
              as List<dynamic>,
    };
    for (final entry in sources.entries) {
      for (final dynamic line in entry.value) {
        final prefix = (line as Map<dynamic, dynamic>)['prefix'].toString();
        // Empty is allowed: a shell continuation deliberately has no prompt.
        expect(
          prefix.length,
          lessThanOrEqualTo(1),
          reason:
              '${entry.key}: prefix "$prefix" is ${prefix.length} columns, so its row starts '
              '${prefix.length - 1} column(s) right of every other row',
        );
      }
    }
  });
}

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

/// The whole declared value of [property] in the rule whose selector text is exactly [selector],
/// or null when the rule or the declaration is absent.
///
/// Whole-value on purpose. A substring match on a CSS keyword is not a match on its meaning:
/// `white-space: pre-wrap` is a prefix of `pre-wrap nowrap`, which the parser rejects outright and
/// computes as `pre` — the very state the assertion exists to forbid. And because Sass drops a rule
/// with an empty body, "the selector kept its name and lost its declarations" arrives here as null
/// rather than as a passing presence check.
String? _declared(String css, String selector, String property) {
  String normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
  final wanted = normalize(selector);
  String? found;
  for (final rule in RegExp(r'([^{}]+)\{([^{}]*)\}').allMatches(css)) {
    if (normalize(rule.group(1)!.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')) != wanted) continue;
    final declaration = RegExp('(?:^|;)\\s*${RegExp.escape(property)}\\s*:\\s*([^;]+)').firstMatch(rule.group(2)!);
    // Later rules win the cascade, so keep looking rather than returning the first.
    if (declaration != null) found = declaration.group(1)!.trim();
  }
  return found;
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
    _requireNodeInCi('the theme client behavioural harness');
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
    // Joining an asset base that already ends in a slash onto a root-relative tail emits `//`,
    // which a browser reads as an authority and fetches from a host named after the first segment.
    for (final attribute in ['src', 'data-light', 'data-dark']) {
      expect(image.attributes[attribute], isNot(startsWith('//')), reason: image.outerHtml);
    }
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

/// Skipping a node-gated check is a local convenience; in CI it is a silent hole
/// - the run reports "All tests passed!" with [what] never executed. Fail loudly
/// there instead, so the gate cannot go green on an assertion that did not run.
void _requireNodeInCi(String what) {
  if (Platform.environment['CI'] == 'true') {
    fail('node is required in CI: $what did not run');
  }
}
