import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

import 'theme_font_contract.dart';

void main() {
  final themeDir = p.join(Directory.current.path, 'themes', 'meadow');

  test('S01/S07 TI01 Meadow manifest exposes the exact landing contract', () {
    final manifest = ThemeManifest.load(themeDir);
    const standard = {
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
    const meadow = {
      'excerpt_length',
      'hero_align',
      'pill_badges',
      'logo',
      'sky_color',
      'sun_color',
      'bloom_color',
      'coral_color',
      'favicon',
    };

    expect(manifest.name, 'meadow');
    expect(manifest.minTrellisVersion, '0.10.0');
    expect(manifest.features.where({'docs', 'landing', 'blog'}.contains), ['landing']);
    expect(manifest.params.keys.toSet(), standard.union(meadow));
    const expectedTypes = {
      'skin': 'enum',
      'primary_color': 'color',
      'accent_color': 'color',
      'text_color': 'color',
      'muted_color': 'color',
      'bg_color': 'color',
      'surface_color': 'color',
      'border_color': 'color',
      'font_family': 'string',
      'heading_font_family': 'string',
      'code_font_family': 'string',
      'max_width': 'string',
      'border_radius': 'string',
      'nav_links': 'list',
      'social_links': 'list',
      'footer_text': 'string',
      'show_powered_by': 'boolean',
      'show_rss_link': 'boolean',
      'excerpt_length': 'int',
      'hero_align': 'enum',
      'pill_badges': 'boolean',
      'logo': 'string',
      'sky_color': 'color',
      'sun_color': 'color',
      'bloom_color': 'color',
      'coral_color': 'color',
      'favicon': 'string',
    };
    for (final entry in expectedTypes.entries) {
      expect(manifest.params[entry.key]!.type, entry.value, reason: entry.key);
      expect(manifest.params[entry.key]!.description, isNotEmpty, reason: entry.key);
    }
    const scalarDefaults = {
      'skin': 'auto',
      'primary_color': '#237a48',
      'accent_color': '#d4f15f',
      'text_color': '#14251a',
      'muted_color': '#476050',
      'bg_color': '#f7faee',
      'surface_color': '#fffef8',
      'border_color': '#d4e2ce',
      'font_family': 'Schibsted Grotesk, Inter, ui-sans-serif, system-ui, sans-serif',
      'heading_font_family': 'Bricolage Grotesque, Arial Rounded MT Bold, Trebuchet MS, sans-serif',
      'code_font_family': 'JetBrains Mono, SFMono-Regular, Consolas, monospace',
      'max_width': '1180px',
      'border_radius': '24px',
      'show_powered_by': true,
      'show_rss_link': true,
      'sky_color': '#69b9ea',
      'sun_color': '#ffd367',
      'bloom_color': '#cf91ef',
      'coral_color': '#fb907b',
      'favicon': 'favicon.svg',
    };
    for (final entry in scalarDefaults.entries) {
      expect(manifest.params[entry.key]!.defaultValue, entry.value, reason: entry.key);
    }
    expect(manifest.params['nav_links']!.defaultValue, hasLength(4));
    expect(manifest.params['social_links']!.defaultValue, isEmpty);
    expect(manifest.params['footer_text']!.defaultValue, isNull);
    expect(manifest.params['excerpt_length']!.defaultValue, 160);
    expect(manifest.params['hero_align']!.enumValues, ['center', 'split']);
    expect(manifest.params['hero_align']!.defaultValue, 'split');
    expect(manifest.params['pill_badges']!.defaultValue, isTrue);
    expect(manifest.params['logo']!.defaultValue, isNull);
    expect(manifest.screenshots, ['screenshots/light.png', 'screenshots/dark.png']);
    final readme = File(p.join(themeDir, 'README.md')).readAsStringSync();
    for (final param in manifest.params.keys) {
      expect(readme, contains('`$param`'), reason: param);
    }
    // The font payload's budget, floors, axes and glyph coverage are asserted in S05 TI08.

    for (final screenshot in manifest.screenshots) {
      final bytes = File(p.join(themeDir, screenshot)).readAsBytesSync();
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10], reason: screenshot);
      expect(_readUint32(bytes, 16), 1280, reason: screenshot);
      expect(_readUint32(bytes, 20), 800, reason: screenshot);
    }
    expect(File(p.join(themeDir, 'example', '.gitignore')).readAsStringSync(), contains('output/'));
  });

  test('S05 TI08 the vendored faces are the fonts the stylesheet claims, and draw what the theme emits', () async {
    await expectThemeFontContract(
      themeDir: themeDir,
      compiledCss: TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), silenceImportDeprecation: true),
      // Floors sit about a tenth under the shipped sizes and glyph counts: a face that loses a
      // table, its embedded OFL name records or a third of its glyphs fails, while trimming a few
      // codepoints does not. `axes` is exact - Bricolage keeps `opsz` because CSS
      // `font-optical-sizing` defaults to auto and the browser drives the axis from font-size, so a
      // file with it instanced out is valid and renders headings about 11% wide.
      faces: const {
        'bricolage-grotesque-latin.woff2': (minBytes: 70 * 1024, minGlyphs: 259, axes: {'opsz', 'wght'}),
        'schibsted-grotesk-latin.woff2': (minBytes: 42 * 1024, minGlyphs: 270, axes: {'wght'}),
        'jetbrains-mono-latin.woff2': (minBytes: 28 * 1024, minGlyphs: 379, axes: {'wght'}),
      },
      // Font payload ships to every deployed site, so it is budgeted; the unused axes cost 86KB.
      maxTotalBytes: 160 * 1024,
      knownGaps: const [
        (
          codepoint: 0x25CF,
          source: 'css .template-window::before in schibsted-grotesk',
          fix:
              'main.scss `.template-window::before` sets `content: \'● ● ●\'` and names no family, so it '
              'inherits the body face. Schibsted Grotesk draws no U+25CF and has none upstream. Add '
              '`font-family: var(--meadow-mono)`, as the sibling window chrome in home.html already does '
              '- JetBrains Mono carries it.',
        ),
      ],
      knownWeightGaps: const [],
    );
  });

  test('S01/S06 TI04/TI05 one dark source drives forced and auto skins', () {
    String compile(String prelude) {
      final tempDir = Directory.systemTemp.createTempSync('meadow_sass_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final wrapper = File(p.join(tempDir.path, 'main.scss'))
        ..writeAsStringSync('$prelude\n@import "${p.join(themeDir, 'sass', 'main.scss')}";\n');
      return TrellisCss.compileSass(wrapper.path, silenceImportDeprecation: true);
    }

    final light = compile(r'''
$trellis-primary-color: #123456;
$trellis-accent-color: #abcdef;
$trellis-text-color: #112233;
$trellis-muted-color: #445566;
$trellis-bg-color: #778899;
$trellis-surface-color: #aabbcc;
$trellis-border-color: #ddeeff;
$trellis-font-family: Arial, sans-serif;
$trellis-heading-font-family: Georgia, serif;
$trellis-code-font-family: Courier New, monospace;
$trellis-max-width: 900px;
$trellis-border-radius: 7px;
''');
    final dark = compile('\$trellis-skin: dark;\n@import "${p.join(themeDir, 'sass', '_skins', '_dark.scss')}";');

    for (final token in [
      '--meadow-leaf: #123456',
      '--meadow-lime: #abcdef',
      '--meadow-ink: #112233',
      '--meadow-muted: #445566',
      '--meadow-paper: #778899',
      '--meadow-surface: #aabbcc',
      '--meadow-line: #ddeeff',
      '--meadow-body: Arial, sans-serif',
      '--meadow-display: Georgia, serif',
      '--meadow-mono: Courier New, monospace',
      '--meadow-width: 900px',
      '--meadow-radius: 7px',
    ]) {
      expect(light.toLowerCase(), contains(token.toLowerCase()), reason: token);
    }
    expect(light, isNot(contains('--meadow-body: "')));
    expect(light, isNot(contains('--meadow-width: "')));
    expect(light, contains('@media (prefers-color-scheme: dark)'));
    expect(light, contains('data-skin=dark'));
    expect(light, contains('@media (prefers-reduced-motion: reduce)'));
    // The marker is a background on the inline box, not an absolutely-positioned ::before, so a
    // wrapped emphasis gets one band per line fragment instead of one box sized to the whole run.
    expect(light, isNot(contains('.marker::before')));
    expect(dark, isNot(contains('.marker::before')));
    expect(RegExp(r'\.marker\s*\{[^}]*box-decoration-break: clone;').hasMatch(light), isTrue);
    // Placement is the fix, not just the gradient: bottom-anchored so the band sits under the lower
    // half of every fragment, unrepeated so `background-size` cannot tile a second band above it,
    // and dark ink so the emphasis stays legible on lime.
    expect(RegExp(r'\.marker\s*\{[^}]*background-repeat: no-repeat;').hasMatch(light), isTrue);
    expect(RegExp(r'\.marker\s*\{[^}]*color: #14251a;').hasMatch(light), isTrue);
    expect(RegExp(r'\.marker\s*\{[^}]*background-position: left 0 bottom 0\.02em;').hasMatch(light), isTrue);
    expect(RegExp(r'\.marker\s*\{[^}]*background-position: left 0 bottom 0;').hasMatch(dark), isTrue);
    expect(RegExp(r'\.marker\s*\{[^}]*white-space').hasMatch(light), isFalse);
    expect(RegExp(r'\.marker\s*\{[^}]*white-space').hasMatch(dark), isFalse);
    // Light keeps the mockup's band over the lower 46%, tilted by the gradient angle rather than by
    // a transform; dark still covers the whole inline box. Both keep the mockup's irregular radii.
    expect(
      RegExp(
        r'\.marker\s*\{[^}]*linear-gradient\(178\.3deg, transparent 0 50%, var\(--meadow-lime\) 50% 100%\)'
        r'[^}]*background-size: 100% 92%;',
      ).hasMatch(light),
      isTrue,
    );
    expect(RegExp(r'\.marker\s*\{[^}]*border-radius: 0\.16em 0\.32em 0\.14em 0\.24em').hasMatch(light), isTrue);
    expect(RegExp(r'\.marker\s*\{[^}]*border-radius: 0\.28em 0\.16em 0\.25em 0\.13em').hasMatch(dark), isTrue);
    expect(RegExp(r'\.marker\s*\{[^}]*background-size: 100% 100%;').hasMatch(dark), isTrue);
    // The header CTA has no room beside the burger, so it leaves with the desktop nav. Above that
    // it reuses `hero.ctas[0].label`, which a landing page may make a sentence.
    expect(RegExp(r'\.desktop-nav, \.nav-cta\s*\{\s*display: none;').hasMatch(light), isTrue);
    expect(RegExp(r'\.nav-cta\s*\{[^}]*max-width: 220px').hasMatch(light), isTrue);
    // Truncation needs all three declarations, not just `text-overflow`. Rendered with the 53-char
    // copy-long label: a visible `overflow` lets the label escape the pill by 251px across the page,
    // and a wrapping `white-space` drives `.nav-inner` from 72px to 95px - M9's original defect.
    // Asserted against those failures rather than pinning one accepted value, so the treatment can
    // change (`clip` for `hidden`, `pre` for `nowrap`) but cannot become nothing.
    final ctaLabel = _declarations(light, '.nav-cta span');
    expect(ctaLabel['text-overflow'], 'ellipsis');
    expect(ctaLabel['overflow'], allOf(isNotNull, isNot('visible')));
    expect(ctaLabel['white-space'], allOf(isNotNull, isNot('normal')));
    // The attribution is the last flex item and cannot shrink, so without wrapping it pushes the
    // document 6px past a 768px viewport - measured, and the reason the rule exists.
    expect(_declarations(light, '.footer-inner')['flex-wrap'], 'wrap');
    // An auto track grows to max-content, so an uncapped tag collapses the message column to 0px
    // (measured 304px -> 0px at 1024px). The cap may be tuned; it may not be removed.
    expect(_declarations(light, '.signal-tag')['max-width'], isNotNull);
    // `anywhere` broke the brand and menu labels mid-word, so `body` keeps `break-word`. Page copy
    // needs `anywhere` because `break-word` does not shrink a box's min-content size, and a track
    // sized from min-content is what pushes an unbreakable token past the viewport.
    expect(RegExp(r'^body \{[^}]*overflow-wrap: break-word', multiLine: true).hasMatch(light), isTrue);
    expect(RegExp(r'^body \{[^}]*overflow-wrap: anywhere', multiLine: true).hasMatch(light), isFalse);
    expect(RegExp(r'^main \* \{\s*overflow-wrap: anywhere;', multiLine: true).hasMatch(light), isTrue);
    // `1fr` is `minmax(auto, 1fr)`: the track floor is the item's min-content size, so a long token
    // widens the track past its grid. Both skins compile the same tracks.
    for (final selector in ['.signal-card', '.quote-card']) {
      final blocks = RegExp('${RegExp.escape(selector)}\\s*\\{([^}]*)\\}').allMatches(light).toList();
      expect(blocks, isNotEmpty, reason: selector);
      var declared = 0;
      for (final block in blocks) {
        final columns = RegExp(r'grid-template-columns: ([^;]*);').firstMatch(block.group(1)!);
        if (columns == null) continue;
        declared++;
        final tracks = columns.group(1)!.replaceAll('minmax(0, 1fr)', 'flex');
        expect(tracks, isNot(contains('1fr')), reason: '$selector: ${columns.group(1)}');
      }
      expect(declared, greaterThanOrEqualTo(2), reason: selector);
    }
    // The desktop rule reset a border no rule sets.
    expect(RegExp(r'\.proof-list[^{]*\{[^}]*border-left').hasMatch(light), isFalse);
    // `pill_badges` had no implementation: the pill radius was hardcoded on every `.eyebrow`.
    expect(RegExp(r'\.eyebrow, \.kicker\s*\{[^}]*border-radius: 8px;').hasMatch(light), isTrue);
    expect(RegExp(r'\.kicker, \.eyebrow-pill\s*\{\s*border-radius: 999px;').hasMatch(light), isTrue);
    // Every class a layout appends must have a rule that selects it. `pill_badges` shipped as a
    // documented no-op for exactly this reason - `.eyebrow-pill` was emitted and never styled - so
    // the set is derived from the templates rather than listed here, and a class added later is
    // covered without anyone remembering to extend this test.
    final appended = <String>{};
    final written = <String>{};
    for (final layout in Directory(
      p.join(themeDir, 'layouts'),
    ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.html'))) {
      final source = layout.readAsStringSync();
      for (final attribute in RegExp('tl:classappend="([^"]*)"').allMatches(source)) {
        // Only the ternary branches name classes; `== 'split'` is a comparison operand.
        for (final branch in RegExp(r"[?:]\s*'([^']*)'").allMatches(attribute.group(1)!)) {
          appended.addAll(branch.group(1)!.split(' ').where((name) => name.isNotEmpty));
        }
      }
      // Static attributes too: `tl:classappend` is not the only way to ship a class nothing styles.
      for (final attribute in RegExp(r'\sclass="([^"$]*)"').allMatches(source)) {
        written.addAll(attribute.group(1)!.split(' ').where((name) => name.isNotEmpty));
      }
    }
    expect(appended, containsAll(const ['eyebrow-pill', 'signal-grid-solo']));
    // Two written classes are knowingly unstyled. `bloom-pop` is the residue of the mockup's hero
    // entrance animation, which this theme never ported - it ships no @keyframes at all - and is a
    // release-gate finding, not something to invent here. `page` is a structural hook on the article
    // wrapper. Naming them is what makes a NEW unstyled class fail rather than join a silent
    // backlog, so do not extend this set to make a test pass.
    const knownUnstyled = {'bloom-pop', 'page'};
    expect(written, containsAll(knownUnstyled), reason: 'stale exception: the class is no longer emitted');
    for (final name in appended.union(written).difference(knownUnstyled)) {
      // The lookahead stops a longer selector - `.signal-grid-solo-x` - from satisfying the search.
      expect(
        RegExp('\\.${RegExp.escape(name)}(?=[\\s,{:.\\[])').hasMatch(light),
        isTrue,
        reason: '$name is emitted by a layout but no rule selects it',
      );
    }
    // Highlight.js bakes these classes into fenced blocks at build time (ADR-010); unstyled means a
    // monochrome code block on a theme that ships a Markdown layout.
    final styledTokens = RegExp(
      r'\.prose pre code \.hljs-([a-z_-]+)',
    ).allMatches(light).map((m) => m.group(1)!).toSet();
    expect(
      styledTokens,
      containsAll(const <String>[
        'attr',
        'attribute',
        'built_in',
        'bullet',
        'class',
        'comment',
        'keyword',
        'literal',
        'meta',
        'meta-keyword',
        'name',
        'number',
        'section',
        'selector-pseudo',
        'string',
        'strong',
        'subst',
        'symbol',
        'tag',
        'title',
        'variable',
      ]),
    );
    // The auto block-start margin bottom-anchors the title+body block inside a stretched flex
    // column, so the cards' bottom edges align and their heights match. Titles coincide only when
    // the bodies wrap to the same number of lines.
    expect(RegExp(r'\.template-card-inner\s*\{[^}]*flex-direction: column;').hasMatch(light), isTrue);
    expect(RegExp(r'\.template-card-inner\s*\{[^}]*height: 100%;').hasMatch(light), isTrue);
    expect(RegExp(r'\.template-card h3\s*\{\s*margin: auto 0 8px;').hasMatch(light), isTrue);
    expect(light, isNot(contains('translateY(-8px) rotate(1.6deg)')));
    expect(dark.toLowerCase(), contains('--meadow-paper: #0f1c14'));
    expect(dark, isNot(contains('@media (prefers-color-scheme: dark)')));

    final darkTokens = File(p.join(themeDir, 'sass', '_dark_tokens.scss')).readAsStringSync();
    final darkSkin = File(p.join(themeDir, 'sass', '_skins', '_dark.scss')).readAsStringSync();
    expect(RegExp(r'#[0-9a-fA-F]{6}').hasMatch(darkSkin), isFalse);
    for (final value in RegExp(r'#[0-9a-fA-F]{6}').allMatches(darkTokens).map((m) => m.group(0)!)) {
      expect(File(p.join(themeDir, 'sass', 'main.scss')).readAsStringSync(), isNot(contains(value)));
    }
  });

  test('S01-S07 TI02/TI03/TI06/TI07 bridged default is complete and clean', () async {
    final config = SiteConfig.load(p.join(themeDir, 'example', 'trellis_site.yaml'));
    final result = await TrellisSite(config).build();
    expect(result.warnings, isEmpty);
    expect(result.pageCount, 4);

    final homeSource = File(p.join(config.outputDir, 'index.html')).readAsStringSync();
    final home = html_parser.parse(homeSource);
    expect(home.body!.children.first.classes, contains('skip-link'));
    expect(home.querySelectorAll('main'), hasLength(1));
    expect(home.querySelectorAll('[id="top"]'), hasLength(1));
    expect(home.querySelector('footer.site-footer'), isNotNull);
    expect(home.querySelectorAll('[data-headline] .marker'), hasLength(1));
    expect(home.querySelector('[data-headline]')!.text, contains('worth building.'));
    expect(home.querySelectorAll('.feature-card'), hasLength(6));
    expect(home.querySelectorAll('.hero-art'), hasLength(1));
    expect(home.querySelectorAll('.home-prose'), isEmpty);
    final sourceLink = home.querySelector('.footer-links a[href="https://github.com/tolo/trellis"]');
    expect(sourceLink, isNotNull);
    expect(sourceLink!.text, 'Source');
    expect(homeSource, isNot(contains(r'${')));
    expect(homeSource, isNot(contains('tl:')));
    expect(homeSource, contains('src="/js/meadow.js"'));
    // `href="data:,"` did not just fail to set an icon, it suppressed the default /favicon.ico
    // request, so dropping a file in static/ did not help either.
    expect(homeSource, contains('<link rel="icon" href="/favicon.svg">'));
    // The header CTA reuses the hero label verbatim; the span is what the ellipsis needs.
    final navCta = home.querySelector('.nav-cta span');
    expect(navCta, isNotNull);
    expect(navCta!.text, home.querySelector('.hero-actions .button')!.text);
    // `margin: auto 0 8px` on the title only bottom-anchors the title+body block while the body is
    // the last child of the flex column.
    for (final card in home.querySelectorAll('.template-card-inner')) {
      expect(card.children.map((child) => child.localName), ['span', 'div', 'h3', 'p']);
    }

    final listSource = File(p.join(config.outputDir, 'notes', 'index.html')).readAsStringSync();
    expect(listSource, isNot(contains('&lt;code&gt;')));
    expect(listSource, isNot(contains('&lt;a ')));
    final about = html_parser.parse(File(p.join(config.outputDir, 'about', 'index.html')).readAsStringSync());
    expect(about.querySelector('.desktop-nav a')!.attributes['href'], '/#features');
    final bridge = result.themeBuildConfig!;
    final tempDir = Directory.systemTemp.createTempSync('meadow_bridge_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final wrapper = File(p.join(tempDir.path, 'main.scss'))
      ..writeAsStringSync(
        '@import "${p.join(bridge.buildDir, '_theme_params.scss')}";\n'
        '@import "${p.join(themeDir, 'sass', 'main.scss')}";\n',
      );
    final css = TrellisCss.compileSass(wrapper.path, loadPaths: bridge.sassLoadPaths, silenceImportDeprecation: true);
    expect(css, isNot(contains('--meadow-body: "')));
    expect(css, isNot(contains('--meadow-width: "')));

    final assetFiles = [
      'fonts/bricolage-grotesque-latin.woff2',
      'fonts/schibsted-grotesk-latin.woff2',
      'fonts/jetbrains-mono-latin.woff2',
      'fonts/OFL-Bricolage-Grotesque.txt',
      'fonts/OFL-Schibsted-Grotesk.txt',
      'fonts/OFL-JetBrains-Mono.txt',
      'js/meadow.js',
      'favicon.svg',
    ];
    for (final asset in assetFiles) {
      expect(File(p.join(config.outputDir, asset)).existsSync(), isTrue, reason: asset);
    }
    final js = File(p.join(config.outputDir, 'js', 'meadow.js')).readAsBytesSync();
    expect(gzip.encode(js).length, lessThan(15 * 1024));
  });

  test('S02-S04 TI03/TI06 exact fixtures render copy, counts, and absence', () async {
    for (var count = 2; count <= 6; count++) {
      for (final skin in ['light', 'dark']) {
        final document = await _buildFixture(themeDir, 'count-$count', skin: skin);
        expect(document.querySelectorAll('.feature-card'), hasLength(count), reason: 'count-$count-$skin');
      }
    }

    final tempDir = Directory.systemTemp.createTempSync('meadow_feature_css_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final wrapper = File(p.join(tempDir.path, 'main.scss'))
      ..writeAsStringSync(
        '\$trellis-skin: light;\n'
        '@import "${p.join(themeDir, 'sass', 'main.scss')}";\n',
      );
    final css = TrellisCss.compileSass(wrapper.path, silenceImportDeprecation: true).replaceAll(RegExp(r'\s+'), '');
    const treatments = {
      '.feature-card:nth-child(4n + 1)': '--meadow-lime-soft',
      '.feature-card:nth-child(4n + 2)': '--meadow-sky-soft',
      '.feature-card:nth-child(4n + 3)': '--meadow-sun-soft',
      '.feature-card:nth-child(4n)': '--meadow-bloom-soft',
    };
    for (final entry in treatments.entries) {
      final selector = entry.key.replaceAll(' ', '');
      final rules = RegExp('${RegExp.escape(selector)}\\{([^}]*)\\}').allMatches(css).toList();
      expect(rules, hasLength(1), reason: entry.key);
      expect(rules.single.group(1), contains('background:var(${entry.value})'), reason: entry.key);
    }
    final gridRules = RegExp(r'\.feature-grid\s*\{([^}]*)\}').allMatches(css).toList();
    expect(gridRules, hasLength(3));
    expect(gridRules.first.group(1), contains('grid-template-columns:repeat(3,minmax(0,1fr))'));
    expect(gridRules[1].group(1), contains('grid-template-columns:repeat(2,minmax(0,1fr))'));
    expect(gridRules.last.group(1), contains('grid-template-columns:1fr'));
    // One base treatment plus the narrow-viewport padding override; neither pins a height.
    final cardRules = RegExp(r'\.feature-card\s*\{([^}]*)\}').allMatches(css).toList();
    expect(cardRules, hasLength(2));
    expect(cardRules.first.group(1), contains('min-width:0'));
    for (final rule in cardRules) {
      expect(rule.group(1), isNot(matches(RegExp(r'(^|;)\s*height\s*:'))));
    }

    final short = await _buildFixture(themeDir, 'copy-short');
    expect(short.querySelector('[data-headline]')!.text.replaceAll(RegExp(r'\s+'), ' ').trim(), 'Ship today.');
    expect(short.querySelector('.hero-lede')!.text, 'A clear landing page.');
    expect(short.querySelector('.feature-card h3')!.text, 'Fast');
    expect(short.querySelector('.feature-card p')!.text, 'Ready now.');

    final long = await _buildFixture(themeDir, 'copy-long');
    expect(long.querySelector('[data-headline]')!.text, contains('without losing the context'));
    expect(long.querySelector('.hero-lede')!.text, contains('expanding product story'));
    expect(long.querySelector('.feature-card h3')!.text, contains('teams that keep expanding'));
    expect(
      long.querySelector('.feature-card p')!.text,
      'Start with the template engine, add static-site generation and server integrations when needed, and keep every '
      'layer in Dart without introducing a client framework or Node-based build chain.',
    );

    // hero.media.src mounts the site's own artwork; hero.media with only `alt` keeps the drawn scene.
    final heroImage = await _buildFixture(themeDir, 'hero-image');
    final art = heroImage.querySelector('.hero-art img')!;
    expect(art.attributes['src'], '/art/hero.webp');
    expect(art.attributes['alt'], 'Product screenshot');
    expect(heroImage.querySelector('.hero-art svg'), isNull, reason: 'drawn trellis must step aside');
    final drawn = await _buildFixture(themeDir, 'copy-short');
    expect(drawn.querySelector('.hero-art img'), isNull);

    final noMedia = await _buildFixture(themeDir, 'no-media');
    expect(noMedia.querySelector('.hero-grid')!.classes, contains('hero-center'));
    expect(noMedia.querySelector('.hero-art'), isNull);

    final noOptionals = await _buildFixture(themeDir, 'no-optionals');
    for (final selector in ['.proof-strip', '#features', '#workflow', '#use-cases', '.quote-band', '#start']) {
      expect(noOptionals.querySelector(selector), isNull, reason: selector);
    }
    expect(noOptionals.querySelectorAll('.home-prose'), hasLength(1));
    expect(noOptionals.body!.text, contains('Page-authored Markdown renders once'));

    const absentFixtures = {
      'no-proof': '.proof-strip',
      'no-features': '#features',
      'no-workflow': '#workflow',
      'no-use-cases': '#use-cases',
      'no-quote': '.quote-band',
      'no-cta': '#start',
    };
    for (final entry in absentFixtures.entries) {
      final document = await _buildFixture(themeDir, entry.key);
      expect(document.querySelector(entry.value), isNull, reason: entry.key);
      for (final selector in absentFixtures.values.where((value) => value != entry.value)) {
        expect(document.querySelector(selector), isNotNull, reason: '${entry.key}: $selector');
      }
    }
    final authoredMeter = await _buildFixture(themeDir, 'no-proof');
    final meter = authoredMeter.querySelector('.meter')!;
    expect(meter.attributes['aria-valuenow'], '42');
    expect(meter.attributes['style'], contains('--confidence: 42%'));

    // A present block may still have absent optional fields. Unguarded, the insight card emitted an
    // empty span/h3/p and `--confidence: null%` - an invalid clamp, so the width was dropped and the
    // block-level span filled the meter: a full bar for a value that does not exist.
    final partial = await _buildFixture(themeDir, 'partial-workflow');
    expect(partial.querySelector('#workflow'), isNotNull);
    expect(partial.querySelectorAll('.signal-card'), hasLength(1));
    expect(partial.querySelector('.insight-card'), isNull);
    expect(partial.querySelector('.meter'), isNull);
    // With no insight card the second track would still reserve its 320px minimum.
    expect(partial.querySelector('.signal-grid')!.classes, contains('signal-grid-solo'));

    // The mirror case: an insight with no signal list and no confidence. `#lists.size(null)` returns
    // null and `null > 0` throws, so the list guard has to test for null first and let `and`
    // short-circuit; an unguarded meter would render `--confidence: null%` and a full bar.
    final partialInsight = await _buildFixture(themeDir, 'partial-insight');
    expect(partialInsight.querySelector('.insight-card'), isNotNull);
    expect(partialInsight.querySelector('.signal-stack'), isNull);
    expect(partialInsight.querySelector('.meter'), isNull);
    expect(partialInsight.querySelector('.insight-card p'), isNull);
    expect(partialInsight.querySelector('.insight-label')!.text, 'Opportunity');

    // Interpolated absent values reach the page as the literal `null`; no fixture may produce one.
    for (final fixture in Directory(p.join(themeDir, 'example', 'fixtures')).listSync().whereType<Directory>()) {
      final name = p.basename(fixture.path);
      final document = await _buildFixture(themeDir, name);
      expect(document.outerHtml, isNot(contains('null')), reason: name);
    }

    // `pill_badges` was documented and unimplemented: the class was emitted and never selected.
    final pill = await _buildFixture(themeDir, 'long-token', params: {'pill_badges': true});
    expect(pill.querySelector('.eyebrow')!.classes, contains('eyebrow-pill'));
    final square = await _buildFixture(themeDir, 'long-token', params: {'pill_badges': false});
    expect(square.querySelector('.eyebrow')!.classes, isNot(contains('eyebrow-pill')));
    expect(square.querySelector('.kicker'), isNotNull);

    // A site that ships its own /favicon.ico needs the theme to emit no icon link at all.
    final noIcon = await _buildFixture(themeDir, 'copy-short', params: {'favicon': null});
    expect(noIcon.querySelector('link[rel="icon"]'), isNull);
    expect(
      (await _buildFixture(themeDir, 'copy-short')).querySelector('link[rel="icon"]')!.attributes['href'],
      '/favicon.svg',
    );
  });

  test('S06/S07 TI05/TI06 prefix and progressive-enhancement contracts hold', () async {
    final tempDir = Directory.systemTemp.createTempSync('meadow_prefix_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
    Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
    Link(p.join(tempDir.path, 'themes', 'meadow')).createSync(themeDir);
    final source = File(p.join(themeDir, 'example', 'trellis_site.subpath.yaml')).readAsStringSync();
    File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync(source);
    final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
    final result = await TrellisSite(config).build();
    expect(result.warnings, isEmpty);
    final home = File(p.join(config.outputDir, 'index.html')).readAsStringSync();
    expect(home, contains('href="/trellis/css/main.css"'));
    expect(home, contains('src="/trellis/js/meadow.js"'));
    final prefixedAbout = html_parser.parse(File(p.join(config.outputDir, 'about', 'index.html')).readAsStringSync());
    expect(prefixedAbout.querySelector('.desktop-nav a')!.attributes['href'], '/trellis/#features');
    expect(home, isNot(contains('/trellis/trellis/')));

    final base = File(p.join(themeDir, 'layouts', 'base.html')).readAsStringSync();
    final script = File(p.join(themeDir, 'static', 'js', 'meadow.js')).readAsStringSync();
    expect(base, contains("theme.skin} == 'auto'"));
    expect(base, contains('data-meadow-skin-toggle'));
    expect(base, contains('aria-pressed="false" hidden'));
    expect(script, contains("localStorage.setItem('meadow-skin'"));
    expect(script, contains("matchMedia('(prefers-color-scheme: dark)')"));
    expect(script, contains('skinButton.hidden = false'));
    expect(script, contains('copyButton.hidden = false'));
    expect(script, contains('navigator.clipboard'));

    final forced = await _buildFixture(themeDir, 'no-optionals', skin: 'dark');
    expect(forced.querySelector('[data-meadow-skin-toggle]'), isNull);
    expect(forced.head!.text, isNot(contains('localStorage.getItem')));

    // A bare <details> overlay does not close on Escape or on a click elsewhere, and its summary
    // keeps announcing "Open navigation menu" while it is open. Driven against a DOM stub because
    // the assertion is about behaviour, not about the source containing the word "Escape".
    final menu = await _runMenuHarness(p.join(themeDir, 'static', 'js', 'meadow.js'));
    if (menu == null) return;
    expect(menu['initial'], {'open': false, 'label': 'Open navigation menu'});
    expect(menu['opened'], {'open': true, 'label': 'Close navigation menu'});
    expect(menu['otherKey'], {'open': true}, reason: 'only Escape closes it');
    expect(menu['escaped'], {'open': false, 'label': 'Open navigation menu', 'focused': 1});
    expect(menu['insideClick'], {'open': true}, reason: 'a click on the menu itself must not close it');
    expect(menu['outsideClick'], {'open': false, 'label': 'Open navigation menu'});
  });
}

/// Drives `meadow.js` against a DOM stub and reports the mobile menu's state after each step.
Future<Map<String, dynamic>?> _runMenuHarness(String scriptPath) async {
  final tempDir = Directory.systemTemp.createTempSync('meadow_menu_');
  addTearDown(() => tempDir.deleteSync(recursive: true));
  final harness = File(p.join(tempDir.path, 'menu.js'))..writeAsStringSync(_menuHarness);
  try {
    final result = await Process.run('node', [harness.path, scriptPath]);
    expect(result.exitCode, 0, reason: 'menu harness failed: ${result.stderr}');
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  } on ProcessException {
    _requireNodeInCi('the mobile-menu behavioural harness');
    markTestSkipped('system node not found - mobile menu behavioural harness skipped');
    return null;
  }
}

const _menuHarness = r'''
'use strict';
const fs = require('fs');
const vm = require('vm');

function element(tag) {
  const attributes = {};
  const listeners = {};
  return {
    tag,
    focused: 0,
    children: [],
    setAttribute(name, value) { attributes[name] = String(value); },
    getAttribute(name) { return name in attributes ? attributes[name] : null; },
    focus() { this.focused++; },
    addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
    dispatch(type) { (listeners[type] || []).forEach((fn) => fn({})); },
    querySelector() { return null; },
    contains(node) { return node === this || this.children.indexOf(node) !== -1; },
  };
}

const summary = element('summary');
summary.setAttribute('aria-label', 'Open navigation menu');
const menu = element('details');
menu.children.push(summary);
menu.querySelector = (selector) => (selector === 'summary' ? summary : null);
let isOpen = false;
Object.defineProperty(menu, 'open', {
  get() { return isOpen; },
  set(value) { isOpen = !!value; menu.dispatch('toggle'); },
});

const documentListeners = {};
const context = {
  window: { matchMedia: () => ({ matches: false, addEventListener() {} }), isSecureContext: false },
  document: {
    documentElement: { dataset: {} },
    querySelector: (selector) => (selector === '.mobile-menu' ? menu : null),
    getElementById: () => null,
    addEventListener(type, fn) { (documentListeners[type] = documentListeners[type] || []).push(fn); },
  },
  navigator: {},
  localStorage: { getItem: () => null, setItem() {} },
};
context.window.document = context.document;
vm.createContext(context);
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), context, { filename: process.argv[2] });

const fire = (type, event) => (documentListeners[type] || []).forEach((fn) => fn(event));
const label = () => summary.getAttribute('aria-label');
const steps = {};
steps.initial = { open: menu.open, label: label() };
menu.open = true;
steps.opened = { open: menu.open, label: label() };
fire('keydown', { key: 'a' });
steps.otherKey = { open: menu.open };
fire('keydown', { key: 'Escape' });
steps.escaped = { open: menu.open, label: label(), focused: summary.focused };
menu.open = true;
fire('pointerdown', { target: summary });
steps.insideClick = { open: menu.open };
fire('pointerdown', { target: element('main') });
steps.outsideClick = { open: menu.open, label: label() };
process.stdout.write(JSON.stringify(steps));
''';

/// Declarations of the first rule matching [selector], as property -> value.
///
/// Splitting on `;` avoids the prefix traps of matching a declaration with a substring regex:
/// `overflow:` would otherwise match inside `text-overflow:`, and `column` inside `column-reverse`.
Map<String, String> _declarations(String css, String selector) {
  final body = RegExp('${RegExp.escape(selector)}\\s*\\{([^}]*)\\}').firstMatch(css)?.group(1) ?? '';
  return {
    for (final declaration in body.split(';'))
      if (declaration.contains(':'))
        declaration.substring(0, declaration.indexOf(':')).trim(): declaration
            .substring(declaration.indexOf(':') + 1)
            .trim(),
  };
}

int _readUint32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];

Future<Document> _buildFixture(
  String themeDir,
  String fixture, {
  String skin = 'auto',
  Map<String, Object?> params = const {},
}) async {
  final tempDir = Directory.systemTemp.createTempSync('meadow_fixture_');
  final contentDir = Directory(p.join(tempDir.path, 'content'))..createSync(recursive: true);
  File(p.join(themeDir, 'example', 'fixtures', fixture, '_index.md')).copySync(p.join(contentDir.path, '_index.md'));
  Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
  Link(p.join(tempDir.path, 'themes', 'meadow')).createSync(themeDir);
  File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync('''
title: Meadow fixture
description: Meadow fixture
baseUrl: http://localhost:8080
theme: meadow
theme_params:
  skin: $skin
  excerpt_length: 160
${params.entries.map((e) => '  ${e.key}: ${e.value}\n').join()}''');
  final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
  final result = await TrellisSite(config).build();
  expect(result.warnings, isEmpty, reason: fixture);
  final source = File(p.join(config.outputDir, 'index.html')).readAsStringSync();
  tempDir.deleteSync(recursive: true);
  return html_parser.parse(source);
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
