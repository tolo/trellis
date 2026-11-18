import 'dart:io';

import 'package:test/test.dart';

import 'browser_reflow_probe.dart';
import 'ui_gate_test_support.dart';

void main() {
  test('Enter activates a focused native button', () async {
    final temp = Directory('.agent_temp/native-enter')..createSync(recursive: true);
    final root = temp.createTempSync('site_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/index.html').writeAsStringSync('''
      <!doctype html>
      <button id="target">Activate</button>
      <script>window.clicks = 0; document.querySelector('#target').addEventListener('click', () => window.clicks++);</script>
    ''');
    final server = await StaticSiteServer.serve(root);
    addTearDown(server.close);

    await forBrowsers((driver) async {
      await driver.open(server.baseUrl);
      await driver.evaluate("document.querySelector('#target').focus()");
      await driver.press('Enter');
      await driver.press('Enter');

      expect(await driver.evaluate('window.clicks'), 2, reason: '${driver.name} should use native activation');
      expect(await driver.evaluate('document.activeElement.id'), 'target');
    });
  });
}
