import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

import 'theme_sass_sources.dart';
import 'theme_use_support.dart' show findRepoRoot;

/// The compile-every-theme gate (ADR-013, Enforcement).
///
/// Dart Sass 3.0 removes `@import`. This gate compiles every theme found under
/// `themes/` with that deprecation fatal, bridged at each skin through the same
/// wrapper `trellis build` compiles and standalone, and holds each theme to the
/// per-mode contract: no `@import` in a theme, a scaffold template or a bridge
/// file, a `_dark` twin for every colour param that agrees with the palettes,
/// and every param variable reachable by the bridge.
///
/// Every check is a function over a themes root returning violations, so the
/// last group runs the same functions on mutated copies of a bundled theme and
/// proves each one fails. A theme added under `themes/` is covered without
/// editing this file, and discovery cannot pass on an empty directory.
///
/// The scaffold's twins and palette defaults are checked by the CLI package's own
/// test, because this package cannot depend on the CLI. Only the scaffold's
/// template sources, read by path, are swept for `@import` here.

/// Themes that ship with the SDK. The discovered set must contain every one, so a
/// moved or deleted theme cannot make the gate pass on fewer themes.
const _bundledThemes = ['arbor', 'bloom', 'folio', 'lattice', 'meadow', 'verdant'];

final _scaffoldTemplates = p.join('packages', 'trellis_cli', 'lib', 'src', 'templates', 'theme');

Future<void> main() async {
  final repoRoot = await findRepoRoot();
  final themesRoot = p.join(repoRoot, 'themes');
  final scaffoldDir = p.join(repoRoot, _scaffoldTemplates);
  final themes = discoverThemes(themesRoot);

  group('discovery', () {
    test('every directory under themes/ holds a theme.yaml', () {
      expect(discoveryViolations(themesRoot), isEmpty);
    });

    test('all bundled themes are discovered', () {
      expect(themes.map(p.basename), containsAll(_bundledThemes));
    });
  });

  group('no @import', () {
    test('theme SASS sources', () {
      expect(importViolations(themesRoot), isEmpty);
    });

    test('scaffold template sources', () {
      expect(Directory(scaffoldDir).existsSync(), isTrue, reason: scaffoldDir);
      expect(importViolations(scaffoldDir, extensions: null), isEmpty);
    });
  });

  for (final themeDir in themes) {
    group(p.basename(themeDir), () {
      for (final skin in SkinMode.values) {
        test('bridged at skin ${skin.name} compiles with @import fatal, and its bridge files hold none', () {
          expect(bridgedViolations(themeDir, skin), isEmpty);
        });
      }

      test('standalone compiles with @import fatal', () {
        expect(standaloneViolations(themeDir), isEmpty);
      });

      test('every colour param has a _dark twin, and defaults equal the palettes', () {
        expect(twinViolations(themeDir), isEmpty);
      });

      test('every param variable is one the bridge configures', () {
        expect(configurabilityViolations(themeDir), isEmpty);
      });
    });
  }

  group('the gate fails on bad input', () {
    late Directory work;
    final source = p.join(themesRoot, 'arbor');

    setUp(() => work = Directory.systemTemp.createTempSync('trellis_use_gate_'));
    tearDown(() => work.deleteSync(recursive: true));

    String copy([String name = 'arbor']) => _copyTheme(source, p.join(work.path, 'themes'), name);

    test('a copy under a new name is a seventh theme and passes every check', () {
      final seventh = copy('seventh');
      final root = p.dirname(seventh);

      expect(discoverThemes(root), [seventh]);
      expect(discoveryViolations(root), isEmpty);
      expect(importViolations(root), isEmpty);
      for (final skin in SkinMode.values) {
        expect(bridgedViolations(seventh, skin), isEmpty, reason: skin.name);
      }
      expect(standaloneViolations(seventh), isEmpty);
      expect(twinViolations(seventh), isEmpty);
      expect(configurabilityViolations(seventh), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a directory without theme.yaml is reported by name', () {
      copy();
      Directory(p.join(work.path, 'themes', 'half_added', 'sass')).createSync(recursive: true);
      Directory(p.join(work.path, 'themes', '.hidden')).createSync();

      final violations = discoveryViolations(p.join(work.path, 'themes'));
      expect(violations, hasLength(1));
      expect(violations.single, contains('half_added'));
    });

    test('an empty themes root fails, and so does a missing one', () {
      final empty = Directory(p.join(work.path, 'themes'))..createSync();
      expect(discoveryViolations(empty.path), isNotEmpty);
      expect(discoveryViolations(p.join(work.path, 'nowhere')), isNotEmpty);
    });

    test('an @import in a partial trips the text check and the fatal compile', () {
      final theme = copy();
      _edit(p.join(theme, 'sass', '_footer.scss'), (s) => "@import 'variables';\n$s");

      final hits = importViolations(p.dirname(theme));
      expect(hits, hasLength(1));
      expect(hits.single, contains('_footer.scss'));
      expect(() => compileStandalone(p.join(theme, 'sass', 'main.scss')), throwsA(isA<SassCompilationException>()));
      expect(standaloneViolations(theme).single, allOf(contains('arbor'), contains('main.scss')));
      expect(bridgedViolations(theme, SkinMode.light).single, allOf(contains('arbor'), contains('light')));
    });

    test('an @import in a scaffold template copy trips the text check', () {
      final templates = Directory(p.join(work.path, 'templates'));
      _copyDirectory(Directory(p.join(repoRoot, _scaffoldTemplates)), templates);
      expect(importViolations(templates.path, extensions: null), isEmpty, reason: 'the untouched copy is clean');

      final template = File(p.join(templates.path, 'theme_main_scss_template.dart'));
      template.writeAsStringSync("// @import 'variables';\n${template.readAsStringSync()}");

      final hits = importViolations(templates.path, extensions: null);
      expect(hits, hasLength(1));
      expect(hits.single, contains('theme_main_scss_template.dart'));
    });

    test('an @import in a bridge file trips the text check', () {
      final theme = copy();
      final site = Directory(p.join(work.path, 'site'))..createSync();
      final config = _generate(theme, SkinMode.light, site.path);
      expect(importViolations(config.buildDir), isEmpty, reason: 'the generated bridge files are clean');

      File(
        p.join(config.buildDir, 'bridge_main.scss'),
      ).writeAsStringSync('@import "${p.join(theme, 'sass', 'main.scss')}";\n');

      final hits = importViolations(config.buildDir);
      expect(hits, hasLength(1));
      expect(hits.single, contains('bridge_main.scss'));
    });

    group('twin check', () {
      void expectDrift(void Function(String theme) mutate, Pattern mentions) {
        final theme = copy();
        expect(twinViolations(theme), isEmpty, reason: 'the untouched copy is clean');
        mutate(theme);

        final violations = twinViolations(theme);
        expect(violations, isNotEmpty);
        expect(violations, everyElement(contains('arbor')));
        expect(violations.join('\n'), contains(mentions));
        expect(configurabilityViolations(theme), isEmpty, reason: 'no other check moves');
        expect(importViolations(p.dirname(theme)), isEmpty);
        expect(standaloneViolations(theme), isEmpty);
        expect(bridgedViolations(theme, SkinMode.dark), isEmpty);
      }

      test('a removed twin', () {
        expectDrift(
          (theme) => _edit(p.join(theme, 'theme.yaml'), (s) => _dropParam(s, 'primary_color_dark')),
          'primary_color',
        );
      });

      test('a changed twin default', () {
        expectDrift(
          (theme) => _edit(p.join(theme, 'theme.yaml'), (s) => _setDefault(s, 'primary_color_dark', '#000001')),
          'primary_color_dark',
        );
      });

      test('a changed base default', () {
        expectDrift(
          (theme) => _edit(p.join(theme, 'theme.yaml'), (s) => _setDefault(s, 'primary_color', '#000002')),
          'primary_color',
        );
      });

      test('a missing palette entry', () {
        expectDrift(
          (theme) => _edit(p.join(theme, 'sass', '_skins', '_dark.scss'), (s) => _dropPaletteEntry(s, 'primary-color')),
          'primary-color',
        );
      });

      test('a twin given a twin', () {
        expectDrift(
          (theme) => _edit(
            p.join(theme, 'theme.yaml'),
            (s) => '$s\n  primary_color_dark_dark:\n    type: color\n    default: "#4ade80"\n',
          ),
          // The rule's own message: the twin's missing palette entry also names the param.
          "'primary_color_dark_dark': a twin of a twin",
        );
      });

      test('a twin that is not a colour', () {
        expectDrift(
          (theme) => _edit(
            p.join(theme, 'theme.yaml'),
            (s) => s.replaceFirstMapped(
              _paramBlock('primary_color_dark'),
              (m) => m.group(0)!.replaceFirst('type: color', 'type: string'),
            ),
          ),
          "'primary_color_dark': must be type color",
        );
      });

      test('a theme with colour params and no skin files', () {
        final theme = copy();
        Directory(p.join(theme, 'sass', '_skins')).deleteSync(recursive: true);
        expect(twinViolations(theme), everyElement(contains('arbor')));
        expect(twinViolations(theme), isNotEmpty);
      });

      test('a palette entry built from a variable, in a different hex case, still passes', () {
        final theme = copy();
        final light = p.join(theme, 'sass', '_skins', '_light.scss');
        final hex = RegExp(r'primary-color:\s*(#[0-9a-fA-F]+)').firstMatch(File(light).readAsStringSync())!.group(1)!;
        _edit(
          light,
          (s) =>
              '\$brand: ${hex.toUpperCase()};\n${s.replaceFirst(RegExp(r'primary-color:\s*#[0-9a-fA-F]+'), r'primary-color: $brand')}',
        );

        expect(twinViolations(theme), isEmpty);
      });
    });

    test('a param variable moved out of _variables.scss trips the configurability check', () {
      final theme = copy();
      expect(configurabilityViolations(theme), isEmpty, reason: 'the untouched copy is clean');
      const declaration = r'$trellis-max-width: 1200px !default;';
      _edit(p.join(theme, 'sass', '_variables.scss'), (s) => s.replaceFirst(declaration, '// moved'));
      _edit(p.join(theme, 'sass', 'main.scss'), (s) => '$s\n$declaration\n');

      final violations = configurabilityViolations(theme);
      expect(violations, hasLength(1));
      expect(violations.single, allOf(contains('arbor'), contains(r'$trellis-max-width')));
      expect(twinViolations(theme), isEmpty, reason: 'no other check moves');
      // The compile checks are not asserted: arbor's partials read the moved variable,
      // so moving it past them also breaks the compile.
      expect(importViolations(p.dirname(theme)), isEmpty);
    });

    test('a multi-line declaration of a param variable elsewhere is still found', () {
      final theme = copy();
      _edit(
        p.join(theme, 'sass', 'main.scss'),
        (s) => '$s\n\$trellis-nav-links:\n  (a, b)\n  !default;\n\$trellis-toc-title: "x;y" !default;\n',
      );

      final violations = configurabilityViolations(theme);
      expect(violations.join('\n'), allOf(contains('trellis-nav-links'), contains('trellis-toc-title')));
    });
  });
}

// ---------------------------------------------------------------------------
// Checks: each returns its violations, empty when the check holds.
// ---------------------------------------------------------------------------

/// Directories directly under [themesRoot] that are not hidden, with a `theme.yaml`.
List<String> discoverThemes(String themesRoot) => [
  for (final dir in _themeDirectories(themesRoot))
    if (File(p.join(dir.path, 'theme.yaml')).existsSync()) dir.path,
];

List<String> discoveryViolations(String themesRoot) {
  if (!Directory(themesRoot).existsSync()) return ['themes root does not exist: $themesRoot'];
  final dirs = _themeDirectories(themesRoot);
  return [
    if (dirs.isEmpty) 'no theme directories under $themesRoot',
    for (final dir in dirs)
      if (!File(p.join(dir.path, 'theme.yaml')).existsSync()) "directory '${p.basename(dir.path)}' has no theme.yaml",
  ];
}

List<Directory> _themeDirectories(String themesRoot) =>
    Directory(themesRoot).listSync().whereType<Directory>().where((d) => !p.basename(d.path).startsWith('.')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Files under [dir] (see [sweepFiles]: only those with an extension in [extensions], every file when null)
/// that contain `@import`, as paths relative to [dir]. Comments count: the rule is literal.
List<String> importViolations(String dir, {Set<String>? extensions = sassExtensions}) {
  final hits = <String>[];
  for (final file in sweepFiles(dir, extensions: extensions)) {
    if (file.readAsStringSync().contains('@import')) hits.add("@import in '${p.relative(file.path, from: dir)}'");
  }
  return hits..sort();
}

/// Compiles every entry of [themeDir] through the build's wrapper at [skin] with
/// `@import` fatal, then sweeps the bridge files that compile wrote.
List<String> bridgedViolations(String themeDir, SkinMode skin) {
  final theme = p.basename(themeDir);
  final site = Directory.systemTemp.createTempSync('trellis_use_gate_site_');
  try {
    final config = _generate(themeDir, skin, site.path);
    final violations = <String>[];
    for (final entry in themeEntries(themeDir)) {
      final name = p.relative(entry, from: p.join(themeDir, 'sass'));
      try {
        compileBridged(config, entry);
      } on SassCompilationException catch (e) {
        violations.add("theme '$theme', skin '${skin.name}', entry '$name' failed to compile: $e");
      }
    }
    return [
      ...violations,
      for (final hit in importViolations(config.buildDir)) "theme '$theme', skin '${skin.name}': $hit",
    ];
  } finally {
    site.deleteSync(recursive: true);
  }
}

List<String> standaloneViolations(String themeDir) {
  final violations = <String>[];
  for (final entry in themeEntries(themeDir)) {
    try {
      compileStandalone(entry);
    } on SassCompilationException catch (e) {
      final name = p.relative(entry, from: p.join(themeDir, 'sass'));
      violations.add("theme '${p.basename(themeDir)}', standalone, entry '$name' failed to compile: $e");
    }
  }
  return violations;
}

/// The twin rule: a `type: color` param named `<x>_dark` whose base `<x>` is also a
/// colour param is a twin; every other colour param is a base and needs a twin.
/// A palette key is the base param's name in kebab case.
List<String> twinViolations(String themeDir) {
  final theme = p.basename(themeDir);
  final params = ThemeManifest.load(themeDir).params;
  final colors = {
    for (final e in params.entries)
      if (e.value.type == 'color') e.key: e.value,
  };
  if (colors.isEmpty) return [];

  final palettes = <String, Map<String, String>>{};
  final violations = <String>[];
  for (final mode in ['light', 'dark']) {
    final file = p.join(themeDir, 'sass', '_skins', '_$mode.scss');
    if (!File(file).existsSync()) {
      violations.add("theme '$theme' has colour params but no sass/_skins/_$mode.scss");
      continue;
    }
    try {
      palettes[mode] = readPalette(file);
    } on SassCompilationException catch (e) {
      violations.add("theme '$theme': palette of _$mode.scss does not compile: $e");
    }
  }

  bool isTwin(String name) => name.endsWith('_dark') && colors.containsKey(_baseOf(name));

  void expectDefault(String param, String base, String mode) {
    final palette = palettes[mode];
    if (palette == null) return;
    final key = base.replaceAll('_', '-');
    final entry = palette[key];
    if (entry == null) {
      violations.add("theme '$theme', param '$param': no '$key' entry in the $mode palette");
    } else if (colors[param]!.defaultValue.toString().toLowerCase() != entry.toLowerCase()) {
      violations.add(
        "theme '$theme', param '$param': default '${colors[param]!.defaultValue}' differs from the $mode palette "
        "entry '$entry'",
      );
    }
  }

  for (final name in colors.keys) {
    if (isTwin(name)) {
      if (isTwin(_baseOf(name))) {
        violations.add("theme '$theme', param '$name': a twin of a twin ('${_baseOf(name)}' is already a twin)");
      }
      expectDefault(name, _baseOf(name), 'dark');
    } else {
      final twin = '${name}_dark';
      final declared = params[twin];
      if (declared == null) {
        violations.add("theme '$theme', param '$name': no '$twin' twin");
      } else if (declared.type != 'color') {
        violations.add("theme '$theme', param '$twin': must be type color, is '${declared.type}'");
      }
      expectDefault(name, name, 'light');
    }
  }
  return violations;
}

String _baseOf(String twin) => twin.substring(0, twin.length - '_dark'.length);

/// The configurability rule: a `!default` declaration of a variable named for a
/// manifest param, anywhere under `sass/`, must be one the bridge configures. The
/// bridge only reads `_variables.scss`, so a declaration elsewhere would never take
/// a site override and nothing would say so.
List<String> configurabilityViolations(String themeDir) {
  final theme = p.basename(themeDir);
  final manifest = ThemeManifest.load(themeDir);
  final site = Directory.systemTemp.createTempSync('trellis_use_gate_site_');
  try {
    final configurable = _generate(themeDir, SkinMode.light, site.path).configurableVars.toSet();
    final paramVars = {for (final name in manifest.params.keys) 'trellis-${name.replaceAll('_', '-')}'};
    final violations = <String>[];
    for (final file in sweepFiles(p.join(themeDir, 'sass'))) {
      for (final name in defaultDeclarations(
        file.readAsStringSync(),
        indented: p.extension(file.path).toLowerCase() == '.sass',
      )) {
        if (paramVars.contains(name) && !configurable.contains(name)) {
          violations.add(
            "theme '$theme': \$$name is declared !default in '${p.relative(file.path, from: themeDir)}' but the "
            'bridge cannot configure it (only sass/_variables.scss is read)',
          );
        }
      }
    }
    return violations;
  } finally {
    site.deleteSync(recursive: true);
  }
}

// ---------------------------------------------------------------------------
// Compiling.
// ---------------------------------------------------------------------------

/// Non-partial `.scss`/`.sass` files under `sass/`, as `build_command.dart#_compileSass` selects them.
List<String> themeEntries(String themeDir) {
  final entries = [
    for (final file in sweepFiles(p.join(themeDir, 'sass')))
      if (!p.basename(file.path).startsWith('_')) p.canonicalize(file.path),
  ]..sort();
  if (entries.isEmpty) throw StateError("theme '${p.basename(themeDir)}' has no SASS entry under sass/");
  return entries;
}

/// Writes the bridge files for [themeDir] at [skin] into [siteDir], merging the theme's
/// defaults with `skin` as the only site param, as the site builder does.
ThemeBuildConfig _generate(String themeDir, SkinMode skin, String siteDir) {
  final manifest = ThemeManifest.load(themeDir);
  final merged = const ThemeParamMerger().merge(manifest.defaultParams, {'skin': skin.name}).params;
  return const ThemeSassGenerator().generate(
    mergedParams: merged,
    paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
    siteDir: siteDir,
    themeDir: themeDir,
  );
}

/// Compiles [entry] through the wrapper `trellis build` writes, compressed, `@import` fatal.
String compileBridged(ThemeBuildConfig config, String entry) {
  final wrapper = File(p.join(config.buildDir, 'bridge_${p.basenameWithoutExtension(entry)}.scss'))
    ..writeAsStringSync(config.bridgeWrapperSource(entry));
  return TrellisCss.compileSass(
    wrapper.path,
    outputStyle: OutputStyle.compressed,
    loadPaths: config.sassLoadPaths,
    fatalImportDeprecation: true,
  );
}

String compileStandalone(String entry) =>
    TrellisCss.compileSass(entry, outputStyle: OutputStyle.compressed, fatalImportDeprecation: true);

/// Reads a skin's `$palette` by compiling it, so an entry may be a literal or built from
/// variables. Interpolating a colour keeps its authored hex. Keys are the map's keys.
Map<String, String> readPalette(String skinFile) {
  final css = TrellisCss.compileSassString(
    '''
@use "${p.basename(skinFile)}" as skin;
:root { @each \$key, \$value in skin.\$palette { --#{\$key}: #{\$value}; } }
''',
    loadPaths: [p.dirname(skinFile)],
  );
  return {for (final m in RegExp(r'--([\w-]+):\s*([^;]+);').allMatches(css)) m.group(1)!: m.group(2)!.trim()};
}

/// Names (kebab case, no `$`) of the `$trellis-*` variables [source] declares `!default`.
///
/// Matches each declaration as a whole statement, so a value wrapped across lines
/// cannot hide it, and skips comments and quoted `;`. [indented] reads `.sass`, where
/// a statement ends at the line break.
Iterable<String> defaultDeclarations(String source, {bool indented = false}) sync* {
  final code = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ').replaceAll(RegExp(r'(?<!:)//.*'), '');
  const value = r'''(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[^;"'])*''';
  final declaration = RegExp(indented ? r'\$(trellis-[\w-]+)[ \t]*:([^\n]*)' : '\\\$(trellis-[\\w-]+)\\s*:($value);');
  for (final m in declaration.allMatches(code)) {
    if (RegExp(r'!default\b').hasMatch(m.group(2)!)) yield m.group(1)!.replaceAll('_', '-');
  }
}

// ---------------------------------------------------------------------------
// Fixtures: mutated copies of a bundled theme.
// ---------------------------------------------------------------------------

/// Copies `theme.yaml` and `sass/` of [source] into `[root]/[name]`, renaming the manifest.
String _copyTheme(String source, String root, String name) {
  final dest = Directory(p.join(root, name))..createSync(recursive: true);
  _copyDirectory(Directory(p.join(source, 'sass')), Directory(p.join(dest.path, 'sass')));
  File(p.join(dest.path, 'theme.yaml')).writeAsStringSync(
    File(
      p.join(source, 'theme.yaml'),
    ).readAsStringSync().replaceFirst(RegExp(r'^name:.*$', multiLine: true), 'name: $name'),
  );
  return p.canonicalize(dest.path);
}

void _copyDirectory(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(recursive: true)) {
    final target = p.join(to.path, p.relative(entity.path, from: from.path));
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

/// Rewrites [path] and fails if [change] left it as it was, so a mutation that
/// no longer matches its target cannot make a negative test pass vacuously.
void _edit(String path, String Function(String) change) {
  final file = File(path);
  final before = file.readAsStringSync();
  final after = change(before);
  expect(after, isNot(before), reason: 'mutation changed nothing in $path');
  file.writeAsStringSync(after);
}

/// The block of one param in a `theme.yaml`: its key line and the indented lines under it.
RegExp _paramBlock(String name) => RegExp('^  $name:\\n(?:    .*\\n)+', multiLine: true);

String _dropParam(String yaml, String name) => yaml.replaceFirst(_paramBlock(name), '');

String _setDefault(String yaml, String name, String value) => yaml.replaceFirstMapped(
  _paramBlock(name),
  (m) => m.group(0)!.replaceFirst(RegExp(r'default: .*'), 'default: "$value"'),
);

String _dropPaletteEntry(String scss, String key) => scss.replaceFirst(RegExp('^\\s*$key:.*\\n', multiLine: true), '');
