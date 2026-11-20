import 'dart:io';

import 'package:test/test.dart';

import 'browser_reflow_probe.dart';

void main() {
  if (BrowserProbe.locateChrome() == null) requireChromeInCi('CSP browser proofs');
  test('csp violation capture detects inline script, style attribute and style element', () async {
    final dir = Directory.systemTemp.createTempSync('trellis_csp_control_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/index.html').writeAsStringSync(
      '''<!doctype html><html lang="en"><head><title>CSP control</title>
<style>body { color: red; }</style></head><body style="color: blue"><script>window.inlineRan = true;</script></body></html>''',
    );
    File(
      '${dir.path}/clean.html',
    ).writeAsStringSync('<!doctype html><html lang="en"><head><title>Clean</title></head><body>Clean</body></html>');
    final server = await StaticSiteServer.serve(
      dir,
      headers: {'content-security-policy': "script-src 'self'; style-src 'self'"},
    );
    addTearDown(server.close);
    final browser = await BrowserProbe.launch();
    addTearDown(browser.close);
    await browser.captureSecurityPolicyViolations();
    await browser.evaluate(server.baseUrl, 'document.readyState', width: 800, height: 600);
    final violations = await browser.securityPolicyViolations();
    expect(violations.map((v) => v['directive']), containsAll(['script-src-elem', 'style-src-attr', 'style-src-elem']));
    expect(violations.every((v) => v['blocked'] == 'inline'), isTrue);
    expect(await browser.evaluateHere('window.inlineRan === true'), isFalse);
    await browser.evaluate(server.baseUrl.resolve('clean.html'), 'document.readyState', width: 800, height: 600);
    expect(await browser.securityPolicyViolations(), isEmpty);
  }, skip: BrowserProbe.locateChrome() == null ? 'Chrome not installed' : false);
}
