import 'dart:io';

import 'package:html/dom.dart' show Document;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_css/trellis_css.dart';
import 'package:trellis_site/trellis_site.dart';

import 'theme_font_contract.dart';
import 'theme_use_support.dart';

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
      'logo',
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
    const shared = {
      'font_family': 'Arial, sans-serif',
      'heading_font_family': 'Georgia, serif',
      'code_font_family': 'Courier New, monospace',
      'max_width': '900px',
      'border_radius': '7px',
    };
    final light = compileBridged(
      themeDir,
      'light',
      siteParams: {
        ...shared,
        'primary_color': '#123456',
        'accent_color': '#654321',
        'text_color': '#112233',
        'muted_color': '#445566',
        'bg_color': '#778899',
        'surface_color': '#aabbcc',
        'border_color': '#ddeeff',
      },
    );
    final dark = compileBridged(themeDir, 'dark', siteParams: shared);

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

    final apparatusOff = compileBridged(
      themeDir,
      'light',
      siteParams: {'show_plate_numbers': false, 'show_sidenotes': false},
    );
    expect(apparatusOff, isNot(contains('.folio-plate::before')));
    expect(apparatusOff, isNot(contains('.hero-plate::before')));
    expect(apparatusOff, contains('.folio-sidenote'));
    expect(apparatusOff, contains('display: none'));

    // SC03: the dark palette is the one dark authority. Neither the entry nor the
    // variables module restates a dark hex, and the auto blocks read the palette.
    String sass(String relative) => stripComments(File(p.join(themeDir, 'sass', relative)).readAsStringSync());
    final main = sass('main.scss');
    final darkPalette = sass('_skins/_dark.scss');
    final hex = RegExp(r'#[0-9a-fA-F]{6}');
    final darkValues = hex.allMatches(darkPalette).map((match) => match.group(0)!.toLowerCase()).toSet();
    expect(darkValues, hasLength(9));
    for (final source in [main, sass('_variables.scss')]) {
      for (final value in darkValues) {
        expect(source.toLowerCase(), isNot(contains(value)), reason: value);
      }
    }
    expect(File(p.join(themeDir, 'sass', '_dark_tokens.scss')).existsSync(), isFalse);
    expect(main, contains(r'$trellis-palette-dark'));
    expect(main, contains('@media (prefers-color-scheme: dark)'));
    expect(main.indexOf('@media (prefers-color-scheme: dark)'), lessThan(main.indexOf(":root[data-skin='light']")));
  });

  group('per-mode colour params on the @use bridge', () {
    // Palette key -> the `:root` custom property it feeds. The two code pigments
    // have no param; they ride in the same palettes.
    const paletteProps = {
      'text-color': '--folio-ink',
      'muted-color': '--folio-muted',
      'bg-color': '--folio-paper',
      'surface-color': '--folio-surface',
      'border-color': '--folio-rule',
      'primary-color': '--folio-green',
      'accent-color': '--folio-rubric',
      'code-number': '--folio-code-number',
      'code-function': '--folio-code-function',
    };
    late Map<String, String> lightPalette;
    late Map<String, String> darkPalette;

    setUpAll(() {
      lightPalette = readPalette(themeDir, 'light');
      darkPalette = readPalette(themeDir, 'dark');
    });

    void expectPalette(Map<String, String> props, Map<String, String> palette, String reason) {
      for (final entry in paletteProps.entries) {
        expect(props[entry.value], palette[entry.key], reason: '$reason ${entry.key}');
      }
    }

    // Sass strips the quotes from an attribute selector, so these are the unquoted forms.
    const autoOnly = ['@media (prefers-color-scheme: dark)', ':root[data-skin=dark]', ':root[data-skin=light]'];

    test('S01: every skin compiles fatal on @import, and each carries its own palette', () {
      final light = compileBridged(themeDir, 'light');
      final dark = compileBridged(themeDir, 'dark');
      final auto = compileBridged(themeDir, 'auto');

      expect(light, isNot(equals(dark)));
      expectPalette(customProps(rootBlock(light)), lightPalette, 'light');
      final darkRoot = customProps(rootBlock(dark));
      expectPalette(darkRoot, darkPalette, 'dark');
      expect(darkRoot['--folio-paper'], '#111a14');
      expect(darkRoot['--folio-code-number'], '#d9a86a');
      expect(darkRoot['--folio-code-function'], '#97b8dd');

      expectPalette(customProps(rootBlock(auto)), lightPalette, 'auto base');
      expectPalette(customProps(darkMediaRoot(auto)!), darkPalette, 'auto media');
      expectPalette(customProps(ruleBody(auto, ':root[data-skin=dark]')!), darkPalette, 'auto toggle dark');
      expectPalette(customProps(ruleBody(auto, ':root[data-skin=light]')!), lightPalette, 'auto toggle light');

      // Each negative is paired with the same query matching under auto: a query that
      // can never match (a quote style Sass does not emit) would pass vacuously.
      for (final query in autoOnly) {
        expect(auto, contains(query), reason: 'auto emits $query');
        expect(light, isNot(contains(query)), reason: 'light omits $query');
        expect(dark, isNot(contains(query)), reason: 'dark omits $query');
      }
    });

    test('S02: site overrides reach compiled CSS and variable-less params leave it unaffected', () {
      const overrides = {'max_width': '900px', 'font_family': 'Arial, sans-serif', 'show_sidenotes': false};
      final plain = compileBridged(themeDir, 'light');
      final css = compileBridged(themeDir, 'light', siteParams: overrides);

      expect(customProps(rootBlock(css))['--folio-width'], '900px');
      expect(customProps(rootBlock(css))['--folio-body'], 'Arial, sans-serif');
      final sidenoteHidden = RegExp(r'\.folio-sidenote\s*\{\s*display: none;\s*\}');
      expect(sidenoteHidden.hasMatch(css), isTrue);
      expect(sidenoteHidden.hasMatch(plain), isFalse);

      final withLists = compileBridged(
        themeDir,
        'light',
        siteParams: {
          ...overrides,
          'nav_links': [
            {'label': 'Docs', 'url': '/docs/'},
          ],
          'social_links': [
            {'label': 'Source', 'url': 'https://example.com'},
          ],
        },
      );
      expect(withLists, css);
    });

    test('S05: a _dark override reaches a forced dark skin and nothing else moves', () {
      final plain = customProps(rootBlock(compileBridged(themeDir, 'dark')));
      final css = compileBridged(themeDir, 'dark', siteParams: {'primary_color_dark': darkOverride});
      final root = customProps(rootBlock(css));

      expect(root['--folio-green'], darkOverride);
      expect(Map.of(root)..remove('--folio-green'), Map.of(plain)..remove('--folio-green'), reason: 'dark unchanged');
      for (final entry in paletteProps.entries) {
        expect(root[entry.value], isNot(lightPalette[entry.key]), reason: 'no light ${entry.key}');
      }
      for (final query in autoOnly) {
        expect(css, isNot(contains(query)), reason: query);
      }
    });

    test('S06: a _dark override reaches every dark view under auto, and no light view', () {
      final css = compileBridged(themeDir, 'auto', siteParams: {'primary_color_dark': darkOverride});
      final lightPrimary = lightPalette['primary-color'];

      expect(customProps(rootBlock(css))['--folio-green'], lightPrimary);
      expect(customProps(ruleBody(css, ':root[data-skin=light]')!)['--folio-green'], lightPrimary);
      expect(customProps(darkMediaRoot(css)!)['--folio-green'], darkOverride);
      expect(customProps(ruleBody(css, ':root[data-skin=dark]')!)['--folio-green'], darkOverride);
    });

    test('S07: a plain colour param sets the light entry only, under every skin', () {
      // The precedence rule, not load-order luck: a forced skin selects a palette and a
      // param sets one entry in it, so a plain `primary_color` is the light entry and
      // never reaches the dark palette.
      final dark = compileBridged(themeDir, 'dark', siteParams: {'primary_color': lightOverride});
      expect(customProps(rootBlock(dark))['--folio-green'], darkPalette['primary-color']);
      expect(dark, isNot(contains(lightOverride)));

      final auto = compileBridged(themeDir, 'auto', siteParams: {'primary_color': lightOverride});
      expect(customProps(rootBlock(auto))['--folio-green'], lightOverride);
      expect(customProps(ruleBody(auto, ':root[data-skin=light]')!)['--folio-green'], lightOverride);
      expect(customProps(darkMediaRoot(auto)!)['--folio-green'], darkPalette['primary-color']);
      expect(customProps(ruleBody(auto, ':root[data-skin=dark]')!)['--folio-green'], darkPalette['primary-color']);

      final light = compileBridged(themeDir, 'light', siteParams: {'primary_color': lightOverride});
      expect(customProps(rootBlock(light))['--folio-green'], lightOverride);

      expect(
        compileBridged(themeDir, 'light', siteParams: {'primary_color_dark': darkOverride}),
        compileBridged(themeDir, 'light'),
        reason: 'a _dark-only override changes nothing under light',
      );
    });

    test('S09: every colour param has a _dark twin sourced from the palettes', () {
      final colorParams = {
        for (final e in ThemeManifest.load(themeDir).params.entries)
          if (e.value.type == 'color') e.key: e.value,
      };
      final bases = colorParams.keys.where((name) => !name.endsWith('_dark')).toList();
      expect(bases, hasLength(7));

      for (final name in bases) {
        final key = name.replaceAll('_', '-');
        final twin = colorParams['${name}_dark'];
        expect(twin, isNotNull, reason: '$name needs a ${name}_dark twin');
        expect(twin!.defaultValue, darkPalette[key], reason: '${name}_dark default');
        expect(colorParams[name]!.defaultValue, lightPalette[key], reason: '$name default');
        expect(colorParams.containsKey('${name}_dark_dark'), isFalse, reason: 'twins have no twins');
      }
      expect(
        colorParams.keys.where((name) => name.endsWith('_dark')),
        hasLength(bases.length),
        reason: 'no orphan twin',
      );
    });
  });

  group('@use module structure', () {
    String sass(String relative) => stripComments(File(p.join(themeDir, 'sass', relative)).readAsStringSync());

    test('SC01: no @import remains, and the entry compiles standalone with the deprecation fatal', () {
      for (final file in sassSources(p.join(themeDir, 'sass'))) {
        expect(stripComments(file.readAsStringSync()), isNot(contains('@import')), reason: file.path);
      }
      final css = compileStandalone(themeDir);
      expect(customProps(rootBlock(css))['--folio-paper'], '#f2f1e8');
      final dark = compileStandalone(themeDir, configuration: r'$trellis-skin: dark');
      expect(customProps(rootBlock(dark))['--folio-paper'], '#111a14');
    });

    test("SC02: main.scss opens with @forward 'variables' and declares no \$trellis-* of its own", () {
      final main = sass('main.scss');
      expect(RegExp(r'@(use|forward)\b[^;]*;').firstMatch(main)!.group(0), "@forward 'variables';");
      expect(RegExp(r'^\$trellis-[\w-]+\s*:', multiLine: true).hasMatch(main), isFalse);
      // The bridge scans only _variables.scss, so a variable read anywhere must be declared there.
      final declared = RegExp(
        r'^\$(trellis-[\w-]+)\s*:',
        multiLine: true,
      ).allMatches(sass('_variables.scss')).map((m) => m.group(1)!).toSet();
      final read = RegExp(r'\$(trellis-[\w-]+)').allMatches(main).map((m) => m.group(1)!).toSet();
      expect(declared, containsAll(read));
    });

    test('SC03: skins expose a palette and declare nothing !default', () {
      for (final skin in ['_light', '_dark']) {
        final source = sass('_skins/$skin.scss');
        expect(source, contains(r'$palette:'), reason: skin);
        expect(source, isNot(contains('!default')), reason: skin);
      }
    });

    test('SC04: the bridge configures what _variables.scss declares, and nothing it cannot', () {
      final manifest = ThemeManifest.load(themeDir);
      final siteDir = Directory.systemTemp.createTempSync('folio_bridge_vars_');
      addTearDown(() => siteDir.deleteSync(recursive: true));
      final config = const ThemeSassGenerator().generate(
        mergedParams: manifest.defaultParams,
        paramTypes: {for (final e in manifest.params.entries) e.key: e.value.type},
        siteDir: siteDir.path,
        themeDir: themeDir,
      );
      expect(
        config.configurableVars,
        containsAll(['trellis-skin', 'trellis-primary-color', 'trellis-primary-color-dark', 'trellis-max-width']),
      );
      expect(config.configurableVars, isNot(contains('trellis-nav-links')));
    });
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
    final entry = File(p.join(themeDir, 'sass', 'main.scss')).resolveSymbolicLinksSync();
    final wrapper = File(p.join(tempDir.path, 'main.scss'))..writeAsStringSync(bridge.bridgeWrapperSource(entry));
    final css = TrellisCss.compileSass(wrapper.path, loadPaths: bridge.sassLoadPaths, fatalImportDeprecation: true);
    final cssFile = File(p.join(config.outputDir, 'css', 'main.css'))..parent.createSync(recursive: true);
    cssFile.writeAsStringSync(css);
    expect(css, isNot(contains('--folio-serif: "')));
    expect(css, isNot(contains('--folio-width: "')));
    expect(css, contains('counter-increment: folio-plates'));
    expect(RegExp(r'\.docs-shell > \.docs-toc\s*\{\s*display: none;').hasMatch(css), isTrue);
    expect(css, contains('.button-secondary'));
    // A short last card row must not leave the grid rule dangling: every card owns its own border.
    expect(RegExp(r'\.card-list\s*\{[^}]*gap: 18px').hasMatch(css), isTrue);
    expect(RegExp(r'\.doc-card\s*\{[^}]*border: 1px solid').hasMatch(css), isTrue);
    // Absent sidebar or TOC collapses its track instead of reserving a dead column.
    expect(RegExp(r'\.docs-shell\s*\{[^}]*grid-template-columns: auto minmax\(0, 1fr\) auto').hasMatch(css), isTrue);
    expect(css, contains('.breadcrumb-list'));
    expect(css, contains('.hero-plate::before'));
    // size-adjust lifts EB Garamond's small x-height to the metrics the mockup was drawn in. The
    // declared weight range is checked against the file's own fvar in the vendored-font contract.
    expect(RegExp(r'@font-face\s*\{[^}]*size-adjust: 118%').hasMatch(css), isTrue);
    expect(css, isNot(contains('IBM Plex Mono')));
    // Leaf entries must not emit a bare subtree; nesting is indentation, not stacked rules.
    expect(RegExp(r'\.sidebar-subtree\s*\{[^}]*border-left').hasMatch(css), isFalse);
    expect(css, contains('.sidebar-tree > .sidebar-item > .sidebar-link'));
    // The mobile disclosure caps its own tree; an unscoped 46vh would clip the article too.
    expect(_declared(css, r'\.sidebar-disclosure\[open\] > \.docs-sidebar', 'max-height'), '46vh');
    // Touch targets belong to the interactive controls, not to whatever rule happens to carry 44px.
    expect(_declared(css, r'\.nav-list a,[^{]*\.sidebar-link,[^{]*\.toc-list a', 'min-block-size'), '44px');
    // Trail and colophon links clear the 24px minimum target (WCAG 2.5.8) at every width.
    expect(_declared(css, r'\.breadcrumb-list a,\s*\.social-links a,\s*\.footer-powered-by a', 'padding-block'), '6px');
    // The hero is the mockup's: a centred two-column band, not the 830px stack it replaced.
    expect(_declared(css, r'(^|[\s,}])\.hero', 'align-items'), 'center');
    expect(_declared(css, r'(^|[\s,}])\.hero', 'min-height'), '650px');
    // The chart-paper grid tracks the active green, so it has to resolve per skin. This is the
    // `skin: auto` build, so one sheet carries :root, the prefers-color-scheme block and both
    // [data-skin] contexts — and a `contains` match is satisfied by the surviving :root
    // declaration no matter what a later context does, which is the regression it exists to
    // catch: a literal green in the dark context leaves the night edition wearing the light
    // grid, suite green. So check *every* declaration, not that one of them is right.
    // The percentage stays open so the wash can be tuned, but a 0% mix resolves to fully
    // transparent and silently removes the chart-paper texture, so require a visible one.
    final gridValues = RegExp(r'--folio-grid:([^;}]*)').allMatches(css).map((m) => m[1]!.trim());
    expect(gridValues, isNotEmpty, reason: 'the chart-paper grid token is gone');
    final tracksGreen = RegExp(r'^color-mix\(in srgb, var\(--folio-green\) [1-9]\d*%, transparent\)$');
    for (final value in gridValues) {
      expect(value, matches(tracksGreen), reason: '--folio-grid: $value does not follow the skin');
    }
    // flex: 1 0 auto inside the 100vh body column already reaches the footer; a vh floor over-reserves.
    expect(RegExp(r'\.docs-shell\s*\{[^}]*min-height:').hasMatch(css), isFalse);
    // Every class static/js/search.js builds has to be styled, or the results list falls
    // back to unstyled body text. Derived from the script rather than hardcoded, so a rename
    // on one side alone fails, and anchored so a longer selector cannot satisfy the match.
    final searchClasses = RegExp(
      r"className = '([\w-]+)'",
    ).allMatches(File(p.join(themeDir, 'static', 'js', 'search.js')).readAsStringSync()).map((m) => m[1]!).toSet();
    expect(searchClasses, containsAll(<String>['search-result', 'search-result-title', 'search-result-snippet']));
    for (final built in searchClasses) {
      expect(RegExp('\\.$built(?=[\\s,{:])').hasMatch(css), isTrue, reason: built);
    }
    expect(_declared(css, r'\.search-results', 'max-height'), '320px');
    // The cap needs its own scroll, or a 20-hit list overflows the sidebar instead of scrolling.
    expect(_declared(css, r'\.search-results', 'overflow-y'), 'auto');
    // The defect was layout, not absence: title and snippet are <span>s, so without an explicit
    // block they render inline and concatenate ("Semantic apparatusUse ordinary HTML..."), and
    // the link inherits the body underline. Selector presence alone does not hold any of that.
    for (final rule in ['search-result-title', 'search-result-snippet']) {
      final declared = _declared(css, '\\.$rule', 'display');
      expect(declared, isNotNull, reason: '$rule must declare a display');
      expect(declared, isNot('inline'), reason: '$rule renders concatenated when inline');
    }
    expect(_declared(css, r'\.search-result-link', 'text-decoration'), 'none');
    // An ancestor of the current page is marked; the class is computed in all three tree levels.
    expect(css, contains('.sidebar-link.is-active-trail'));
    // A selector that exists but declares nothing reproduces the finding exactly: the trail
    // entry renders pixel-identical to its non-trail siblings. Require a visual declaration,
    // without pinning which one, so the treatment can change but cannot become nothing.
    // Sass drops a rule with an empty body, so "declares nothing" shows up as "rule absent".
    // The trail is emitted at all three tree levels, so require a visible declaration in both
    // the top-level and the nested context - losing either returns that level to rendering
    // pixel-identical to its non-trail siblings, which is the finding verbatim.
    final trailRules = {
      for (final match in RegExp(r'([^{}]*\.is-active-trail[^{]*)\{([^}]*)\}').allMatches(css))
        match[1]!.trim(): match[2]!,
    };
    const visual = r'(color|background|box-shadow|border|font-weight|text-decoration|outline)[a-z-]*\s*:';
    for (final context in ['sidebar-tree', 'sidebar-subtree']) {
      final rules = trailRules.entries.where((e) => e.key.contains(context));
      expect(rules, isNotEmpty, reason: 'no is-active-trail rule for $context');
      expect(
        rules.every((e) => RegExp(visual).hasMatch(e.value)),
        isTrue,
        reason: '$context trail rule must declare a visible difference',
      );
    }
    // Every class the layouts append must either be selected by a rule or be a deliberate
    // default-state marker. Derived from tl:classappend rather than hardcoded, so a newly
    // appended class that nothing styles fails here instead of waiting for a review to spot it
    // (which is how is-active-trail shipped). Comparison operands are stripped: the right-hand
    // side of `== 'secondary'` is a value, not a class.
    const unstyledMarkers = {
      // The filled look is .button's own; button-primary marks the default for site authors
      // to hook, and adding a rule for it here would only restate .button.
      'button-primary',
    };
    final appended = <String>{};
    for (final layout in Directory(p.join(themeDir, 'layouts')).listSync(recursive: true).whereType<File>()) {
      for (final match in RegExp('tl:classappend="(.*?)"', dotAll: true).allMatches(layout.readAsStringSync())) {
        final operandsStripped = match[1]!.replaceAll(RegExp("==\\s*'[^']*'"), '==');
        appended.addAll(RegExp("'([a-zA-Z][\\w-]*)'").allMatches(operandsStripped).map((m) => m[1]!));
      }
    }
    expect(appended, containsAll(<String>['is-active', 'is-active-trail', 'button-secondary']));
    expect(appended, isNot(contains('secondary')), reason: 'comparison operand must not count as a class');
    for (final applied in appended.difference(unstyledMarkers)) {
      expect(RegExp('\\.$applied(?=[\\s,{:.\\[])').hasMatch(css), isTrue, reason: applied);
    }
    // Only the wrapped case sheds the inner frame — a <pre> mounted straight on the plate keeps it.
    expect(css, contains('.folio-plate .plate-frame pre'));
    expect(RegExp(r'(^|[\s,}])\.folio-plate pre\s*\{').hasMatch(css), isFalse);
    // Article code wraps rather than clipping: the SSG emits <pre> with no tabindex (WCAG 2.1.1).
    expect(_declared(css, r'(^|[\s,}])pre', 'white-space'), 'pre-wrap');
    // pre-wrap alone still scrolls on a token with no break opportunity (measured: 3281px of
    // content in a 662px box), which re-creates the unreachable scroll region F9 removed.
    expect(_declared(css, r'(^|[\s,}])pre', 'overflow-wrap'), 'break-word');
    // The rubric label heads its own line above the neighbour's title.
    expect(_declared(css, r'\.page-nav-label', 'display'), 'block');
    // Masthead navigation is small caps; the underline would fight the tracking.
    expect(_declared(css, r'\.nav-list a', 'text-decoration'), 'none');
    // The edition control and the mobile disclosure summary share the mono-caps rubric voice.
    for (final selector in ['skin-toggle', 'sidebar-toggle']) {
      expect(_declared(css, '\\.$selector[^{]*', 'text-transform'), 'uppercase', reason: selector);
    }
    // Every rule in the sheet is reachable from a layout or from authored page content.
    expect(css, isNot(contains('.sr-only')));
    expect(css, isNot(contains('search-unavailable')));

    final htmlFiles = Directory(
      config.outputDir,
    ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.html')).toList();
    // Every highlight token the build actually emits has to be a token the sheet colours,
    // or most of a code sample renders as plain body text.
    final emittedTokens = {
      for (final file in htmlFiles) ...RegExp(r'hljs-[a-z_-]+').allMatches(file.readAsStringSync()).map((m) => m[0]!),
    };
    final styledTokens = RegExp(r'\.(hljs-[a-z_-]+)').allMatches(css).map((m) => m[1]!).toSet();
    expect(emittedTokens, isNotEmpty);
    expect(emittedTokens.difference(styledTokens), isEmpty, reason: 'unstyled tokens in the built HTML');
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
    // Both enhanced controls ship hidden: with no JavaScript neither can do anything, and a
    // permanently disabled search box in the sidebar is worse than no search box.
    expect(apparatus.querySelector('.search-shell')!.attributes, contains('hidden'));
    expect(apparatus.querySelector('.search-input')!.attributes, contains('disabled'));
    expect(apparatus.querySelector('.skin-toggle')!.attributes, contains('hidden'));
    expect(apparatus.querySelector('.page-nav'), isNotNull);
    // The trail ends on the current page, inline, rather than stopping at its parent section.
    expect(apparatus.querySelectorAll('.breadcrumb-list li').map((li) => li.text.trim()), [
      'Home',
      'Documentation',
      'Semantic apparatus',
    ]);
    expect(apparatus.querySelector('.breadcrumb-list [aria-current="page"]')!.text.trim(), 'Semantic apparatus');

    final home = html_parser.parse(File(p.join(config.outputDir, 'index.html')).readAsStringSync());
    expect(home.querySelectorAll('.hero-actions a').map((link) => link.text.trim()), [
      'Open the manual',
      'Browse specimens',
    ]);
    expect(home.querySelector('.hero-actions a')!.classes, contains('button-primary'));
    expect(home.querySelectorAll('.hero-actions a').last.classes, contains('button-secondary'));
    expect(home.querySelector('.plate-caption')!.text.trim(), startsWith('Sea lavender'));
    expect(home.querySelector('.social-links')!.text, contains('Source'));
    expect(home.querySelector('.footer-text')!.text, contains('Observations arranged with Folio'));
    expect(home.querySelector('.footer-powered-by'), isNotNull);
    expect(home.querySelectorAll('link[rel="alternate"]'), hasLength(2));
  });

  test('S02 TI07 prefixed build joins same-origin assets exactly once', () async {
    final tempDir = Directory.systemTemp.createTempSync('folio_prefix_contract_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
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
    for (final asset in ['search-index.json', 'fonts/eb-garamond-latin.woff2']) {
      expect(File(p.join(config.outputDir, asset)).existsSync(), isTrue, reason: asset);
    }
  });

  test('S03/S06 TI07 template controls remove their regions', () async {
    final tempDir = Directory.systemTemp.createTempSync('folio_controls_contract_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
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
    copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
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
    final entry = File(p.join(themeDir, 'sass', 'main.scss')).resolveSymbolicLinksSync();
    final wrapper = File(p.join(tempDir.path, 'forced-dark.scss'))
      ..writeAsStringSync(bridge.bridgeWrapperSource(entry));
    final css = TrellisCss.compileSass(wrapper.path, loadPaths: bridge.sassLoadPaths, fatalImportDeprecation: true);
    expect(css, contains('--folio-paper: #111a14'));
    // A forced skin never emits the folio-dark mixin, so the code pigments have to arrive
    // through the forced-dark reassignment rather than through the media query.
    expect(css, contains('--folio-code-number: #d9a86a'));
    expect(css, contains('--folio-code-function: #97b8dd'));
    expect(css, isNot(contains('@media (prefers-color-scheme: dark)')));
    expect(css, isNot(contains(':root[data-skin=dark]')));

    final skinScript = File(p.join(themeDir, 'static', 'js', 'folio.js')).readAsStringSync();
    expect(skinScript.indexOf('sync()'), lessThan(skinScript.indexOf("button.addEventListener('click'")));
    expect(skinScript, contains("media.matches ? 'dark' : 'light'"));
    // Both scripts reveal the control they drive; the layout ships it hidden.
    expect(skinScript, contains('button.hidden = false'));
    expect(File(p.join(themeDir, 'static', 'js', 'search.js')).readAsStringSync(), contains('shell.hidden = false'));
  });

  test('S05/TI05 auto skin control follows OS only without a stored choice', () async {
    final result = await runNodeHarness('folio', p.join(themeDir, 'static', 'js', 'folio.js'));
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

  test('site-supplied logo and hero image replace the built-in artwork, prefix-joined', () async {
    Future<Document> artwork(String label, String imageSrc, String logo, {String pathPrefix = ''}) => _buildVariant(
      themeDir,
      label,
      index: (source) =>
          source.replaceFirst('hero:\n', 'hero:\n  image: {src: $imageSrc, alt: Pressed sea lavender}\n'),
      config: (source) => '$source${pathPrefix.isEmpty ? '' : '\npathPrefix: $pathPrefix\n'}'.replaceFirst(
        '  skin: auto',
        '  skin: auto\n  logo: "$logo"',
      ),
    );

    // A path written with or without its own leading slash joins pathPrefix exactly once.
    // Naive concatenation turns "/x" into "//x", which the browser resolves against a
    // host named x — a request to a foreign origin derived from site config.
    const cases = {
      'plain-prefixed': ('art/specimen.webp', 'brand/mark.svg', '/trellis/', '/trellis/'),
      'rooted-prefixed': ('/art/specimen.webp', '/brand/mark.svg', '/trellis/', '/trellis/'),
      'plain-root': ('art/specimen.webp', 'brand/mark.svg', '', '/'),
      'rooted-root': ('/art/specimen.webp', '/brand/mark.svg', '', '/'),
    };
    for (final entry in cases.entries) {
      final (imageSrc, logo, pathPrefix, expected) = entry.value;
      final home = await artwork(entry.key, imageSrc, logo, pathPrefix: pathPrefix);

      final plate = home.querySelector('.hero-plate img.engraving')!;
      expect(plate.attributes['src'], '${expected}art/specimen.webp', reason: entry.key);
      expect(plate.attributes['alt'], 'Pressed sea lavender', reason: entry.key);
      expect(home.querySelector('.hero-plate svg.engraving'), isNull, reason: 'drawn engraving must step aside');

      final logoImage = home.querySelector('.site-title img.site-logo')!;
      expect(logoImage.attributes['src'], '${expected}brand/mark.svg', reason: entry.key);
      expect(logoImage.attributes['alt'], 'Folio Field Notes', reason: entry.key);
      expect(home.querySelector('.site-title svg.site-mark'), isNull, reason: 'built-in sprout must step aside');
    }

    // Unset keys keep the theme's own artwork rather than emitting an empty <img>.
    final plain = await _buildVariant(themeDir, 'no-artwork');
    expect(plain.querySelector('.hero-plate svg.engraving'), isNotNull);
    expect(plain.querySelector('.hero-plate img.engraving'), isNull);
    expect(plain.querySelector('.site-title svg.site-mark'), isNotNull);
    expect(plain.querySelector('.site-title img.site-logo'), isNull);
  });

  test('empty lists and blank strings remove their region instead of leaving it empty', () async {
    // Truthiness is not emptiness: an empty list and a blank string are both truthy here, so a
    // bare tl:if leaves an empty ARIA landmark, an empty <figcaption>, and an empty card grid
    // sitting next to the "no entries" state it contradicts.
    final home = await _buildVariant(
      themeDir,
      'empty-regions',
      index: (source) => source
          .replaceFirst(RegExp(r'  ctas:\n(    - .*\n)+'), '  ctas: []\n')
          .replaceFirst(RegExp('  caption: .*\n'), '  caption: ""\n'),
      // Only the landing page remains, so the featured list has nothing to show.
      keepOnly: '_index.md',
    );
    expect(home.querySelector('.hero-actions'), isNull);
    expect(home.querySelector('.plate-caption'), isNull);
    expect(home.querySelector('.card-list'), isNull);
    expect(home.querySelector('.no-pages'), isNotNull);
  });

  test('the vendored face is the font the stylesheet claims, and draws what the theme emits', () async {
    await expectThemeFontContract(
      themeDir: themeDir,
      compiledCss: TrellisCss.compileSass(p.join(themeDir, 'sass', 'main.scss'), fatalImportDeprecation: true),
      // Floors sit about a tenth under the shipped size and glyph count: a face that loses a table,
      // its embedded OFL name records or a third of its glyphs fails, while trimming a few
      // codepoints does not. No instancer step runs - `wght` is the family's only axis and the
      // theme renders it - so the axis set is the file's own.
      faces: const {
        'eb-garamond-latin.woff2': (minBytes: 40 * 1024, minGlyphs: 340, axes: {'wght'}),
      },
      // Font payload is a budgeted part of every deployed site; hold it under 50KB. A vendored
      // italic would take the theme to 94,756 B, which is what this cap refuses (VENDORED.md).
      maxTotalBytes: 50 * 1024,
      // 0 of 1 faces have their unicode-range asserted, because the theme declares none. The
      // one face has no companion subset for a range to route between, so a descriptor would
      // only gate its download - worth declaring or not is a theme-authoring call nobody has
      // made. Named so the absence is visible rather than read as a check that ran.
      unicodeRangeExemptions: const {
        'eb-garamond-latin.woff2': 'declares no unicode-range; single face, no companion subset to route between',
      },
      knownGaps: const [],
      knownWeightGaps: const [],
    );
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
      'static/fonts/OFL-EB-Garamond.txt',
      'screenshots/light.png',
      'screenshots/dark.png',
    ]) {
      expect(File(p.join(themeDir, asset)).existsSync(), isTrue, reason: asset);
    }
    // Code font is the system stack the mockup uses, so no monospace file is vendored.
    expect(Directory(p.join(themeDir, 'static', 'fonts')).listSync().map((e) => p.basename(e.path)).toSet(), {
      'eb-garamond-latin.woff2',
      'OFL-EB-Garamond.txt',
    });
    // The font payload's budget, floors, axes and glyph coverage are asserted below.
    for (final screenshot in ['screenshots/light.png', 'screenshots/dark.png']) {
      final bytes = File(p.join(themeDir, screenshot)).readAsBytesSync();
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10], reason: screenshot);
      expect(_readUint32(bytes, 16), 1280, reason: screenshot);
      expect(_readUint32(bytes, 20), 800, reason: screenshot);
    }
    expect(readme, contains('<figure class="folio-plate">'));
    expect(readme, contains('<aside class="folio-sidenote">'));
    // Every content-authored class the sheet styles is documented, or it is undiscoverable.
    expect(readme, contains('plate-frame'));
    expect(readme, contains('folio-note'));
    expect(
      File(p.join(themeDir, 'static', 'fonts', 'OFL-EB-Garamond.txt')).readAsStringSync(),
      contains('EB Garamond'),
    );
    // Folio has no _code.scss; the comment used to point contributors at arbor's file.
    final base = File(p.join(themeDir, 'layouts', 'base.html')).readAsStringSync();
    expect(base, isNot(contains('_code.scss')));
    for (final reference in RegExp(r'sass/[\w/]+\.scss').allMatches(base).map((m) => m[0]!)) {
      expect(File(p.join(themeDir, reference)).existsSync(), isTrue, reason: reference);
    }
  });
}

/// Build the bundled example into its own temp directory, optionally rewriting the landing
/// page's front matter or `trellis_site.yaml` first, and return the parsed home page.
///
/// Each variant owns its output tree: reading a sibling test's build artifact would make the
/// suite order-dependent and would fail outright on a clean checkout.
Future<Document> _buildVariant(
  String themeDir,
  String label, {
  String Function(String source)? index,
  String Function(String source)? config,
  String? keepOnly,
}) async {
  final tempDir = Directory.systemTemp.createTempSync('folio_${label}_contract_');
  addTearDown(() => tempDir.deleteSync(recursive: true));
  copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
  if (keepOnly != null) {
    for (final entity in Directory(p.join(tempDir.path, 'content')).listSync()) {
      if (p.basename(entity.path) != keepOnly) entity.deleteSync(recursive: true);
    }
  }
  Directory(p.join(tempDir.path, 'themes')).createSync(recursive: true);
  Link(p.join(tempDir.path, 'themes', 'folio')).createSync(themeDir);

  if (index != null) {
    final indexFile = File(p.join(tempDir.path, 'content', '_index.md'));
    indexFile.writeAsStringSync(index(indexFile.readAsStringSync()));
  }
  final source = File(p.join(themeDir, 'example', 'trellis_site.yaml')).readAsStringSync();
  File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync(config == null ? source : config(source));

  final siteConfig = SiteConfig.load(p.join(tempDir.path, 'trellis_site.yaml'));
  final result = await TrellisSite(siteConfig).build();
  expect(result.warnings, isEmpty, reason: label);
  return html_parser.parse(File(p.join(siteConfig.outputDir, 'index.html')).readAsStringSync());
}

/// The declared value of [property] in the first rule whose selector matches [selectorPattern],
/// or null if no matching rule declares it.
///
/// Splitting on `;` and the first `:` compares whole values, so a longer value can never
/// prefix-match a shorter one. Every value-shaped hole found in this suite was that prefix:
/// `6px` inside `6px 0`, `uppercase` inside `uppercase full-width`, `pre-wrap` inside
/// `pre-wrap nowrap` (Chrome resolves that to `pre`, restoring the scrollable code block),
/// and `none` inside `none underline` (resolves to `underline`).
///
/// Scoped to the property rather than returning the first matching rule wholesale: a class
/// usually appears in an earlier grouped rule too (`.sidebar-tree, ..., .search-results`),
/// and that rule declares none of what is being asserted. Taking the first rule that declares
/// the property also keeps the base rule rather than a media-query override of it.
String? _declared(String css, String selectorPattern, String property) {
  for (final match in RegExp('$selectorPattern\\s*\\{([^}]*)\\}', multiLine: true).allMatches(css)) {
    for (final declaration in match.group(match.groupCount)!.split(';')) {
      final colon = declaration.indexOf(':');
      if (colon < 0) continue;
      if (declaration.substring(0, colon).trim() == property) return declaration.substring(colon + 1).trim();
    }
  }
  return null;
}

int _readUint32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
