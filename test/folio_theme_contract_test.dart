import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

void main() {
  final themeDir = p.join(Directory.current.path, 'themes', 'folio');

  test('S03/S07 TI01 manifest exposes the Folio contract', () {
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
    const folioParams = {'excerpt_length', 'plate_label', 'show_plate_numbers', 'show_sidenotes'};

    expect(manifest.name, 'folio');
    expect(manifest.features.where({'docs', 'landing', 'blog'}.contains), ['docs']);
    expect(manifest.params.keys.toSet(), standardParams.union(docsParams).union(folioParams));
    expect(manifest.params, isNot(contains('rubric_color')));
    expect(manifest.screenshots, ['screenshots/light.png', 'screenshots/dark.png']);
  });

  test('S03-S05 TI03/TI04 skins and semantic apparatus use one token authority', () {
    String compile(String prelude) {
      final tempDir = Directory.systemTemp.createTempSync('folio_skin_contract_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final wrapper = File(p.join(tempDir.path, 'main.scss'))
        ..writeAsStringSync('$prelude\n@import "${p.join(themeDir, 'sass', 'main.scss')}";\n');
      return TrellisCss.compileSass(wrapper.path, silenceImportDeprecation: true);
    }

    const shared = r'''
$trellis-font-family: Arial, sans-serif;
$trellis-heading-font-family: Georgia, serif;
$trellis-code-font-family: Courier New, monospace;
$trellis-max-width: 900px;
$trellis-border-radius: 7px;
''';
    const lightColors = r'''
$trellis-primary-color: #123456;
$trellis-accent-color: #654321;
$trellis-text-color: #112233;
$trellis-muted-color: #445566;
$trellis-bg-color: #778899;
$trellis-surface-color: #aabbcc;
$trellis-border-color: #ddeeff;
''';
    final light = compile(lightColors + shared);
    final dark = compile(
      '\$trellis-skin: dark;\n'
              '@import "${p.join(themeDir, 'sass', '_skins', '_dark.scss')}";\n' +
          shared,
    );

    for (final css in [light, dark]) {
      expect(css, contains('--folio-body: Arial, sans-serif'));
      expect(css, contains('--folio-serif: Georgia, serif'));
      expect(css, contains('--folio-mono: Courier New, monospace'));
      expect(css, contains('--folio-width: 900px'));
      expect(css, contains('--folio-radius: 7px'));
      expect(css, contains('.folio-plate'));
      expect(css, contains('.folio-sidenote'));
      expect(css, isNot(contains('--folio-serif: "')));
      expect(css, isNot(contains('--folio-width: "')));
    }
    expect(light, contains('.folio-plate::before'));
    expect(light, contains('counter(folio-plates, upper-roman)'));
    for (final token in [
      '--folio-green: #123456',
      '--folio-rubric: #654321',
      '--folio-ink: #112233',
      '--folio-muted: #445566',
      '--folio-paper: #778899',
      '--folio-surface: #aabbcc',
      '--folio-rule: #ddeeff',
    ]) {
      expect(light.toLowerCase(), contains(token));
    }
    expect(dark.toLowerCase(), contains('--folio-paper: #111a14'));
    expect(light, contains('border-radius: var(--folio-radius)'));
    expect(dark, isNot(contains('@media (prefers-color-scheme: dark)')));
    expect(dark, isNot(contains(":root[data-skin='light']")));

    final apparatusOff = compile(r'''
$trellis-show-plate-numbers: false;
$trellis-show-sidenotes: false;
''');
    expect(apparatusOff, isNot(contains('.folio-plate::before')));
    expect(apparatusOff, contains('.folio-sidenote'));
    expect(apparatusOff, contains('display: none'));

    final main = File(p.join(themeDir, 'sass', 'main.scss')).readAsStringSync();
    final darkSkin = File(p.join(themeDir, 'sass', '_skins', '_dark.scss')).readAsStringSync();
    final darkTokens = File(p.join(themeDir, 'sass', '_dark_tokens.scss')).readAsStringSync();
    expect(main, contains('@media (prefers-color-scheme: dark)'));
    expect(main.indexOf('@media (prefers-color-scheme: dark)'), lessThan(main.indexOf(":root[data-skin='light']")));
    final darkValues = RegExp(r'#[0-9a-fA-F]{6}').allMatches(darkTokens).map((match) => match.group(0)!);
    expect(darkValues, isNotEmpty);
    expect(RegExp(r'#[0-9a-fA-F]{6}').hasMatch(darkSkin), isFalse);
    for (final value in darkValues) {
      expect(main.toLowerCase(), isNot(contains(value.toLowerCase())), reason: value);
    }
    expect(darkSkin, contains(r'$folio-dark-paper'));
    expect(main, contains(r'$folio-dark-paper'));
    expect(main, contains('@media (prefers-reduced-motion: reduce)'));
  });

  test('S02-S07 TI02/TI05/TI06/TI07 bridged example builds cleanly', () async {
    final config = SiteConfig.load(p.join(themeDir, 'example', 'trellis_site.yaml'));
    final result = await TrellisSite(config).build();
    expect(result.warnings, isEmpty);
    expect(result.pageCount, greaterThanOrEqualTo(6));

    final bridge = result.themeBuildConfig!;
    final bridgeParams = File(p.join(bridge.buildDir, '_theme_params.scss')).readAsStringSync();
    for (final param in ThemeManifest.load(themeDir).params.keys) {
      expect(bridgeParams, contains('\$trellis-${param.replaceAll('_', '-')}:'), reason: param);
    }
    final tempDir = Directory.systemTemp.createTempSync('folio_sass_contract_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final wrapper = File(p.join(tempDir.path, 'main.scss'))
      ..writeAsStringSync(
        '@import "${p.join(bridge.buildDir, '_theme_params.scss')}";\n'
        '@import "${p.join(themeDir, 'sass', 'main.scss')}";\n',
      );
    final css = TrellisCss.compileSass(wrapper.path, loadPaths: bridge.sassLoadPaths, silenceImportDeprecation: true);
    final cssFile = File(p.join(config.outputDir, 'css', 'main.css'))..parent.createSync(recursive: true);
    cssFile.writeAsStringSync(css);
    expect(css, isNot(contains('--folio-serif: "')));
    expect(css, isNot(contains('--folio-width: "')));
    expect(css, contains('counter-increment: folio-plates'));
    expect(RegExp(r'\.docs-shell > \.docs-toc\s*\{\s*display: none;').hasMatch(css), isTrue);
    expect(css, contains('.hero-actions span + span a'));
    expect(css, contains('.search-shell.search-unavailable'));
    expect(css, contains('min-block-size: 44px'));

    final htmlFiles = Directory(
      config.outputDir,
    ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.html'));
    for (final file in htmlFiles) {
      final source = file.readAsStringSync();
      final document = html_parser.parse(source);
      expect(document.querySelector('body')!.children.first.classes, contains('skip-to-content'), reason: file.path);
      expect(document.querySelector('main'), isNotNull, reason: file.path);
      expect(document.querySelector('footer'), isNotNull, reason: file.path);
      if (file.path.endsWith('heading-less/index.html')) {
        expect(document.body!.text, isNot(contains(r'${')), reason: file.path);
        expect(document.querySelector('.docs-toc'), isNull, reason: file.path);
      }
      expect(
        document.querySelectorAll('*').expand((e) => e.attributes.keys).any((a) => '$a'.startsWith('tl:')),
        isFalse,
      );
    }
    final apparatus = html_parser.parse(
      File(p.join(config.outputDir, 'docs', 'apparatus', 'index.html')).readAsStringSync(),
    );
    expect(apparatus.querySelectorAll('figure.folio-plate'), hasLength(2));
    expect(apparatus.querySelectorAll('figure.folio-plate figcaption'), hasLength(1));
    expect(apparatus.querySelector('aside.folio-sidenote'), isNotNull);
    expect(apparatus.querySelector('.sidebar-title')!.text, 'Contents');
    expect(apparatus.querySelector('.toc-title')!.text, 'Field index');
    expect(apparatus.querySelector('.search-shell'), isNotNull);
    expect(apparatus.querySelector('.page-nav'), isNotNull);

    final home = html_parser.parse(File(p.join(config.outputDir, 'index.html')).readAsStringSync());
    expect(home.querySelectorAll('.hero-actions a').map((link) => link.text.trim()), ['Home', 'Entries']);
    expect(home.querySelector('.social-links')!.text, contains('Source'));
    expect(home.querySelector('.footer-text')!.text, contains('Observations arranged with Folio'));
    expect(home.querySelector('.footer-powered-by'), isNotNull);
    expect(home.querySelectorAll('link[rel="alternate"]'), hasLength(2));
  });

  test('S02 TI07 prefixed build joins same-origin assets exactly once', () async {
    final tempDir = Directory.systemTemp.createTempSync('folio_prefix_contract_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
    Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
    Link(p.join(tempDir.path, 'themes', 'folio')).createSync(themeDir);
    final source = File(p.join(themeDir, 'example', 'trellis_site.yaml')).readAsStringSync();
    File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync('$source\npathPrefix: /trellis/\n');

    final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
    final result = await TrellisSite(config).build();
    expect(result.warnings, isEmpty);
    final home = File(p.join(config.outputDir, 'index.html')).readAsStringSync();
    expect(home, contains('href="/trellis/css/main.css"'));
    expect(home, contains('src="/trellis/js/folio.js"'));
    expect(home, contains('href="/trellis/"'));
    expect(home, contains('href="/trellis/docs/"'));
    expect(home, isNot(contains('/trellis/trellis/')));
    final document = html_parser.parse(home);
    final rootRelativeLinks = document
        .querySelectorAll('a[href]')
        .map((link) => link.attributes['href']!)
        .where((href) => href.startsWith('/'));
    expect(rootRelativeLinks, everyElement(startsWith('/trellis/')));

    final docs = File(p.join(config.outputDir, 'docs', 'apparatus', 'index.html')).readAsStringSync();
    final docsDocument = html_parser.parse(docs);
    expect(docs, contains('src="/trellis/js/search.js"'));
    expect(docs, contains('src="/trellis/js/folio.js"'));
    expect(docs, contains('data-search-index="/trellis/search-index.json"'));
    expect(docs, contains('href="/trellis/css/main.css"'));
    final docsRootUrls = docsDocument
        .querySelectorAll('[href], [src]')
        .expand((element) => [element.attributes['href'], element.attributes['src']])
        .whereType<String>()
        .where((url) => url.startsWith('/'));
    expect(docsRootUrls, everyElement(startsWith('/trellis/')));
    for (final asset in ['search-index.json', 'fonts/eb-garamond-latin.woff2', 'fonts/ibm-plex-mono-latin.woff2']) {
      expect(File(p.join(config.outputDir, asset)).existsSync(), isTrue, reason: asset);
    }
  });

  test('S03/S06 TI07 template controls remove their regions', () async {
    final tempDir = Directory.systemTemp.createTempSync('folio_controls_contract_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
    Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
    Link(p.join(tempDir.path, 'themes', 'folio')).createSync(themeDir);
    var source = File(p.join(themeDir, 'example', 'trellis_site.yaml')).readAsStringSync();
    source = source
        .replaceFirst(
          'social_links: [{platform: GitHub, label: Source, url: https://github.com/tolo/trellis}]',
          'social_links: []',
        )
        .replaceFirst('footer_text: "Observations arranged with Folio"', 'footer_text: null');
    for (final control in ['powered_by', 'rss_link', 'sidebar', 'toc', 'prev_next', 'search']) {
      source = source.replaceFirst('  show_$control: true', '  show_$control: false');
    }
    File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync(source);

    final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
    final result = await TrellisSite(config).build();
    expect(result.warnings, isEmpty);
    final docs = html_parser.parse(
      File(p.join(config.outputDir, 'docs', 'apparatus', 'index.html')).readAsStringSync(),
    );
    expect(docs.querySelector('.sidebar-disclosure'), isNull);
    expect(docs.querySelector('.docs-toc'), isNull);
    expect(docs.querySelector('.page-nav'), isNull);
    expect(docs.querySelector('.search-shell'), isNull);
    expect(docs.querySelector('script[src*="search.js"]'), isNull);
    expect(docs.querySelector('.social-links'), isNull);
    expect(docs.querySelector('.footer-text'), isNull);
    expect(docs.querySelector('.footer-powered-by'), isNull);
    expect(docs.querySelector('link[rel="alternate"]'), isNull);
  });

  test('S05 TI07 forced skin omits auto-only scripts and controls', () async {
    final tempDir = Directory.systemTemp.createTempSync('folio_forced_skin_contract_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
    Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
    Link(p.join(tempDir.path, 'themes', 'folio')).createSync(themeDir);
    final source = File(p.join(themeDir, 'example', 'trellis_site.yaml')).readAsStringSync();
    File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync(source.replaceFirst('skin: auto', 'skin: dark'));

    final config = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
    final result = await TrellisSite(config).build();
    expect(result.warnings, isEmpty);
    final home = File(p.join(config.outputDir, 'index.html')).readAsStringSync();
    expect(home, isNot(contains('data-folio-skin-toggle')));
    expect(home, isNot(contains('js/folio.js')));
    expect(home, isNot(contains("localStorage.getItem('folio-skin')")));

    final bridge = result.themeBuildConfig!;
    final wrapper = File(p.join(tempDir.path, 'forced-dark.scss'))
      ..writeAsStringSync(
        '@import "${p.join(themeDir, 'sass', '_skins', '_dark.scss')}";\n'
        '@import "${p.join(bridge.buildDir, '_theme_params.scss')}";\n'
        '@import "${p.join(themeDir, 'sass', 'main.scss')}";\n',
      );
    final css = TrellisCss.compileSass(wrapper.path, loadPaths: bridge.sassLoadPaths, silenceImportDeprecation: true);
    expect(css, contains('--folio-paper: #111a14'));
    expect(css, isNot(contains('@media (prefers-color-scheme: dark)')));
    expect(css, isNot(contains(":root[data-skin='dark']")));

    final skinScript = File(p.join(themeDir, 'static', 'js', 'folio.js')).readAsStringSync();
    expect(skinScript.indexOf('sync()'), lessThan(skinScript.indexOf("button.addEventListener('click'")));
    expect(skinScript, contains("media.matches ? 'dark' : 'light'"));
  });

  test('S05/TI05 auto skin control follows OS only without a stored choice', () async {
    final result = await _runNodeHarness('folio', p.join(themeDir, 'static', 'js', 'folio.js'));
    if (result == null) return;

    final osDark = result['osDark']! as Map<String, dynamic>;
    expect(osDark['initial'], {'skin': '', 'pressed': 'true'});
    expect(osDark['afterMediaChange'], {'skin': '', 'pressed': 'false'});
    expect(osDark['persisted'], isEmpty);

    final storedLight = result['storedLight']! as Map<String, dynamic>;
    expect(storedLight['initial'], {'skin': 'light', 'pressed': 'false'});
    expect(storedLight['afterMediaChange'], {'skin': 'light', 'pressed': 'false'});
    expect(storedLight['persisted'], isEmpty);

    final storedDark = result['storedDark']! as Map<String, dynamic>;
    expect(storedDark['initial'], {'skin': 'dark', 'pressed': 'true'});
    expect(storedDark['afterMediaChange'], {'skin': 'dark', 'pressed': 'true'});
    expect(storedDark['persisted'], isEmpty);

    final click = result['click']! as Map<String, dynamic>;
    expect(click['skin'], 'dark');
    expect(click['pressed'], 'true');
    expect(click['persisted'], [
      {'key': 'folio-skin', 'value': 'dark'},
    ]);

    final failedLight = result['failedLight']! as Map<String, dynamic>;
    expect(failedLight['initial'], {'skin': '', 'pressed': 'true'});
    expect(failedLight['click'], {'skin': 'light', 'pressed': 'false', 'persisted': []});
    expect(failedLight['afterOsLight'], {'skin': 'light', 'pressed': 'false'});
    expect(failedLight['afterOsDark'], {'skin': 'light', 'pressed': 'false'});
    expect(failedLight['persisted'], isEmpty);

    final failedDark = result['failedDark']! as Map<String, dynamic>;
    expect(failedDark['initial'], {'skin': '', 'pressed': 'false'});
    expect(failedDark['click'], {'skin': 'dark', 'pressed': 'true', 'persisted': []});
    expect(failedDark['afterOsDark'], {'skin': 'dark', 'pressed': 'true'});
    expect(failedDark['afterOsLight'], {'skin': 'dark', 'pressed': 'true'});
    expect(failedDark['persisted'], isEmpty);
  });

  test('S07 TI08 publishability collateral and local assets are complete', () {
    final manifest = ThemeManifest.load(themeDir);
    final readme = File(p.join(themeDir, 'README.md')).readAsStringSync();
    for (final param in manifest.params.keys) {
      expect(readme, contains('`$param`'), reason: param);
    }
    for (final asset in [
      'static/js/folio.js',
      'static/js/search.js',
      'static/fonts/eb-garamond-latin.woff2',
      'static/fonts/ibm-plex-mono-latin.woff2',
      'static/fonts/OFL-EB-Garamond.txt',
      'static/fonts/OFL-IBM-Plex-Mono.txt',
      'screenshots/light.png',
      'screenshots/dark.png',
    ]) {
      expect(File(p.join(themeDir, asset)).existsSync(), isTrue, reason: asset);
    }
    for (final screenshot in ['screenshots/light.png', 'screenshots/dark.png']) {
      final bytes = File(p.join(themeDir, screenshot)).readAsBytesSync();
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10], reason: screenshot);
      expect(_readUint32(bytes, 16), 1280, reason: screenshot);
      expect(_readUint32(bytes, 20), 800, reason: screenshot);
    }
    expect(readme, contains('<figure class="folio-plate">'));
    expect(readme, contains('<aside class="folio-sidenote">'));
    expect(
      File(p.join(themeDir, 'static', 'fonts', 'OFL-EB-Garamond.txt')).readAsStringSync(),
      contains('EB Garamond'),
    );
    expect(File(p.join(themeDir, 'static', 'fonts', 'OFL-IBM-Plex-Mono.txt')).readAsStringSync(), contains('IBM'));
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
