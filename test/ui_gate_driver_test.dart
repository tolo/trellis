import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/ui_gate/driver.dart';
import '../tool/ui_gate/firefox.dart';
import 'browser_reflow_probe.dart';
import 'ui_gate_test_support.dart';

void main() {
  test('native pointer reaches a control inside a horizontally scrolled region', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      await driver.viewport(390, 844);
      await driver.open(server.baseUrl.resolve('/pass.html'));
      await driver.evaluate('''(() => {
        const root = document.querySelector('#component');
        root.insertAdjacentHTML('beforeend',
          '<div id="scroller"><div id="track"><button id="far">Open actions</button></div></div>');
        const scroller=document.getElementById('scroller'), far=document.getElementById('far');
        Object.assign(scroller.style, {width:'200px',overflowX:'auto'});
        document.getElementById('track').style.width='600px';
        far.style.marginInlineStart='480px';
        window.pointerClicks=0;
        far.addEventListener('click', () => window.pointerClicks++);
      })()''');
      expect(await driver.evaluate("document.getElementById('far').getBoundingClientRect().left > innerWidth"), true);
      await driver.pointer('#far');
      expect(
        await driver.evaluate(
          "document.getElementById('scroller').scrollLeft > 0 && document.querySelector('#far:hover') !== null",
        ),
        true,
        reason: driver.name,
      );
      await driver.pointer('#far', click: true);
      expect(await driver.evaluate('window.pointerClicks'), 1, reason: driver.name);
    });
  }, timeout: Timeout(Duration(minutes: 2)));

  test('firefox forced active cleanup does not activate a link', () async {
    if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
      markTestSkipped('Firefox or geckodriver not installed');
      return;
    }
    final root = Directory.systemTemp.createTempSync('gate_active_link_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/index.html').writeAsStringSync(
      '<a id="target" href="?next">Next</a><button id="disabled" disabled>Disabled</button>'
      '<dialog><button id="dormant">Dormant</button></dialog>',
    );
    final server = await StaticSiteServer.serve(root);
    addTearDown(server.close);
    final driver = await FirefoxDriver.launch();
    addTearDown(driver.close);
    await driver.open(server.baseUrl);
    await driver.evaluate(
      "(() => {window.clicks=0;document.querySelector('#target').addEventListener('click',()=>window.clicks++)})()",
    );
    for (final state in ['hover', 'active', 'focus-visible']) {
      await driver.pseudo('#dormant', [state]);
      expect(await driver.evaluate("document.activeElement.id"), isNot('dormant'));
    }
    await expectLater(driver.pseudo('#missing', ['hover']), throwsA(isA<StateError>()));
    await driver.pseudo('#target', ['active']);
    expect(await driver.evaluate("document.querySelector('#target').matches(':active')"), true);
    await driver.pseudo('#target', []);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await driver.evaluate('location.search'), '');
    expect(await driver.evaluate('window.clicks'), 0);
    expect(await driver.evaluate("Object.hasOwn(window,'__gateCancelForcedClick')"), false);
    await driver.pseudo('#disabled', ['active']);
    await driver.pseudo('#disabled', []);
    expect(await driver.evaluate("Object.hasOwn(window,'__gateCancelForcedClick')"), false);
    await driver.pointer('#target', click: true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await driver.evaluate('location.search'), '?next');
  });

  test('firefox driver confirms focus during asynchronous backgrounding', () async {
    if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
      markTestSkipped('Firefox or geckodriver not installed');
      return;
    }
    final root = Directory.systemTemp.createTempSync('gate_focus_readback_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/index.html').writeAsStringSync('<button id="target">Target</button>');
    final server = await StaticSiteServer.serve(root);
    addTearDown(server.close);
    final driver = await FirefoxDriver.launch();
    addTearDown(driver.close);
    await driver.open(server.baseUrl);
    await driver.evaluate('''document.querySelector('#target').addEventListener('focus', () => {
      requestAnimationFrame(() => { window.other = window.open(location.href, 'focus-contender'); });
    }, {once:true})''');
    await driver.pseudo('#target', ['focus', 'focus-visible']);
    expect(await driver.evaluate('!!window.other'), true);
    expect(
      await driver.evaluate(
        "[document.hasFocus(),document.activeElement.id,document.querySelector('#target').matches(':focus-visible')]",
      ),
      [true, 'target', true],
    );
  });

  test('firefox driver reactivates a backgrounded context before focus', () async {
    if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
      markTestSkipped('Firefox or geckodriver not installed');
      return;
    }
    final root = Directory.systemTemp.createTempSync('gate_activation_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/index.html').writeAsStringSync('<input id="name" aria-label="Name">');
    final server = await StaticSiteServer.serve(root);
    addTearDown(server.close);
    final driver = await FirefoxDriver.launch();
    addTearDown(driver.close);
    await driver.open(server.baseUrl);
    expect(
      await driver.evaluate(
        "(() => {window.other=window.open(location.href,'focus-contender');return !!window.other;})()",
      ),
      true,
    );
    expect(await driver.evaluate('document.hasFocus()'), false);
    await driver.pseudo('#name', ['focus', 'focus-visible']);
    expect(await driver.evaluate('document.hasFocus()'), true);
    expect(await driver.evaluate("document.querySelector('#name').matches(':focus-visible')"), true);
  });

  test('firefox concurrent drivers own separate sessions', () async {
    if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
      markTestSkipped('Firefox or geckodriver not installed');
      return;
    }
    final drivers = <FirefoxDriver>[];
    addTearDown(() async {
      for (final driver in drivers) {
        await driver.close();
      }
    });
    await Future.wait(
      List.generate(2, (_) async {
        final driver = await FirefoxDriver.launch();
        drivers.add(driver);
      }),
    );
    final root = Directory.systemTemp.createTempSync('gate_concurrent_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/index.html').writeAsStringSync('<input aria-label="Name">');
    final server = await StaticSiteServer.serve(root);
    addTearDown(server.close);
    await Future.wait([
      for (var index = 0; index < drivers.length; index++)
        () async {
          final driver = drivers[index];
          await driver.open(server.baseUrl.replace(query: 'driver=$index'));
          await driver.evaluate("document.querySelector('input').value='$index'");
          expect(await driver.evaluate("document.querySelector('input').value"), '$index');
          expect(await driver.evaluate('location.search'), '?driver=$index');
        }(),
    ]);
  }, timeout: Timeout(Duration(minutes: 2)));

  test('vendored inputs', () {
    final pins = (jsonDecode(File('tool/ui_gate/vendor/checksums.json').readAsStringSync()) as Map)
        .cast<String, String>();
    expect(pins.length, 4);
    for (final entry in pins.entries) {
      expect(sha256.convert(File(entry.key).readAsBytesSync()).toString(), entry.value, reason: entry.key);
    }
    expect(File('tool/ui_gate/vendor/axe.min.js').readAsStringSync(), startsWith('/*! axe v4.10.2\n'));
    expect(File('tool/ui_gate/vendor/LICENSE.axe.txt').readAsStringSync(), contains('Mozilla'));
    expect(File('test/ui_gate_fixtures/LICENSE.htmx.txt').readAsStringSync(), contains('Zero-Clause'));
  });

  test('chrome driver', () async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('UI gate driver');
      markTestSkipped('Chrome not installed');
      return;
    }
    await exerciseDriver(ChromeDriver.launch);
  });
  test('firefox driver', () async {
    if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
      markTestSkipped('Firefox or geckodriver not installed');
      return;
    }
    await exerciseDriver(FirefoxDriver.launch);
  });
}

Future<void> exerciseDriver(Future<GateDriver> Function() launch) async {
  final root = Directory.systemTemp.createTempSync('gate_driver_');
  addTearDown(() => root.deleteSync(recursive: true));
  File('${root.path}/index.html').writeAsStringSync(
    '''<!doctype html><html><head><script src="/driver.js"></script></head>
      <body><input aria-label="Name"><button>Button</button><script>window.inlineRan=true</script></body></html>''',
  );
  File('${root.path}/driver.js').writeAsStringSync("document.addEventListener('keydown', () => {});");
  final server = await StaticSiteServer.serve(
    root,
    headers: {'content-security-policy': "default-src 'self'; script-src 'self'; style-src 'self'"},
  );
  addTearDown(server.close);
  final driver = await launch();
  addTearDown(driver.close);
  await driver.open(server.baseUrl);
  await driver.evaluate("document.querySelector('input').focus()");
  await driver.type('Dart');
  await driver.press('!');
  expect(await driver.evaluate("document.querySelector('input').value"), 'Dart!');
  final count = await driver.listeners();
  await driver.evaluate("document.addEventListener('test-listener', () => {})");
  expect(await driver.listeners(), count + 1);
  await driver.evaluate(
    "(() => { document.addEventListener('gate-once', () => {}, {once:true}); document.dispatchEvent(new Event('gate-once')); })()",
  );
  expect(await driver.listeners(), count + 1, reason: 'a consumed once listener is not live');
  await driver.evaluate(
    "(() => {const controller=new AbortController(); document.addEventListener('gate-abort',()=>{},{signal:controller.signal}); controller.abort();})()",
  );
  expect(await driver.listeners(), count + 1, reason: 'an aborted listener is not live');
  expect(await driver.media(coarse: true), isTrue);
  expect(await driver.media(forcedColors: true), isTrue);
  expect(await driver.media(reducedMotion: true), isTrue);
  expect(await driver.media(dark: true), isTrue);
  await driver.viewport(390, 844);
  expect(await driver.evaluate('innerWidth'), 390);
  await driver.pointer('button');
  expect(await driver.evaluate("document.querySelector('button').matches(':hover')"), isTrue);
  await driver.pseudo('button', ['focus-visible']);
  expect(await driver.evaluate("document.querySelector('button').matches(':focus-visible')"), isTrue);
  final violations = await driver.evaluate('window.__uiGate.violations') as List;
  if (driver is ChromeDriver) expect(await driver.probe.securityPolicyViolations(), isNotEmpty);
  expect(violations, isNotEmpty);
  expect((violations.first as Map)['directive'], 'script-src-elem');
  expect((violations.first as Map)['source'], anyOf('', '/'));
  expect(driver.requests, contains('${server.baseUrl}/driver.js'));
  await driver.open(server.baseUrl.replace(query: 'second'));
  await driver.history(-1);
  expect(await driver.evaluate('location.search'), '');
}
