import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
import '../tool/src/bundle.dart';
import '../tool/src/gallery.dart';

void main() {
  late HttpServer server;
  late ChromeDriver driver;
  Future<void> Function()? holdOptions;
  String? suiteScript;

  setUp(() async {
    holdOptions = null;
    suiteScript = null;
    final gallery = galleryHandler(Directory.current);
    server = await shelf_io.serve(
      (request) async {
        final uri = request.requestedUri;
        if (uri.path == '/trellis-ui/trellis-ui.js' && suiteScript != null) {
          return Response.ok(suiteScript, headers: {'content-type': 'text/javascript'});
        }
        if (uri.path == '/demo/options' &&
            (uri.queryParameters['q'] == 'zz' || uri.queryParameters['mode'] == 'timeout')) {
          await holdOptions?.call();
        }
        return gallery(request);
      },
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    driver = await ChromeDriver.launch();
    addTearDown(driver.close);
  });

  Future<void> waitFor(String expression) async {
    for (var attempt = 0; attempt < 150; attempt++) {
      if (await driver.evaluate(expression) == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('Timed out waiting for $expression');
  }

  Future<void> open(String component) =>
      driver.open(Uri.parse('http://127.0.0.1:${server.port}/components/$component'));
  Future<void> click(String selector) => driver.pointer(selector, click: true);

  const typed = "document.querySelector('#fruit').value";
  const selection = "document.querySelector('[name=fruitId]').value";
  const announcement = "document.querySelector('#component [role=status]').textContent";
  const comboboxOpen = "document.querySelector('#fruit-popup').matches(':popover-open')";
  const menuOpen = "document.querySelector('#menu').matches(':popover-open')";
  const noCsp = 'window.__trellisCsp.violations';

  test('combobox selection stores the value and editing clears it', () async {
    await open('combobox');
    await click('#fruit');
    await driver.type('ap');
    await waitFor("$announcement === '2 results available'");
    await driver.press('ArrowDown');
    await driver.press('Enter');
    expect(await driver.evaluate(typed), 'Apple');
    expect(await driver.evaluate(selection), 'apple');
    expect(await driver.evaluate(comboboxOpen), isFalse);

    await click('#navigate');
    await waitFor("location.pathname === '/components/input' && !document.querySelector('#fruit')");
    await driver.history(-1);
    await waitFor("location.pathname === '/components/combobox' && document.querySelector('#fruit') !== null");
    expect(await driver.evaluate(typed), 'Apple', reason: 'Restored display text must match the submitted value');
    expect(await driver.evaluate(selection), 'apple');
    expect(await driver.evaluate(comboboxOpen), isFalse);

    await click('#fruit');
    await driver.press('End');
    await driver.type('s');
    expect(await driver.evaluate(typed), 'Apples');
    expect(await driver.evaluate(selection), '');
  });

  test('combobox cannot select a previous match while new options are pending', () async {
    final pending = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    holdOptions = () {
      pending.complete();
      return release.future;
    };
    await open('combobox');
    await click('#fruit');
    await driver.type('zz');
    await pending.future.timeout(const Duration(seconds: 3));
    await driver.press('ArrowDown');
    await driver.press('Enter');
    expect(await driver.evaluate(typed), 'zz');
    expect(await driver.evaluate(selection), isEmpty);
    expect(await driver.evaluate(comboboxOpen), isFalse);

    release.complete();
    await waitFor("$announcement === 'No results'");
    expect(await driver.evaluate(typed), 'zz');
    expect(await driver.evaluate(comboboxOpen), isTrue);
  });

  test('combobox with no options or a failed request announces no results and keeps the typed text', () async {
    final timeoutResponse = Completer<void>();
    holdOptions = () => timeoutResponse.future;
    addTearDown(timeoutResponse.complete);
    for (final (mode, event) in [
      ('empty', 'htmx:afterSettle'),
      ('error', 'htmx:responseError'),
      ('abort', 'htmx:sendError'),
      ('timeout', 'htmx:timeout'),
    ]) {
      await open('combobox');
      await driver.evaluate('''(() => {
        window.errors = [];
        window.received = false;
        window.addEventListener('error', event => window.errors.push(event.message));
        const input = document.querySelector('#fruit');
        input.addEventListener('htmx:configRequest', event => {
          event.detail.parameters.mode = '$mode';
          if ('$mode' === 'timeout') event.detail.timeout = 250;
        });
        document.body.addEventListener('$event', () => window.received = true, {once: true});
      })()''');
      expect(await driver.evaluate("document.querySelectorAll('#fruit-results [role=option]').length"), 3);
      await click('#fruit');
      await driver.type('ap');
      await waitFor('window.received === true');
      expect(await driver.evaluate(announcement), 'No results', reason: mode);
      expect(await driver.evaluate(typed), 'ap', reason: mode);
      expect(await driver.evaluate(comboboxOpen), isTrue, reason: mode);
      expect(
        await driver.evaluate("document.querySelectorAll('#fruit-results [role=option]').length"),
        0,
        reason: mode,
      );
      expect(await driver.evaluate("document.querySelector('[data-slot=combobox-empty]').offsetHeight > 0"), isTrue);
      expect(await driver.evaluate('window.errors'), isEmpty, reason: mode);
      await driver.press('Escape');
      expect(await driver.evaluate(comboboxOpen), isFalse, reason: mode);
    }
  });

  test('popup style attributes are dropped before swap and history save', () async {
    await open('dropdown-menu');
    await click('#menu-trigger');
    await waitFor("$menuOpen && document.querySelector('#menu').hasAttribute('style')");
    await driver.press('Escape');
    await waitFor('!$menuOpen');
    expect(await driver.evaluate("document.querySelector('#menu').hasAttribute('style')"), isTrue);
    await driver.evaluate(
      "document.querySelector('#demo').dispatchEvent(new Event('htmx:beforeSwap', {bubbles:true}))",
    );
    expect(await driver.evaluate("document.querySelector('#menu').hasAttribute('style')"), isFalse);

    await click('#menu-trigger');
    await waitFor("$menuOpen && document.querySelector('#menu').matches('[data-open]')");
    await driver.evaluate("document.body.dispatchEvent(new Event('htmx:beforeHistorySave', {bubbles:true}))");
    expect(await driver.evaluate("document.querySelector('#menu').hasAttribute('style')"), isFalse);
    expect(await driver.evaluate(menuOpen), isFalse);
    await click('#menu-trigger');
    await waitFor("$menuOpen && document.querySelector('#menu').hasAttribute('style')");
    await driver.evaluate(
      "(() => {window.oldMenu = document.querySelector('#menu'); document.querySelector('#swap').click()})()",
    );
    await waitFor(
      "!window.oldMenu.isConnected && !document.querySelector('#demo').classList.contains('htmx-settling')",
    );
    expect(await driver.evaluate("window.oldMenu.hasAttribute('style')"), isFalse);
    expect(await driver.evaluate(noCsp), isEmpty);

    await open('combobox');
    await click('#fruit');
    await driver.type('ap');
    await waitFor("$announcement === '2 results available'");
    expect(await driver.evaluate(comboboxOpen), isTrue);
    expect(await driver.evaluate("document.querySelector('#fruit-popup').style.left.endsWith('px')"), isTrue);
    expect(await driver.evaluate(noCsp), isEmpty);
  });

  test('popups stay inside the viewport and follow their anchor', () async {
    for (final (component, trigger, anchor, popup) in [
      ('dropdown-menu', '#menu-trigger', '#menu-trigger', '#menu'),
      ('combobox', '[data-slot=combobox-trigger]', '.trellis-combobox-input', '#fruit-popup'),
    ]) {
      await driver.viewport(390, 700);
      await open(component);
      await driver.evaluate(r'''(() => {
        const box = document.querySelector('#component').style;
        box.position = 'fixed';
        box.inset = 'auto 2px 8px auto';
        box.width = '160px';
        box.margin = '0';
      })()''');
      await click(trigger);
      await waitFor("document.querySelector('$popup:popover-open[data-side=top]') !== null");
      await driver.evaluate("Promise.all(document.querySelector('$popup').getAnimations().map(a=>a.finished))");
      Future<num> verify() async {
        final result =
            await driver.evaluate('''(() => {
          const anchor = document.querySelector('$anchor').getBoundingClientRect();
          const popup = document.querySelector('$popup').getBoundingClientRect();
          return { inside: popup.left >= 0 && popup.top >= 0 && popup.right <= innerWidth && popup.bottom <= innerHeight,
            above: Math.abs(popup.bottom - anchor.top + 4) < 2,
            wide: popup.width >= anchor.width - 0.1, left: popup.left, anchorTop: anchor.top, popupBottom: popup.bottom };
        })()''')
                as Map;
        expect(result['inside'], isTrue, reason: '$component: $result');
        expect(result['above'], isTrue, reason: '$component: $result');
        expect(result['wide'], isTrue, reason: component);
        return result['left'] as num;
      }

      final left = await verify();
      await driver.viewport(560, 640);
      await waitFor("document.querySelector('$popup').getBoundingClientRect().left > $left + 100");
      await driver.evaluate("Promise.all(document.querySelector('$popup').getAnimations().map(a=>a.finished))");
      expect(await verify(), greaterThan(left));
      expect(await driver.evaluate(noCsp), isEmpty);
    }
  });

  test('hover intent cancels opposite transitions and pending work on disconnect', () async {
    final script = bundleScript(Directory.current);
    // Observe the internal helper without adding a production export or a second bundle.
    final end = script.lastIndexOf('})();');
    suiteScript = script.replaceRange(end, end, r"""
window.hoverTransitions = [];
customElements.define('hover-intent-probe', class extends TlElement {
  onConnect() {
    const transition = action => () => window.hoverTransitions.push(action);
    this.intent = hoverIntent({open: transition('open'), close: transition('close'), openDelay: 40, closeDelay: 40});
    this.listen(this, 'pointerenter', this.intent.enter);
    this.listen(this, 'pointerleave', this.intent.leave);
  }
  onDisconnect() { this.intent.cancel(); }
});
""");
    await open('dropdown-menu');
    final result = await driver.evaluate(r"""(async () => {
      const probe = document.createElement('hover-intent-probe');
      document.body.append(probe);
      const fire = type => probe.dispatchEvent(new PointerEvent(type));
      const settle = () => new Promise(resolve => setTimeout(resolve, 80));

      fire('pointerenter');
      fire('pointerleave');
      await settle();

      fire('pointerleave');
      fire('pointerenter');
      await settle();

      fire('pointerleave');
      probe.remove();
      await settle();
      return window.hoverTransitions;
    })()""");
    expect(result, ['close', 'open']);
    expect(await driver.evaluate(noCsp), isEmpty);
  });
}
