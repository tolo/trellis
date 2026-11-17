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
  }); document.querySelector('[hx-post="/counter/increment"]').click(); })()''');
  await waitForBrowser(browser, "document.querySelector('.counter-value')?.textContent.trim() === '${count + 1}'");
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
  fail('Browser did not reach: $expression');
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

Future<void> expectBrowserReload(Uri base, Directory project) async {
  final browser = await BrowserProbe.launch();
  addTearDown(browser.close);
  await browser.captureSecurityPolicyViolations();
  await browser.evaluate(base, 'window.__beforeReload = true', width: 1024, height: 800);
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
  await waitForBrowser(browser, "document.readyState === 'complete'");
  // Wait for the EventSource handshake before changing an asset.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final css = File('${project.path}/static/styles.css');
  await css.writeAsString('${await css.readAsString()}\n/* browser reload proof */\n');
  await waitForBrowser(
    browser,
    "window.__beforeReload !== true && document.readyState === 'complete' && typeof htmx === 'object'",
  );
  expect(await browser.securityPolicyViolations(), isEmpty);
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
