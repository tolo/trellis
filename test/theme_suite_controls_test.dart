import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_site/trellis_site.dart';
import 'package:trellis_ui/trellis_ui.dart';

import '../tool/ui_gate/checks.dart' show strictPolicy;
import '../tool/ui_gate/driver.dart';
import '../tool/ui_gate/firefox.dart';
import '../tool/visual_baseline.dart';
import 'browser_reflow_probe.dart';
import 'reflow_sweep.dart' show builtPages;
import 'theme_use_support.dart';

const _adopting = {'arbor', 'folio', 'lattice', 'meadow'};
const _composed = {'lattice', 'meadow'};
const _prefixes = ['', '/trellis/'];
const _css = 'trellis-ui/trellis-ui.css';
const _js = 'trellis-ui/trellis-ui.js';

void main() {
  final repo = Directory.current.path;
  final themes = discoverThemeExamples(repo);
  late Directory builds;
  final examples = <(String, String), Directory>{};

  setUpAll(() {
    builds = (Directory('.agent_temp')..createSync()).createTempSync('suite_theme_controls_');
  });
  tearDownAll(() => builds.deleteSync(recursive: true));

  Future<Directory> outputFor(String name, [String prefix = '']) async {
    final key = (name, prefix);
    return examples[key] ??= await buildExample(
      themes.singleWhere((theme) => theme.name == name),
      into: Directory(p.join(builds.path, prefix.isEmpty ? 'root' : 'prefixed')),
      repoRoot: repo,
      pathPrefix: prefix,
    );
  }

  Future<Directory> docsOutput(String prefix) async {
    final key = ('docs', prefix);
    if (examples[key] case final output?) return output;
    final output = Directory(p.join(builds.path, prefix.isEmpty ? 'docs-root' : 'docs-prefixed')).absolute;
    final build = await Process.run('dart', [
      'run',
      p.join(repo, 'packages', 'trellis_cli', 'bin', 'trellis.dart'),
      'build',
      '--path-prefix',
      prefix,
      '--output',
      output.path,
    ], workingDirectory: p.join(repo, 'site'));
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    return examples[key] = output;
  }

  Future<ChromeDriver?> chrome() async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('theme suite controls');
      markTestSkipped('Chrome is required for rendered theme suite controls');
      return null;
    }
    final driver = await ChromeDriver.launch();
    addTearDown(driver.close);
    return driver;
  }

  for (final name in ['chrome', 'firefox']) {
    test('$name Meadow navigation hands off focus and releases the Sheet', () async {
      final browser = await _launch(name);
      if (browser == null) return;

      for (final prefix in _prefixes) {
        final server = await serveThemeOutput(await outputFor('meadow', prefix), pathPrefix: prefix);
        final home = server.baseUrl.resolve(prefix.isEmpty ? '/' : prefix);
        await browser.viewport(390, 844);
        await browser.open(home);
        await browser.pointer('.mobile-navigation [data-slot=sheet-trigger] button', click: true);
        expect(await browser.evaluate("document.querySelector('#meadow-main-menu').matches(':modal')"), isTrue);
        await _watchMeadowReturn(browser);
        final features = '${home.path}#features';
        await _tabTo(browser, '#meadow-main-menu a[href="$features"]', checkCurrent: true);
        await browser.press('Enter');
        await waitForThemeBrowser(browser, 'location.hash === "#features" && document.activeElement.id === "features"');
        expect(await browser.evaluate('document.querySelector("dialog:modal")'), isNull);
        expect(await browser.evaluate("sessionStorage.getItem('trigger-focused')"), 'no');

        await browser.open(home.resolve('about/'));
        await browser.pointer('.mobile-navigation [data-slot=sheet-trigger] button', click: true);
        await _watchMeadowReturn(browser);
        await _tabTo(browser, '#meadow-main-menu a[href="$features"]', checkCurrent: true);
        await browser.press('Enter');
        await _expectLocation(browser, home.replace(fragment: 'features'));
        expect(await browser.evaluate('document.querySelector("dialog:modal")'), isNull);
        expect(await browser.evaluate("sessionStorage.getItem('trigger-focused')"), 'no');

        await browser.viewport(839, 844);
        await browser.pointer('.mobile-navigation [data-slot=sheet-trigger] button', click: true);
        await waitForThemeBrowser(browser, 'document.querySelector("dialog:modal") !== null');
        await browser.viewport(841, 844);
        await waitForThemeBrowser(browser, 'document.querySelector("dialog:modal") === null');
        expect(
          await browser.evaluate('''
(() => {
  const link = document.querySelector('.desktop-nav a');
  link.focus();
  return link.checkVisibility() && document.activeElement === link;
})()
'''),
          isTrue,
        );
        await browser.viewport(839, 844);
        await waitForThemeBrowser(browser, '!document.querySelector("#meadow-main-menu").open');
        expect(await browser.evaluate("document.querySelector('.desktop-nav').checkVisibility()"), isFalse);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('$name Lattice moves the same sidebar across the breakpoint', () async {
      final browser = await _launch(name);
      if (browser == null) return;
      final server = await serveThemeOutput(
        await outputFor('lattice'),
        headers: {'content-security-policy': strictPolicy},
      );
      await browser.viewport(700, 844);
      await browser.open(server.baseUrl.resolve(_docs['lattice']!));
      await browser.pointer('.docs-menu-toggle', click: true);
      const panel = "document.getElementById('lattice-sidebar')";
      const selected = '$panel.querySelector("[aria-current=page]")';
      await waitForThemeBrowser(browser, "$panel.matches(':modal')");
      expect(await browser.evaluate('$selected.checkVisibility()'), isTrue);
      final titled = await browser.evaluate('$selected.textContent.trim()');
      expect(titled, 'Getting Started');
      await browser.evaluate("window.originalLink = $selected");
      await browser.viewport(701, 844);
      await waitForThemeBrowser(browser, "$panel.open && !$panel.matches(':modal')");
      expect(await browser.evaluate('$selected === window.originalLink && $selected.checkVisibility()'), isTrue);
      await browser.viewport(700, 844);
      await waitForThemeBrowser(browser, '!$panel.open');
      await browser.pointer('.docs-menu-toggle', click: true);
      await waitForThemeBrowser(browser, "$panel.matches(':modal')");
      const disclosure = '$selected.closest("details")';
      final trigger = '#lattice-sidebar details[data-slot=accordion-item] > summary';
      await _tabTo(browser, trigger, checkCurrent: true);
      await browser.press('Enter');
      await waitForThemeBrowser(browser, '!$disclosure.open && !$selected.checkVisibility()');
      await browser.press('Enter');
      await waitForThemeBrowser(browser, '$disclosure.open && $selected.checkVisibility()');
      await _tabTo(browser, '#lattice-sidebar a[href="/docs/heading-less/"]');
      await browser.press('Enter');
      await _expectLocation(browser, server.baseUrl.resolve('/docs/heading-less/'));
    });
  }

  test('Lattice gives configured header destinations one owner at both prefixes', () async {
    final browser = await chrome();
    if (browser == null) return;
    for (final prefix in _prefixes) {
      final output = await docsOutput(prefix);
      final home = prefix.isEmpty ? '/' : prefix;
      final server = await serveThemeOutput(output, pathPrefix: prefix);
      const package = 'docs/packages/trellis/';
      const gallery = 'docs/themes/gallery/';
      const reference = 'docs/ui/components/button/';
      for (final (route, currentLabel) in [
        (package, 'Packages'),
        (gallery, 'Themes'),
        (reference, 'Docs'),
        ('', null),
      ]) {
        final doc = html.parse(File(p.join(output.path, route, 'index.html')).readAsStringSync());
        final header = doc.querySelector('[data-slot=navigation-menu]')!;
        final matched = header.querySelectorAll('[aria-current=page]');
        if (currentLabel == null) {
          expect(matched, isEmpty, reason: route);
        } else {
          expect(matched.single.attributes['href'], '$home$route');
          final group = _containingDetails(matched.single);
          expect((group?.querySelector('summary') ?? matched.single).text.trim(), currentLabel);
        }
        for (final href in [package, gallery]) {
          expect(header.querySelectorAll('a[href="$home$href"]'), hasLength(1), reason: route);
        }
        expect(_containingDetails(header.querySelector('a[href="https://github.com/tolo/trellis"]')!), isNull);
        if (route == reference || route == gallery) {
          expect(doc.querySelectorAll('tl-dialog > #lattice-sidebar'), hasLength(1), reason: route);
        }
      }

      final base = server.baseUrl.resolve(home);
      await browser.probe.command('Emulation.setTouchEmulationEnabled', {'enabled': true});
      await _open(browser, base.resolve(package), width: 768);
      expect(
        await browser.evaluate(r'''
(() => {
  const targets = document.querySelectorAll(
    '.header-navigation [data-slot=navigation-menu-trigger], .header-navigation li > a'
  );
  return matchMedia('(pointer: coarse)').matches &&
    [...targets].filter(target => target.checkVisibility()).length === 5 &&
    [...targets].filter(target => target.checkVisibility())
      .every(target => target.getBoundingClientRect().height >= 44);
})()
'''),
        isTrue,
        reason: 'the 768px touch masthead keeps all five targets at least 44px tall',
      );
      await browser.probe.command('Emulation.setTouchEmulationEnabled', {'enabled': false});
      await _open(browser, base.resolve(package));
      await _tabTo(browser, '#lattice-header-2-trigger');
      await browser.press('Enter');
      expect(await browser.evaluate("document.querySelector('#lattice-header-2').matches(':popover-open')"), isTrue);
      await _tabTo(browser, '#lattice-header-2 a[href="${home}docs/packages/"]');
      await browser.press('Enter');
      await waitForThemeBrowser(browser, "location.pathname === '${home}docs/packages/'");
    }

    final standalone = html.parse(File(p.join((await outputFor('lattice')).path, 'index.html')).readAsStringSync());
    expect(_containingDetails(standalone.querySelector('[data-slot=navigation-menu] a[href="/"]')!), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Lattice keeps the argument-free sidebar override', () async {
    final into = Directory(p.join(builds.path, 'override'));
    final overrides = Directory(p.join(into.path, 'lattice', 'layouts'))..createSync(recursive: true);
    final bundled = File(p.join(repo, 'themes', 'lattice', 'layouts', 'base.html')).readAsStringSync();
    final first = bundled.indexOf('<tl:block tl:fragment="sidebar">');
    final last = bundled.indexOf('<aside class="docs-toc"', first);
    File(
      p.join(overrides.path, 'base.html'),
    ).writeAsStringSync(bundled.replaceRange(first, last, '<aside tl:fragment="sidebar">Custom sidebar</aside>'));
    final output = await buildExample(
      themes.singleWhere((theme) => theme.name == 'lattice'),
      into: into,
      repoRoot: repo,
      editConfig: (source) => source.replaceFirst(RegExp(r'  nav_links:\n(?:    -.*\n)+'), '  nav_links: []\n'),
    );
    final inner = File(p.join(output.path, _docs['lattice']!, 'index.html')).readAsStringSync();
    expect(inner, contains('Custom sidebar'));
    expect(inner, isNot(contains('id="lattice-sidebar"')));
    expect(inner, isNot(contains('id="lattice-main-menu"')), reason: 'empty navigation has no Menu button');
  });

  test('Lattice keeps an independent color toggle name and keyboard Tooltip', () async {
    final browser = await chrome();
    if (browser == null) return;
    final server = await serveThemeOutput(await outputFor('lattice'));
    await _open(browser, server.baseUrl);
    const selector = '[data-lattice-theme-toggle]';
    await _tabTo(browser, selector);
    await waitForThemeBrowser(browser, "document.getElementById('lattice-color-hint').matches(':popover-open')");
    expect(
      await browser.evaluate('''
(() => {
  const trigger = document.querySelector('$selector');
  return [trigger.getAttribute('aria-label'), trigger.getAttribute('aria-describedby')];
})()
'''),
      ['Switch to dark mode', 'lattice-color-hint'],
    );
    await browser.press('Enter');
    await _expectToggle(browser, 'lattice', _toggles['lattice']!, dark: true, saved: 'dark');
  });

  test('navigation stays keyboard reachable with JavaScript or suite assets unavailable', () async {
    final browser = await chrome();
    if (browser == null) return;
    for (final prefix in _prefixes) {
      final basePath = prefix.isEmpty ? '/' : prefix;
      for (final (name, route, output) in [
        ('lattice', _docs['lattice']!, await outputFor('lattice', prefix)),
        ('docs', 'docs/packages/trellis/', await docsOutput(prefix)),
        ('meadow', _docs['meadow']!, await outputFor('meadow', prefix)),
      ]) {
        for (final mode in ['js-off', 'suite-script', 'suite-assets']) {
          final server = await serveThemeOutput(
            output,
            pathPrefix: prefix,
            statusCodes: {
              if (mode != 'js-off') '$basePath$_js': 404,
              if (mode == 'suite-assets') '$basePath$_css': 404,
            },
          );
          final url = server.baseUrl.resolve('$basePath$route');
          await browser.probe.evaluate(url, 'true', width: 390, height: 844, disableScripts: mode == 'js-off');
          final target = switch (name) {
            'meadow' => '#meadow-main-menu a[href="$basePath#features"]',
            'docs' => '#lattice-sidebar a[href="${basePath}docs/packages/trellis/"]',
            _ => '#lattice-sidebar a[href="${basePath}docs/getting-started/"]',
          };
          if (name != 'meadow') {
            final group = name == 'docs' ? '#lattice-header-0-trigger' : '#lattice-header-1-trigger';
            await _tabTo(browser, group);
            await browser.press('Enter');
            await _tabTo(browser, '$group + div li:last-child a');
            await waitForThemeBrowser(browser, r'''
(() => {
  const link = document.activeElement;
  const rect = link.getBoundingClientRect();
  return rect.height > 0 && document.elementFromPoint(
    rect.left + rect.width / 2, rect.top + rect.height / 2
  )?.closest('a') === link;
})()
''', reason: '$name $mode the last navigation link must be visible when focused');
          }
          await _tabTo(browser, target);
          await browser.press('Enter');
          if (name == 'meadow') {
            await waitForThemeBrowser(browser, "location.pathname === '$basePath' && location.hash === '#features'");
          }
          await browser.probe.evaluate(url, 'true', width: 1440, height: 844, disableScripts: mode == 'js-off');
          final wide = name == 'meadow' ? '.desktop-nav a[href="$basePath#features"]' : target;
          await _tabTo(browser, wide);
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  for (final name in ['chrome', 'firefox']) {
    test('$name adopted home and inner routes pass whole-page CSP, axe and reflow', () async {
      final driver = await _launch(name);
      if (driver == null) return;
      final sites = <(String, Uri, String)>[];
      for (final (theme, output, inner) in [
        ('lattice', await outputFor('lattice'), _docs['lattice']!),
        ('docs', await docsOutput('/trellis/'), 'docs/packages/trellis/'),
        ('meadow', await outputFor('meadow'), _docs['meadow']!),
      ]) {
        final prefix = theme == 'docs' ? '/trellis/' : '';
        final server = await serveThemeOutput(
          output,
          pathPrefix: prefix,
          headers: {'content-security-policy': strictPolicy},
        );
        sites.add((theme, server.baseUrl.resolve(prefix.isEmpty ? '/' : prefix), inner));
      }

      final axe = File('tool/ui_gate/vendor/axe.min.js').readAsStringSync();
      final counts = <String, int>{};
      for (final dark in [false, true]) {
        expect(await driver.media(dark: dark, reducedMotion: true), isTrue);
        for (final (theme, home, inner) in sites) {
          final meadow = theme == 'meadow';
          for (final route in ['', inner]) {
            await driver.open(home.resolve(route));
            expect(await driver.media(dark: dark, reducedMotion: true), isTrue);
            expect(await driver.evaluate("matchMedia('(prefers-color-scheme: dark)').matches"), dark);
            await driver.evaluate('(() => {$axe; return true;})()');
            expect(
              await driver.evaluate(
                "performance.getEntriesByType('resource').filter(e => "
                "[location.origin + '${home.path}$_css', location.origin + '${home.path}$_js'].includes(e.name)).length",
              ),
              2,
              reason: '$theme $route assets',
            );
            if (route.isEmpty) {
              if (meadow) {
                expect(await driver.evaluate('document.querySelector("progress.meter").position'), closeTo(.78, .01));
              } else {
                expect(
                  await driver.evaluate('''
[...document.querySelectorAll('.vine-leaf')]
  .map(leaf => getComputedStyle(leaf).getPropertyValue('--origin').trim())
'''),
                  ['48px 500px', '24px 400px', '48px 310px', '72px 210px', '48px 120px', '73px 15px'],
                );
              }
            }
            for (final width in [
              390,
              768,
              1024,
              1440,
              if (meadow) ...[839, 841] else ...[700, 701],
            ]) {
              await driver.viewport(width, 844);
              await driver.evaluate('new Promise(resolve => requestAnimationFrame(() => resolve(true)))');
              final detail = '$name $theme /$route at $width ${_scheme(dark)}';
              await _expectPage(driver, detail);
              counts[theme] = (counts[theme] ?? 0) + 1;
              if (meadow && width <= 840) {
                await driver.pointer('.mobile-navigation [data-slot=sheet-trigger] button', click: true);
                await waitForThemeBrowser(driver, "document.querySelector('#meadow-main-menu').matches(':modal')");
                await _expectPage(driver, '$detail with Meadow Sheet');
                await driver.press('Escape');
              } else if (!meadow && width <= 700 && route.isNotEmpty) {
                await driver.pointer('.docs-menu-toggle', click: true);
                await waitForThemeBrowser(driver, "document.querySelector('#lattice-sidebar').matches(':modal')");
                await _expectPage(driver, '$detail with sidebar Sheet');
                await driver.press('Escape');
              }
              if (!meadow) {
                if (width <= 700) {
                  await driver.pointer('.header-navigation [data-slot=sheet-trigger] button', click: true);
                  await waitForThemeBrowser(driver, "document.querySelector('#lattice-main-menu').matches(':modal')");
                }
                const trigger = '.header-navigation [data-slot=navigation-menu-trigger]';
                await driver.evaluate("document.querySelector('$trigger').focus()");
                await driver.press('Enter');
                await waitForThemeBrowser(
                  driver,
                  "document.querySelector('.header-navigation :popover-open') !== null",
                  reason: '$detail navigation panel opened',
                );
                await _expectPage(driver, '$detail with a navigation panel');
                await driver.press('Escape');
                if (width <= 700) {
                  await driver.press('Escape');
                  await waitForThemeBrowser(driver, "!document.querySelector('#lattice-main-menu').open");
                }
              }
            }
          }
        }
      }
      expect(counts, {'docs': 24, 'lattice': 24, 'meadow': 24});
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('$name suite popups nest inside a Sheet', () async {
      final driver = await _launch(name);
      if (driver == null) return;
      for (final popup in ['tooltip', 'popover']) {
        final output = Directory(p.join(builds.path, 'nested-$name-$popup'))..createSync(recursive: true);
        final content = popup == 'tooltip'
            ? '''
              <tl-tooltip tl:replace="~{trellis-ui/tooltip :: tooltip('nested-popup', 'Explanation', 'bottom', 0)}">
                <tl:block tl:slot="trigger"><button id="nested-opener" type="button">Hint</button></tl:block>
              </tl-tooltip>'''
            : '''
              <tl-popover tl:replace="~{trellis-ui/popover :: popover('nested-popup')}">
                <tl:block tl:slot="trigger"><span id="nested-opener">Open popup</span></tl:block>
                <tl:block tl:slot="content"><p>Additional information</p></tl:block>
              </tl-popover>''';
        final render = Trellis(loader: TrellisUiLoader()).render('''
<!doctype html><html lang="en"><head><title>Nested navigation</title>
<link rel="stylesheet" href="/$_css"><script src="/$_js" defer></script></head>
<body><main><tl-dialog tl:replace="~{trellis-ui/sheet :: sheet('outer', 'right', 'Layers')}">
  <tl:block tl:slot="trigger"><button id="outer-opener" type="button">Open navigation</button></tl:block>
  <tl:block tl:slot="content"><p><a id="first-link" href="#outer-opener">First destination</a></p>$content</tl:block>
</tl-dialog></main></body></html>
''', const {});
        File(p.join(output.path, 'index.html')).writeAsStringSync(render);
        for (final url in trellisUiAssetPaths) {
          final file = File(p.join(output.path, url.substring(1)))..parent.createSync(recursive: true);
          file.writeAsBytesSync(trellisUiRespond(url)!.body);
        }
        final server = await serveThemeOutput(output, headers: {'content-security-policy': strictPolicy});
        await driver.viewport(390, 844);
        await driver.open(server.baseUrl);
        expect(await driver.media(reducedMotion: true), isTrue);
        Future<void> show() async {
          await driver.pointer('#outer-opener', click: true);
          if (popup == 'tooltip') {
            await _tabTo(driver, '#nested-opener', checkCurrent: true);
          } else {
            await driver.pointer('#nested-popup-trigger', click: true);
          }
          await waitForThemeBrowser(driver, "document.querySelector('#nested-popup:popover-open') !== null");
        }

        await show();
        expect(
          await driver.evaluate('''
(() => {
  const element = document.querySelector('#nested-popup');
  const box = element.getBoundingClientRect();
  const pointer = document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2);
  return [!!element.closest('dialog:modal'), box.width > 0, pointer.closest('#outer') !== null,
    pointer === element || element.contains(pointer) || getComputedStyle(element).pointerEvents === 'none'];
})()
'''),
          [true, true, true, true],
        );
        await driver.press('Escape');
        await waitForThemeBrowser(driver, "!document.querySelector('#nested-popup').matches(':popover-open')");
        expect(await driver.evaluate("!!document.querySelector('#outer:modal')"), isTrue);
        await driver.press('Escape');
        await waitForThemeBrowser(driver, "!document.querySelector('#outer').open");
        await show();
        const close = '#outer [data-dialog-close]';
        expect(
          await driver.evaluate('''
(() => {
  const button = document.querySelector('$close');
  const box = button.getBoundingClientRect();
  const hit = document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2);
  return {hit: hit?.outerHTML.slice(0, 160), button: button.outerHTML.slice(0, 160), x: box.x, y: box.y,
    width: box.width, height: box.height, matches: hit?.closest('$close') === button};
})()
'''),
          containsPair('matches', true),
          reason: '$name $popup Sheet close button accepts pointer input',
        );
        await driver.pointer(close, click: true);
        await waitForThemeBrowser(
          driver,
          "!document.querySelector('#outer').open && !document.querySelector('#nested-popup').matches(':popover-open')",
          reason: '$name $popup direct dismissal',
        );
        expect(await driver.evaluate('window.__trellisCsp.violations'), isEmpty, reason: '$name $popup');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  test('manifests list uses and the minimum version', () {
    expect(themes.map((theme) => theme.name), unorderedEquals([..._adopting, 'bloom', 'verdant']));
    for (final theme in themes) {
      final manifest = ThemeManifest.load(theme.themeDir);
      if (_adopting.contains(theme.name)) {
        expect(manifest.uses, ['trellis_ui'], reason: theme.name);
        expect(manifest.minTrellisVersion, _composed.contains(theme.name) ? '0.15.0' : '0.14.0', reason: theme.name);
      } else {
        expect(manifest.uses, isEmpty, reason: theme.name);
        expect(manifest.minTrellisVersion, isNot('0.14.0'), reason: theme.name);
      }
    }
  });

  test('only adopting themes ship and link the suite', () async {
    for (final prefix in _prefixes) {
      final assetBase = prefix.isEmpty ? '/' : prefix;
      for (final theme in themes) {
        final output = await outputFor(theme.name, prefix);
        final adopts = _adopting.contains(theme.name);
        final label = '${theme.name} at $assetBase';
        expect(Directory(p.join(output.path, 'trellis-ui')).existsSync(), adopts, reason: label);
        expect(Directory(p.join(output.path, 'trellis')).existsSync(), isFalse, reason: label);
        if (adopts) {
          for (final url in trellisUiAssetPaths) {
            final file = File(p.join(output.path, url.substring(1)));
            expect(file.readAsBytesSync(), trellisUiRespond(url)!.body, reason: '$label $url');
          }
        }
        final pages = builtPages(output.path);
        expect(pages, isNotEmpty, reason: label);
        for (final page in pages) {
          final document = html.parse(File(p.join(output.path, page)).readAsStringSync());
          final suiteStylesheets = document.querySelectorAll('link[href*="/trellis-ui/"]');
          final suiteScripts = document.querySelectorAll('script[src*="/trellis-ui/"]');
          if (adopts) {
            expect(suiteStylesheets.single.attributes, containsPair('href', '$assetBase$_css'), reason: '$label $page');
            expect(suiteStylesheets.single.attributes, containsPair('rel', 'stylesheet'), reason: '$label $page');
            expect(suiteScripts.single.attributes, containsPair('src', '$assetBase$_js'), reason: '$label $page');
            expect(suiteScripts.single.attributes, contains('defer'), reason: '$label $page');
          } else {
            expect(suiteStylesheets, isEmpty, reason: '$label $page');
            expect(suiteScripts, isEmpty, reason: '$label $page');
          }
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('same-origin skin files apply the saved palette before theme scripts', () async {
    final browser = await chrome();
    if (browser == null) return;
    for (final theme in _composed) {
      final toggle = _toggles[theme]!;
      final server = await serveThemeOutput(
        await outputFor(theme),
        headers: {'content-security-policy': strictPolicy},
        statusCodes: {'/js/$theme.js': 404},
      );
      await _open(browser, server.baseUrl);
      await browser.evaluate("localStorage.setItem('${toggle.key}', 'dark')");
      await _open(browser, server.baseUrl);
      expect(
        await browser.evaluate("document.documentElement.getAttribute('${toggle.rootAttribute}')"),
        'dark',
        reason: theme,
      );
      expect(await browser.evaluate("document.querySelector('${toggle.selector}').hidden"), isTrue);
      expect(await browser.evaluate('window.__trellisCsp.violations'), isEmpty);
    }
  });

  test('toggle is a suite button', () async {
    for (final MapEntry(key: name, value: toggle) in _toggles.entries) {
      final output = await outputFor(name);
      final home = html.parse(File(p.join(output.path, 'index.html')).readAsStringSync());
      final button = home.querySelector(toggle.selector)!;
      expect(button.localName, 'button', reason: name);
      expect(button.classes, contains('trellis-button'), reason: name);
      expect(button.attributes, allOf(containsPair('data-slot', 'button'), contains('hidden')), reason: name);
      expect(button.attributes['aria-label'], toggle.initialLabel, reason: name);
      expect(button.attributes['aria-pressed'], toggle.hasPressed ? 'false' : null, reason: name);
    }
  });

  test('toggle applies, persists and reports its state', () async {
    final driver = await chrome();
    if (driver == null) return;
    for (final MapEntry(key: name, value: toggle) in _toggles.entries) {
      final server = await serveThemeOutput(await outputFor(name));
      for (final dark in [false, true]) {
        await _open(driver, server.baseUrl, dark: dark);
        await driver.evaluate("localStorage.removeItem('${toggle.key}')");
        await _open(driver, server.baseUrl, dark: dark);
        await _expectToggle(driver, name, toggle, dark: dark);

        await driver.pointer(toggle.selector, click: true);
        await _expectToggle(driver, name, toggle, dark: !dark, saved: _scheme(!dark));
        await _open(driver, server.baseUrl, dark: dark);
        await _expectToggle(driver, name, toggle, dark: !dark, saved: _scheme(!dark));

        await driver.evaluate("localStorage.setItem('${toggle.key}', '${_scheme(dark)}')");
        await _open(driver, server.baseUrl, dark: !dark);
        await _expectToggle(driver, name, toggle, dark: dark, saved: _scheme(dark));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('copy button copies, reports success and failure, and fits at 390', () async {
    final driver = await chrome();
    if (driver == null) return;
    await driver.probe.preloadScript(_clipboardStub);
    final server = await serveThemeOutput(await outputFor('arbor'));
    final url = server.baseUrl.resolve(_docs['arbor']!);
    final statusByClipboardMode = <String, Object?>{};
    for (final mode in ['resolve', 'reject', 'absent']) {
      await _open(driver, url.replace(queryParameters: {'clipboard': mode}), width: 390);
      expect(
        await driver.evaluate(r'''
(() => {
  const blocks = [...document.querySelectorAll('.code-block')];
  if (!blocks.length) return false;
  const contains = (parent, child) => {
    const p = parent.getBoundingClientRect(), c = child.getBoundingClientRect();
    return c.left >= p.left && c.right <= p.right && c.top >= p.top && c.bottom <= p.bottom;
  };
  return blocks.every(block => {
    const bar = block.querySelector('.code-bar');
    const button = bar.querySelector('button[data-slot="button"]');
    return button?.classList.contains('trellis-button') && button.textContent.trim() === 'Copy' &&
      button.getAttribute('aria-label') === 'Copy code to clipboard' && contains(block, bar) &&
      contains(bar, button) && contains(bar, bar.querySelector('.code-lang'));
  });
})()
'''),
        isTrue,
        reason: mode,
      );
      final code = await driver.evaluate("document.querySelector('.code-block pre code').textContent");
      expect(code, isNotEmpty);
      await driver.evaluate(r'''
(() => {
  const button = document.querySelector('.code-bar button');
  const emptyStatuses = [...document.querySelectorAll('[role="status"]')]
    .filter(status => status.textContent.trim() === '');
  window.copyHistory = [];
  window.copyStatus = [];
  new MutationObserver(() => {
    window.copyHistory.push([button.textContent.trim(), performance.now()]);
    if (window.copyHistory.length === 1) {
      window.copyStatus = emptyStatuses.filter(status => status.isConnected)
        .map(status => status.textContent.trim()).filter(Boolean);
    }
  }).observe(button, {childList: true});
})()
''');
      await driver.pointer('.code-bar button', click: true);
      final feedback = mode == 'resolve' ? 'Copied' : 'Error';
      await waitForThemeBrowser(
        driver,
        'window.copyHistory.length === 2',
        reason: '$mode feedback/reset did not occur',
      );
      final history = (await driver.evaluate('window.copyHistory') as List).cast<List<Object?>>();
      expect(history.map((step) => step.first), [feedback, 'Copy'], reason: mode);
      expect((history[1][1] as num) - (history[0][1] as num), closeTo(1600, 150), reason: mode);
      expect(await driver.evaluate('window.clipboardCalls'), mode == 'absent' ? [] : [code], reason: mode);
      expect(
        await driver.evaluate("document.querySelector('.code-bar button').getAttribute('aria-label')"),
        'Copy code to clipboard',
        reason: mode,
      );
      statusByClipboardMode[mode] = await driver.evaluate('window.copyStatus');
    }
    expect(statusByClipboardMode, {
      'resolve': ['Code copied to clipboard.'],
      'reject': ['Could not copy code to clipboard.'],
      'absent': ['Could not copy code to clipboard.'],
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('overlapping copy actions keep the latest feedback for each button and announcement', () async {
    final driver = await chrome();
    if (driver == null) return;
    final server = await serveThemeOutput(await outputFor('arbor'));
    await _open(driver, server.baseUrl.resolve(_docs['arbor']!), width: 390);
    final states = await driver.evaluate(r'''
(async () => {
  const writes = [];
  Object.defineProperty(navigator, 'clipboard', {value: {
    writeText: () => new Promise((resolve, reject) => writes.push({resolve, reject}))
  }});
  const [first, second] = document.querySelectorAll('.code-bar button');
  const status = document.querySelector('[data-code-copy-status]');
  const state = () => [first.textContent.trim(), second.textContent.trim(), status.textContent];
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  first.click();
  first.click();
  writes[1].resolve();
  await Promise.resolve();
  writes[0].reject();
  await Promise.resolve();
  const afterStaleWrite = state();

  await delay(900);
  first.click();
  second.click();
  writes[3].resolve();
  await Promise.resolve();
  writes[2].reject();
  await Promise.resolve();
  const afterOtherButton = state();
  await delay(900);
  return [afterStaleWrite, afterOtherButton, state()];
})()
''');
    expect(states, [
      ['Copied', 'Copy', 'Code copied to clipboard.'],
      ['Error', 'Copied', 'Code copied to clipboard.'],
      ['Error', 'Copied', 'Code copied to clipboard.'],
    ]);
  });

  test('44px touch targets fit their controls at 390', () async {
    final driver = await chrome();
    if (driver == null) return;
    await driver.probe.command('Emulation.setTouchEmulationEnabled', {'enabled': true});
    final violations = <String, Object?>{};
    for (final name in _adopting) {
      final server = await serveThemeOutput(await outputFor(name));
      await _open(driver, server.baseUrl.resolve(_docs[name]!), width: 390);
      expect(await driver.evaluate("matchMedia('(pointer: coarse)').matches"), isTrue);
      if (name != 'meadow') {
        await waitForThemeBrowser(driver, _searchReady);
        await _showSearchSidebar(driver);
      }
      violations[name] = await driver.evaluate('''
(() => {
  const misses = [];
  const check = (target, frame, minimum = 44) => {
    const a = target.getBoundingClientRect(), b = frame.getBoundingClientRect();
    if (a.width < minimum || a.height < minimum || a.top < b.top ||
        a.right > b.right || a.bottom > b.bottom || a.left < b.left) {
      misses.push({target: target.className, size: [a.width, a.height], frame: [b.width, b.height]});
    }
  };
  const input = document.querySelector('$_searchInput');
  if (input) {
    check(input, input.parentElement);
    check(document.querySelector('$_search .trellis-combobox-trigger'), input.parentElement);
  }
  const buttons = document.querySelectorAll(${jsonEncode(_button(name))});
  if (!buttons.length) return ['No suite button'];
  for (const button of buttons) {
    const bar = button.closest('.code-bar');
    check(button, bar ?? button.closest('header'));
    if (bar) {
      check(bar, bar.closest('.code-block'), 0);
      check(bar.querySelector('.code-lang'), bar, 0);
    }
  }
  return misses;
})()
''');
    }
    expect(violations, {for (final name in _adopting) name: isEmpty});
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('controls follow the theme palette in both skins', () async {
    final driver = await chrome();
    if (driver == null) return;
    final suiteButton = await Trellis(
      loader: TrellisUiLoader(),
    ).renderFileFragment('trellis-ui/button', fragment: 'button', context: const {});
    for (final name in _adopting) {
      final output = await outputFor(name);
      final docs = File(p.join(output.path, _docs[name]!, 'index.html')).readAsStringSync();
      final body = RegExp(r'<article(?:\s[^>]*)?>');
      expect(body.hasMatch(docs), isTrue, reason: name);
      File(p.join(output.path, 'palette-probe.html')).writeAsStringSync(
        docs.replaceFirstMapped(body, (match) => '${match[0]}<div id="suite-default">$suiteButton</div>'),
      );
      File(p.join(output.path, 'suite-only.html')).writeAsStringSync(
        '<!doctype html><html lang="en"><link rel="stylesheet" href="/$_css">'
        '<div id="suite-default">$suiteButton</div></html>',
      );
      final server = await serveThemeOutput(output);

      final button = _button(name);
      final palette = _palettes[name]!;
      for (final dark in [false, true]) {
        final reason = '$name ${_scheme(dark)}';
        await _open(driver, server.baseUrl.resolve('suite-only.html'), dark: dark);
        final suiteColors = await driver.evaluate(_defaultButtonColors);
        await _open(driver, server.baseUrl.resolve('palette-probe.html'), dark: dark);
        expect(
          await driver.evaluate(_defaultButtonColors),
          suiteColors,
          reason: '$reason default suite button in article',
        );
        final buttonPaint =
            await driver.evaluate('''
(() => {
  const button = document.querySelector(${jsonEncode(button)});
  $_resolvedColor
  const css = getComputedStyle(button);
  return [css.backgroundColor, css.color, color('${palette.primary}'), color('${palette.onPrimary}')];
})()
''')
                as List;
        expect(
          _contrast(buttonPaint[0] as String, buttonPaint[1] as String),
          greaterThanOrEqualTo(4.5),
          reason: reason,
        );
        expect(buttonPaint.take(2), buttonPaint.skip(2), reason: reason);

        if (name == 'meadow') continue;
        await waitForThemeBrowser(driver, _searchReady);
        final border =
            await driver.evaluate('''
(() => {
  $_resolvedColor
  const input = document.querySelector('$_searchInput');
  return [getComputedStyle(input.parentElement).borderTopColor, color('${palette.border}')];
})()
''')
                as List;
        expect(border.first, border.last, reason: '$reason search border');

        await _focusSearch(driver);
        final paint =
            await driver.evaluate('''
(() => {
  $_resolvedColor
  const input = document.querySelector('$_searchInput'), popup = document.querySelector('$_search :popover-open');
  const outline = getComputedStyle(input);
  return {focused: input.matches(':focus-visible'), outline: outline.outlineStyle === 'solid' &&
    parseFloat(outline.outlineWidth) >= 2 && outline.outlineColor === color('${palette.primary}'),
    ringFits: parseFloat(outline.outlineOffset) <= -parseFloat(outline.outlineWidth) &&
      getComputedStyle(input.parentElement).boxShadow === 'none',
    foreground: getComputedStyle(popup).color, background: getComputedStyle(popup).backgroundColor,
    text: color('${palette.text}'), surface: color('${palette.surface}')};
})()
''')
                as Map;
        expect(paint['focused'], isTrue, reason: reason);
        expect(paint['outline'], isTrue, reason: reason);
        expect(paint['ringFits'], isTrue, reason: '$reason focus ring clipped at the sidebar edge');
        expect(paint['foreground'], paint['text'], reason: '$reason search result text');
        expect(paint['background'], paint['surface'], reason: '$reason search surface');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('axe finds no violation in the adopted controls', () async {
    final driver = await chrome();
    if (driver == null) return;
    final axe = File('tool/ui_gate/vendor/axe.min.js').readAsStringSync();
    for (final name in _adopting) {
      final server = await serveThemeOutput(await outputFor(name));
      for (final width in [390, 1440]) {
        for (final dark in [false, true]) {
          await _open(driver, server.baseUrl.resolve(_docs[name]!), width: width, dark: dark);
          if (name != 'meadow') await _focusSearch(driver);
          await driver.evaluate('(() => {$axe; return true;})()');
          final scopes = [if (name != 'meadow') _search, if (name == 'arbor') '.code-bar' else _button(name)];
          final violations = await driver.evaluate('''
axe.run({include: ${jsonEncode(scopes)}}, { runOnly: { type: 'tag',
  values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22a', 'wcag22aa'] } })
  .then(result => result.violations.map(({id, nodes}) => ({id, nodes: nodes.map(({target}) => target)})))
''');
          expect(violations, isEmpty, reason: '$name $width ${_scheme(dark)}');
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('strict policy permits the shipped assets and retains Folio’s TD-023 record', () async {
    final driver = await chrome();
    if (driver == null) return;
    await driver.probe.preloadScript(_clipboardStub);
    for (final name in _adopting) {
      final output = await outputFor(name);
      final route = _docs[name]!;
      final index = name == 'meadow'
          ? const []
          : jsonDecode(File(p.join(output.path, 'search-index.json')).readAsStringSync()) as List;
      final server = await serveThemeOutput(output, headers: {'content-security-policy': strictPolicy});
      final url = server.baseUrl.resolve(route);
      await _open(driver, url);
      await driver.pointer(_button(name), click: true);
      if (name == 'arbor') {
        await waitForThemeBrowser(driver, 'window.clipboardCalls.length === 1');
      } else {
        final toggle = _toggles[name]!;
        await _expectToggle(driver, name, toggle, dark: true, saved: 'dark');
      }
      if (name != 'meadow') {
        await _focusSearch(driver);
        await driver.press('Escape');
        expect(await driver.evaluate("document.querySelector('$_search :popover-open')"), isNull, reason: name);
      }
      await _expectStrictReports(driver, output, name, route);

      if (name != 'meadow') {
        final first = index.first as Map;
        final title = first['title'] as String;
        await driver.evaluate("document.querySelector('$_searchInput').select()");
        await driver.type(title);
        await waitForThemeBrowser(driver, "document.querySelectorAll('$_search [role=option]').length > 0");
        final destination =
            await driver.evaluate("document.querySelector('$_search [role=option]').dataset.value") as String;
        await driver.press('ArrowDown');
        await driver.press('Enter');
        final target = server.baseUrl.resolve(destination);
        await waitForThemeBrowser(
          driver,
          'location.href === ${jsonEncode(target.toString())} && document.readyState === "complete"',
        );
        await _expectStrictReports(driver, output, name, Uri.parse(destination).path.substring(1));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

const _search = '[data-trellis-search]';
const _searchInput = '$_search [role=combobox]';
const _searchReady = "document.querySelector('$_searchInput')?.disabled === false";
const _docs = {
  'arbor': 'docs/getting-started/',
  'folio': 'docs/apparatus/',
  'lattice': 'docs/getting-started/',
  'meadow': 'about/',
};

typedef _Palette = ({String primary, String onPrimary, String text, String surface, String border});
const _palettes = <String, _Palette>{
  'arbor': (
    primary: '--trellis-primary',
    onPrimary: '--trellis-bg',
    text: '--trellis-text',
    surface: '--trellis-surface',
    border: '--trellis-border',
  ),
  'folio': (
    primary: '--folio-green',
    onPrimary: '--folio-paper',
    text: '--folio-ink',
    surface: '--folio-surface',
    border: '--folio-rule',
  ),
  'lattice': (primary: '--leaf', onPrimary: '--on-leaf', text: '--ink', surface: '--card', border: '--lattice'),
  'meadow': (
    primary: '--meadow-primary-bg',
    onPrimary: '--meadow-primary-text',
    text: '--meadow-ink',
    surface: '--meadow-surface',
    border: '--meadow-line',
  ),
};

typedef _Toggle = ({String selector, String rootAttribute, String key, String initialLabel, bool hasPressed});
const _toggles = <String, _Toggle>{
  'folio': (
    selector: '[data-folio-skin-toggle]',
    rootAttribute: 'data-skin',
    key: 'folio-skin',
    initialLabel: 'Change color scheme',
    hasPressed: true,
  ),
  'lattice': (
    selector: '[data-lattice-theme-toggle]',
    rootAttribute: 'data-theme',
    key: 'trellis-theme',
    initialLabel: 'Switch color mode',
    hasPressed: false,
  ),
  'meadow': (
    selector: '[data-meadow-skin-toggle]',
    rootAttribute: 'data-skin',
    key: 'meadow-skin',
    initialLabel: 'Change color scheme',
    hasPressed: true,
  ),
};

String _button(String name) => name == 'arbor' ? '.code-bar button' : _toggles[name]!.selector;
String _scheme(bool dark) => dark ? 'dark' : 'light';

Future<void> _open(ChromeDriver driver, Uri url, {int width = 1440, bool dark = false}) async {
  await driver.probe.evaluate(
    url,
    'true',
    width: width,
    height: 844,
    colorScheme: _scheme(dark),
    reducedMotion: 'reduce',
  );
}

Future<void> _expectPage(GateDriver driver, String reason) async {
  expect(await driver.evaluate('window.__trellisCsp.violations'), isEmpty, reason: reason);
  expect(
    await driver.evaluate('document.documentElement.scrollWidth === document.documentElement.clientWidth'),
    isTrue,
    reason: '$reason horizontal overflow',
  );
  expect(
    await driver.evaluate('''
axe.run({runOnly: {type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22a', 'wcag22aa']}})
  .then(result => result.violations.map(({id, nodes}) => ({id, nodes: nodes.map(({target}) => target)})))
'''),
    isEmpty,
    reason: reason,
  );
}

Element? _containingDetails(Element element) {
  for (var parent = element.parent; parent != null; parent = parent.parent) {
    if (parent.localName == 'details') return parent;
  }
  return null;
}

Future<GateDriver?> _launch(String name) async {
  if (name == 'chrome' && BrowserProbe.locateChrome() == null) {
    requireChromeInCi('theme suite navigation');
    markTestSkipped('Chrome is required for theme suite navigation');
    return null;
  }
  if (name == 'firefox' && (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null)) {
    if (Platform.environment['CI'] == 'true') fail('Firefox and geckodriver are required');
    markTestSkipped('Firefox and geckodriver are required for theme suite navigation');
    return null;
  }
  final driver = name == 'chrome' ? await ChromeDriver.launch() : await FirefoxDriver.launch();
  addTearDown(driver.close);
  expect(await driver.media(reducedMotion: true), isTrue);
  return driver;
}

Future<void> _tabTo(GateDriver driver, String selector, {bool checkCurrent = false}) async {
  final active = 'document.activeElement.matches(${jsonEncode(selector)})';
  if (checkCurrent && await driver.evaluate(active) == true) return;
  final seen = <Object?>{};
  for (var i = 0; i < 140; i++) {
    await driver.press('Tab');
    if (await driver.evaluate(active) == true) return;
    seen.add(
      await driver.evaluate(
        "document.activeElement.id || document.activeElement.getAttribute('href') || document.activeElement.localName",
      ),
    );
  }
  fail('${driver.name} could not Tab to $selector. Reached: $seen');
}

Future<void> _expectLocation(GateDriver driver, Uri expected) async {
  if (driver is FirefoxDriver) {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    do {
      if (await driver.currentUrl() == expected) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    } while (DateTime.now().isBefore(deadline));
    fail('Firefox did not navigate to $expected');
  }
  await waitForThemeBrowser(driver, 'location.href === ${jsonEncode('$expected')}');
}

Future<void> _watchMeadowReturn(GateDriver driver) async {
  await driver.evaluate('''
(() => {
  sessionStorage.setItem('trigger-focused', 'no');
  document.querySelector('.mobile-navigation [data-slot=sheet-trigger] button')
    .addEventListener('focus', () => sessionStorage.setItem('trigger-focused', 'yes'), {once: true});
})()
''');
}

Future<void> _showSearchSidebar(ChromeDriver driver) async {
  if (await driver.evaluate("document.querySelector('#lattice-sidebar')?.open") == false) {
    await driver.pointer('.docs-menu-toggle', click: true);
  } else if (await driver.evaluate("document.querySelector('$_search').closest('.sidebar-disclosure')?.open") ==
      false) {
    await driver.pointer('.sidebar-toggle', click: true);
  }
}

Future<void> _focusSearch(ChromeDriver driver) async {
  await waitForThemeBrowser(driver, _searchReady);
  await _showSearchSidebar(driver);
  await driver.pointer(_searchInput, click: true);
  await driver.type('docs');
  await waitForThemeBrowser(driver, "document.querySelector('$_search :popover-open') !== null");
}

Future<void> _expectToggle(
  ChromeDriver driver,
  String name,
  _Toggle toggle, {
  required bool dark,
  String? saved,
}) async {
  final (label, edition) = switch (name) {
    'folio' => (toggle.initialLabel, dark ? 'Night edition' : 'Light folio'),
    'lattice' => (dark ? 'Switch to light mode' : 'Switch to dark mode', null),
    _ => (dark ? 'Switch to light theme' : 'Switch to dark theme', dark ? '☀' : '☾'),
  };
  expect(
    await driver.evaluate('''
(() => {
  const button = document.querySelector('${toggle.selector}');
  return [document.documentElement.getAttribute('${toggle.rootAttribute}'), button.hidden,
    button.getAttribute('aria-label'), button.getAttribute('aria-pressed'),
    localStorage.getItem('${toggle.key}'), ${edition == null ? 'null' : 'button.textContent.trim()'}];
})()
'''),
    [
      name != 'lattice' && saved == null ? '' : _scheme(dark),
      false,
      label,
      toggle.hasPressed ? '$dark' : null,
      saved,
      edition,
    ],
    reason: '$name ${_scheme(dark)} saved $saved',
  );
}

const _clipboardStub = r'''
(() => {
  window.clipboardCalls = [];
  const mode = new URL(location.href).searchParams.get('clipboard') || 'resolve';
  Object.defineProperty(navigator, 'clipboard', { value: mode === 'absent' ? undefined : {
    writeText(text) {
      window.clipboardCalls.push(text);
      return mode === 'reject' ? Promise.reject(new Error('Clipboard denied')) : Promise.resolve();
    }
  }});
})()
''';

const _resolvedColor = r'''
const color = token => {
  const probe = document.createElement('span');
  probe.style.color = 'var(' + token + ')';
  document.body.append(probe);
  const result = getComputedStyle(probe).color;
  probe.remove();
  return result;
};
''';

const _defaultButtonColors = r'''
(() => {
  const css = getComputedStyle(document.querySelector('#suite-default button'));
  return [css.backgroundColor, css.color, css.getPropertyValue('--primary').trim(),
    css.getPropertyValue('--primary-foreground').trim()];
})()
''';

double _contrast(String foreground, String background) {
  double luminance(String color) {
    final rgb = RegExp(r'^rgb\((\d+), (\d+), (\d+)\)$').firstMatch(color)!;
    double srgb(int channel) {
      final fraction = int.parse(rgb[channel]!) / 255;
      return fraction <= .04045 ? fraction / 12.92 : pow((fraction + .055) / 1.055, 2.4).toDouble();
    }

    return .2126 * srgb(1) + .7152 * srgb(2) + .0722 * srgb(3);
  }

  final a = luminance(foreground);
  final b = luminance(background);
  return (max(a, b) + .05) / (min(a, b) + .05);
}

Future<void> _expectStrictReports(ChromeDriver driver, Directory output, String theme, String route) async {
  // TD-023 allows the existing anti-FOUC script at its original source location.
  // An additional inline script, an inline style, and a blocked suite asset all fail this comparison.
  final expected = <(String, String, int)>[];
  if (theme == 'folio') {
    final toggle = _toggles[theme]!;
    final served = File(p.join(output.path, route, 'index.html')).readAsStringSync();
    final scripts = RegExp(r'<script[^>]*>([\s\S]*?)</script>').allMatches(served);
    final antiFouc = scripts.singleWhere(
      (match) => match[1]!.contains('localStorage.getItem') && match[1]!.contains(toggle.key),
    );
    final line = '\n'.allMatches(served.substring(0, antiFouc.start)).length + 1;
    await waitForThemeBrowser(driver, 'window.__trellisCsp.violations.length > 0');
    expected.add(('script-src-elem', 'inline', line));
  }
  final violations = await driver.probe.securityPolicyViolations();
  expect(
    violations.map((item) => (item['directive'], item['blocked'], item['line'])),
    expected,
    reason: '$theme /$route CSP reports $violations',
  );
}
