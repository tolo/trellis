import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  group('ThemeProjectGenerator — file list', () {
    late InMemoryFileWriter writer;

    setUp(() async {
      writer = InMemoryFileWriter();
      final generator = ThemeProjectGenerator(projectName: 'my_theme', writer: writer);
      await generator.generate();
    });

    test('T01: generates all 15 expected files', () {
      expect(writer.files, hasLength(15));
      expect(
        writer.files.keys,
        containsAll([
          'theme.yaml',
          'layouts/base.html',
          'layouts/_default/single.html',
          'layouts/_default/list.html',
          'layouts/home.html',
          'sass/_variables.scss',
          'sass/_skins/_light.scss',
          'sass/_skins/_dark.scss',
          'sass/main.scss',
          'static/.gitkeep',
          'example/trellis_site.yaml',
          'example/content/_index.md',
          'example/layouts/home.html',
          'README.md',
          '.gitignore',
        ]),
      );
    });

    test('T02: static/.gitkeep is empty', () {
      expect(writer.files['static/.gitkeep'], isEmpty);
    });
  });

  group('ThemeProjectGenerator — theme.yaml', () {
    late InMemoryFileWriter writer;

    setUp(() async {
      writer = InMemoryFileWriter();
      final generator = ThemeProjectGenerator(projectName: 'my_theme', writer: writer);
      await generator.generate();
    });

    test('T03: theme.yaml has required top-level keys', () {
      final content = writer.files['theme.yaml']!;
      expect(content, contains('name:'));
      expect(content, contains('version:'));
      expect(content, contains('params:'));
    });

    test('T04: theme.yaml contains all 25 standard param names', () {
      final content = writer.files['theme.yaml']!;
      const expectedParams = [
        'skin',
        'primary_color',
        'accent_color',
        'text_color',
        'muted_color',
        'bg_color',
        'surface_color',
        'border_color',
        'primary_color_dark',
        'accent_color_dark',
        'text_color_dark',
        'muted_color_dark',
        'bg_color_dark',
        'surface_color_dark',
        'border_color_dark',
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
      ];
      expect(expectedParams, hasLength(25));
      for (final param in expectedParams) {
        expect(content, contains('\n  $param:'), reason: 'theme.yaml should declare param: $param');
      }
      // syntax_highlighting was retired by ADR-010; scaffolds must not emit it.
      expect(content, isNot(contains('syntax_highlighting')), reason: 'retired param must be absent');
    });

    test('T05: theme.yaml includes project name', () {
      expect(writer.files['theme.yaml'], contains('name: my_theme'));
    });

    test('T06: theme.yaml skin param has enum values', () {
      final content = writer.files['theme.yaml']!;
      expect(content, contains('values: [light, dark, auto]'));
    });
  });

  group('ThemeProjectGenerator — layouts', () {
    late InMemoryFileWriter writer;

    setUp(() async {
      writer = InMemoryFileWriter();
      final generator = ThemeProjectGenerator(projectName: 'my_theme', writer: writer);
      await generator.generate();
    });

    test('T07: base.html has tl:define blocks for header, content, footer', () {
      final base = writer.files['layouts/base.html']!;
      expect(base, contains('tl:define="site-header"'));
      expect(base, contains('tl:define="content"'));
      expect(base, contains('tl:define="site-footer"'));
    });

    test('T08: single.html extends base and defines content block', () {
      final single = writer.files['layouts/_default/single.html']!;
      expect(single, contains('tl:extends="layouts/base.html"'));
      expect(single, contains('tl:define="content"'));
    });

    test('T09: list.html extends base and has tl:each', () {
      final list = writer.files['layouts/_default/list.html']!;
      expect(list, contains('tl:extends="layouts/base.html"'));
      expect(list, contains('tl:each'));
    });

    test('T10: home.html extends base and defines content block', () {
      final home = writer.files['layouts/home.html']!;
      expect(home, contains('tl:extends="layouts/base.html"'));
      expect(home, contains('tl:define="content"'));
    });
  });

  group('ThemeProjectGenerator — SASS', () {
    late InMemoryFileWriter writer;

    setUp(() async {
      writer = InMemoryFileWriter();
      final generator = ThemeProjectGenerator(projectName: 'my_theme', writer: writer);
      await generator.generate();
    });

    test('T11: _variables.scss declares a !default pair per colour param and builds both palettes', () {
      final vars = writer.files['sass/_variables.scss']!;
      for (final name in ['primary', 'accent', 'text', 'muted', 'bg', 'surface', 'border']) {
        expect(vars, contains('\$trellis-$name-color: map.get(light.\$palette, $name-color) !default;'));
        expect(vars, contains('\$trellis-$name-color-dark: map.get(dark.\$palette, $name-color) !default;'));
      }
      expect(vars, contains(r'$trellis-palette-light: map.merge('));
      expect(vars, contains(r'$trellis-palette-dark: map.merge('));
      expect(vars, contains(r'$trellis-skin: auto !default;'));
    });

    test('T12: _light.scss is a palette map with light colours and no !default', () {
      final light = writer.files['sass/_skins/_light.scss']!;
      expect(light, contains(r'$palette: ('));
      expect(light, contains('bg-color: #ffffff'));
      expect(light, isNot(contains('!default')));
    });

    test('T13: _dark.scss is a palette map with dark colours distinct from light', () {
      final dark = writer.files['sass/_skins/_dark.scss']!;
      expect(dark, contains(r'$palette: ('));
      expect(dark, contains('bg-color: #111827'));
      expect(dark, contains('primary-color: #3b82f6'));
      expect(dark, isNot(contains('!default')));
    });

    test("T14: main.scss forwards 'variables' and flips colours for auto from the dark palette", () {
      final main = writer.files['sass/main.scss']!;
      expect(main, contains("@forward 'variables';"));
      expect(main, isNot(contains('@import')));
      expect(main, contains(r'@if $trellis-skin == auto'));
      expect(main, contains(r'map.get($trellis-palette-dark, primary-color)'));
    });
  });

  group('ThemeProjectGenerator — example site', () {
    late InMemoryFileWriter writer;

    setUp(() async {
      writer = InMemoryFileWriter();
      final generator = ThemeProjectGenerator(projectName: 'my_theme', writer: writer);
      await generator.generate();
    });

    test('T15: example/trellis_site.yaml exists and contains display name', () {
      final config = writer.files['example/trellis_site.yaml']!;
      expect(config, contains('my theme'));
    });

    test('T16: example/content/_index.md has front matter', () {
      final content = writer.files['example/content/_index.md']!;
      expect(content, contains('---'));
      expect(content, contains('title:'));
    });
  });

  group('ThemeProjectGenerator — project files', () {
    late InMemoryFileWriter writer;

    setUp(() async {
      writer = InMemoryFileWriter();
      final generator = ThemeProjectGenerator(projectName: 'my_theme', writer: writer);
      await generator.generate();
    });

    test('T17: README.md contains theme name', () {
      expect(writer.files['README.md'], contains('my theme'));
    });

    test('T18: .gitignore includes output/', () {
      expect(writer.files['.gitignore'], contains('output/'));
    });

    test('T19: project name used as theme name in theme.yaml', () {
      expect(writer.files['theme.yaml'], contains('name: my_theme'));
    });
  });

  // The scaffold's base layout must link the stylesheets `trellis build` writes
  // for a theme. A link to any other path still builds cleanly, but every page
  // ships unstyled.
  group('ThemeProjectGenerator — built site', () {
    late Directory siteDir;

    setUp(() async {
      siteDir = Directory.systemTemp.createTempSync('trellis_theme_scaffold_');
      await ThemeProjectGenerator(
        projectName: 'my_theme',
        writer: DiskFileWriter(p.join(siteDir.path, 'themes', 'my_theme')),
      ).generate();
      File(p.join(siteDir.path, 'content', '_index.md'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('---\ntitle: Home\n---\nHome.\n');
    });

    tearDown(() => siteDir.deleteSync(recursive: true));

    for (final pathPrefix in ['', '/docs/']) {
      test('T20: base.html links every stylesheet the build writes (pathPrefix: "$pathPrefix")', () async {
        File(p.join(siteDir.path, 'trellis_site.yaml')).writeAsStringSync(
          'title: Test Site\nbaseUrl: https://example.com\ntheme: my_theme\npathPrefix: "$pathPrefix"\n',
        );

        expect(await TrellisCli(workingDirectory: siteDir.path).run(['build']), 0);

        final outputDir = p.join(siteDir.path, 'output');
        final written = Directory(p.join(outputDir, 'css'))
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => p.split(p.relative(file.path, from: outputDir)).join('/'))
            .toSet();
        expect(written, containsAll(['css/main.css', 'css/theme-props.css']), reason: 'compiled SASS + theme params');

        final home = File(p.join(outputDir, 'index.html')).readAsStringSync();
        final linked = RegExp(
          r'<link rel="stylesheet" href="([^"]+)"',
        ).allMatches(home).map((match) => match[1]!).toSet();
        final assetBase = pathPrefix.isEmpty ? '/' : pathPrefix;
        expect(linked, {for (final path in written) '$assetBase$path'});
      });
    }
  });
}
