import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';
import 'package:yaml/yaml.dart';

import '../tool/generate_ui_reference.dart';
import '../tool/ui_gate/release_policy.dart';
import 'browser_reflow_probe.dart';
import 'reflow_sweep.dart' show builtPages;

const _content = 'site/content/docs/ui/components';
const _componentRoute = 'docs/ui/components';
const _suiteCss = 'trellis-ui/trellis-ui.css';
const _suiteJs = 'trellis-ui/trellis-ui.js';
const _preview = '.ui-reference-preview';
const _tabs = 'reference-tabs';

void main() {
  final root = Directory.current.path;
  final policy = ComponentReleasePolicy.read(Directory(root));
  final data = loadYaml(File('site/data/ui_components.yaml').readAsStringSync()) as YamlMap;
  final qualified = {
    for (final item in data.values.cast<YamlMap>())
      if (item['qualified'] == true) item['name'] as String,
  };
  late Directory workspace;
  final outputs = <String, Directory>{};

  setUpAll(() async {
    workspace = Directory.systemTemp.createTempSync('trellis_ui_reference_site_');
    final cli = p.join(root, 'packages', 'trellis_cli', 'bin', 'trellis.dart');
    for (final prefix in ['', '/trellis/']) {
      final output = Directory(p.join(workspace.path, prefix.isEmpty ? 'root' : 'prefixed'));
      final build = await Process.run(Platform.resolvedExecutable, [
        cli,
        'build',
        '--path-prefix',
        prefix,
        '--output',
        output.path,
        '--verbose',
      ], workingDirectory: p.join(root, 'site'));
      expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
      expect('${build.stdout}${build.stderr}', isNot(contains('warning')), reason: prefix);
      outputs[prefix] = output;
    }
  });

  tearDownAll(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Document referencePage(String name) =>
      html.parse(File(p.join(outputs['']!.path, _componentRoute, name, 'index.html')).readAsStringSync());

  Set<String> builtComponents(Directory output) => builtPages(output.path)
      .map((path) => path.replaceAll(p.separator, '/'))
      .where((path) => path.startsWith('$_componentRoute/') && path != '$_componentRoute/index.html')
      .map((path) => path.substring('$_componentRoute/'.length).replaceFirst(RegExp(r'/index\.html$'), ''))
      .toSet();

  test('one reference page per qualified record in each deploy shape', () async {
    expect(UiReferenceGenerator(root).check(), isEmpty);
    expect(qualified, isNotEmpty);
    for (final MapEntry(key: prefix, value: output) in outputs.entries) {
      expect(builtComponents(output), qualified, reason: prefix);
      for (final path in trellisUiAssetPaths) {
        final asset = File(p.join(output.path, path.substring(1)));
        expect(asset.readAsBytesSync(), trellisUiRespond(path)!.body, reason: '$prefix:$path');
      }
      expect(Directory(p.join(output.path, 'trellis')).existsSync(), isFalse);
      final prefixForLinks = prefix.isEmpty ? '/' : prefix;
      final index = html.parse(File(p.join(output.path, _componentRoute, 'index.html')).readAsStringSync());
      final cards = index.querySelectorAll('.doc-card');
      expect(
        cards.map((card) => card.querySelector('h2 a')!.attributes['href']),
        unorderedEquals(qualified.map((name) => '$prefixForLinks$_componentRoute/$name/')),
        reason: '$prefix component index',
      );
      for (final card in cards) {
        expect(card.querySelector('p')!.text, isNot(contains('&quot;')), reason: '$prefix component index');
      }
      for (final path in builtPages(output.path)) {
        final document = html.parse(File(p.join(output.path, path)).readAsStringSync());
        final refs = document
            .querySelectorAll('[href], [src]')
            .map((element) => element.attributes['href'] ?? element.attributes['src']!)
            .where((url) => url.contains('/trellis-ui/') || url.endsWith('/ui-reference.css'));
        final componentPage =
            path.replaceAll(p.separator, '/').startsWith('$_componentRoute/') &&
            p.basename(p.dirname(path)) != 'components';
        expect(
          refs,
          unorderedEquals([
            '$prefixForLinks$_suiteCss',
            '$prefixForLinks$_suiteJs',
            if (componentPage) '${prefixForLinks}ui-reference.css',
          ]),
          reason: '$prefix:$path',
        );
      }
      final links = await Process.run(Platform.resolvedExecutable, [
        p.join(root, 'tool', 'link_check.dart'),
        output.path,
        if (prefix.isNotEmpty) ...['--base-path', prefix],
      ]);
      expect(links.exitCode, 0, reason: '${links.stdout}${links.stderr}');
      expect(links.stdout, contains('0 broken'), reason: prefix);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'each page states its fragments, slots, attribute target, part classes and gate results from the generated data',
    () {
      final names = builtComponents(outputs['']!);
      expect(names, unorderedEquals(qualified));
      for (final component in names) {
        final inventory = data[component] as YamlMap;
        final document = referencePage(component);
        final fragments = document.querySelectorAll('.ui-reference-fragment');
        final expectedFragments = (inventory['fragments'] as YamlList).cast<YamlMap>();
        expect(fragments, hasLength(expectedFragments.length), reason: component);
        for (final (i, fragment) in expectedFragments.indexed) {
          final node = fragments[i];
          final signature = 'trellis-ui/$component :: ${fragment['signature']}';
          expect(node.querySelector('h3 code')!.text, signature);
          expect(_texts(node, '.ui-reference-parameters code'), fragment['parameters'], reason: signature);
          expect(_texts(node, '.ui-reference-slots code'), fragment['slots'], reason: signature);
          final targets = (fragment['attribute_targets'] as YamlList).cast<YamlMap>();
          expect(_texts(node, '.ui-reference-targets code'), [
            for (final target in targets) ...[target['tag'], if (target['part'] != null) target['part']],
          ], reason: signature);
        }
        expect(_texts(document, '.ui-reference-parts code'), inventory['part_classes'], reason: component);
        final qualification = document.querySelector('.ui-reference-qualification')!;
        expect(
          qualification.querySelector('p')!.text.startsWith('Supported.'),
          inventory['supported'],
          reason: component,
        );
        final items = qualification.querySelectorAll('.ui-reference-gate > li');
        final expectedItems = (inventory['items'] as YamlList).cast<YamlMap>();
        expect(items, hasLength(expectedItems.length), reason: component);
        for (final (i, item) in expectedItems.indexed) {
          final row = items[i];
          final reason = '$component:${item['name']}';
          expect(row.querySelector('code')!.text, item['name'], reason: reason);
          expect(row.querySelector('strong')!.text, item['status'], reason: reason);
          expect(_texts(row, 'ul li'), [
            for (final browser in (item['browsers'] as YamlList).cast<YamlMap>())
              '${browser['name']} ${browser['status']}${browser['unsupported'] == true ? ' (unsupported)' : ''}',
          ], reason: reason);
        }
        expect(_texts(document, 'h2, h3'), containsAll(['Tokens', 'Keyboard interaction', 'Accessibility notes']));
      }
    },
  );

  test("each page's live example source appears in its page", () {
    for (final component in builtComponents(outputs['']!)) {
      final slug = 'ui_${component.replaceAll('-', '_')}';
      final markdown = File('$_content/$component.md').readAsStringSync();
      final tags = RegExp(r'^<!-- tl:(ui_\w+) -->$', multiLine: true).allMatches(markdown).map((match) => match[1]);
      expect(tags, [slug], reason: component);
      final template = html
          .parse(File('site/layouts/shortcodes/$slug.html').readAsStringSync())
          .querySelector(_preview)!;
      final source = _normalize(template.innerHtml);
      expect(_invocations(template), isNotEmpty, reason: component);
      final document = referencePage(component);
      final fences = _texts(document, 'pre code').map((code) => _normalize(html.parseFragment(code).outerHtml));
      expect(fences, contains(source), reason: component);
      final wells = document.querySelectorAll(_preview);
      expect(wells, hasLength(1), reason: component);
      final preview = wells.single;
      expect(_invocations(preview), isEmpty, reason: component);
      expect(preview.querySelectorAll('[class*="trellis-$component"]'), isNotEmpty, reason: component);
      expect(
        preview
            .querySelectorAll('*')
            .expand((el) => el.attributes.keys)
            .where((key) => key.toString().startsWith('hx-')),
        isEmpty,
        reason: component,
      );
      final ids = preview.querySelectorAll('[id]').map((el) => el.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: component);
    }
    if (builtComponents(outputs['']!).contains('table')) {
      expect(_texts(referencePage('table'), '$_preview tbody td'), containsAll(['Northfield Studio', 'Pending']));
    }
  });

  test('tokens a page lists exist in the shipped stylesheet', () {
    final css = utf8.decode(trellisUiRespond('/$_suiteCss')!.body);
    final declared = RegExp(r'(--[\w-]+)\s*:').allMatches(css).map((match) => match[1]).toSet();
    for (final name in builtComponents(outputs['']!)) {
      final markdown = File('$_content/$name.md').readAsStringSync();
      final frontMatter = loadYaml(markdown.split('---')[1]) as YamlMap;
      final tokens = (frontMatter['tokens'] as YamlList).cast<String>();
      expect(tokens, isNotEmpty, reason: name);
      expect(_texts(referencePage(name), '.ui-reference-tokens code'), tokens, reason: name);
      expect(declared, containsAll(tokens), reason: name);
    }
  });

  test("the guide's wiring equals the README's and its classes exist", () {
    final guide = html.parse(File(p.join(outputs['']!.path, 'docs', 'ui', 'guide', 'index.html')).readAsStringSync());
    final readme = File('packages/trellis_ui/README.md').readAsStringSync();
    final snippets = _texts(guide, 'pre code');
    for (final framework in ['Shelf', 'Relic', 'Dart Frog']) {
      final snippet = RegExp('### $framework\n\n```dart\n([\\s\\S]*?)```').firstMatch(readme)![1]!;
      expect(snippets, contains(_normalize(snippet)), reason: framework);
    }
    final css = utf8.decode(trellisUiRespond('/$_suiteCss')!.body);
    final classes = RegExp(r'\btrellis-[a-z][a-z0-9-]*\b')
        .allMatches(_normalize(guide.querySelector('.doc-content')!.text))
        .map((match) => match[0]!)
        .where((name) => !{'trellis-ui', 'trellis-ui-css', 'trellis-ui-js'}.contains(name))
        .toSet();
    expect(
      classes,
      containsAll([
        if (!policy.isWithdrawn('button')) 'trellis-button',
        if (!policy.isWithdrawn('card')) 'trellis-card',
      ]),
    );
    for (final name in classes) {
      expect(css, matches(RegExp('\\.$name(?![a-z0-9-])')), reason: name);
    }
    expect(
      _texts(guide, 'h2'),
      containsAll(['Add the package', 'Apply a shadcn theme block', 'Port another shadcn style']),
    );
    expect(_texts(guide, '.doc-content code'), containsAll(['cn-', 'trellis-', 'dart pub add trellis_ui']));
  });

  test('live examples operate', () async {
    final browser = await _startChrome('Trellis UI live reference examples');
    if (browser == null) return;
    final server = await StaticSiteServer.serve(outputs['']!);
    addTearDown(server.close);
    final errors = <Object?>[];
    final subscription = browser.events.listen((event) {
      final params = event['params'] as Map?;
      final error = switch (event['method']) {
        'Runtime.exceptionThrown' => params?['exceptionDetails'],
        'Runtime.consoleAPICalled' when params?['type'] == 'error' => params?['args'],
        'Log.entryAdded' when (params?['entry'] as Map?)?['level'] == 'error' => params?['entry'],
        _ => null,
      };
      if (error != null) errors.add(error);
    });
    addTearDown(subscription.cancel);
    await browser.command('Runtime.enable');
    await browser.command('Log.enable');

    Future<Object?> example(String page, String inspect) => browser.evaluate(
      server.baseUrl.resolve('/$_componentRoute/$page/'),
      inspect,
      width: 1440,
      height: 900,
      reducedMotion: 'reduce',
    );
    expect(
      await example('dialog', r'''(() => {
      const opener = document.querySelector('.ui-reference-preview [data-slot="dialog-trigger"] button');
      opener.click();
      const dialog = document.querySelector('#reference-dialog');
      const opened = dialog.matches(':modal') && dialog.contains(document.activeElement);
      dialog.querySelector('[data-dialog-close]').click();
      return [opened, !dialog.open, document.activeElement === opener, typeof window.htmx];
    })()'''),
      [true, true, true, 'undefined'],
    );
    expect(
      await example('dropdown-menu', r'''(async () => {
      const trigger = document.querySelector('#reference-menu-trigger');
      const popup = document.getElementById(trigger.getAttribute('popovertarget'));
      // The suite syncs aria-expanded and focus in the native toggle task.
      const toggled = new Promise(resolve => popup.addEventListener('toggle', resolve, {once: true}));
      trigger.click();
      await toggled;
      return [trigger.getAttribute('aria-expanded'), document.activeElement.getAttribute('role'), typeof window.htmx];
    })()'''),
      ['true', 'menuitem', 'undefined'],
    );
    expect(
      await example('tabs', '''(() => {
      document.querySelector('#$_tabs-tab-billing').click();
      return [
        getComputedStyle(document.querySelector('#$_tabs-panel-billing')).display !== 'none',
        getComputedStyle(document.querySelector('#$_tabs-panel-account')).display === 'none',
        typeof window.htmx,
      ];
    })()'''),
      [true, true, 'undefined'],
    );
    if (!policy.isWithdrawn('tooltip')) {
      expect(
        await example('tooltip', r'''(() => {
      const control = document.querySelector('#reference-mode');
      const hint = document.querySelector('#reference-mode-hint');
      control.focus();
      const open = hint.matches(':popover-open') && hint.getBoundingClientRect().height > 0;
      const stillFocused = document.activeElement === control;
      control.blur();
      return [open, stillFocused, !hint.matches(':popover-open'), control.getAttribute('aria-describedby')];
    })()'''),
        [true, true, true, 'reference-mode-hint'],
      );
    }
    if (!policy.isWithdrawn('button')) {
      expect(
        await example('button', r'''(() => {
      const button = document.querySelector('.ui-reference-preview .trellis-button');
      const swatch = document.createElement('span');
      swatch.style.backgroundColor = 'var(--primary)';
      button.parentElement.appendChild(swatch);
      return [getComputedStyle(button).backgroundColor === getComputedStyle(swatch).backgroundColor, typeof window.htmx];
    })()'''),
        [true, 'undefined'],
      );
    }
    const skin = '''new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(() =>
      resolve([document.documentElement.dataset.theme,
        document.querySelector('.ui-reference-preview').classList.contains('dark')]))))''';
    expect(await browser.evaluateHere(skin, colorScheme: 'dark'), ['dark', true]);
    await browser.evaluateHere("document.querySelector('[data-lattice-theme-toggle]').click()");
    expect(await browser.evaluateHere(skin), ['light', false]);
    expect(errors, isEmpty);
  });

  test('Popover reference preserves the suite title typography inside an open panel', () async {
    final browser = await _startChrome('Trellis UI Popover reference typography');
    if (browser == null) return;
    final site = await StaticSiteServer.serve(outputs['']!);
    addTearDown(site.close);
    final styles = await browser.evaluate(
      site.baseUrl.resolve('/$_componentRoute/popover/'),
      r"""(async () => {
        const trigger = document.querySelector('#reference-options-trigger');
        const panel = document.querySelector('#reference-options');
        const opened = new Promise(resolve => panel.addEventListener('toggle', resolve, {once: true}));
        trigger.click();
        await opened;
        const title = getComputedStyle(panel.querySelector('.trellis-popover-title'));
        const body = getComputedStyle(panel);
        return [title.fontFamily === body.fontFamily, title.fontSize === body.fontSize,
          title.lineHeight === body.lineHeight, title.fontWeight];
      })()""",
      width: 390,
      height: 844,
    );
    expect(styles, [true, true, true, '500']);
  });

  test('the docs page leaves each preview as the suite renders it', () async {
    final browser = await _startChrome('Trellis UI reference style isolation');
    if (browser == null) return;
    final docs = await StaticSiteServer.serve(outputs['']!);
    addTearDown(docs.close);
    final bareDir = Directory(p.join(workspace.path, 'bare'))..createSync();
    final bare = await StaticSiteServer.serve(bareDir);
    addTearDown(bare.close);
    for (final asset in [_suiteCss, _suiteJs]) {
      final target = File(p.join(bareDir.path, asset))..createSync(recursive: true);
      File(p.join(outputs['']!.path, asset)).copySync(target.path);
    }
    const escape = HtmlEscape(HtmlEscapeMode.attribute);
    final barePage = File(p.join(bareDir.path, 'index.html'));
    final differences = <String>{};
    for (final component in builtComponents(outputs['']!)) {
      for (final skin in ['light', 'dark']) {
        final expectedDark = skin == 'dark';
        Future<Map<String, dynamic>> measure(Uri url) async =>
            (await browser.evaluate(
                      url,
                      _appearanceSnapshot,
                      width: 1440,
                      height: 900,
                      colorScheme: skin,
                      reducedMotion: 'reduce',
                    )
                    as Map)
                .cast<String, dynamic>();
        final actual = await measure(docs.baseUrl.resolve('/$_componentRoute/$component/'));
        expect(actual['dark'], expectedDark, reason: '$component/$skin');
        expect(actual['tokens'], isNotEmpty, reason: '$component/$skin suite :root declarations');
        final modalFocus = component == 'dialog' ? await _dialogFocusAppearance(browser) : null;
        barePage.writeAsStringSync(
          '<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="/$_suiteCss">'
          '<script src="/$_suiteJs" defer></script>'
          '<body style="${escape.convert(actual['inherited'] as String)}">${actual['markup']}</body>',
        );
        final expected = await measure(bare.baseUrl);
        if (modalFocus != null) {
          expect(modalFocus, await _dialogFocusAppearance(browser), reason: '$component/$skin native focus paint');
        }
        expect(actual['tokens'], expected['tokens'], reason: '$component/$skin suite :root declarations');
        expect(actual['backdrop'], expected['backgroundToken'], reason: '$component/$skin preview backdrop');
        final elements = (actual['elements'] as Map).cast<String, Map>();
        final bareElements = (expected['elements'] as Map).cast<String, Map>();
        expect(elements, isNotEmpty, reason: '$component/$skin');
        expect(elements.keys, unorderedEquals(bareElements.keys), reason: '$component/$skin');
        for (final entry in elements.entries) {
          final expectedProperties = bareElements[entry.key]!;
          for (final property in entry.value.entries) {
            final reference = expectedProperties[property.key];
            if (property.value != reference) {
              differences.add(
                '$component/$skin ${entry.key} ${property.key}: docs ${property.value}, suite $reference',
              );
            }
          }
        }
      }
    }
    expect(differences, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the example table scrolls locally on narrow screens and fits desktop', () async {
    if (policy.isWithdrawn('table')) {
      for (final output in outputs.values) {
        expect(builtComponents(output), isNot(contains('table')));
      }
      return;
    }
    final browser = await _startChrome('Trellis UI reference table reflow');
    if (browser == null) return;
    final site = await StaticSiteServer.serve(outputs['']!);
    addTearDown(site.close);
    final route = site.baseUrl.resolve('/$_componentRoute/table/');
    const scrollsInside = r'''(() => {
      const scroll = document.querySelector('.ui-reference-preview [data-slot="table-container"]');
      scroll.scrollLeft = 64;
      return [document.documentElement.scrollWidth === document.documentElement.clientWidth, scroll.scrollLeft > 0];
    })()''';
    expect(await browser.evaluate(route, scrollsInside, width: 390, height: 844), [true, true]);
    expect(await browser.evaluateHere(scrollsInside, width: 1440, height: 800), [true, false]);
  });
}

Future<BrowserProbe?> _startChrome(String what) async {
  if (BrowserProbe.locateChrome() == null) {
    requireChromeInCi(what);
    markTestSkipped('no Chrome/Chromium found');
    return null;
  }
  final browser = await BrowserProbe.launch();
  addTearDown(browser.close);
  return browser;
}

Future<List<Object?>> _dialogFocusAppearance(BrowserProbe browser) async {
  expect(
    await browser.evaluateHere(r'''(() => {
    document.querySelector('.ui-reference-preview [data-slot="dialog-trigger"] button').click();
    return document.querySelector('#reference-dialog').matches(':modal');
  })()'''),
    isTrue,
  );
  const focusPaint = r'''(() => {
    const target = document.activeElement;
    const css = getComputedStyle(target);
    return [
      target.id || target.textContent.trim(), target.matches(':focus-visible'),
      css.borderTopLeftRadius, css.outlineStyle, css.outlineWidth, css.outlineOffset, css.boxShadow,
    ];
  })()''';
  final autofocus = await browser.evaluateHere(focusPaint) as List<Object?>;
  expect(autofocus.take(2), ['reference-profile-name', true]);
  for (final type in ['keyDown', 'keyUp']) {
    await browser.command('Input.dispatchKeyEvent', {
      'type': type,
      'key': 'Tab',
      'code': 'Tab',
      'windowsVirtualKeyCode': 9,
    });
  }
  final tabFocus = await browser.evaluateHere(focusPaint) as List<Object?>;
  expect(tabFocus.take(2), ['Done', true]);
  return [autofocus, tabFocus];
}

const _appearanceSnapshot = r'''(() => {
  const preview = document.querySelector('.ui-reference-preview');
  const previewStyle = getComputedStyle(preview);
  const suite = [...document.styleSheets].find(sheet => sheet.href?.endsWith('/trellis-ui/trellis-ui.css'));
  const tokens = new Set();
  const collect = rules => {
    for (const rule of rules) {
      if (rule.selectorText?.split(',').some(selector => selector.trim() === ':root')) {
        for (const name of rule.style) if (name.startsWith('--')) tokens.add(name);
      }
      if (rule.cssRules) collect(rule.cssRules);
    }
  };
  collect(suite.cssRules);
  const sides = ['top', 'right', 'bottom', 'left'];
  const props = [
    'display', 'border-top-left-radius', 'border-top-right-radius', 'border-bottom-right-radius',
    'border-bottom-left-radius', 'background-color', 'box-shadow', 'opacity', 'text-decoration-line',
    'text-decoration-color', 'text-decoration-style', 'text-decoration-thickness', 'list-style-type',
    'list-style-position', 'list-style-image', 'row-gap', 'column-gap', 'table-layout',
    ...sides.flatMap(side => [
      'padding-' + side, 'margin-' + side, 'border-' + side + '-width',
      'border-' + side + '-style', 'border-' + side + '-color',
    ]),
    ...tokens,
  ];
  const path = element => {
    const trail = [];
    for (let node = element; node !== preview; node = node.parentElement) {
      trail.unshift(node.localName + '[' + [...node.parentElement.children].indexOf(node) + ']');
    }
    return trail.join('/');
  };
  const elements = {};
  for (const element of preview.querySelectorAll('[class*="trellis-"]')) {
    if (![...element.classList].some(name => name.startsWith('trellis-'))) continue;
    const css = getComputedStyle(element);
    elements[path(element)] = Object.fromEntries(props.map(prop => [prop, css.getPropertyValue(prop).trim()]));
  }
  const inherited = ['font-size', 'font-family', 'font-style', 'font-weight', 'line-height', 'letter-spacing', 'color']
    .map(prop => prop + ':' + previewStyle.getPropertyValue(prop)).join(';');
  const swatch = document.createElement('span');
  swatch.style.backgroundColor = 'var(--background)';
  preview.appendChild(swatch);
  const backgroundToken = getComputedStyle(swatch).backgroundColor;
  swatch.remove();
  return {
    dark: preview.classList.contains('dark'),
    backdrop: previewStyle.backgroundColor,
    backgroundToken,
    inherited: 'margin:0;width:' + previewStyle.width + ';' + inherited,
    markup: preview.outerHTML,
    tokens: [...tokens].sort(),
    elements,
  };
})()''';

List<String> _texts(Node node, String selector) {
  final elements = node is Document ? node.querySelectorAll(selector) : (node as Element).querySelectorAll(selector);
  return elements.map((element) => _normalize(element.text)).toList();
}

Iterable<String?> _invocations(Element node) =>
    node.querySelectorAll(r'[tl\:replace]').map((element) => element.attributes['tl:replace']);

String _normalize(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');
