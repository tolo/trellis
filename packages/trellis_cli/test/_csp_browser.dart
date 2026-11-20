import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../../test/browser_reflow_probe.dart';

import '_workspace_root.dart';

export '../../../test/browser_reflow_probe.dart' show BrowserProbe, requireChromeInCi;

Future<void> expectStrictCspApp(Uri base, {required bool csrf}) async {
  final browser = await BrowserProbe.launch();
  addTearDown(browser.close);
  await browser.captureSecurityPolicyViolations();
  final client = HttpClient();
  addTearDown(() => client.close(force: true));
  for (final path in ['/', '/about']) {
    final response = await (await client.getUrl(base.resolve(path))).close();
    final policy = response.headers.value('content-security-policy')!;
    await response.drain<void>();
    final directives = {for (final part in policy.split('; ')) part.split(' ').first: part.split(' ').skip(1).toList()};
    expect(directives['script-src'], ["'self'"]);
    expect(directives['style-src'], ["'self'"]);
    expect(await browser.evaluate(base.resolve(path), 'typeof htmx', width: 1024, height: 800), 'object');
    expect(
      await browser.evaluateHere("new URL(document.querySelector('script[src*=htmx]').src).origin === location.origin"),
      isTrue,
    );
    await expectAccessibleScaffold(browser);
    expect(await browser.securityPolicyViolations(), isEmpty, reason: path);
  }
  await browser.evaluate(base, 'document.readyState', width: 1024, height: 800);
  final count = int.parse(await browser.evaluateHere("document.querySelector('.counter-value').textContent") as String);
  await browser.evaluateHere('''(() => { document.addEventListener('htmx:beforeRequest', function(e) {
    window.__csrfHeader = e.detail.requestConfig.headers['X-CSRF-Token'];
  }); document.querySelector('[hx-post="/counter/increment"]').focus(); })()''');
  for (final increment in [1, 2]) {
    await browser.evaluateHere('''(() => {
      window.__counterSettled = false;
      document.addEventListener('htmx:afterSettle', () => { window.__counterSettled = true; }, {once: true});
    })()''');
    // Enter's text lets Chrome perform the native button action.
    for (final type in ['keyDown', 'keyUp']) {
      await browser.command('Input.dispatchKeyEvent', {
        'type': type,
        'key': 'Enter',
        'code': 'Enter',
        'windowsVirtualKeyCode': 13,
        if (type == 'keyDown') 'text': '\r',
      });
    }
    await waitForBrowser(
      browser,
      "window.__counterSettled && document.querySelector('.counter-value')?.textContent.trim() === '${count + increment}'",
    );
    expect(
      await browser.evaluateHere('''document.activeElement.matches('[hx-post="/counter/increment"]')'''),
      isTrue,
      reason: 'Counter swap preserves the keyboard control for repeated activation',
    );
  }
  if (csrf) {
    expect(
      await browser.evaluateHere(
        "window.__csrfHeader && window.__csrfHeader === document.querySelector('meta[name=csrf-token]').content",
      ),
      isTrue,
    );
  }
  await browser.evaluateHere("document.querySelector('a[hx-get=\"/about\"]').click()");
  await waitForBrowser(browser, "location.pathname === '/about' && !document.querySelector('.counter-value')");
  await browser.evaluateHere('history.back()');
  await waitForBrowser(browser, "location.pathname === '/' && !!document.querySelector('.counter-value')");
  await browser.evaluateHere("document.querySelector('[hx-post=\"/counter/reset\"]').click()");
  await waitForBrowser(browser, "document.querySelector('.counter-value')?.textContent.trim() === '0'");
  expect(await browser.evaluateHere("document.querySelectorAll('style').length"), 0);
  expect(await browser.securityPolicyViolations(), isEmpty);
}

Future<void> waitForBrowser(BrowserProbe browser, String expression) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await browser.evaluateHere(expression) == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail(
    'Browser did not reach: $expression; state=${await browser.evaluateHere("JSON.stringify({count: document.querySelector('.counter-value')?.textContent, settled: window.__counterSettled, focus: document.activeElement?.id || document.activeElement?.tagName, documentFocus: document.hasFocus()})")}',
  );
}

Future<void> expectStaticReload(Uri base, Directory project, String staticRoot) async {
  final client = HttpClient();
  addTearDown(() => client.close(force: true));
  final response = await (await client.getUrl(
    base.resolve('/_dev/reload'),
  )).close().timeout(const Duration(seconds: 5));
  expect(response.statusCode, 200);
  expect(response.headers.contentType?.mimeType, 'text/event-stream');
  final frames = StreamIterator(
    response.transform(utf8.decoder).transform(const LineSplitter()).where((line) => line == 'event: reload'),
  );
  addTearDown(frames.cancel);
  for (final path in ['styles.css', 'js/csrf.js']) {
    final file = File('${project.path}/$staticRoot/$path');
    final original = await file.readAsString();
    final next = frames.moveNext();
    final timer = Stopwatch()..start();
    await file.writeAsString('$original\n/* reload proof */\n');
    expect(await next.timeout(const Duration(seconds: 1)), isTrue, reason: path);
    expect(timer.elapsed, lessThan(const Duration(seconds: 1)), reason: path);
  }
}

Future<void> expectBrowserReload(
  Uri base,
  Directory project, {
  List<String> assets = const ['styles.css'],
  bool observeEvents = false,
}) async {
  final browser = await BrowserProbe.launch();
  addTearDown(browser.close);
  await browser.captureSecurityPolicyViolations();
  // Observe the scaffold's own connection without adding a second one in this page.
  await browser.preloadScript("""
    window.EventSource = class extends EventSource {
      constructor(url, options) {
        super(url, options);
        if (new URL(this.url).pathname === '/_dev/reload') window.__reloadSource = this;
      }
    };
  """);
  await browser.evaluate(base, 'document.readyState', width: 1024, height: 800);
  expect(
    await browser.evaluateHere('[...document.scripts].every(script => script.src && !script.textContent.trim())'),
    isTrue,
  );
  final client = HttpClient();
  addTearDown(() => client.close(force: true));
  final response = await (await client.getUrl(base.resolve('/_dev/reload.js'))).close();
  expect(response.statusCode, 200);
  expect(response.headers.contentType?.mimeType, contains('javascript'));
  await response.drain<void>();

  const ready =
      "document.readyState === 'complete' && typeof htmx === 'object' && "
      'window.__reloadSource?.readyState === EventSource.OPEN';
  await waitForBrowser(browser, ready);
  expect(await browser.evaluateHere('window.__reloadSource.url'), base.resolve('/_dev/reload').toString());
  expect(await browser.securityPolicyViolations(), isEmpty, reason: 'Before file edits');
  var documentStart = await browser.evaluateHere('performance.timeOrigin') as num;

  final observer = observeEvents ? await _openReloadObserver(base) : null;
  for (final (index, path) in assets.indexed) {
    final file = File('${project.path}/static/$path');
    final original = await file.readAsString();
    final loaded = browser.events
        .firstWhere((event) => event['method'] == 'Page.loadEventFired')
        .timeout(const Duration(seconds: 10));
    await Future.wait([loaded, file.writeAsString('$original\n/* browser reload proof */\n')]);
    await waitForBrowser(browser, ready);
    expect(await browser.evaluateHere("performance.getEntriesByType('navigation')[0].type"), 'reload', reason: path);
    final reloadedAt = await browser.evaluateHere('performance.timeOrigin') as num;
    expect(reloadedAt, greaterThan(documentStart), reason: path);
    documentStart = reloadedAt;
    expect(await browser.securityPolicyViolations(), isEmpty, reason: path);
    if (observer != null) {
      await waitForBrowser(observer, 'window.__reloadEvents.length >= ${index + 1}');
      expect(await observer.evaluateHere('window.__reloadEvents'), List.filled(index + 1, 'reload'), reason: path);
      expect(
        await observer.evaluateHere('[window.__reloadOpens, window.__reloadErrors, window.__observer.readyState]'),
        [1, 0, 1],
        reason: 'One observer connection received the reload for $path',
      );
      expect(await observer.securityPolicyViolations(), isEmpty, reason: path);
    }
  }
}

Future<BrowserProbe> _openReloadObserver(Uri base) async {
  final observer = await BrowserProbe.launch();
  addTearDown(observer.close);
  await observer.captureSecurityPolicyViolations();
  await observer.command('Network.enable');
  // A served HTMX fragment gives the observer a same-origin document with no reload client.
  await observer.command('Network.setExtraHTTPHeaders', {
    'headers': {'HX-Request': 'true'},
  });
  expect(await observer.evaluate(base.resolve('/about'), 'document.scripts.length', width: 1024, height: 800), 0);
  await observer.evaluateHere("""
    (() => {
      window.__reloadEvents = [];
      window.__reloadOpens = 0;
      window.__reloadErrors = 0;
      const source = window.__observer = new EventSource('/_dev/reload');
      source.addEventListener('open', () => window.__reloadOpens++);
      source.addEventListener('error', () => window.__reloadErrors++);
      source.addEventListener('reload', ({data}) => window.__reloadEvents.push(data));
    })()
  """);
  await waitForBrowser(observer, 'window.__observer.readyState === EventSource.OPEN');
  expect(await observer.evaluateHere('window.__observer.url'), base.resolve('/_dev/reload').toString());
  return observer;
}

Future<void> expectAccessibleScaffold(BrowserProbe browser) async {
  final root = await findWorkspaceRoot();
  final axe = await File('${root.path}/tool/ui_gate/vendor/axe.min.js').readAsString();
  await browser.evaluateHere('(() => {$axe; return true;})()');
  final violations = await browser.evaluateHere('''axe.run(document, {
    runOnly: {type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']}
  }).then(result => result.violations.map(v => v.id + ': ' + v.nodes.map(n => n.target.join(' ')).join(', ')))''');
  expect(violations, isEmpty, reason: 'Scaffold WCAG 2.2 AA audit');
}
