import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';
import 'package:yaml/yaml.dart';

void main() {
  final root = Directory.current.path;

  test('S01/TI01 site config selects Lattice with the complete settled headline contract', () {
    final configPath = p.join(root, 'site', 'trellis_site.yaml');
    final config = SiteConfig.load(configPath);
    final source = loadYaml(File(configPath).readAsStringSync()) as YamlMap;
    final params = source['theme_params'] as YamlMap;

    expect(config.baseUrl, 'https://tolo.github.io');
    expect(config.pathPrefix, '/trellis/');
    expect(source['theme'], '../../themes/lattice');
    expect((source['search'] as YamlMap)['enabled'], isTrue);
    expect(params.keys, containsAll(<String>['skin', 'hero_headlines', 'terminal_card_lines', 'show_demo']));
    for (final headline in params['hero_headlines'] as YamlList) {
      final map = headline as YamlMap;
      expect(map.keys.toSet(), <Object>{'prefix', 'emphasis', 'suffix'});
      expect(map.values, everyElement(isA<String>()));
    }
  });

  test('S01/TI02 site owns the complete Lattice data shape and gallery route', () {
    final data = loadYaml(File(p.join(root, 'site', 'data', 'lattice.yaml')).readAsStringSync()) as YamlMap;
    expect(data.keys.toSet(), <Object>{'code_showcase', 'why', 'demo', 'showcase'});

    // The showcase deliberately curates three of the six themes (Meadow is
    // omitted by choice), so the count is not derived from themes.yaml. What
    // must hold is that every field of a card names the *same* theme: a card is
    // a name, a config line, alt text and two screenshots, and swapping any one
    // of them for another theme's ships a mislabelled card that renders fine.
    final generated = loadYaml(File(p.join(root, 'site', 'data', 'themes.yaml')).readAsStringSync()) as YamlMap;
    final installed = {for (final item in generated['themes'] as YamlList) (item as YamlMap)['name'] as String};
    final cards = (data['showcase'] as YamlMap)['cards'] as YamlList;
    expect(cards, hasLength(3));
    final slugs = <String>[];
    for (final item in cards) {
      final card = item as YamlMap;
      final config = card['config'] as String;
      expect(config, matches(RegExp(r'^theme: [a-z0-9][a-z0-9_-]*$')), reason: '${card['name']}');
      final slug = config.substring('theme: '.length);
      slugs.add(slug);
      expect(installed, contains(slug), reason: 'showcase card "$config" is not an installed theme');
      expect((card['name'] as String).toLowerCase(), slug, reason: config);
      expect(card['alt'], startsWith(card['name'] as String), reason: config);
      for (final variant in <String>['light', 'dark']) {
        final declared = card['screenshot_$variant'] as String;
        expect(declared, 'themes/$slug/$variant.png', reason: config);
        expect(File(p.join(root, 'site', 'static', declared)).existsSync(), isTrue, reason: declared);
      }
    }
    expect(slugs.toSet(), hasLength(slugs.length), reason: 'a theme is showcased twice: $slugs');

    final home = File(p.join(root, 'site', 'content', '_index.md')).readAsStringSync();
    expect(home, contains('layout: home'));
    expect(home, isNot(contains('Modern web apps in pure Dart')));

    final themesIndex = File(p.join(root, 'site', 'content', 'docs', 'themes', '_index.md')).readAsStringSync();
    expect(themesIndex, contains('/docs/themes/gallery/'));
    expect(File(p.join(root, 'site', 'content', 'docs', 'themes', 'gallery.md')).existsSync(), isTrue);
  });

  test('S04/TI04 both workflows gate generated gallery freshness after dependencies and before builds', () {
    for (final relative in <String>['.github/workflows/ci.yml', '.github/workflows/deploy-docs-site.yml']) {
      final workflow = File(p.join(root, relative)).readAsStringSync();
      final dependencies = workflow.indexOf('dart pub get');
      final freshness = workflow.indexOf('dart run tool/generate_theme_gallery.dart --check');
      final firstBuild = relative.endsWith('ci.yml')
          ? workflow.indexOf('- name: Root workspace tests')
          : workflow.indexOf('- name: Build site (production, sub-path)');
      expect(freshness, greaterThan(dependencies), reason: relative);
      expect(firstBuild, greaterThan(freshness), reason: relative);
    }
  });

  test('S04/S06 gallery layout is site-local, conditional, prefix-safe, and count-neutral', () {
    final source = File(p.join(root, 'site', 'layouts', 'gallery.html')).readAsStringSync();
    final document = html_parser.parse(source);
    expect(source, contains('theme:layouts/base.html'));
    expect(source, contains("assetBase=\${site.pathPrefix} == '' ? '/' : \${site.pathPrefix}"));
    expect(source, contains('tl:if="\${themeItem.screenshot_light}"'));
    expect(source, contains('tl:if="\${themeItem.screenshot_dark}"'));
    expect(source, contains("\${assetBase} + \${themeItem.screenshot_light}"));
    expect(document.querySelectorAll('[tl\\:each="themeItem : \${data.themes.themes}"]'), hasLength(1));
    expect(source, isNot(matches(RegExp(r'\b(three|six|total) themes\b', caseSensitive: false))));
  });

  // Two full builds and two link checks can exceed package:test's 30-second default under parallel CI load.
  test('S01-S04/TI02/TI05-TI07 bridged root and sub-path builds preserve the complete site', () async {
    final tempDir = Directory.systemTemp.createTempSync('site_migration_build_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final cli = p.join(root, 'packages', 'trellis_cli', 'bin', 'trellis.dart');
    final linkCheck = p.join(root, 'tool', 'link_check.dart');
    final siteDir = p.join(root, 'site');

    for (final (label, prefix) in <(String, String)>[('root', ''), ('subpath', '/trellis/')]) {
      final outputDir = p.join(tempDir.path, label);
      final build = await Process.run('dart', <String>[
        'run',
        cli,
        'build',
        '--path-prefix',
        prefix,
        '--output',
        outputDir,
      ], workingDirectory: siteDir);
      expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
      expect('${build.stdout}${build.stderr}', isNot(contains('warning')));

      final linkArgs = <String>[
        'run',
        linkCheck,
        outputDir,
        if (prefix.isNotEmpty) ...['--base-path', prefix],
      ];
      final links = await Process.run('dart', linkArgs, workingDirectory: root);
      expect(links.exitCode, 0, reason: '${links.stdout}${links.stderr}');
      expect(links.stdout, contains('0 broken'));
      expect(Directory(p.join(outputDir, 'trellis')).existsSync(), isFalse);

      final home = File(p.join(outputDir, 'index.html')).readAsStringSync();
      final expectedOrder = <String>[
        'Open it in a browser. Then render it.',
        'Why Trellis',
        'One file, two views',
        'Built-in themes, grown in the same garden',
        'All themes →',
        'One dependency away',
      ];
      var prior = -1;
      for (final text in expectedOrder) {
        final position = home.indexOf(text);
        expect(position, greaterThan(prior), reason: '$label: $text');
        prior = position;
      }
      final homeDocument = html_parser.parse(home);
      final directiveAttributes = homeDocument
          .querySelectorAll('*')
          .expand((element) => element.attributes.keys)
          .where((name) => name.toString().startsWith('tl:'));
      expect(directiveAttributes, isEmpty);
      expect(home, isNot(contains('Lattice preview')));
      expect(home, contains('aria-pressed="true"'));
      expect(homeDocument.querySelector('main#main-content')!.attributes['tabindex'], '-1');
      expect(homeDocument.querySelector('.home-content'), isNull);
      final galleryHref = prefix.isEmpty ? '/docs/themes/gallery/' : '${prefix}docs/themes/gallery/';
      expect(homeDocument.querySelector('.showcase-link a')!.attributes['href'], galleryHref);
      expect(homeDocument.querySelector('[data-demo-panel="rendered"]')!.attributes, contains('hidden'));

      final docs = File(p.join(outputDir, 'docs', 'syntax', 'expressions', 'index.html')).readAsStringSync();
      expect(docs, allOf(contains('docs-sidebar'), contains('docs-toc'), contains('data-lattice-search')));
      expect(docs, contains('page-nav'));
      expect(docs, contains('hljs-'));
      final css = File(p.join(outputDir, 'css', 'main.css')).readAsStringSync();
      expect(css, allOf(contains('.prose :not(pre)>code'), contains('overflow-wrap:anywhere')));
      expect(css, allOf(contains('.prose table'), contains('table-layout:fixed')));
      expect(css, allOf(contains('.prose pre'), contains('white-space:pre-wrap')));

      final gallery = html_parser.parse(
        File(p.join(outputDir, 'docs', 'themes', 'gallery', 'index.html')).readAsStringSync(),
      );
      final generatedData = loadYaml(File(p.join(root, 'site', 'data', 'themes.yaml')).readAsStringSync()) as YamlMap;
      final generatedThemes = generatedData['themes'] as YamlList;
      final expectedImages = generatedThemes.fold<int>(0, (count, item) {
        final theme = item as YamlMap;
        return count + (theme.containsKey('screenshot_light') ? 1 : 0) + (theme.containsKey('screenshot_dark') ? 1 : 0);
      });
      expect(gallery.querySelectorAll('.gallery-card'), hasLength(generatedThemes.length));
      expect(gallery.querySelectorAll('.gallery-card img'), hasLength(expectedImages));
      final assetPrefix = prefix.isEmpty ? '/' : prefix;
      for (final image in gallery.querySelectorAll('.gallery-card img')) {
        final source = image.attributes['src']!;
        expect(source, startsWith('${assetPrefix}themes/'));
        expect(source, isNot(contains('//themes/')));
      }
      expect(gallery.querySelector('link[href="${assetPrefix}gallery.css"]'), isNotNull);
      final previous = gallery.querySelector('.page-nav a');
      expect(previous, isNotNull);
      expect(previous!.text, allOf(contains('Previous'), contains('Theme Authoring')));
      expect(previous.attributes['href'], '${assetPrefix}docs/themes/authoring/');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
