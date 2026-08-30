import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';
import 'package:yaml/yaml.dart';

import '../tool/generate_theme_gallery.dart';

void main() {
  late Directory root;
  late List<String> warnings;

  setUp(() {
    root = Directory.systemTemp.createTempSync('theme_gallery_test_');
    warnings = <String>[];
    Directory(p.join(root.path, 'themes')).createSync(recursive: true);
    Directory(p.join(root.path, 'site')).createSync(recursive: true);
  });

  tearDown(() => root.deleteSync(recursive: true));

  void addTheme(
    String directory, {
    String? name,
    String features = 'docs, dark-mode',
    String? description,
    bool lightExists = true,
    bool darkExists = true,
    bool declareScreenshots = true,
    bool readme = true,
    List<String>? screenshotPaths,
  }) {
    final themeDir = Directory(p.join(root.path, 'themes', directory))..createSync(recursive: true);
    final declared = screenshotPaths ?? const <String>['screenshots/light.png', 'screenshots/dark.png'];
    final screenshotsYaml = declareScreenshots ? 'screenshots:\n${declared.map((path) => '  - $path\n').join()}' : '';
    File(p.join(themeDir.path, 'theme.yaml')).writeAsStringSync('''
name: ${name ?? directory}
description: ${description ?? 'Description for ${name ?? directory}'}
features: [$features]
$screenshotsYaml
''');
    if (lightExists) {
      File(p.join(themeDir.path, 'screenshots', 'light.png'))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(<int>[1, directory.length]);
    }
    if (darkExists) {
      File(p.join(themeDir.path, 'screenshots', 'dark.png'))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(<int>[2, directory.length]);
    }
    if (readme) {
      File(p.join(themeDir.path, 'README.md')).writeAsStringSync('# ${name ?? directory}\n');
    }
    final pinsFile = File(p.join(root.path, 'tool', 'theme_screenshot_digests.json'));
    final pins = pinsFile.existsSync()
        ? (jsonDecode(pinsFile.readAsStringSync()) as Map<String, dynamic>)
        : <String, dynamic>{};
    pins[name ?? directory] = <String, String>{
      if (lightExists)
        'light': sha256.convert(File(p.join(themeDir.path, 'screenshots', 'light.png')).readAsBytesSync()).toString(),
      if (darkExists)
        'dark': sha256.convert(File(p.join(themeDir.path, 'screenshots', 'dark.png')).readAsBytesSync()).toString(),
    };
    pinsFile
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(pins)}\n');
  }

  ThemeGalleryGenerator generator() => ThemeGalleryGenerator(root.path, warningSink: warnings.add);

  test('S04 writes sorted count-neutral metadata and both declared screenshots', () {
    addTheme('zeta', features: 'responsive, landing, dark-mode');
    addTheme('alpha', features: 'search, docs');

    generator().write();

    final dataFile = File(p.join(root.path, 'site', 'data', 'themes.yaml'));
    final dataText = dataFile.readAsStringSync();
    final data = loadYaml(dataText) as YamlMap;
    final themes = data['themes'] as YamlList;
    expect(themes.map((item) => (item as YamlMap)['name']), <String>['alpha', 'zeta']);
    expect((themes.first as YamlMap)['archetype'], 'docs');
    expect((themes.last as YamlMap)['archetype'], 'landing');
    expect((themes.first as YamlMap)['config_hint'], 'theme: alpha');
    expect((themes.first as YamlMap)['readme_url'], 'https://github.com/tolo/trellis/tree/main/themes/alpha/README.md');
    expect(dataText, isNot(contains('count:')));
    expect(dataText, isNot(matches(RegExp(r'\b(total|three|six)\b', caseSensitive: false))));
    expect(File(p.join(root.path, 'site', 'static', 'themes', 'alpha', 'light.png')).existsSync(), isTrue);
    expect(File(p.join(root.path, 'site', 'static', 'themes', 'zeta', 'dark.png')).existsSync(), isTrue);
    expect(generator().check().isFresh, isTrue);
  });

  test('S05 rejects missing, repeated, and multiple recognized archetype occurrences', () {
    addTheme('none', features: 'responsive, accessible');
    expect(
      generator().write,
      throwsA(
        isA<ThemeGalleryException>()
            .having((error) => error.toString(), 'message', contains('none'))
            .having((error) => error.toString(), 'message', contains('found []'))
            .having((error) => error.toString(), 'message', contains('exactly one')),
      ),
    );

    root.deleteSync(recursive: true);
    root = Directory.systemTemp.createTempSync('theme_gallery_test_');
    Directory(p.join(root.path, 'themes')).createSync(recursive: true);
    Directory(p.join(root.path, 'site')).createSync(recursive: true);
    addTheme('duplicate', features: 'docs, search, docs');
    expect(
      generator().write,
      throwsA(
        isA<ThemeGalleryException>()
            .having((error) => error.toString(), 'message', contains('duplicate'))
            .having((error) => error.toString(), 'message', contains('[docs, docs]')),
      ),
    );
  });

  test('S06 warns, omits a missing declared screenshot, removes stale copy, and renders one image', () async {
    addTheme('partial', features: 'blog, other', darkExists: false);
    final staleDark = File(p.join(root.path, 'site', 'static', 'themes', 'partial', 'dark.png'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('stale');

    generator().write();

    final data = loadYaml(File(p.join(root.path, 'site', 'data', 'themes.yaml')).readAsStringSync()) as YamlMap;
    final entry = (data['themes'] as YamlList).single as YamlMap;
    expect(entry['screenshot_light'], 'themes/partial/light.png');
    expect(entry.containsKey('screenshot_dark'), isFalse);
    expect(staleDark.existsSync(), isFalse);
    expect(warnings.single, allOf(contains('partial'), contains('screenshots/dark.png')));
    expect(generator().check().isFresh, isTrue);

    final siteDir = Directory(p.join(root.path, 'site'));
    final outputDir = Directory(p.join(root.path, 'output'));
    File(p.join(siteDir.path, 'layouts', 'gallery.html'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(File(p.join(Directory.current.path, 'site', 'layouts', 'gallery.html')).readAsStringSync());
    File(p.join(siteDir.path, 'content', 'docs', 'themes', 'gallery.md'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('---\ntitle: Themes\nlayout: gallery\n---\nGallery\n');
    final lattice = p.join(Directory.current.path, 'themes', 'lattice');
    final relativeTheme = p.relative(lattice, from: p.join(siteDir.path, 'themes'));
    final result = await TrellisSite(
      SiteConfig(
        siteDir: siteDir.path,
        title: 'Gallery fixture',
        baseUrl: 'https://example.com',
        outputDir: outputDir.path,
        themeConfig: ThemeConfig(name: relativeTheme),
      ),
    ).build();
    expect(result.hasWarnings, isFalse);
    final gallery = html_parser.parse(
      File(p.join(outputDir.path, 'docs', 'themes', 'gallery', 'index.html')).readAsStringSync(),
    );
    expect(gallery.querySelectorAll('.gallery-card img'), hasLength(1));
    expect(gallery.querySelector('img[src="/themes/partial/light.png"]'), isNotNull);
  });

  test('S04 accepts a theme that does not declare screenshots', () {
    addTheme('text-only', declareScreenshots: false, lightExists: false, darkExists: false);

    generator().write();

    final data = loadYaml(File(p.join(root.path, 'site', 'data', 'themes.yaml')).readAsStringSync()) as YamlMap;
    final entry = (data['themes'] as YamlList).single as YamlMap;
    expect(entry['name'], 'text-only');
    expect(entry.containsKey('screenshot_light'), isFalse);
    expect(entry.containsKey('screenshot_dark'), isFalse);
    expect(generator().check().isFresh, isTrue);
  });

  test('S07 check reports metadata, byte, inventory, and orphan drift without mutating outputs', () {
    addTheme('alpha');
    generator().write();

    File(p.join(root.path, 'site', 'static', 'themes', 'alpha', 'light.png')).writeAsBytesSync(<int>[9]);
    addTheme('beta', features: 'landing');
    final orphan = File(p.join(root.path, 'site', 'static', 'themes', 'orphan.png'))..writeAsStringSync('orphan');

    final result = generator().check();

    expect(result.isFresh, isFalse);
    expect(result.problems.join('\n'), contains('themes.yaml'));
    expect(result.problems.join('\n'), contains('alpha/light.png'));
    expect(result.problems.join('\n'), contains('beta'));
    expect(result.problems.join('\n'), contains('orphan.png'));
    expect(result.problems.join('\n'), contains('dart run tool/generate_theme_gallery.dart'));
    expect(orphan.existsSync(), isTrue);

    generator().write();
    expect(generator().check().isFresh, isTrue);
    expect(orphan.existsSync(), isFalse);

    Directory(p.join(root.path, 'themes', 'beta')).deleteSync(recursive: true);
    final removed = generator().check();
    expect(removed.isFresh, isFalse);
    expect(removed.problems.join('\n'), allOf(contains('beta'), contains('beta/light.png')));
  });

  test('S07 identical-byte screenshot relocation is stale until regeneration', () {
    addTheme('alpha');
    generator().write();
    final themeDir = p.join(root.path, 'themes', 'alpha');
    final original = File(p.join(themeDir, 'screenshots', 'light.png'));
    final relocated = File(p.join(themeDir, 'previews', 'light.png'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(original.readAsBytesSync());
    final manifest = File(p.join(themeDir, 'theme.yaml'));
    manifest.writeAsStringSync(manifest.readAsStringSync().replaceFirst('screenshots/light.png', 'previews/light.png'));

    final stale = generator().check();
    expect(stale.isFresh, isFalse);
    expect(stale.problems.join('\n'), contains('themes.yaml'));
    generator().write();
    expect(generator().check().isFresh, isTrue);
    expect(relocated.existsSync(), isTrue);
  });

  test('S07 swapped screenshot bytes fail even after gallery regeneration', () {
    addTheme('alpha');
    addTheme('beta', features: 'landing');
    generator().write();
    final alpha = File(p.join(root.path, 'themes', 'alpha', 'screenshots', 'light.png'));
    final beta = File(p.join(root.path, 'themes', 'beta', 'screenshots', 'light.png'));
    final alphaBytes = alpha.readAsBytesSync();
    alpha.writeAsBytesSync(beta.readAsBytesSync());
    beta.writeAsBytesSync(alphaBytes);

    expect(
      generator().write,
      throwsA(isA<ThemeGalleryException>().having((error) => error.toString(), 'message', contains('reviewed digest'))),
    );
  });

  test('S04 rejects unsafe or mismatched manifest names before mutating outputs', () {
    for (final unsafeName in <String>['../escape', 'other/name', r'other\name']) {
      addTheme('safe', name: unsafeName);
      final sentinel = File(p.join(root.path, 'site', 'data', 'themes.yaml'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('sentinel\n');
      expect(
        generator().write,
        throwsA(isA<ThemeGalleryException>().having((error) => error.toString(), 'message', contains('safe'))),
      );
      expect(sentinel.readAsStringSync(), 'sentinel\n');
      Directory(p.join(root.path, 'themes', 'safe')).deleteSync(recursive: true);
    }

    addTheme(r'other\name');
    expect(
      generator().write,
      throwsA(
        isA<ThemeGalleryException>()
            .having((error) => error.toString(), 'message', contains(r'other\name'))
            .having((error) => error.toString(), 'message', contains('portable path segment')),
      ),
    );
  });

  test('S04 rejects screenshot symlinks that resolve outside the theme', () {
    addTheme('safe');
    final external = File(p.join(root.path, 'secret.txt'))..writeAsStringSync('not public');
    final source = File(p.join(root.path, 'themes', 'safe', 'screenshots', 'light.png'))..deleteSync();
    Link(source.path).createSync(external.path);

    expect(
      generator().write,
      throwsA(
        isA<ThemeGalleryException>()
            .having((error) => error.toString(), 'message', contains('safe'))
            .having((error) => error.toString(), 'message', contains('outside the theme directory')),
      ),
    );
    expect(File(p.join(root.path, 'site', 'static', 'themes', 'safe', 'light.png')).existsSync(), isFalse);
  });

  test('S04 does not traverse generated-output symlinks', () {
    addTheme('safe');
    final externalDir = Directory(p.join(root.path, 'external'))..createSync();
    final sentinel = File(p.join(externalDir.path, 'sentinel.txt'))..writeAsStringSync('keep');
    final generatedDir = Directory(p.join(root.path, 'site', 'static', 'themes'))..createSync(recursive: true);
    Link(p.join(generatedDir.path, 'safe')).createSync(externalDir.path);

    expect(
      generator().write,
      throwsA(isA<ThemeGalleryException>().having((error) => error.toString(), 'message', contains('symbolic link'))),
    );
    expect(sentinel.readAsStringSync(), 'keep');
    final check = generator().check();
    expect(check.isFresh, isFalse);
    expect(check.problems.join('\n'), contains('unsafe symbolic link'));
  });

  test('S04 rejects in-repository symlinked output parents', () {
    addTheme('safe');
    final themeDir = Directory(p.join(root.path, 'themes', 'safe'));
    final sentinel = File(p.join(themeDir.path, 'sentinel.txt'))..writeAsStringSync('keep');
    Link(p.join(root.path, 'site', 'static')).createSync(themeDir.path);

    expect(
      generator().write,
      throwsA(
        isA<ThemeGalleryException>()
            .having((error) => error.toString(), 'message', contains('site/static'))
            .having((error) => error.toString(), 'message', contains('generated output path')),
      ),
    );
    expect(sentinel.readAsStringSync(), 'keep');
    expect(generator().check().problems.join('\n'), contains('site/static'));
  });

  test('D2 a theme without a README fails, naming it — the gallery links every card to one', () {
    addTheme('noreadme', readme: false);
    final sentinel = File(p.join(root.path, 'site', 'data', 'themes.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('sentinel\n');

    expect(
      generator().write,
      throwsA(
        isA<ThemeGalleryException>()
            .having((error) => error.toString(), 'message', contains('noreadme'))
            .having((error) => error.toString(), 'message', contains('README.md')),
      ),
    );
    expect(sentinel.readAsStringSync(), 'sentinel\n');
  });

  test('D7 an unparseable manifest fails as a named gallery error, not a raw YamlException', () {
    addTheme('broken');
    File(p.join(root.path, 'themes', 'broken', 'theme.yaml')).writeAsStringSync('name: broken\ndescription: a: b: c\n');

    expect(
      generator().write,
      throwsA(
        isA<ThemeGalleryException>()
            .having((error) => error.toString(), 'message', contains('broken'))
            .having((error) => error.toString(), 'message', contains('not valid YAML')),
      ),
    );
  });

  test('D7 a description containing backticks is rejected — the card renders it as text', () {
    addTheme('ticks', description: 'A theme that bakes `.hljs-*` spans in');

    expect(
      generator().write,
      throwsA(
        isA<ThemeGalleryException>()
            .having((error) => error.toString(), 'message', contains('ticks'))
            .having((error) => error.toString(), 'message', contains('plain prose')),
      ),
    );
  });

  test('D7 a declared screenshot with an unrecognized variant warns instead of vanishing', () {
    addTheme('extra', screenshotPaths: <String>['screenshots/light.png', 'screenshots/mobile.png']);
    File(p.join(root.path, 'themes', 'extra', 'screenshots', 'mobile.png')).writeAsBytesSync(<int>[7]);

    generator().write();

    expect(warnings.single, allOf(contains('extra'), contains('screenshots/mobile.png'), contains('mobile')));
    final data = loadYaml(File(p.join(root.path, 'site', 'data', 'themes.yaml')).readAsStringSync()) as YamlMap;
    final entry = (data['themes'] as YamlList).single as YamlMap;
    expect(entry['screenshot_light'], 'themes/extra/light.png');
    expect(entry.containsKey('screenshot_dark'), isFalse);
  });

  test('D7 generated metadata carries a header naming the generator and the regeneration command', () {
    addTheme('alpha');

    generator().write();

    final text = File(p.join(root.path, 'site', 'data', 'themes.yaml')).readAsStringSync();
    expect(text, startsWith('# GENERATED FILE'));
    expect(text, contains('tool/generate_theme_gallery.dart'));
    expect(text, contains('themes/<name>/theme.yaml'));
    // The header must not break the consumer: the site reads this as data.
    expect(((loadYaml(text) as YamlMap)['themes'] as YamlList).single, isA<YamlMap>());
  });

  test('S05/S07 CLI exits non-zero with actionable validation and drift output', () async {
    addTheme('alpha');
    final toolPath = p.join(Directory.current.path, 'tool', 'generate_theme_gallery.dart');

    final stale = await Process.run('dart', <String>['run', toolPath, '--check', root.path]);
    expect(stale.exitCode, 1);
    expect('${stale.stdout}${stale.stderr}', allOf(contains('alpha'), contains('Regenerate with')));

    generator().write();
    final fresh = await Process.run('dart', <String>['run', toolPath, '--check', root.path]);
    expect(fresh.exitCode, 0);
    expect(fresh.stdout, contains('generated gallery outputs are current'));

    File(p.join(root.path, 'themes', 'alpha', 'theme.yaml')).writeAsStringSync('''
name: alpha
description: Invalid fixture
features: [docs, blog]
screenshots: []
''');
    final invalid = await Process.run('dart', <String>['run', toolPath, root.path]);
    expect(invalid.exitCode, 1);
    expect(
      '${invalid.stdout}${invalid.stderr}',
      allOf(contains('alpha'), contains('[docs, blog]'), contains('exactly one')),
    );
  });

  group('repository gallery wiring', () {
    final repoRoot = Directory.current.path;

    /// The theme the docs site renders with, resolved the way the SSG resolves
    /// `theme:` — against `<siteDir>/themes/`.
    Directory siteTheme() {
      final config = loadYaml(File(p.join(repoRoot, 'site', 'trellis_site.yaml')).readAsStringSync()) as YamlMap;
      return Directory(p.normalize(p.join(repoRoot, 'site', 'themes', config['theme'] as String)));
    }

    test('D7 gallery.md names every generated theme, so site search can find them', () {
      // The gallery's substance lives in the layout and site/data/themes.yaml,
      // neither of which the search index reads: a theme name that appears only
      // there returns no hit for anyone searching the docs site.
      final body = File(p.join(repoRoot, 'site', 'content', 'docs', 'themes', 'gallery.md')).readAsStringSync();
      final data = loadYaml(File(p.join(repoRoot, 'site', 'data', 'themes.yaml')).readAsStringSync()) as YamlMap;
      final names = [for (final entry in data['themes'] as YamlList) (entry as YamlMap)['name'] as String];

      expect(names, isNotEmpty);
      for (final name in names) {
        expect(body.toLowerCase(), contains(name), reason: '$name is missing from gallery.md');
      }
      // The PRD requires count-free headings; a spelled-out total would drift
      // the moment a theme is added or removed.
      expect(body, isNot(matches(RegExp(r'\b(three|four|five|six|seven)\b', caseSensitive: false))));
    });

    test('D4 every custom property gallery.css reads is declared by the site theme', () {
      // gallery.css deliberately consumes Lattice's skin-aware tokens rather
      // than the static --trellis-* param bridge. Nothing in the build fails if
      // one is renamed — the page just loses its borders, background or radius.
      final css = File(p.join(repoRoot, 'site', 'static', 'gallery.css')).readAsStringSync();
      final consumed = RegExp(r'var\(\s*(--[a-z0-9-]+)').allMatches(css).map((m) => m.group(1)!).toSet();
      expect(consumed, isNotEmpty);

      final theme = siteTheme();
      final declared = <String>{};
      for (final file in theme.listSync(recursive: true, followLinks: false).whereType<File>()) {
        if (p.extension(file.path) != '.scss') continue;
        declared.addAll(
          RegExp(
            r'^\s*(--[a-z0-9-]+)\s*:',
            multiLine: true,
          ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
        );
      }

      expect(consumed.difference(declared), isEmpty, reason: 'undeclared in ${p.basename(theme.path)}');
    });

    test('H4 every card\'s screenshot paths live under its own theme directory', () {
      // Mutation-proven gap (release-gate review, finding H4): swapping two themes'
      // screenshot_light/screenshot_dark while leaving both names untouched left every
      // suite green. Nothing bound a card's name to its own screenshots.
      final data = loadYaml(File(p.join(repoRoot, 'site', 'data', 'themes.yaml')).readAsStringSync()) as YamlMap;
      for (final entry in data['themes'] as YamlList) {
        final theme = entry as YamlMap;
        final name = theme['name'] as String;
        final ownDir = 'themes/$name/';
        for (final key in <String>['screenshot_light', 'screenshot_dark']) {
          if (!theme.containsKey(key)) continue;
          final path = theme[key] as String;
          expect(path, contains(ownDir), reason: '$name.$key = "$path" is not under $ownDir');
        }
      }
    });
  });
}
