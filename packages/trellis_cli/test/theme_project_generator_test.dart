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

    test('T04: theme.yaml contains all 19 standard param names', () {
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
        'syntax_highlighting',
      ];
      for (final param in expectedParams) {
        expect(content, contains(param), reason: 'theme.yaml should contain param: $param');
      }
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

    test('T11: _variables.scss has trellis- prefixed variables with !default', () {
      final vars = writer.files['sass/_variables.scss']!;
      expect(vars, contains(r'$trellis-primary-color'));
      expect(vars, contains('!default'));
    });

    test('T12: _light.scss has light skin colors', () {
      final light = writer.files['sass/_skins/_light.scss']!;
      expect(light, contains(r'$trellis-bg-color: #ffffff'));
    });

    test('T13: _dark.scss has dark skin colors distinct from light', () {
      final dark = writer.files['sass/_skins/_dark.scss']!;
      expect(dark, contains(r'$trellis-bg-color: #111827'));
    });

    test('T14: main.scss imports variables', () {
      final main = writer.files['sass/main.scss']!;
      expect(main, contains("@import 'variables'"));
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
}
