import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_site/trellis_site.dart';
import 'package:trellis_ui/trellis_ui.dart';

import '../tool/ui_gate/checks.dart' show strictPolicy;
import '../tool/ui_gate/driver.dart';
import '../tool/visual_baseline.dart';
import 'browser_reflow_probe.dart';
import 'reflow_sweep.dart' show builtPages;
import 'theme_use_support.dart';

const _adopting = {'arbor', 'folio', 'lattice', 'meadow'};
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

  test('manifests list uses and the minimum version', () {
    expect(themes.map((theme) => theme.name), unorderedEquals([..._adopting, 'bloom', 'verdant']));
    for (final theme in themes) {
      final manifest = ThemeManifest.load(theme.themeDir);
      if (_adopting.contains(theme.name)) {
        expect(manifest.uses, ['trellis_ui'], reason: theme.name);
        expect(manifest.minTrellisVersion, '0.14.0', reason: theme.name);
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
  window.copyHistory = [];
  new MutationObserver(() => window.copyHistory.push([button.textContent.trim(), performance.now()]))
    .observe(button, {childList: true});
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
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

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
        if (await driver.evaluate("document.querySelector('$_search').closest('details').open") == false) {
          await driver.pointer('.sidebar-toggle', click: true);
        }
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

  test('strict policy: only the TD-023 inline script is blocked', () async {
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

Future<void> _focusSearch(ChromeDriver driver) async {
  await waitForThemeBrowser(driver, _searchReady);
  if (await driver.evaluate("document.querySelector('.sidebar-disclosure').open") == false) {
    await driver.pointer('.sidebar-toggle', click: true);
  }
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
  if (_toggles[theme] case final toggle?) {
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
