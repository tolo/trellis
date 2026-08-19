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
    expect(manifest.screenshots, ['screenshots/light.png', 'screenshots/dark.png']);

    final headlines = manifest.params['hero_headlines']!.defaultValue as List<dynamic>;
    for (final dynamic headline in headlines) {
      expect((headline as Map<String, dynamic>).keys.toSet(), {'prefix', 'emphasis', 'suffix'});
      expect(headline.values, everyElement(isA<String>()));
    }
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
    expect(dark, contains('--syntax-keyword: #c792ea'));
  });

  test('S04-S06/TI06 progressive enhancement avoids innerHTML and obeys reduced motion', () {
    final script = File(p.join(themeDir, 'static', 'js', 'lattice.js')).readAsStringSync();
    final styles = File(p.join(themeDir, 'sass', 'main.scss')).readAsStringSync();
    expect(script, isNot(contains('innerHTML')));
    expect(script, contains("matchMedia('(prefers-reduced-motion: reduce)')"));
    expect(script, contains('document.createTextNode'));
    expect(script, contains('localStorage.setItem'));
    expect(script, contains('document.hidden'));
    expect(styles, contains('@media (max-width: 1180px)'));
    expect(styles, contains('@media (max-width: 900px)'));
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
    expect(home, contains('src="/trellis/showcase/arbor-light.svg"'));
    expect(home, contains('data-dark="/trellis/showcase/arbor-dark.svg"'));
    expect(home, contains('src="/trellis/js/lattice.js"'));
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
      'screenshots/light.png',
      'screenshots/dark.png',
    ]) {
      expect(File(p.join(themeDir, asset)).existsSync(), isTrue, reason: asset);
    }

    final manifest = ThemeManifest.load(themeDir);
    final readme = File(p.join(themeDir, 'README.md')).readAsStringSync();
    for (final param in manifest.params.keys) {
      expect(readme, contains('`$param`'), reason: param);
    }
    expect(File(p.join(themeDir, 'VENDORED.md')).readAsStringSync(), contains('static/favicon.svg'));

    final base = File(p.join(themeDir, 'layouts', 'base.html')).readAsStringSync();
    final list = File(p.join(themeDir, 'layouts', '_default', 'list.html')).readAsStringSync();
    expect(base, contains(r'${#lists.size(theme.social_links)} > 0'));
    expect(list, contains(r'${#lists.size(pages)} > 0'));
    expect(list, contains(r'${#lists.size(pages)} == 0'));
  });
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
