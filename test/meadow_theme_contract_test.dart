import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

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
    // Font payload ships to every deployed site, so it is budgeted. Bricolage keeps opsz because
    // optical sizing moves it at display sizes; the rest are wght-only. The unused axes cost 86KB.
    final fontBytes = Directory(p.join(themeDir, 'static', 'fonts'))
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.woff2'))
        .fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(fontBytes, lessThanOrEqualTo(160 * 1024), reason: '$fontBytes bytes');

    for (final screenshot in manifest.screenshots) {
      final bytes = File(p.join(themeDir, screenshot)).readAsBytesSync();
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10], reason: screenshot);
      expect(_readUint32(bytes, 16), 1280, reason: screenshot);
      expect(_readUint32(bytes, 20), 800, reason: screenshot);
    }
    expect(File(p.join(themeDir, 'example', '.gitignore')).readAsStringSync(), contains('output/'));
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
    // One rotated marker drives both skins; dark widens its inset instead of swapping in a flat block.
    expect(RegExp(r'\.marker::before\s*\{[^}]*inset: 54% -0\.08em 0\.02em').hasMatch(light), isTrue);
    expect(light, contains('rotate(-1.7deg)'));
    expect(RegExp(r'\.marker::before\s*\{[^}]*inset: -0\.02em -0\.1em -0\.05em').hasMatch(dark), isTrue);
    expect(RegExp(r'\.marker::before\s*\{[^}]*display: none').hasMatch(dark), isFalse);
    // The header CTA has no room beside the burger, so it leaves with the desktop nav.
    expect(RegExp(r'\.desktop-nav, \.nav-cta\s*\{\s*display: none;').hasMatch(light), isTrue);
    // `anywhere` broke the brand and menu labels mid-word; only the terminal command still needs it.
    expect(RegExp(r'^body \{[^}]*overflow-wrap: break-word', multiLine: true).hasMatch(light), isTrue);
    expect(RegExp(r'^body \{[^}]*overflow-wrap: anywhere', multiLine: true).hasMatch(light), isFalse);
    // Tilt stays gentle and the title takes the slack, so all three card titles share a baseline.
    expect(RegExp(r'\.template-card-inner\s*\{[^}]*flex-direction: column').hasMatch(light), isTrue);
    expect(RegExp(r'\.template-card h3\s*\{[^}]*margin: auto 0 8px').hasMatch(light), isTrue);
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
  });
}

int _readUint32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];

Future<Document> _buildFixture(String themeDir, String fixture, {String skin = 'auto'}) async {
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
''');
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
