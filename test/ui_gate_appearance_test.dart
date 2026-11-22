import 'dart:io';

import 'package:test/test.dart';

import '../tool/ui_gate/appearance.dart';
import '../tool/ui_gate/checks.dart';
import '../tool/ui_gate/firefox.dart';
import '../tool/ui_gate/manifest.dart';
import '../tool/visual_baseline.dart' show digestScript;
import 'ui_gate_test_support.dart';

void main() {
  test('Firefox preserves modal autofocus and keeps outside controls inert', () async {
    if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
      markTestSkipped('Firefox or geckodriver not installed');
      return;
    }
    final server = await fixtureServer();
    final driver = await FirefoxDriver.launch();
    addTearDown(driver.close);
    await driver.open(server.baseUrl.resolve('/pass.html'));
    await driver.evaluate('''(() => {
      const modal = document.createElement('dialog');
      document.getElementById('component').append(modal);
      modal.append(document.getElementById('name'), document.createElement('button'));
      modal.showModal();
    })()''');
    for (final (id, focusTarget) in [('implicit', null), ('inert-target', '#trigger')]) {
      await driver.pseudo('#name', ['focus', 'focus-visible']);
      final blurred = await driver.evaluate('''new Promise((resolve, reject) => {
        window.addEventListener('blur', event => {
          resolve(event.isTrusted && !document.hidden && document.activeElement.id === 'name');
        }, {once: true});
        if (!window.open('/next.html', 'focus-contender-$id', 'popup,width=260,height=180')) {
          reject(Error('Firefox blocked the focus contender'));
        }
      })''');
      expect(blurred, isTrue);
      expect(await driver.evaluate("document.getElementById('name').matches(':focus-visible')"), isFalse);

      final target = focusTarget == null ? 'null' : '"$focusTarget"';
      final state = await driver.evaluate('($digestScript)({input: "#name"}, $target)') as Map;
      expect(state['focus'], focusTarget == null ? isNull : equals({'applicable': false}));
      final input = (state['elements'] as Map)['input'] as Map;
      expect(input['style'], containsPair('outlineStyle', 'solid'));
      expect(input['style'], containsPair('outlineColor', 'rgb(0, 95, 204)'));
    }
  }, timeout: Timeout(Duration(minutes: 2)));

  test('state capture keeps native focus during asynchronous backgrounding', () async {
    if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
      markTestSkipped('Firefox or geckodriver not installed');
      return;
    }
    final server = await fixtureServer();
    final directory = Directory.systemTemp.createTempSync('gate_focus_settle_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final manifest = GateManifest.load(
      File('${directory.path}/focus.yaml')..writeAsStringSync("""
page: /pass.html?defect=background-focus
root: '#component'
elements: {input: '#name'}
states: {default: []}
"""),
    );
    final driver = await FirefoxDriver.launch();
    addTearDown(driver.close);
    final capture = await captureAppearance(GateSession(manifest, driver, server.baseUrl));
    expect(
      driver.requests,
      contains(server.baseUrl.resolve('/next.html?fixture=visible-background-blur').toString()),
      reason: 'The focus-visible capture must background the visible source with its input still active.',
    );
    final state = (capture['states'] as Map)['default/focus-visible:input'] as Map;
    final style = ((state['elements'] as Map)['input'] as Map)['style'] as Map;
    expect(style['outlineStyle'], 'solid');
    expect(style['outlineColor'], 'rgb(0, 95, 204)');
    expect(state['focus'], {'applicable': true, 'document': true, 'target': true, 'visible': true});
  }, timeout: Timeout(Duration(minutes: 2)));

  test('state capture settles selected styles', () async {
    final server = await fixtureServer();
    final directory = Directory.systemTemp.createTempSync('gate_settle_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final manifest = GateManifest.load(
      File('${directory.path}/settle.yaml')..writeAsStringSync("""
page: /pass.html?defect=late-outline
root: '#component'
elements: {input: '#name'}
states: {default: []}
"""),
    );
    await forBrowsers((driver) async {
      final capture = await captureAppearance(GateSession(manifest, driver, server.baseUrl));
      final state = (capture['states'] as Map)['default/focus-visible:input'] as Map;
      final style = ((state['elements'] as Map)['input'] as Map)['style'] as Map;
      expect(style['outlineColor'], 'rgb(0, 0, 255)', reason: driver.name);

      await driver.open(server.baseUrl.resolve(manifest.page));
      final steps = await driver.evaluate(r'''(async () => {
        const input = document.querySelector('#name');
        const nextFrame = () => new Promise(resolve => requestAnimationFrame(resolve));
        input.focus();
        for (let frame = 0; frame < 7; frame++) await nextFrame();
        const before = input.dataset.outlineStep;
        input.blur();
        input.focus();
        await nextFrame();
        return [before, input.dataset.outlineStep];
      })()''');
      expect(steps, ['7', '8'], reason: '${driver.name}: focus recovery continues the same outline sequence');
    });
  }, timeout: Timeout(Duration(minutes: 2)));

  test('spike regressions', () async {
    final server = await fixtureServer();
    final directory = Directory.systemTemp.createTempSync('gate_replay_');
    addTearDown(() => directory.deleteSync(recursive: true));
    GateManifest recipe(String name) => GateManifest.load(
      File('${directory.path}/$name.yaml')..writeAsStringSync('''
page: /regressions/$name.html
root: '#component'
elements: {secondary: '#secondary', error: '#error'}
states: {default: []}
distinct: [['#one', '#two']]
'''),
    );
    await forBrowsers((driver) async {
      final before = await captureAppearance(GateSession(recipe('before'), driver, server.baseUrl));
      final control = await captureAppearance(GateSession(recipe('control'), driver, server.baseUrl));
      expect(compareAppearance(before, control), isEmpty, reason: '${driver.name} unchanged control');
      for (final entry in {
        'hover': ['hover:secondary', '#secondary', 'backgroundColor'],
        'tokens': ['token light --destructive', 'token dark --primary'],
        'overlap': ['#one overlaps #two'],
      }.entries) {
        final after = await captureAppearance(GateSession(recipe(entry.key), driver, server.baseUrl));
        final differences = compareAppearance(before, after).join('\n');
        for (final expected in entry.value) {
          expect(differences, contains(expected), reason: '${driver.name} ${entry.key}');
        }
      }
    });
  }, timeout: Timeout(Duration(minutes: 3)));

  test('state capture', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      final session = GateSession(fixtureManifest(), driver, server.baseUrl);
      final capture = await captureAppearance(session);
      final states = capture['states'] as Map;
      for (final state in ['default', 'open']) {
        expect(states.keys, containsAll([state, '$state/dark']));
        for (final element in ['trigger', 'input']) {
          for (final pseudo in ['hover', 'focus-visible', 'active', 'disabled']) {
            expect(states.keys, contains('$state/$pseudo:$element'));
          }
        }
      }
      expect(((capture['tokens'] as Map)['light'] as Map)['--primary'], '#005fcc');
      expect(((capture['tokens'] as Map)['dark'] as Map)['--destructive'], '#ff8080');
      expect(capture['invariants'], isEmpty, reason: '${driver.name}: ${capture['invariants']}');
      expect(session.violations, isEmpty, reason: 'measurement must not violate the strict policy');
      expect(compareAppearance(capture, capture), isEmpty);
      final result = await session.security();
      expect(result.status, 'pass', reason: '${driver.name}: ${result.evidence}');
    });
  }, timeout: Timeout(Duration(minutes: 3)));
}
