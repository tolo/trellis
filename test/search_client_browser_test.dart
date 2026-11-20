import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
