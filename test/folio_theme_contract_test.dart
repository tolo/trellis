import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' show Document;
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
    expect(apparatusOff, isNot(contains('.hero-plate::before')));
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
    expect(css, contains('.button-secondary'));
    // A short last card row must not leave the grid rule dangling: every card owns its own border.
    expect(RegExp(r'\.card-list\s*\{[^}]*gap: 18px').hasMatch(css), isTrue);
    expect(RegExp(r'\.doc-card\s*\{[^}]*border: 1px solid').hasMatch(css), isTrue);
    // Absent sidebar or TOC collapses its track instead of reserving a dead column.
    expect(RegExp(r'\.docs-shell\s*\{[^}]*grid-template-columns: auto minmax\(0, 1fr\) auto').hasMatch(css), isTrue);
    expect(css, contains('.breadcrumb-list'));
    expect(css, contains('.hero-plate::before'));
    // One variable face spans 400-600, so headings get real weight instead of synthesised bold,
    // and size-adjust lifts EB Garamond's small x-height to the metrics the mockup was drawn in.
    expect(RegExp(r'@font-face\s*\{[^}]*font-weight: 400 600').hasMatch(css), isTrue);
    expect(RegExp(r'@font-face\s*\{[^}]*size-adjust: 118%').hasMatch(css), isTrue);
    expect(css, isNot(contains('IBM Plex Mono')));
    // Leaf entries must not emit a bare subtree; nesting is indentation, not stacked rules.
    expect(RegExp(r'\.sidebar-subtree\s*\{[^}]*border-left').hasMatch(css), isFalse);
    expect(css, contains('.sidebar-tree > .sidebar-item > .sidebar-link'));
    // The mobile disclosure caps its own tree; an unscoped 46vh would clip the article too.
    expect(RegExp(r'\.sidebar-disclosure\[open\] > \.docs-sidebar\s*\{[^}]*max-height: 46vh').hasMatch(css), isTrue);
    // Touch targets belong to the interactive controls, not to whatever rule happens to carry 44px.
    expect(
      RegExp(r'\.nav-list a,[^{]*\.sidebar-link,[^{]*\.toc-list a\s*\{[^}]*min-block-size: 44px').hasMatch(css),
      isTrue,
    );
    // Trail and colophon links clear the 24px minimum target (WCAG 2.5.8) at every width.
    expect(
      RegExp(
        r'\.breadcrumb-list a,\s*\.social-links a,\s*\.footer-powered-by a\s*\{[^}]*padding-block: 6px;',
      ).hasMatch(css),
      isTrue,
    );
    // The hero is the mockup's: a centred two-column band, not the 830px stack it replaced.
    expect(RegExp(r'\.hero\s*\{[^}]*align-items: center').hasMatch(css), isTrue);
    expect(RegExp(r'\.hero\s*\{[^}]*min-height: 650px').hasMatch(css), isTrue);
    // The chart-paper grid tracks the active green; a literal would stay light-mode in the dark skin.
    // Percentage left open so the wash can be tuned, but a 0% mix resolves to fully
    // transparent and silently removes the chart-paper texture, so require a visible one.
    expect(RegExp(r'--folio-grid: color-mix\(in srgb, var\(--folio-green\) [1-9]\d*%').hasMatch(css), isTrue);
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
    expect(RegExp(r'\.search-results\s*\{[^}]*max-height: 320px').hasMatch(css), isTrue);
    // An ancestor of the current page is marked; the class is computed in all three tree levels.
    expect(css, contains('.sidebar-link.is-active-trail'));
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
    expect(RegExp(r'(^|[\s,}])pre\s*\{[^}]*white-space: pre-wrap').hasMatch(css), isTrue);
    // The rubric label heads its own line above the neighbour's title.
    expect(RegExp(r'\.page-nav-label\s*\{[^}]*display: block').hasMatch(css), isTrue);
    // Masthead navigation is small caps; the underline would fight the tracking.
    expect(RegExp(r'\.nav-list a\s*\{[^}]*text-decoration: none').hasMatch(css), isTrue);
    // The edition control and the mobile disclosure summary share the mono-caps rubric voice.
    for (final selector in ['skin-toggle', 'sidebar-toggle']) {
      expect(RegExp('\\.$selector[^{]*\\{[^}]*text-transform: uppercase;').hasMatch(css), isTrue, reason: selector);
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
    for (final asset in ['search-index.json', 'fonts/eb-garamond-latin.woff2']) {
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
    // A forced skin never emits the folio-dark mixin, so the code pigments have to arrive
    // through the skin partial rather than through the media query.
    expect(css, contains('--folio-code-number: #d9a86a'));
    expect(css, contains('--folio-code-function: #97b8dd'));
    expect(css, isNot(contains('@media (prefers-color-scheme: dark)')));
    expect(css, isNot(contains(":root[data-skin='dark']")));

    final skinScript = File(p.join(themeDir, 'static', 'js', 'folio.js')).readAsStringSync();
    expect(skinScript.indexOf('sync()'), lessThan(skinScript.indexOf("button.addEventListener('click'")));
    expect(skinScript, contains("media.matches ? 'dark' : 'light'"));
    // Both scripts reveal the control they drive; the layout ships it hidden.
    expect(skinScript, contains('button.hidden = false'));
    expect(File(p.join(themeDir, 'static', 'js', 'search.js')).readAsStringSync(), contains('shell.hidden = false'));
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
    // Font payload is a budgeted part of every deployed site; hold it under 50KB.
    final fontBytes = File(p.join(themeDir, 'static', 'fonts', 'eb-garamond-latin.woff2')).lengthSync();
    expect(fontBytes, lessThan(50 * 1024), reason: '$fontBytes bytes');
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
  _copyDirectory(Directory(p.join(themeDir, 'example', 'content')), Directory(p.join(tempDir.path, 'content')));
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

int _readUint32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];

Future<Map<String, dynamic>?> _runNodeHarness(String mode, String scriptPath) async {
  try {
    final harnessPath = p.join(Directory.current.path, 'test', 'theme_client_behavior_harness.js');
    final result = await Process.run('node', [harnessPath, mode, scriptPath]);
    expect(result.exitCode, 0, reason: 'theme client harness failed: ${result.stderr}');
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  } on ProcessException {
    _requireNodeInCi('the theme client behavioural harness');
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

/// Skipping a node-gated check is a local convenience; in CI it is a silent hole
/// - the run reports "All tests passed!" with [what] never executed. Fail loudly
/// there instead, so the gate cannot go green on an assertion that did not run.
void _requireNodeInCi(String what) {
  if (Platform.environment['CI'] == 'true') {
    fail('node is required in CI: $what did not run');
  }
}
