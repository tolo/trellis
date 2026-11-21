import 'package:test/test.dart';

import '../tool/ui_gate/appearance.dart';
import '../tool/ui_gate/checks.dart';
import '../tool/ui_gate/driver.dart';
import 'ui_gate_test_support.dart';

void main() {
  test('conditions preserve failures before an unsupported condition', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      final result = await GateSession(
        fixtureManifest(page: '/pass.html?defect=fine'),
        UnsupportedCoarseDriver(driver),
        server.baseUrl,
      ).touchTargets();
      expect(result.status, 'fail', reason: '${driver.name}: ${result.evidence}');
      expect(result.evidence.join(), contains('24 px'));
      expect(result.evidence.join(), contains('did not read back'));
      expect(result.unsupported, false);
    });
  }, timeout: Timeout(Duration(minutes: 2)));

  test('conditions and touch targets include an interactive component root', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      for (final defect in ['fine', 'coarse', 'forced']) {
        final session = GateSession(
          fixtureManifest(
            page: '/pass.html?defect=$defect',
            replace: "root: '#component'",
            withText: "root: '${defect == 'forced' ? '#trigger' : '#probe'}'",
          ),
          driver,
          server.baseUrl,
        );
        final result = await (defect == 'forced' ? session.forcedColors() : session.touchTargets());
        expect(result.status, 'fail', reason: '${driver.name} $defect: ${result.evidence}');
        expect(result.evidence.join(), contains(defect == 'forced' ? 'focus indicator' : 'below'));
      }
    });
  }, timeout: Timeout(Duration(minutes: 2)));

  test('touch targets ignore inert presentation and still reject small interactive controls', () async {
    final server = await fixtureServer();
    final chrome = await ChromeDriver.launch();
    addTearDown(chrome.close);

    Future<GateResult> measure({required bool inert}) {
      final manifest = fixtureManifest(
        replace: "  default: []",
        withText:
            """
  default:
    - eval: >
        (() => {
          const root = document.getElementById('component');
          for (const mode of ['html', 'css']) {
            const panel = document.createElement('section');
            panel.inert = $inert && mode === 'html';
            if ($inert && mode === 'css') panel.style.interactivity = 'inert';
            const button = document.createElement('button');
            button.id = mode + '-control';
            button.textContent = 'X';
            Object.assign(button.style, {width: '20px', height: '20px', minWidth: '0', minHeight: '0'});
            panel.append(button);
            root.append(panel);
          }
        })()""",
      );
      return GateSession(manifest, chrome, server.baseUrl).touchTargets();
    }

    final passive = await measure(inert: true);
    expect(passive.status, 'pass', reason: '${passive.evidence}');
    final interactive = await measure(inert: false);
    expect(interactive.status, 'fail');
    expect(interactive.evidence.join(), allOf(contains('#html-control'), contains('#css-control'), contains('44 px')));
  });

  test('conditions and touch targets keep forced-focus paint atomic', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      final result = await GateSession(
        fixtureManifest(),
        BackgroundAfterFocusDriver(driver),
        server.baseUrl,
      ).forcedColors();
      expect(result.status, 'pass', reason: '${driver.name}: ${result.evidence}');
    });
  }, timeout: Timeout(Duration(minutes: 2)));

  test('forced colors checks native-modal controls while the visible background is inert', () async {
    final server = await fixtureServer();
    final failures = <String>[];
    await forBrowsers((driver) async {
      GateSession modal({required bool broken}) => GateSession(
        fixtureManifest(
          page: '/pass.html${broken ? '?defect=forced' : ''}',
          replace: "  default: []\n  open:\n    - click: '#trigger'",
          withText: '''  modal:
    - eval: >
        (() => {
          const root = document.querySelector('#component');
          root.insertAdjacentHTML('beforeend', '<dialog id="modal"><button id="inside">Close</button><button>Cancel</button></dialog>');
          root.querySelector('#modal').showModal();
        })()
    - expect: {expression: "document.querySelector('#modal').matches(':modal')", equals: true}
''',
        ),
        driver,
        server.baseUrl,
      );

      final passing = await modal(broken: false).forcedColors();
      if (passing.status != 'pass') {
        failures.add('${driver.name}: ${passing.evidence}');
        return;
      }
      expect(await driver.evaluate("document.querySelector('#trigger').hasAttribute('data-ui-gate-focus')"), isFalse);
      expect(await driver.evaluate("document.querySelector('#inside').hasAttribute('data-ui-gate-focus')"), isTrue);
      final appearance = await captureAppearance(modal(broken: false));
      final states = appearance['states'] as Map;
      final outer = states['modal/focus-visible:trigger'] as Map;
      expect(outer['focus'], {'applicable': false}, reason: driver.name);
      final broken = await modal(broken: true).forcedColors();
      expect(broken.status, 'fail', reason: '${driver.name}: ${broken.evidence}');
      expect(broken.evidence.join(), contains('no outline/border focus indicator'));
    });
    expect(failures, isEmpty);
  }, timeout: Timeout(Duration(minutes: 2)));

  test('forced colors reaches a single-tab-stop dialog opened with the pointer', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      final session = GateSession(
        fixtureManifest(
          replace: "  default: []\n  open:\n    - click: '#trigger'",
          withText: '''  modal:
    - eval: >
        (() => {
          const root = document.querySelector('#component');
          root.insertAdjacentHTML('beforeend', '<button id="launch">Launch</button><dialog id="modal"><button id="only">Close</button></dialog>');
          const dialog = root.querySelector('#modal'), button = root.querySelector('#only');
          root.querySelector('#launch').addEventListener('click', () => dialog.showModal());
          dialog.addEventListener('keydown', event => {
            if (event.key === 'Tab' && event.target === button) {
              event.preventDefault();
              button.focus();
            }
          });
        })()
    - click: '#launch'
    - expect: {expression: "document.activeElement.id === 'only' && !document.activeElement.matches(':focus-visible')", equals: true}
''',
        ),
        driver,
        server.baseUrl,
      );
      final result = await session.forcedColors();
      expect(result.status, 'pass', reason: '${driver.name}: ${result.evidence}');
      expect(await driver.evaluate("document.querySelector('#modal').hasAttribute('tabindex')"), isFalse);
    });
  }, timeout: Timeout(Duration(minutes: 2)));

  test('conditions and touch targets', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      final session = GateSession(fixtureManifest(), driver, server.baseUrl);
      for (final result in [
        await session.forcedColors(),
        await session.reducedMotion(),
        await session.reflow([390, 768, 1440]),
        await session.reflow([640, 320]),
        await session.touchTargets(),
      ]) {
        expect(result.status, 'pass', reason: '${driver.name}: ${result.evidence}');
      }
      for (final entry in {
        'forced': 'forced-colors',
        'motion': 'reduced-motion',
        'width': '390',
        'zoom': '320',
        'popup': 'viewport',
        'fine': '24 px',
        'coarse': '44 px',
      }.entries) {
        final broken = GateSession(fixtureManifest(page: '/pass.html?defect=${entry.key}'), driver, server.baseUrl);
        final result = await switch (entry.key) {
          'forced' => broken.forcedColors(),
          'motion' => broken.reducedMotion(),
          'width' || 'popup' => broken.reflow([390, 768, 1440]),
          'zoom' => broken.reflow([640, 320]),
          _ => broken.touchTargets(),
        };
        expect(result.status, 'fail', reason: '${driver.name} ${entry.key}: ${result.evidence}');
        expect(result.evidence.join(), contains(entry.value));
      }
      final unconfirmed = await GateSession(
        fixtureManifest(),
        UnconfirmedDriver(driver),
        server.baseUrl,
      ).touchTargets();
      expect(unconfirmed.status, 'not-run');
      expect(unconfirmed.evidence.join(), contains('did not read back'));
    });
  }, timeout: Timeout(Duration(minutes: 4)));

  test('htmx lifecycle', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      for (final entry in {
        '': 'pass',
        'listeners': 'listener counts',
        'double-fire': 'single-fire probe',
        'stale': 'stale transient UI',
        'wrong-region': 'swap region',
      }.entries) {
        final session = GateSession(
          fixtureManifest(page: '/pass.html${entry.key.isEmpty ? '' : '?defect=${entry.key}'}'),
          driver,
          server.baseUrl,
        );
        final result = await session.lifecycle();
        expect(
          result.status,
          entry.key.isEmpty ? 'pass' : 'fail',
          reason: '${driver.name} ${entry.key}: ${result.evidence}',
        );
        if (entry.key.isNotEmpty)
          expect(result.evidence.join(), contains(entry.value), reason: '${driver.name}: ${result.evidence}');
      }
    });
  }, timeout: Timeout(Duration(minutes: 4)));

  test('axe, semantics and keyboard', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      final passing = GateSession(fixtureManifest(), driver, server.baseUrl);
      for (final result in [await passing.accessibility(), await passing.semantics(), await passing.keyboard()]) {
        expect(result.status, 'pass', reason: '${driver.name}: ${result.evidence}');
      }
      final unlabelled = GateSession(
        fixtureManifest(
          page: '/pass.html?defect=label',
          replace: '  default: []',
          withText: "  default: []\n  changed:\n    - click: '#mutate'",
        ),
        driver,
        server.baseUrl,
      );
      final axe = await unlabelled.accessibility();
      expect(axe.status, 'fail', reason: '${driver.name}: ${axe.evidence}');
      expect(axe.evidence.join(), allOf(contains('changed'), contains('button-name')));
      final semantics = await GateSession(
        fixtureManifest(replace: 'attribute: aria-haspopup, equals: menu', withText: 'attribute: role, equals: menu'),
        driver,
        server.baseUrl,
      ).semantics();
      expect(semantics.status, 'fail');
      expect(semantics.evidence.join(), allOf(contains('semantics'), contains('#trigger'), contains('actual')));
      final broken = await GateSession(
        fixtureManifest(page: '/pass.html?defect=keyboard'),
        driver,
        server.baseUrl,
      ).keyboard();
      expect(broken.status, 'fail');
      expect(broken.evidence.join(), allOf(contains('step'), contains('expected "first"'), contains('actual "last"')));
      final missing = await GateSession(
        fixtureManifest(replace: "focus: '#trigger'", withText: "focus: '#missing'"),
        driver,
        server.baseUrl,
      ).keyboard();
      expect(missing.status, 'fail');
      expect(missing.evidence.join(), allOf(contains('step 1'), contains('#missing')));
    });
  }, timeout: Timeout(Duration(minutes: 3)));

  test('csp and self-hosting', () async {
    final server = await fixtureServer();
    await forBrowsers((driver) async {
      final passing = GateSession(fixtureManifest(), driver, server.baseUrl);
      await passing.load();
      await passing.load('open');
      final security = await passing.security();
      expect(security.status, 'pass', reason: '${driver.name}: ${security.evidence}');
      expect(passing.selfHosting().status, 'pass');
      for (final page in ['/inline-script.html', '/inline-style.html', '/pass.html?defect=style-interaction']) {
        final session = GateSession(fixtureManifest(page: page), driver, server.baseUrl);
        await session.load();
        if (page.contains('interaction'))
          await session.steps([
            {'click': '#mutate'},
          ]);
        final result = await session.security();
        expect(result.status, 'fail', reason: '${driver.name}: $page ${result.evidence}');
        expect(result.evidence.join(), contains(page.contains('script') ? 'script-src' : 'style-src'));
        expect(result.evidence.join(), contains('source='));
      }
      final external = GateSession(fixtureManifest(page: '/pass.html?defect=external'), driver, server.baseUrl);
      await external.load();
      await external.collect();
      expect(external.selfHosting().status, 'fail', reason: driver.name);
      expect(external.selfHosting().evidence.join(), contains('https://example.invalid/gate.png'));
      for (final policy in [
        null,
        strictPolicy.replaceFirst("script-src 'self'", "script-src 'self' 'unsafe-inline'"),
      ]) {
        final other = await fixtureServer(policy: policy);
        final session = GateSession(fixtureManifest(), driver, other.baseUrl);
        await session.load();
        final result = await session.security();
        expect(result.status, 'fail', reason: '${driver.name}: ${result.evidence}');
        expect(result.evidence.join(), contains('policy'));
      }
    });
  }, timeout: Timeout(Duration(minutes: 2)));
}

/// Models an unsupported browser condition at the browser boundary.
base class DriverProxy implements GateDriver {
  DriverProxy(this.delegate);
  final GateDriver delegate;
  @override
  String get name => delegate.name;
  @override
  List<String> get requests => delegate.requests;
  @override
  List<String> get console => delegate.console;
  @override
  Future<void> open(Uri url) => delegate.open(url);
  @override
  Future<Object?> evaluate(String expression) => delegate.evaluate(expression);
  @override
  Future<void> viewport(int width, int height) => delegate.viewport(width, height);
  @override
  Future<bool> media({bool coarse = false, bool forcedColors = false, bool reducedMotion = false, bool dark = false}) =>
      delegate.media(coarse: coarse, forcedColors: forcedColors, reducedMotion: reducedMotion, dark: dark);
  @override
  Future<void> press(String key) => delegate.press(key);
  @override
  Future<void> type(String text) => delegate.type(text);
  @override
  Future<void> pointer(String selector, {bool click = false, bool down = false}) =>
      delegate.pointer(selector, click: click, down: down);
  @override
  Future<void> dragTouch(String selector, {required int dx, required int dy}) =>
      delegate.dragTouch(selector, dx: dx, dy: dy);
  @override
  Future<void> pseudo(String selector, List<String> states) => delegate.pseudo(selector, states);
  @override
  Future<int> listeners() => delegate.listeners();
  @override
  Future<void> history(int delta) => delegate.history(delta);
  @override
  Future<void> close() => delegate.close();
}

final class UnconfirmedDriver extends DriverProxy {
  UnconfirmedDriver(super.delegate);
  @override
  Future<bool> media({
    bool coarse = false,
    bool forcedColors = false,
    bool reducedMotion = false,
    bool dark = false,
  }) async => false;
}

final class UnsupportedCoarseDriver extends DriverProxy {
  UnsupportedCoarseDriver(super.delegate);
  @override
  Future<bool> media({
    bool coarse = false,
    bool forcedColors = false,
    bool reducedMotion = false,
    bool dark = false,
  }) async => coarse
      ? false
      : await super.media(coarse: coarse, forcedColors: forcedColors, reducedMotion: reducedMotion, dark: dark);
}

final class BackgroundAfterFocusDriver extends DriverProxy {
  BackgroundAfterFocusDriver(super.delegate);
  @override
  Future<void> pseudo(String selector, List<String> states) async {
    await delegate.pseudo(selector, states);
    if (states.contains('focus-visible')) {
      await delegate.evaluate(
        "(() => {window.__gateFocusOther=window.open('about:blank','paint-contender');return true;})()",
      );
    }
  }
}
