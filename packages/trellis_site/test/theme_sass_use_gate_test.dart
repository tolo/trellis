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
/// file, a `_dark` twin for every colour param that agrees with the palettes and
/// reaches exactly the dark views, and every param variable reachable by the bridge.
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

  group("every colour param and its twin reach exactly their mode's views", () {
    for (final themeDir in themes) {
      group(p.basename(themeDir), () {
        final colors = colourBases(themeDir);
        final compile = _memoisedCompile(themeDir);

        test('has colour params to prove', () {
          expect(colors, isNotEmpty);
        });

        for (final name in colors) {
          test('$name and ${name}_dark', () {
            expect(colourReachViolations(themeDir, name, compile), isEmpty);
          });
        }
      });
    }
  });

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

    group('colour reach check', () {
      test('a palette-merge entry deleted from the dark merge fails that twin only', () {
        final theme = copy();
        expect(colourReachViolations(theme, 'text_color'), isEmpty, reason: 'the untouched copy is clean');
        _edit(
          p.join(theme, 'sass', '_variables.scss'),
          (s) => s.replaceFirst(RegExp(r'^\s*text-color: \$trellis-text-color-dark,\n', multiLine: true), ''),
        );

        final violations = colourReachViolations(theme, 'text_color');
        expect(violations, isNotEmpty);
        expect(violations, everyElement(allOf(contains('arbor'), contains('text_color_dark'))));
        expect(violations.join('\n'), allOf(contains('forced dark'), contains('auto')));
        expect(colourReachViolations(theme, 'primary_color'), isEmpty, reason: 'only the dropped entry is affected');
        expect(twinViolations(theme), isEmpty, reason: 'no other check moves');
      });

      test('a plain colour that leaks into the dark merge fails', () {
        final theme = copy();
        _edit(
          p.join(theme, 'sass', '_variables.scss'),
          (s) => s.replaceFirst(r'text-color: $trellis-text-color-dark,', r'text-color: $trellis-text-color,'),
        );

        final violations = colourReachViolations(theme, 'text_color');
        expect(violations, isNotEmpty);
        expect(violations.join('\n'), contains('text_color_dark'));
      });

      test('a light toggle token that stops following its colour param fails', () {
        final theme = _copyTheme(p.join(themesRoot, 'folio'), p.join(work.path, 'themes'), 'folio');
        expect(colourReachViolations(theme, 'text_color'), isEmpty, reason: 'the untouched copy is clean');
        _edit(
          p.join(theme, 'sass', 'main.scss'),
          (s) => s.replaceFirstMapped(
            RegExp(r"(:root\[data-skin='light'\] \{\s*)--folio-ink: #\{\$trellis-text-color\};"),
            (m) => '${m[1]}--folio-ink: #17291f;',
          ),
        );

        final violations = colourReachViolations(theme, 'text_color');
        expect(violations.join('\n'), allOf(contains("param 'text_color'"), contains('light toggle')));
      });

      test('a twin read inside a non-dark @media fails', () {
        final theme = copy();
        File(p.join(theme, 'sass', 'main.scss')).writeAsStringSync(
          '@media (max-width: 900px) { :root { --leak: #{\$trellis-text-color-dark}; } }\n',
          mode: FileMode.append,
        );

        final violations = colourReachViolations(theme, 'text_color');
        expect(violations.join('\n'), allOf(contains('text_color_dark'), contains('forced light')));
      });

      test('a twin read inside a non-dark @media under auto only fails', () {
        // Emitted only at skin: auto, so the forced-light comparison cannot see it.
        final theme = copy();
        File(p.join(theme, 'sass', 'main.scss')).writeAsStringSync(
          '@if \$trellis-skin == auto { '
          '@media (max-width: 900px) { :root { --leak: #{\$trellis-text-color-dark}; } } }\n',
          mode: FileMode.append,
        );

        final violations = colourReachViolations(theme, 'text_color');
        expect(violations.join('\n'), allOf(contains('text_color_dark'), contains('other @media carries it')));
      });
    });

    test(
      'a param variable declared !default in the entry instead of _variables.scss trips the configurability check',
      () {
        final theme = copy();
        expect(configurabilityViolations(theme), isEmpty, reason: 'the untouched copy is clean');
        const declaration = r'$trellis-max-width: 1200px !default;';
        _edit(
          p.join(theme, 'sass', '_variables.scss'),
          (s) => s.replaceFirst(declaration, r'$trellis-max-width: 1200px;'),
        );
        _edit(p.join(theme, 'sass', 'main.scss'), (s) => '$s\n$declaration\n');

        final violations = configurabilityViolations(theme);
        expect(violations, hasLength(1));
        expect(violations.single, allOf(contains('arbor'), contains(r'$trellis-max-width')));
        expect(twinViolations(theme), isEmpty, reason: 'no other check moves');
        // _variables.scss keeps a plain copy for the partials to read, so the theme still compiles and the oracle
        // can answer.
        expect(importViolations(p.dirname(theme)), isEmpty);
        expect(standaloneViolations(theme), isEmpty);
      },
    );

    test('a param variable declared !default in a partial the entry does not forward is caught, by file', () {
      // `with()` reaches the entry and what it forwards; a partial it only `@use`s loads unconfigured, so the
      // override would silently never arrive. Sass answers "not configurable" for this exactly as for a variable that
      // does not exist, so the file is found by reading the text.
      final theme = copy();
      expect(configurabilityViolations(theme), isEmpty, reason: 'the untouched copy is clean');
      _edit(
        p.join(theme, 'sass', '_variables.scss'),
        (s) => s.replaceFirst(r'$trellis-max-width: 1200px !default;', r'$trellis-max-width: 1200px;'),
      );
      File(p.join(theme, 'sass', '_extra.scss')).writeAsStringSync('\$trellis-max-width: 1200px !default;\n');
      _edit(
        p.join(theme, 'sass', 'main.scss'),
        (s) => s.replaceFirst("@forward 'variables';", "@forward 'variables';\n@use 'extra';"),
      );

      final violations = configurabilityViolations(theme);
      expect(violations, hasLength(1));
      expect(violations.single, allOf(contains('arbor'), contains(r'$trellis-max-width'), contains('_extra.scss')));
      expect(standaloneViolations(theme), isEmpty, reason: 'the theme itself compiles');
    });

    test('a protocol-relative url() default that hides the next declaration from the generator is caught', () {
      // The generator's statement splitter reads `//` after `(` as a comment, so the declaration after this one
      // is swallowed into it and never configured. Sass still accepts configuring it; only the oracle sees that.
      final theme = copy();
      expect(configurabilityViolations(theme), isEmpty, reason: 'the untouched copy is clean');
      _edit(
        p.join(theme, 'sass', '_variables.scss'),
        (s) => s.replaceFirst(
          r'$trellis-max-width: 1200px !default;',
          r'$trellis-max-width: url(//cdn.example/x.png) !default;',
        ),
      );

      final violations = configurabilityViolations(theme);
      expect(violations, hasLength(1));
      expect(violations.single, allOf(contains('arbor'), contains(r'$trellis-border-radius')));
      expect(standaloneViolations(theme), isEmpty, reason: 'the theme itself compiles');
    });

    test(r'a $trellis_ spelling is configured by the generator and by Sass alike, so the gate passes', () {
      final theme = copy();
      _edit(
        p.join(theme, 'sass', '_variables.scss'),
        (s) => s.replaceFirst(r'$trellis-max-width: 1200px !default;', r'$trellis_max_width: 1200px !default;'),
      );

      expect(configurabilityViolations(theme), isEmpty);
      final site = Directory(p.join(work.path, 'site'))..createSync();
      final config = _generate(theme, SkinMode.light, site.path, siteParams: {'max_width': '777px'});
      expect(config.configurableVars, contains('trellis-max-width'));
      expect(compileBridged(config, p.join(theme, 'sass', 'main.scss')), contains('777px'));
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

/// The configurability rule: the variables the bridge configures are exactly the ones Sass accepts configuring.
///
/// The bridge reads only `sass/_variables.scss` for `!default` declarations, so a param variable declared anywhere
/// else would never take a site override and nothing would say so. The oracle is Sass itself, not a second reading
/// of the source: for each manifest param, `@use "<entry>" with ($trellis-<param>: ...)` either compiles, or fails
/// with "not declared with !default". The generator's [ThemeBuildConfig.configurableVars] must agree with that.
///
/// One further violation, strictly additive: a param variable that a theme file declares `!default` while Sass says
/// the entry cannot configure it (a partial the entry does not forward). Sass cannot name that declaration, so this
/// part reads the text. It can add a violation, never remove one the oracle found.
List<String> configurabilityViolations(String themeDir) {
  final theme = p.basename(themeDir);
  final manifest = ThemeManifest.load(themeDir);
  final declaredIn = _defaultDeclarationsByFile(themeDir);
  final site = Directory.systemTemp.createTempSync('trellis_use_gate_site_');
  try {
    final config = _generate(themeDir, SkinMode.light, site.path);
    final configurable = config.configurableVars.toSet();
    final violations = <String>{};
    for (final entry in themeEntries(themeDir)) {
      final entryName = p.relative(entry, from: p.join(themeDir, 'sass'));
      for (final param in manifest.params.keys) {
        final variable = 'trellis-${param.replaceAll('_', '-')}';
        final bool sassConfigures;
        try {
          sassConfigures = _sassConfigures(config, entry, variable);
        } on SassCompilationException catch (e) {
          violations.add("theme '$theme', entry '$entryName': configuring \$$variable failed unexpectedly: $e");
          continue;
        }
        if (sassConfigures && !configurable.contains(variable)) {
          violations.add(
            "theme '$theme': \$$variable is declared !default and Sass configures it on '$entryName', but the bridge "
            'does not (only sass/_variables.scss is read)',
          );
        } else if (!sassConfigures && configurable.contains(variable)) {
          violations.add(
            "theme '$theme': the bridge configures \$$variable, but Sass rejects it on '$entryName' (not declared "
            '!default there)',
          );
        }
        if (!sassConfigures) {
          for (final file in declaredIn.entries) {
            if (!file.value.contains(variable)) continue;
            violations.add(
              "theme '$theme': \$$variable is declared !default in '${file.key}', but Sass cannot configure it on "
              "'$entryName' (the entry does not forward that file)",
            );
          }
        }
      }
    }
    return violations.toList();
  } finally {
    site.deleteSync(recursive: true);
  }
}

/// The `$trellis-*` variables (kebab case, no `$`) each `.scss`/`.sass` file under `sass/` declares `!default`, keyed
/// by path relative to `sass/`. Each declaration is read as a whole statement, so a value wrapped across lines cannot
/// hide it; comments and quoted `;` are skipped. `.sass` reads a statement as ending at the line break.
Map<String, Set<String>> _defaultDeclarationsByFile(String themeDir) {
  final sassDir = p.join(themeDir, 'sass');
  return {
    for (final file in sweepFiles(sassDir))
      p.relative(file.path, from: sassDir): _defaultDeclarations(
        file.readAsStringSync(),
        indented: p.extension(file.path).toLowerCase() == '.sass',
      ).toSet(),
  };
}

Iterable<String> _defaultDeclarations(String source, {required bool indented}) sync* {
  final code = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ').replaceAll(RegExp(r'(?<!:)//.*'), '');
  const value = r'''(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[^;"'])*''';
  final declaration = RegExp(
    indented ? r'\$(trellis[-_][\w-]+)[ \t]*:([^\n]*)' : '\\\$(trellis[-_][\\w-]+)\\s*:($value);',
  );
  for (final m in declaration.allMatches(code)) {
    if (RegExp(r'!default\b').hasMatch(m.group(2)!)) yield m.group(1)!.replaceAll('_', '-');
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
/// defaults with `skin` and [siteParams] as the site's params, as the site builder does.
ThemeBuildConfig _generate(
  String themeDir,
  SkinMode skin,
  String siteDir, {
  Map<String, dynamic> siteParams = const {},
}) {
  final manifest = ThemeManifest.load(themeDir);
  final merged = const ThemeParamMerger().merge(manifest.defaultParams, {'skin': skin.name, ...siteParams}).params;
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

/// Compiles every entry of [themeDir] through the build's wrapper at [skin] with [siteParams] as the site's
/// params, and returns the stylesheets concatenated.
String compileTheme(String themeDir, SkinMode skin, Map<String, dynamic> siteParams) {
  final site = Directory.systemTemp.createTempSync('trellis_use_gate_site_');
  try {
    final config = _generate(themeDir, skin, site.path, siteParams: siteParams);
    return [for (final entry in themeEntries(themeDir)) compileBridged(config, entry)].join('\n');
  } finally {
    site.deleteSync(recursive: true);
  }
}

typedef CompileTheme = String Function(SkinMode skin, [Map<String, dynamic> siteParams]);

/// [compileTheme], lowercased and remembered, so the baselines are compiled once per theme.
CompileTheme _memoisedCompile(String themeDir) {
  final compiled = <String, String>{};
  return (skin, [siteParams = const {}]) => compiled.putIfAbsent(
    '${skin.name} ${siteParams.entries.map((e) => '${e.key}=${e.value}')}',
    () => compileTheme(themeDir, skin, siteParams).toLowerCase(),
  );
}

/// The base colour params of a theme: `type: color`, not named `<x>_dark`.
List<String> colourBases(String themeDir) => [
  for (final e in ThemeManifest.load(themeDir).params.entries)
    if (e.value.type == 'color' && !e.key.endsWith('_dark')) e.key,
];

/// A colour compressed output can neither shorten nor name, so it appears only where a param put it.
const _sentinel = '#0a0b0c';

/// The reach rule, per view and not per token: colour param [name] set to a sentinel reaches the light views and no
/// dark one, and its twin `<name>_dark` reaches the dark views and no light one, at every skin. Views are sorted by
/// [cssViews]. Whole stylesheets are not compared, because a theme may emit its dark toggle rule under every skin.
List<String> colourReachViolations(String themeDir, String name, [CompileTheme? compile]) {
  final theme = p.basename(themeDir);
  final twin = '${name}_dark';
  compile ??= _memoisedCompile(themeDir);
  final violations = <String>[];

  void expectView(String param, String view, bool holds, String what) {
    if (!holds) violations.add("theme '$theme', param '$param': $view $what");
  }

  final plainLight = cssViews(compile(SkinMode.light));
  final twinLight = cssViews(compile(SkinMode.light, {twin: _sentinel}));
  expectView(twin, 'forced light', twinLight.top == plainLight.top, 'top level moved');
  expectView(twin, 'forced light', twinLight.lightToggle == plainLight.lightToggle, 'light toggle rule moved');
  expectView(twin, 'forced light', twinLight.darkMedia == plainLight.darkMedia, 'dark @media moved');
  expectView(twin, 'forced light', twinLight.otherMedia == plainLight.otherMedia, 'other @media moved');

  final twinDark = cssViews(compile(SkinMode.dark, {twin: _sentinel}));
  expectView(twin, 'forced dark', twinDark.top.contains(_sentinel), 'top level lacks the override');
  expectView(twin, 'forced dark', !twinDark.lightToggle.contains(_sentinel), 'light toggle rule carries it');

  final plainAuto = cssViews(compile(SkinMode.auto));
  final twinAuto = cssViews(compile(SkinMode.auto, {twin: _sentinel}));
  expectView(twin, 'auto', twinAuto.darkMedia.contains(_sentinel), 'dark @media lacks the override');
  if (plainAuto.darkToggle.isNotEmpty) {
    expectView(twin, 'auto', twinAuto.darkToggle.contains(_sentinel), 'dark toggle rule lacks the override');
  }
  expectView(twin, 'auto', !twinAuto.top.contains(_sentinel), 'light top level carries it');
  expectView(twin, 'auto', !twinAuto.lightToggle.contains(_sentinel), 'light toggle rule carries it');
  expectView(twin, 'auto', !twinAuto.otherMedia.contains(_sentinel), 'other @media carries it');

  final baseLight = cssViews(compile(SkinMode.light, {name: _sentinel}));
  expectView(name, 'forced light', baseLight.root.contains(_sentinel), ':root lacks the override');

  expectView(name, 'forced dark', !compile(SkinMode.dark, {name: _sentinel}).contains(_sentinel), 'output carries it');

  final baseAuto = cssViews(compile(SkinMode.auto, {name: _sentinel}));
  expectView(name, 'auto', baseAuto.root.contains(_sentinel), 'light :root lacks the override');
  if (plainAuto.lightToggle.isNotEmpty) {
    expectView(name, 'auto', baseAuto.lightToggle.contains(_sentinel), 'light toggle rule lacks the override');
  }
  expectView(name, 'auto', !baseAuto.darkMedia.contains(_sentinel), 'dark @media carries it');
  expectView(name, 'auto', !baseAuto.darkToggle.contains(_sentinel), 'dark toggle rule carries it');
  return violations;
}

/// The declarations of a stylesheet sorted by the view that selects them. A rule counts toward every comma-separated
/// selector it carries, so `:root, [data-theme=dark]` feeds [root] and [darkToggle].
class CssViews {
  /// `:root` outside any `@media`.
  String root = '';

  /// Every selector outside any `@media` that is not a skin toggle (includes [root]).
  String top = '';

  /// Rules scoped to `[data-skin=light]` / `[data-theme=light]`, outside any `@media`.
  String lightToggle = '';

  /// Rules scoped to `[data-skin=dark]` / `[data-theme=dark]`, outside any `@media`.
  String darkToggle = '';

  /// Everything inside `@media (prefers-color-scheme: dark)`.
  String darkMedia = '';

  /// Everything inside any other `@media` (responsive, print, `prefers-color-scheme: light`): light views a twin
  /// must not reach.
  String otherMedia = '';
}

/// Sorts the rules of [css] into [CssViews]. A `:not([data-theme=...])` guard is not a toggle selector: it
/// qualifies a view instead of naming one.
CssViews cssViews(String css) {
  final views = CssViews();
  _sortRules(css.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ''), '', views);
  return views;
}

void _sortRules(String css, String media, CssViews views) {
  var start = 0;
  var i = 0;
  while (i < css.length) {
    final c = css[i];
    if (c == ';') {
      start = ++i;
    } else if (c == '{') {
      final end = _closingBrace(css, i);
      final prelude = css.substring(start, i).trim();
      final body = css.substring(i + 1, end);
      if (prelude.startsWith('@media')) {
        _sortRules(body, prelude, views);
      } else {
        _addRule(media, prelude, body, views);
      }
      start = i = end + 1;
    } else {
      i++;
    }
  }
}

void _addRule(String media, String selectorList, String body, CssViews views) {
  if (RegExp(r'prefers-color-scheme:\s*dark').hasMatch(media)) {
    views.darkMedia += body;
    return;
  }
  if (media.isNotEmpty) {
    views.otherMedia += body;
    return;
  }
  for (final selector in selectorList.replaceAll(RegExp(r':not\([^)]*\)'), '').split(',')) {
    if (RegExp(
      r'\[data-(?:skin|theme)=["'
      "'"
      r']?dark',
    ).hasMatch(selector)) {
      views.darkToggle += body;
    } else if (RegExp(
      r'\[data-(?:skin|theme)=["'
      "'"
      r']?light',
    ).hasMatch(selector)) {
      views.lightToggle += body;
    } else {
      views.top += body;
      if (selector.trim() == ':root') views.root += body;
    }
  }
}

/// Index of the `}` that closes the `{` at [open], skipping quoted strings.
int _closingBrace(String css, int open) {
  var depth = 0;
  String? quote;
  for (var i = open; i < css.length; i++) {
    final c = css[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
    } else if (c == '"' || c == "'") {
      quote = c;
    } else if (c == '{') {
      depth++;
    } else if (c == '}' && --depth == 0) {
      return i;
    }
  }
  return css.length;
}

String compileStandalone(String entry) =>
    TrellisCss.compileSass(entry, outputStyle: OutputStyle.compressed, fatalImportDeprecation: true);

/// Whether Sass accepts configuring `$[variable]` on [entry], through the wrapper's own `@use ... with` form, with
/// the generated params module as the value. A compile error other than the one Sass raises for a variable that is
/// not declared `!default` is rethrown.
bool _sassConfigures(ThemeBuildConfig config, String entry, String variable) {
  final wrapper = File(p.join(config.buildDir, 'oracle_$variable.scss'))
    ..writeAsStringSync(
      '@use "theme_params" as tp;\n'
      '@use "${p.toUri(entry).path}" as theme with (\$$variable: tp.\$$variable);\n',
    );
  try {
    TrellisCss.compileSass(wrapper.path, loadPaths: config.sassLoadPaths, fatalImportDeprecation: true);
    return true;
  } on SassCompilationException catch (e) {
    if (e.toString().contains('not declared with !default')) return false;
    rethrow;
  }
}

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
