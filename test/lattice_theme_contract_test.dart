import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

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
    expect(
      terminal.map((dynamic line) => (line as Map<String, dynamic>)['text']),
      contains(contains('trellis create')),
    );
    expect(
      terminal.map((dynamic line) => (line as Map<String, dynamic>)['text']),
      everyElement(isNot(contains('trellis new'))),
    );
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
    expect(styles, contains('h1.fit-initial'));
    expect(styles, contains('overflow: hidden'));
    expect(home, contains('class="fit-initial" data-headline'));
    expect(styles, contains('@media (min-width: 1180px)'));
    expect(styles, contains('@media (max-width: 1199px)'));
    expect(styles, contains('@media (max-width: 900px)'));
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
    expect(home, contains('src="/trellis/showcase/arbor-light.svg"'));
    expect(home, contains('data-dark="/trellis/showcase/arbor-dark.svg"'));
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

    final canonicalLogo = File(p.join(Directory.current.path, 'assets', 'logo-with-text.png')).readAsBytesSync();
    final themeLogo = File(p.join(themeDir, 'static', 'trellis-logo.png')).readAsBytesSync();
    expect(themeLogo, canonicalLogo, reason: 'the Trellis site must use the canonical wordmark bytes');

    final mark = File(p.join(themeDir, 'static', 'trellis-mark.png')).readAsBytesSync();
    expect(mark.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(_readUint32(mark, 16), _readUint32(mark, 20), reason: 'the Trellis favicon crop must be square');
    for (final screenshot in ['screenshots/light.png', 'screenshots/dark.png']) {
      final bytes = File(p.join(themeDir, screenshot)).readAsBytesSync();
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10], reason: screenshot);
      expect(_readUint32(bytes, 16), 1280, reason: screenshot);
      expect(_readUint32(bytes, 20), 800, reason: screenshot);
    }

    final siteConfig = File(p.join(Directory.current.path, 'site', 'trellis_site.yaml')).readAsStringSync();
    expect(siteConfig, contains('logo: trellis-logo.png'));
    expect(siteConfig, contains('favicon: trellis-mark.png'));

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
