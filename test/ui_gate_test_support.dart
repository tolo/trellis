import 'dart:io';

import 'package:test/test.dart';

import '../tool/ui_gate/checks.dart';
import '../tool/ui_gate/driver.dart';
import '../tool/ui_gate/firefox.dart';
import '../tool/ui_gate/manifest.dart';
import 'browser_reflow_probe.dart';

/// Both real engines; CI requires Chrome, Firefox remains a local gate.
Future<void> forBrowsers(Future<void> Function(GateDriver driver) testBody) async {
  final factories = <String, Future<GateDriver> Function()>{
    if (BrowserProbe.locateChrome() != null) 'chrome': ChromeDriver.launch,
    if (FirefoxDriver.locateFirefox() != null && FirefoxDriver.locateGeckodriver() != null)
      'firefox': FirefoxDriver.launch,
  };
  if (!factories.containsKey('chrome')) requireChromeInCi('UI gate fixtures');
  if (!factories.containsKey('firefox'))
    markTestSkipped('Firefox or geckodriver not installed; Firefox fixture checks did not run');
  for (final entry in factories.entries) {
    final driver = await entry.value();
    try {
      await testBody(driver);
    } finally {
      await driver.close();
    }
  }
}

Future<StaticSiteServer> fixtureServer({String? policy = strictPolicy}) async {
  final server = await StaticSiteServer.serve(
    Directory('test/ui_gate_fixtures'),
    headers: {if (policy != null) 'content-security-policy': policy},
  );
  addTearDown(server.close);
  return server;
}

GateManifest fixtureManifest({String page = '/pass.html', String? replace, String? withText}) {
  final root = Directory.systemTemp.createTempSync('gate_recipe_');
  addTearDown(() => root.deleteSync(recursive: true));
  var source = File(
    'test/ui_gate_fixtures/pass.yaml',
  ).readAsStringSync().replaceFirst('page: /pass.html', 'page: $page');
  source = source.replaceFirst('file: LICENSE', 'file: ${Directory.current.path}/test/ui_gate_fixtures/LICENSE');
  if (replace != null) source = source.replaceFirst(replace, withText!);
  final file = File('${root.path}/fixture.yaml')..writeAsStringSync(source);
  return GateManifest.load(file);
}
