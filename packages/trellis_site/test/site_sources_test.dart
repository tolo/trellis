import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis/trellis.dart' show MapLoader, TemplateNotFoundException;
import 'package:trellis_site/trellis_site.dart' hide TemplateNotFoundException;

void main() {
  late Directory root;

  File write(String path, String contents) => File(p.join(root.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);

  SiteConfig siteConfig([String yaml = '']) => SiteConfig.load(write('trellis_site.yaml', yaml).path);

  ThemeManifest themeManifest([String yaml = '']) {
    final file = write('themes/sample/theme.yaml', 'name: sample\nversion: 1.0.0\n$yaml');
    return ThemeManifest.load(file.parent.path);
  }

  const invocation = """<i tl:replace="~{acme/badge :: badge('new')}">Template placeholder</i>""";
  const badge = r'<b tl:fragment="badge(label)" tl:text="${label}">Badge placeholder</b>';
  const css = [0, 127, 255];
  const assetPath = 'acme/badge.css';
  SiteSource source({String path = assetPath}) =>
      SiteSource(loader: MapLoader({'acme/badge': badge}), assets: {path: css});
  File output(String path) => File(p.join(root.path, 'output', path));
  String builtPage() => output('sample/index.html').readAsStringSync();

  void fixture({bool themed = false, bool useFragment = true}) {
    write('content/sample.md', '# Sample\n\n<!-- tl:badge -->\n');
    write('layouts/shortcodes/badge.html', '<section>$invocation</section>');
    write(
      themed ? 'themes/sample/layouts/_default/single.html' : 'layouts/_default/single.html',
      '<html><head><link rel="stylesheet" href="/$assetPath">'
      '${themed ? '<link rel="stylesheet" href="/css/theme-props.css">' : ''}</head>'
      '<body><header>${useFragment ? invocation : 'Plain layout'}</header>'
      '<main tl:utext="\${page.content}"></main></body></html>',
    );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('trellis_site_sources_');
    addTearDown(() => root.deleteSync(recursive: true));
  });

  test('uses parses from site config and theme manifest and rejects other shapes', () {
    const names = 'uses: [acme, example_2]';
    expect(siteConfig(names).uses, ['acme', 'example_2']);
    expect(themeManifest(names).uses, ['acme', 'example_2']);
    expect(siteConfig().uses, isEmpty);
    expect(themeManifest().uses, isEmpty);
    expect(siteConfig('uses: []').uses, isEmpty);
    expect(themeManifest('uses: []').uses, isEmpty);

    for (final value in ['acme', '[[acme]]', '[Bad-Name]', '[123]', '[null]', 'null']) {
      expect(
        () => siteConfig('uses: $value'),
        throwsA(
          isA<SiteConfigException>().having((e) => e.message, 'message', allOf(contains('uses'), contains('list'))),
        ),
        reason: value,
      );
      expect(
        () => themeManifest('uses: $value'),
        throwsA(
          isA<ThemeManifestException>().having((e) => e.message, 'message', allOf(contains('uses'), contains('list'))),
        ),
        reason: value,
      );
    }
  });

  test('a named source reaches layouts, shortcodes and the output', () async {
    fixture();
    final result = await TrellisSite(siteConfig('uses: [acme]'), sourceFactories: {'acme': source}).build();
    expect(builtPage(), contains('<header><b>new</b></header>'));
    expect(builtPage(), contains('<section><b>new</b></section>'));
    expect(output(assetPath).readAsBytesSync(), css);
    expect(result.warnings, isEmpty);
    expect(result.staticFileCount, 1);
  });

  test('post-Markdown shortcodes can pass structured page data to a source', () async {
    fixture();
    write('content/sample.md', '''
---
options:
  - label: In development
    status: draft
  - label: Public
    status: live
status: ignored
---
<!-- tl:badge status="live" -->
''');
    write(
      'layouts/shortcodes/badge.html',
      r'<tl:block tl:each="option : ${options}"><span tl:if="${option.status == status}">'
          r'<i tl:replace="~{acme/badge :: badge(${option.label})}"></i></span></tl:block>',
    );
    final result = await TrellisSite(siteConfig('uses: [acme]'), sourceFactories: {'acme': source}).build();
    expect(builtPage(), contains('<b>Public</b>'));
    expect(builtPage(), isNot(contains('In development')));
    expect(result.warnings, isEmpty);
  });

  test('site and theme naming one source write its asset once', () async {
    fixture(themed: true);
    for (final (siteUses, themeUses) in [(false, true), (true, false), (true, true)]) {
      themeManifest(themeUses ? 'uses: [acme]' : '');
      final config = siteConfig('theme: sample\n${siteUses ? 'uses: [acme, acme]' : ''}');
      var calls = 0;
      final result = await TrellisSite(
        config,
        sourceFactories: {
          'acme': () {
            calls++;
            return source();
          },
        },
      ).build();
      expect(calls, 1);
      expect(result.staticFileCount, 2); // The source asset plus the theme custom properties.
      expect(result.warnings, isEmpty);
      expect(output(assetPath).readAsBytesSync(), css);
      expect(builtPage(), contains('<header><b>new</b></header>'));
      expect(builtPage(), contains('<section><b>new</b></section>'));
    }
  });

  test('a source nobody names is never built and changes nothing', () async {
    fixture(useFragment: false);
    write('content/sample.md', '# Sample\n');
    write('static/one.txt', 'Unrelated static file');
    final config = siteConfig();
    Map<String, List<int>> outputFiles() => {
      for (final file in Directory(config.outputDir).listSync(recursive: true).whereType<File>())
        p.relative(file.path, from: config.outputDir): file.readAsBytesSync(),
    };
    await TrellisSite(config).build();
    final baseline = outputFiles();
    final site = TrellisSite(config, sourceFactories: {'acme': () => throw StateError('An unused factory ran')});
    await site.build();
    expect(outputFiles(), baseline);
    expect(Directory(p.join(config.outputDir, 'acme')).existsSync(), isFalse);

    fixture();
    await expectLater(site.build(), throwsA(isA<TemplateNotFoundException>()));
    expect(Directory(config.outputDir).existsSync(), isFalse);
  });

  test('bad names and paths fail the build and leave no output', () async {
    fixture();
    final outputDir = Directory(p.join(root.path, 'output'));
    final cases = [
      ('[acme, nope]', assetPath, ['uses', 'nope', 'acme', 'other']),
      ('[acme, other]', assetPath, ['acme', 'other', assetPath]),
      for (final uses in ['[acme, other]', '[other, acme]'])
        (uses, 'acme', ['Source "acme"', '"acme"', 'source "other"', '"$assetPath"']),
      for (final path in ['../escape.txt', '/abs.txt', r'..\escape.txt', r'C:\abs.txt', './ambiguous.css', 'a//b'])
        ('[acme]', path, ['acme', path]),
    ];
    for (final (uses, path, details) in cases) {
      final site = TrellisSite(
        siteConfig('uses: $uses'),
        sourceFactories: {
          'acme': uses.contains('nope') ? () => throw StateError('Validate all names first') : () => source(path: path),
          'other': source,
        },
      );
      await expectLater(
        site.build(),
        throwsA(isA<SiteConfigException>().having((e) => e.message, 'message', allOf(details.map(contains).toList()))),
        reason: '$uses, $path',
      );
      expect(outputDir.existsSync(), isFalse);
      expect(File(p.join(root.path, 'escape.txt')).existsSync(), isFalse);
    }

    expect(() => siteConfig('uses: acme'), throwsA(isA<SiteConfigException>()));
    expect(outputDir.existsSync(), isFalse);
  });

  test('site and theme win over a source', () async {
    fixture(themed: true);
    themeManifest();
    write('themes/sample/acme/badge.html', '<b tl:fragment="badge(label)">Theme badge</b>');
    write('themes/sample/static/$assetPath', 'theme CSS');
    final site = TrellisSite(siteConfig('theme: sample\nuses: [acme]'), sourceFactories: {'acme': source});

    final themeOnly = await site.build();
    expect(builtPage(), contains('<header><b>Theme badge</b></header>'));
    expect(builtPage(), contains('<section><b>Theme badge</b></section>'));
    expect(output(assetPath).readAsStringSync(), 'theme CSS');
    expect(themeOnly.staticFileCount, 3);

    write('acme/badge.html', '<strong tl:fragment="badge(label)">Site badge</strong>');
    write('static/$assetPath', 'site CSS');
    final siteAndTheme = await site.build();
    expect(builtPage(), contains('<header><strong>Site badge</strong></header>'));
    expect(builtPage(), contains('<section><strong>Site badge</strong></section>'));
    expect(output(assetPath).readAsStringSync(), 'site CSS');
    expect(siteAndTheme.staticFileCount, 4);
  });
}
