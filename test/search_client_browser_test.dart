import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/ui_gate/checks.dart' show strictPolicy;
import '../tool/ui_gate/driver.dart';
import '../tool/ui_gate/firefox.dart';
import '../tool/visual_baseline.dart';
import 'browser_reflow_probe.dart';
import 'reflow_sweep.dart' show builtPages;
import 'theme_use_support.dart';
import 'ui_gate_test_support.dart';

const _shell = '[data-trellis-search]';
const _input = '$_shell [role=combobox]';
const _option = '$_shell [role=option]';
const _route = 'docs/';
const _prefixes = {'arbor': '', 'folio': '', 'lattice': '/trellis/'};
const _searchReady =
    "document.querySelector('$_shell')?.hidden === false && "
    "document.querySelector('$_input')?.disabled === false";

void main() {
  final repo = Directory.current.path;
  final themes = discoverThemeExamples(repo).where((example) => _prefixes.containsKey(example.name)).toList();
  late Directory scratch;
  final outputs = <String, Directory>{};

  setUpAll(() async {
    scratch = (Directory('.agent_temp')..createSync()).createTempSync('search_client_browser_');
    for (final theme in themes) {
      outputs[theme.name] = await buildExample(theme, into: scratch, repoRoot: repo, pathPrefix: _prefixes[theme.name]);
    }
  });

  tearDownAll(() {
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
  });

  for (final theme in themes) {
    test('typing lists matches and Enter or click opens one in ${theme.name}', () async {
      await forBrowsers((driver) async {
        await driver.viewport(1440, 460);
        final output = outputs[theme.name]!;
        final prefix = _prefixes[theme.name]!;
        final index = _originalIndex(output);
        expect(index, hasLength(greaterThanOrEqualTo(2)), reason: theme.name);
        final urls = [for (final (i, page) in index.take(2).indexed) "${page['url']}?selected=$i#title"];
        final matches = [
          for (var i = 0; i < 24; i++)
            {
              'title': 'Alpha result $i',
              'summary': 'Some BRAVO',
              'content': 'About Charlie',
              'tags': ['DELTA'],
              'url': urls[i % urls.length],
            },
        ];
        final entries = [
          // Put decoys first so the cap cannot hide a faulty match.
          for (final field in ['title', 'summary', 'content', 'tags'])
            {...matches.first, field: field == 'tags' ? <String>[] : 'decoy'},
          ...matches,
        ];
        final page = _copyDocsPage(
          output,
          'search-probe.html',
          (source) => _indexAt(source, '${prefix.isEmpty ? '/' : prefix}probe-index.json'),
        );
        File(p.join(output.path, 'probe-index.json')).writeAsStringSync(jsonEncode(entries));
        final server = await serveThemeOutput(output, pathPrefix: prefix);
        final origin = server.baseUrl;
        final url = origin.resolve('$prefix$page');
        final client = File(p.join(output.path, 'trellis-search.js')).readAsStringSync();
        expect(client, isNot(_externalAsset));

        Future<void> search() async {
          driver.requests.clear();
          await driver.open(url);
          await waitForThemeBrowser(driver, _searchReady, reason: '${theme.name} search did not load');
          expect(driver.requests, contains(origin.resolve('${prefix}probe-index.json').toString()));
          expect(
            driver.requests.where((request) => request.startsWith('http')),
            everyElement(startsWith(origin.toString())),
          );
          await driver.pointer(_input, click: true);
          await driver.type('dELTa alpha CHARLIE bravo');
          await waitForThemeBrowser(driver, "document.querySelectorAll('$_option').length === 20");
          expect(
            await driver.evaluate(r'''
(() => {
  const input = document.querySelector('[data-trellis-search] [role=combobox]');
  const list = document.getElementById(input.getAttribute('aria-controls'));
  const popup = list.closest(':popover-open');
  const rect = popup.getBoundingClientRect();
  const option = getComputedStyle(list.firstElementChild);
  const scrolls = [list, popup].some(element =>
    getComputedStyle(element).overflowY === 'auto' && element.scrollHeight > element.clientHeight);
  return {titles: [...list.children].map(option => option.textContent),
    focus: input === document.activeElement, expanded: input.getAttribute('aria-expanded'),
    scrolls,
    styled: option.display !== 'inline' && parseFloat(option.paddingInlineStart) >= 4 && option.textDecorationLine === 'none',
    fits: rect.left >= 0 && rect.top >= 0 && rect.right <= innerWidth && rect.bottom <= innerHeight};
})()
'''),
            {
              'titles': [for (var i = 0; i < 20; i++) 'Alpha result $i'],
              'focus': true,
              'expanded': 'true',
              'scrolls': true,
              'styled': true,
              'fits': true,
            },
            reason: '${driver.name} ${theme.name}',
          );
        }

        await search();
        await driver.press('Enter');
        expect(await driver.evaluate('location.href'), url.toString(), reason: 'Enter without a highlight');
        for (var i = 0; i < 2; i++) {
          await driver.press('ArrowDown');
          expect(
            await driver.evaluate('''
(() => {
  const input = document.querySelector('$_input');
  const option = document.querySelectorAll('$_option')[$i];
  return input === document.activeElement && input.getAttribute('aria-activedescendant') === option.id &&
    option.getAttribute('aria-selected') === 'true';
})()
'''),
            isTrue,
            reason: '${driver.name} ${theme.name} ArrowDown index $i',
          );
        }
        await driver.press('Enter');
        await _expectNavigation(driver, origin.resolve(urls[1]));

        await search();
        await driver.evaluate("document.querySelector('$_input').select()");
        await driver.type('zzz no match');
        await waitForThemeBrowser(
          driver,
          "document.querySelector('$_shell [role=status]').textContent === 'No results'",
        );
        expect(await driver.evaluate("document.querySelector('$_shell :popover-open').innerText.trim()"), 'No results');
        await search();
        await driver.pointer('$_option:nth-child(2)', click: true);
        await _expectNavigation(driver, origin.resolve(urls[1]));
      });
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  group('docs command palette', () {
    const trigger = '.site-header .search-trigger';
    const query = '#lattice-command-query';
    const modal = "document.getElementById('lattice-command').matches(':modal')";
    const resultStatus = "document.querySelector('#lattice-command tl-combobox [role=status]').textContent";
    const indexPath = 'indexes/docs/search.json';
    const clientPath = 'indexes/docs/trellis-search.js';

    Future<Directory> docsOutput(String name, String prefix, {String Function(String)? editConfig}) async {
      final site = Directory(p.join(scratch.path, 'docs-$name')).absolute..createSync();
      var config = File(p.join(repo, 'site', 'trellis_site.yaml')).readAsStringSync();
      config = config.replaceFirst(
        'theme: ../../themes/lattice',
        'theme: ${jsonEncode(p.relative(p.join(repo, 'themes', 'lattice'), from: p.join(site.path, 'themes')))}',
      );
      for (final directory in ['content', 'layouts', 'static', 'data']) {
        final source = Directory(p.join(repo, 'site', directory));
        for (final file in source.listSync(recursive: true, followLinks: false).whereType<File>()) {
          final destination = File(p.join(site.path, directory, p.relative(file.path, from: source.path)));
          destination.parent.createSync(recursive: true);
          file.copySync(destination.path);
        }
      }
      config = config.replaceFirst('search:\n', 'search:\n  output: $indexPath\n');
      File(p.join(site.path, 'trellis_site.yaml')).writeAsStringSync(editConfig?.call(config) ?? config);
      final build = await Process.run(Platform.resolvedExecutable, [
        'run',
        p.join(repo, 'packages', 'trellis_cli', 'bin', 'trellis.dart'),
        'build',
        '--path-prefix',
        prefix,
      ], workingDirectory: site.path);
      expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
      return Directory(p.join(site.path, 'output'));
    }

    Future<void> shortcut(GateDriver driver) => switch (driver) {
      ChromeDriver() => driver.pressShortcut('k', command: Platform.isMacOS),
      FirefoxDriver() => driver.pressShortcut('k', command: Platform.isMacOS),
      _ => throw StateError('Unexpected docs browser'),
    };

    Future<void> checkVisiblePalette(GateDriver driver) async {
      expect(
        await driver.evaluate(r'''(() => {
        const panel = document.getElementById('lattice-command').getBoundingClientRect();
        const popup = document.getElementById('lattice-command-query-popup');
        const inside = rect => rect.left >= 0 && rect.right <= innerWidth && rect.top >= 0 && rect.bottom <= innerHeight;
        return document.documentElement.scrollWidth <= innerWidth && inside(panel) &&
          (!popup.matches(':popover-open') || inside(popup.getBoundingClientRect()));
      })()'''),
        isTrue,
        reason: '${driver.name} palette viewport geometry',
      );
      final axe = File('tool/ui_gate/vendor/axe.min.js').readAsStringSync();
      await driver.evaluate('(() => {$axe; return true;})()');
      final findings = await driver.evaluate(
        r'''axe.run(document.getElementById('lattice-command'), {
        runOnly: {type:'tag', values:['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']}
      }).then(result => result.violations.map(issue => issue.id + ': ' + issue.nodes.map(node => node.target.join(' ')).join(', ')))''',
      );
      expect(findings, isEmpty, reason: '${driver.name} open palette WCAG checks');
    }

    Future<void> ready(GateDriver driver) => waitForThemeBrowser(
      driver,
      "document.querySelector('$trigger')?.checkVisibility() === true && document.querySelector('$query').readOnly === false",
    );

    test('the built home and inner pages use one palette and navigate to real indexed paths', () async {
      for (final (name, mount) in [('root', ''), ('prefix', '/trellis/')]) {
        final base = mount.isEmpty ? '/' : mount;
        final output = await docsOutput(name, mount);
        final index = jsonDecode(File(p.join(output.path, indexPath)).readAsStringSync()) as List<dynamic>;
        final combobox = index.cast<Map<String, dynamic>>().singleWhere((entry) => entry['title'] == 'Combobox');
        expect(combobox['url'], '${base}docs/ui/components/combobox/');
        final server = await serveThemeOutput(
          output,
          pathPrefix: mount,
          headers: {'content-security-policy': strictPolicy},
        );

        await forBrowsers((driver) async {
          for (final (route, width) in [(base, 390), ('${base}docs/ui/components/input/', 1440)]) {
            await driver.viewport(width, 820);
            driver.requests.clear();
            await driver.open(server.baseUrl.resolve(route));
            await ready(driver);
            expect(await driver.evaluate("document.querySelectorAll('$trigger').length"), 1);
            expect(await driver.evaluate("document.querySelector('.search-shell [role=combobox]')"), isNull);
            expect(driver.requests, contains(server.baseUrl.resolve('$base$clientPath').toString()));
            expect(driver.requests, contains(server.baseUrl.resolve('$base$indexPath').toString()));

            await driver.evaluate("document.querySelector('.skip-to-content').focus()");
            await shortcut(driver);
            expect(await driver.evaluate(_paletteFocus(modal, query)), isTrue);
            await driver.viewport(width == 390 ? 320 : width, 500);
            await driver.type('trellis the');
            await waitForThemeBrowser(driver, "$resultStatus === '20 results available'");
            expect(
              await driver.evaluate(r'''(() => {
              const popup = document.getElementById('lattice-command-query-popup');
              const input = document.getElementById('lattice-command-query');
              const list = document.getElementById('lattice-command-query-listbox');
              const close = document.querySelector('#lattice-command [data-dialog-close]');
              const rect = close.getBoundingClientRect();
              return (popup.scrollHeight > popup.clientHeight || list.scrollHeight > list.clientHeight) &&
                popup.getBoundingClientRect().top >= input.getBoundingClientRect().bottom &&
                close.contains(document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2));
            })()'''),
              isTrue,
              reason: '${driver.name}: scrollable results leave the close target exposed',
            );
            await driver.press('ArrowUp');
            expect(
              await driver.evaluate(r'''(() => {
                const popup = document.getElementById('lattice-command-query-popup');
                const list = document.getElementById('lattice-command-query-listbox');
                const last = list.lastElementChild;
                const panel = popup.getBoundingClientRect();
                const option = last.getBoundingClientRect();
                return document.activeElement.getAttribute('aria-activedescendant') === last.id &&
                  option.top >= panel.top && option.bottom <= panel.bottom && (popup.scrollTop > 0 || list.scrollTop > 0);
              })()'''),
              isTrue,
              reason: '${driver.name}: the last result scrolls into view',
            );
            await driver.press('Escape');
            await waitForThemeBrowser(driver, "!($modal) && document.activeElement.matches('.skip-to-content')");
            await shortcut(driver);
            expect(await driver.evaluate(_paletteFocus(modal, query)), isTrue);
            expect(await driver.evaluate('document.activeElement.value'), isEmpty);
            expect(await driver.evaluate("document.querySelectorAll('#lattice-command [role=option]').length"), 0);
            await driver.type('combobox suggestions');
            await waitForThemeBrowser(driver, "$resultStatus === '1 result available'");
            await driver.press('ArrowDown');
            await driver.press('ArrowUp');
            expect(
              await driver.evaluate(
                "document.getElementById(document.activeElement.getAttribute('aria-activedescendant')).textContent",
              ),
              'Combobox',
            );
            expect(await driver.evaluate('window.__trellisCsp.violations'), isEmpty);
            await driver.press('Enter');
            await _expectNavigation(driver, server.baseUrl.resolve(combobox['url'] as String));

            driver.requests.clear();
            await driver.open(server.baseUrl.resolve(route));
            await ready(driver);
            await driver.pointer(trigger, click: true);
            expect(await driver.evaluate(_paletteFocus(modal, query)), isTrue);
            await driver.type('combobox suggestions');
            await waitForThemeBrowser(driver, "$resultStatus === '1 result available'");
            await driver.pointer('#lattice-command [role=option]', click: true);
            await _expectNavigation(driver, server.baseUrl.resolve(combobox['url'] as String));
          }
        });
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('no match and index failure stay distinct across both deferred script orders', () async {
      final output = await docsOutput('errors', '');
      final original = File(p.join(output.path, 'index.html')).readAsStringSync();
      final suite = RegExp(
        r'<script[^>]+src="/trellis-ui/trellis-ui.js"[^>]*></script>',
      ).firstMatch(original)!.group(0)!;
      final client = RegExp(
        r'<script[^>]+src="/indexes/docs/trellis-search.js"[^>]*></script>',
      ).firstMatch(original)!.group(0)!;
      final reordered = original.replaceFirst(suite, '').replaceFirst(client, '$client$suite');
      expect(reordered.indexOf(client), lessThan(reordered.indexOf(suite)));
      File(p.join(output.path, 'client-first.html')).writeAsStringSync(reordered);
      File(p.join(output.path, 'invalid.json')).writeAsStringSync('{"not": "an index"}');
      File(p.join(output.path, 'invalid.html')).writeAsStringSync(_indexAt(original, '/invalid.json'));

      final healthy = await serveThemeOutput(output, headers: {'content-security-policy': strictPolicy});
      final broken = await serveThemeOutput(
        output,
        headers: {'content-security-policy': strictPolicy},
        statusCodes: {'/$indexPath': HttpStatus.notFound},
      );
      final missingClient = await serveThemeOutput(output, statusCodes: {'/$clientPath': HttpStatus.notFound});
      final disconnected = await StaticSiteServer.serve(
        output,
        headers: {'content-security-policy': strictPolicy},
        disconnectPaths: {'/$indexPath'},
      );
      addTearDown(disconnected.close);

      await forBrowsers((driver) async {
        await driver.viewport(390, 820);
        final release = Completer<void>();
        final delayed = await StaticSiteServer.serve(
          output,
          headers: {'content-security-policy': strictPolicy},
          beforeResponses: {'/$indexPath': release.future},
        );
        try {
          await driver.open(delayed.baseUrl);
          await waitForThemeBrowser(driver, "document.querySelector('$trigger')?.checkVisibility() === true");
          await driver.pointer(trigger, click: true);
          expect(
            await driver.evaluate("document.querySelector('[data-command-status][role=status]').innerText"),
            'Loading search…',
          );
          expect(await driver.evaluate("document.querySelector('$query').getAttribute('aria-busy')"), 'true');
          release.complete();
          await ready(driver);
          expect(await driver.evaluate("document.querySelector('[data-command-status]').hidden"), isTrue);
          await driver.type('combobox suggestions');
          await waitForThemeBrowser(driver, "$resultStatus === '1 result available'");
          await driver.press('Escape');
        } finally {
          if (!release.isCompleted) release.complete();
          await delayed.close();
        }
        for (final route in ['/', '/client-first.html']) {
          await driver.open(healthy.baseUrl.resolve(route));
          await ready(driver);
          await driver.pointer(trigger, click: true);
          await driver.type('qzzzz no match');
          await waitForThemeBrowser(driver, "$resultStatus === 'No results'");
          await checkVisiblePalette(driver);
          expect(
            await driver.evaluate("document.querySelector('#lattice-command [data-slot=combobox-empty]').innerText"),
            'No results',
          );
          expect(await driver.evaluate('window.__trellisCsp.violations'), isEmpty);
        }
        await driver.open(missingClient.baseUrl);
        await waitForThemeBrowser(driver, "customElements.get('tl-dialog') !== undefined");
        await driver.evaluate(r'''window.addEventListener('keydown', event => {
          if (event.key === 'k') window.shortcutObserved = [event.isTrusted, event.defaultPrevented];
        })''');
        await shortcut(driver);
        expect(await driver.evaluate("document.querySelector('$trigger').hidden"), isTrue);
        expect(await driver.evaluate(modal), isFalse);
        expect(await driver.evaluate('window.shortcutObserved'), [true, false]);

        for (final url in [broken.baseUrl, disconnected.baseUrl, healthy.baseUrl.resolve('/invalid.html')]) {
          await driver.open(url);
          await waitForThemeBrowser(driver, "document.querySelector('$trigger')?.checkVisibility() === true");
          await driver.pointer(trigger, click: true);
          await waitForThemeBrowser(driver, "document.querySelector('[data-command-status]').checkVisibility()");
          expect(
            await driver.evaluate("document.querySelector('[data-command-status][role=status]').innerText"),
            'Search unavailable',
          );
          expect(await driver.evaluate("document.querySelectorAll('#lattice-command [role=option]').length"), 0);
          await checkVisiblePalette(driver);
          expect(await driver.evaluate("document.querySelector('$query').readOnly"), isTrue);
          expect(
            await driver.evaluate("document.querySelector('$query').getAttribute('aria-describedby')"),
            'lattice-command-status',
          );
          expect(await driver.evaluate('window.__trellisCsp.violations'), isEmpty);
          await driver.press('Escape');
          expect(await driver.evaluate(modal), isFalse);
        }
      });
    });

    test('no build index or show_search false leaves no shortcut or entry point', () async {
      for (final (name, edit, hasIndex) in <(String, String Function(String), bool)>[
        ('disabled', (c) => c.replaceFirst('enabled: true', 'enabled: false'), false),
        ('excluded', (c) => c.replaceFirst('search:\n', 'search:\n  excludeSections: [docs]\n'), false),
        ('theme-disabled', (c) => c.replaceFirst('show_search: true', 'show_search: false'), true),
      ]) {
        final output = await docsOutput(name, '', editConfig: edit);
        expect(File(p.join(output.path, indexPath)).existsSync(), hasIndex, reason: name);
        final server = await serveThemeOutput(output);
        await forBrowsers((driver) async {
          await driver.open(server.baseUrl);
          await shortcut(driver);
          expect(await driver.evaluate("document.querySelector('$trigger, #lattice-command')"), isNull, reason: name);
          expect(
            await driver.evaluate("document.querySelector('script[src\$=\"trellis-search.js\"]')"),
            isNull,
            reason: name,
          );
          expect(await driver.evaluate("document.querySelector('dialog:modal')"), isNull, reason: name);
        });
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  test('no match, empty query and markup in titles', () async {
    final output = outputs['arbor']!;
    const title = '<img src=x onerror="window.__xss=1">';
    File(p.join(output.path, 'empty-probe.json')).writeAsStringSync(
      jsonEncode([
        {'title': title, 'url': _originalIndex(output).first['url']},
      ]),
    );
    final page = _copyDocsPage(output, 'empty-probe.html', (source) => _indexAt(source, '/empty-probe.json'));
    final server = await serveThemeOutput(output);

    await forBrowsers((driver) async {
      await driver.open(server.baseUrl.resolve(page));
      await waitForThemeBrowser(driver, _searchReady);
      await driver.pointer(_input, click: true);
      await driver.type('zzzz');
      await waitForThemeBrowser(driver, "document.querySelector('$_shell [role=status]').textContent === 'No results'");
      expect(
        await driver.evaluate('''
[
  document.querySelector('$_input').value,
  document.querySelector('$_shell :popover-open').innerText.trim(),
  document.querySelectorAll('$_option').length
]'''),
        ['zzzz', 'No results', 0],
      );

      for (var i = 0; i < 4; i++) {
        await driver.press('Backspace');
      }
      await driver.type('img');
      await waitForThemeBrowser(driver, "document.querySelectorAll('$_option').length === 1");
      for (var i = 0; i < 3; i++) {
        await driver.press('Backspace');
      }
      for (final text in ['', '  ']) {
        if (text.isNotEmpty) await driver.type(text);
        expect(
          await driver.evaluate('''
[
  document.querySelector('$_input').getAttribute('aria-expanded'),
  document.querySelector('$_shell :popover-open') === null,
  document.querySelectorAll('$_option').length
]'''),
          ['false', true, 0],
          reason: '${driver.name} query ${jsonEncode(text)}',
        );
      }

      await driver.type('img');
      await waitForThemeBrowser(driver, "document.querySelectorAll('$_option').length === 1");
      expect(
        await driver.evaluate('''
[
  document.querySelector('$_option').textContent,
  document.querySelector('$_option').childElementCount,
  typeof window.__xss
]'''),
        [title, 0, 'undefined'],
      );
    });
  });

  test('the search client can run before the combobox is defined', () async {
    final output = outputs['arbor']!;
    final suite = RegExp(r'<script [^>]*src="/trellis-ui/trellis-ui\.js"[^>]*></script>');
    final page = _copyDocsPage(output, 'late-combobox.html', (source) {
      expect(suite.allMatches(source), hasLength(1));
      return source.replaceFirst(suite, '<script src="/late-combobox.js" defer></script>');
    });
    File(p.join(output.path, 'late-combobox.js')).writeAsStringSync('''
const fetchIndex = window.fetch.bind(window);
window.fetch = async (...args) => {
  const response = await fetchIndex(...args);
  if (new URL(response.url).pathname !== '/search-index.json') return response;
  const decode = response.json.bind(response);
  response.json = async () => {
    const entries = await decode();
    // Observe the shell after the search client's setup microtasks, even when the index arrives slowly.
    setTimeout(() => {
      window.searchWaitedForUpgrade = document.querySelector('$_input').disabled && document.querySelector('$_shell').hidden;
      const script = document.createElement('script');
      script.src = '/trellis-ui/trellis-ui.js';
      document.head.append(script);
    }, 0);
    return entries;
  };
  return response;
};
''');
    final server = await serveThemeOutput(output);
    await forBrowsers((driver) async {
      await driver.open(server.baseUrl.resolve(page));
      await waitForThemeBrowser(driver, _searchReady);
      expect(await driver.evaluate('window.searchWaitedForUpgrade'), isTrue);
      await driver.pointer(_input, click: true);
      await driver.type('zzzz');
      await waitForThemeBrowser(driver, "document.querySelector('$_shell [role=status]').textContent === 'No results'");
    });
  });

  test('an unavailable index leaves no control', () async {
    final output = outputs['arbor']!;
    final crossOrigin = await serveThemeOutput(output, headers: {'access-control-allow-origin': '*'});
    const routes = {
      'missing': '/404.json',
      'error': '/500.json',
      'json': '/invalid.json',
      'object': '/object.json',
      'no-attribute': null,
    };
    File(p.join(output.path, 'invalid.json')).writeAsStringSync('broken json');
    File(p.join(output.path, 'object.json')).writeAsStringSync('{"url":"/"}');
    final pages = [
      for (final entry in {
        ...routes,
        'cross-origin': crossOrigin.baseUrl.resolve('search-index.json').toString(),
      }.entries)
        _copyDocsPage(output, 'unavailable-${entry.key}.html', (source) {
          return _indexAt(source, entry.value).replaceFirst('<head>', '''<head><script>
window.__searchErrors = [];
addEventListener('error', e => window.__searchErrors.push(e.message));
addEventListener('unhandledrejection', e => window.__searchErrors.push(String(e.reason)));
</script>''');
        }),
    ];
    final server = await serveThemeOutput(output, statusCodes: {'/500.json': HttpStatus.internalServerError});

    await forBrowsers((driver) async {
      for (final page in pages) {
        await driver.open(server.baseUrl.resolve(page));
        await waitForThemeBrowser(
          driver,
          "document.querySelector('$_input').getAttribute('aria-disabled') === 'true'",
          reason: '$page did not mark the control unavailable',
        );
        expect(
          await driver.evaluate('''
[
  document.querySelector('$_shell').hidden,
  document.querySelector('$_shell').getClientRects().length,
  document.querySelector('$_input').disabled,
  window.__searchErrors
]'''),
          [true, 0, true, <String>[]],
          reason: '${driver.name} $page',
        );
      }
    });
  });

  test('without script the shell is hidden and the input disabled', () async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('search without script');
      markTestSkipped('Chrome is required to disable scripting before navigation');
      return;
    }
    final browser = await BrowserProbe.launch();
    addTearDown(browser.close);
    for (final theme in themes) {
      final prefix = _prefixes[theme.name]!;
      final server = await serveThemeOutput(outputs[theme.name]!, pathPrefix: prefix);
      expect(
        await browser.evaluate(
          server.baseUrl.resolve('$prefix$_route'),
          '''
[
  document.querySelector('$_shell').hidden,
  document.querySelector('$_shell').getClientRects().length,
  document.querySelector('$_input').disabled
]''',
          width: 1440,
          height: 800,
          disableScripts: true,
        ),
        [true, 0, true],
        reason: theme.name,
      );
    }
  });

  test('search off ships no shell or script', () async {
    final into = Directory(p.join(scratch.path, 'off'));
    for (final theme in themes) {
      final output = await buildExample(
        theme,
        into: into,
        repoRoot: repo,
        pathPrefix: _prefixes[theme.name],
        editConfig: (source) => source.replaceFirst('show_search: true', 'show_search: false'),
      );
      final pages = builtPages(output.path);
      expect(pages, isNotEmpty, reason: theme.name);
      for (final page in pages) {
        final document = html.parse(File(p.join(output.path, page)).readAsStringSync());
        expect(
          document.querySelector('$_shell, script[src\$="/trellis-search.js"]'),
          isNull,
          reason: '${theme.name} $page',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

final _externalAsset = matches(RegExp(r'cdnjs|unpkg|jsdelivr|googleapis|https?://', caseSensitive: false));

List<Map<String, Object?>> _originalIndex(Directory output) =>
    (jsonDecode(File(p.join(output.path, 'search-index.json')).readAsStringSync()) as List)
        .cast<Map<String, Object?>>();

String _copyDocsPage(Directory output, String name, String Function(String) edit) {
  final source = File(p.join(output.path, _route, 'index.html')).readAsStringSync();
  File(p.join(output.path, name)).writeAsStringSync(edit(source));
  return name;
}

String _indexAt(String source, String? url) {
  final attribute = RegExp(r' data-search-index="[^"]+"');
  expect(attribute.allMatches(source), hasLength(1));
  return source.replaceFirst(attribute, url == null ? '' : ' data-search-index="$url"');
}

Future<void> _expectNavigation(GateDriver driver, Uri destination) async {
  if (driver is FirefoxDriver) {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    var actual = await driver.currentUrl();
    while (actual != destination && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      actual = await driver.currentUrl();
    }
    expect(actual, destination);
  } else {
    await waitForThemeBrowser(
      driver,
      'location.href === ${jsonEncode(destination.toString())}',
      reason: 'did not navigate to $destination',
    );
  }
  expect(
    driver.requests.where((request) => Uri.parse(request).removeFragment() == destination.removeFragment()),
    hasLength(1),
    reason: '${driver.name} requested the selected page once',
  );
}

String _paletteFocus(String modal, String query) => "$modal && document.activeElement.matches('$query')";
