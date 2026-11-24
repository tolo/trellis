import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

import '../../../tool/ui_gate/driver.dart';
import '../../../tool/ui_gate/firefox.dart';
import '../tool/src/gallery.dart';

const _trigger = '#colour-mode';
const _hint = "document.getElementById('colour-hint')";
const _open = "$_hint.matches(':popover-open')";
const _placed = "$_open && $_hint.style.top.endsWith('px')";
const _csp = 'window.__trellisCsp.violations';
const _button = "document.querySelector('$_trigger')";

void main() {
  late Uri gallery;

  setUpAll(() async {
    final server = await shelf_io.serve(galleryHandler(Directory.current), InternetAddress.loopbackIPv4, 0);
    gallery = Uri.parse('http://127.0.0.1:${server.port}/components/tooltip');
    addTearDown(() => server.close(force: true));
  });

  Future<ChromeDriver> chrome() async {
    final driver = await ChromeDriver.launch();
    addTearDown(driver.close);
    await driver.open(gallery);
    return driver;
  }

  test('hover waits, crosses the gap, and cancels pending opens and closes', () async {
    final driver = await chrome();
    await driver.pointer(_trigger);
    expect(await driver.evaluate(_open), isFalse);
    await driver.pointer('#before-hint');
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 500))'), isFalse);

    await driver.pointer(_trigger);
    await _waitFor(driver, _placed);
    await _waitFor(driver, "$_hint.getAnimations().every(animation => animation.playState !== 'running')");
    final gap =
        await driver.evaluate('''(() => {
      const trigger = $_button.getBoundingClientRect(), hint = $_hint.getBoundingClientRect();
      return {x: (trigger.left + trigger.right) / 2, y: (trigger.top + hint.bottom) / 2,
        gap: trigger.top - hint.bottom, side: $_hint.dataset.side, text: $_hint.textContent.trim()};
    })()''')
            as Map;
    expect(gap['gap'], closeTo(4, 1));
    expect(gap['side'], 'top');
    expect(gap['text'], 'Find light and dark themes.');
    await driver.probe.command('Input.dispatchMouseEvent', {'type': 'mouseMoved', 'x': gap['x'], 'y': gap['y']});
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 300))'), isTrue);
    await driver.pointer('#colour-hint');
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 300))'), isTrue);

    await driver.pointer('#before-hint');
    expect(await driver.evaluate(_open), isTrue);
    await driver.pointer('#colour-hint');
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 300))'), isTrue);
    await driver.pointer('#before-hint');
    await _waitFor(driver, '!$_open');

    const defaultOpen = "document.getElementById('shortcut-hint').matches(':popover-open')";
    await driver.pointer('#shortcuts');
    expect(await driver.evaluate(defaultOpen), isFalse);
    await _waitFor(driver, defaultOpen);
    await driver.pointer('#before-hint');
    expect(await driver.evaluate(defaultOpen), isTrue);
    await _waitFor(driver, '!$defaultOpen');
    expect(await driver.evaluate(_csp), isEmpty);
  });

  test('Tab describes the same control once and blur closes even if still hovered', () async {
    final driver = await chrome();
    await driver.evaluate("document.getElementById('before-hint').focus()");
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'colour-mode');
    expect(await driver.evaluate(_placed), isTrue, reason: 'No hover delay on Tab');
    expect(
      await driver.evaluate('''[
      $_button.textContent.trim(),
      $_button.tagName,
      $_button.getAttribute('aria-describedby'),
      $_hint.getAttribute('role'),
      document.getElementById('colour-mode-help').textContent.trim(),
      document.querySelectorAll('#colour-hint').length
    ]'''),
      ['Colour mode', 'A', 'colour-mode-help colour-hint', 'tooltip', 'Light and dark modes are available.', 1],
    );
    await driver.pointer(_trigger);
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'shortcuts');
    expect(await driver.evaluate("document.getElementById('shortcut-hint').matches(':popover-open')"), isTrue);
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 500))'), isFalse);
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'swap');
    expect(await driver.evaluate("document.getElementById('shortcut-hint').matches(':popover-open')"), isFalse);
    expect(await driver.evaluate(_csp), isEmpty);
  });

  test('Escape cancels both modes and a later input can reopen the hint', () async {
    final driver = await chrome();
    await driver.evaluate("document.getElementById('before-hint').focus()");
    await driver.press('Tab');
    expect(await driver.evaluate(_open), isTrue);
    await driver.pointer(_trigger);
    await driver.press('Escape');
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 500))'), isFalse);
    expect(await driver.evaluate('document.activeElement.id'), 'colour-mode');

    await driver.press('Tab');
    await driver.press('Escape');
    await driver.pointer('#before-hint');
    await driver.pointer(_trigger);
    await _waitFor(driver, _placed);
    await driver.press('Escape');
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 500))'), isFalse);
    expect(await driver.evaluate('document.activeElement.id'), 'shortcuts');

    await driver.pointer('#before-hint');
    await driver.pointer(_trigger);
    await driver.press('Escape');
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 500))'), isFalse);
    await driver.pointer('#before-hint');
    await driver.pointer(_trigger);
    await _waitFor(driver, _placed);
    expect(await driver.evaluate(_csp), isEmpty);
  });

  for (final (name, launch) in [('Chrome', ChromeDriver.launch), ('Firefox', FirefoxDriver.launch)]) {
    test('native touch activates the independently named link with $name', () async {
      final driver = await launch();
      addTearDown(driver.close);
      await driver.open(gallery);
      expect(await driver.media(coarse: true), isTrue, reason: '${driver.name} coarse/no-hover emulation');
      await driver.evaluate('''$_button.addEventListener('pointerdown', event => {
        window.tap = {type: event.pointerType, id: event.target.id, trusted: event.isTrusted};
      })''');
      switch (driver) {
        case final ChromeDriver chrome:
          final center = await chrome.evaluate('''(() => {
            const rect = $_button.getBoundingClientRect();
            return {x: rect.x + rect.width / 2, y: rect.y + rect.height / 2};
          })()''');
          await chrome.probe.command('Input.dispatchTouchEvent', {
            'type': 'touchStart',
            'touchPoints': [center],
          });
          await chrome.probe.command('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []});
        case final FirefoxDriver firefox:
          await firefox.tap(_trigger);
      }
      await _waitFor(driver, "location.hash === '#colour-settings'");
      expect(await driver.evaluate('window.tap'), {'type': 'touch', 'id': 'colour-mode', 'trusted': true});
      expect(await driver.evaluate("document.getElementById('colour-settings').textContent.trim()"), 'Colour settings');
      expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 500))'), isFalse);
      expect(await driver.evaluate(_csp), isEmpty);
    }, tags: name == 'Firefox' ? 'ui-gate' : null);
  }

  test('explicit zero delays survive the embedded fragment', () {
    final engine = Trellis(loader: TrellisUiLoader());
    final rendered = engine.render("""
      <div tl:replace="~{trellis-ui/tooltip :: tooltip('hint', 'Help', 'right', 0, 0)}">
        <tl:block tl:slot="trigger"><button type="button">Options</button></tl:block>
      </div>
      """, const {});
    expect(rendered, contains('data-open-delay="0"'));
    expect(rendered, contains('data-close-delay="0"'));
  });

  test('a closed enclosing dialog cannot gain a delayed hint', () async {
    final driver = await chrome();
    await driver.evaluate(r"""
      (() => {
        const dialog = document.createElement('dialog');
        dialog.id = 'dialog';
        const button = document.createElement('button');
        button.id = 'modal-before';
        button.textContent = 'Previous control in modal';
        dialog.append(button, document.querySelector('tl-tooltip'));
        document.body.append(dialog);
        dialog.showModal();
      })()
      """);
    await driver.pointer(_trigger);
    await driver.evaluate("document.getElementById('dialog').close()");
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve($_open), 500))'), isFalse);
    expect(await driver.evaluate("$_hint.hasAttribute('style')"), isFalse);
  });

  test('a covered hint cannot consume Escape intended for the active modal', () async {
    final driver = await chrome();
    await driver.evaluate(r'''(() => {
      const lower = document.createElement('dialog');
      const top = document.createElement('dialog');
      top.id = 'top-modal';
      const previous = document.createElement('button');
      previous.textContent = 'Previous control';
      lower.append(previous, document.querySelector('tl-tooltip'));
      document.body.append(lower, top);
      lower.showModal();
    })()''');
    await driver.pointer(_trigger);
    await _waitFor(driver, _placed);
    await driver.evaluate("document.getElementById('top-modal').showModal()");
    await driver.press('Escape');
    expect(await driver.evaluate("document.getElementById('top-modal').open"), isFalse);
    expect(await driver.evaluate(_open), isFalse);
  });

  test('real HTMX cancels detached timers and saves clean, reusable markup for Back', () async {
    final driver = await chrome();
    await driver.evaluate('''(() => {
      window.oldHint = $_hint;
      window.pageErrors = [];
      window.addEventListener('error', event => window.pageErrors.push(event.message));
      window.detachedOpens = 0;
      window.oldHint.addEventListener('beforetoggle', event => {
        if (event.newState === 'open') window.detachedOpens++;
      });
    })()''');
    await driver.pointer(_trigger);
    await driver.evaluate("document.getElementById('swap').click()");
    await _waitFor(
      driver,
      "!oldHint.isConnected && !document.querySelector('#demo').classList.contains('htmx-settling')",
    );
    await driver.pointer('#before-hint');
    expect(await driver.evaluate('new Promise(resolve => setTimeout(() => resolve(detachedOpens), 500))'), 0);
    expect(await driver.evaluate('window.pageErrors'), isEmpty);
    expect(await driver.evaluate("!$_open && !$_hint.hasAttribute('style')"), isTrue);
    await driver.pointer(_trigger);
    await _waitFor(driver, _placed);
    await driver.evaluate("document.getElementById('navigate').click()");
    await _waitFor(driver, "location.pathname === '/components/button'");
    expect(
      await driver.evaluate(r'''(() => {
      const cache = JSON.parse(sessionStorage.getItem('htmx-history-cache'));
      const entry = cache.find(item => item.url === '/components/tooltip');
      const snapshot = new DOMParser().parseFromString(entry.content, 'text/html');
      return !!snapshot.querySelector('#colour-hint[data-closed]:not([style],[data-open])');
    })()'''),
      isTrue,
    );
    await driver.history(-1);
    await _waitFor(driver, "location.pathname === '/components/tooltip' && !!$_hint");
    expect(await driver.evaluate("!$_open && !$_hint.hasAttribute('style')"), isTrue);
    await driver.evaluate('''(() => {
      window.opens = 0;
      $_hint.addEventListener('beforetoggle', event => { if (event.newState === 'open') window.opens++; });
      document.getElementById('before-hint').focus();
    })()''');
    await driver.press('Tab');
    await _waitFor(driver, _placed);
    expect(await driver.evaluate('window.opens'), 1);
    expect(await driver.evaluate("$_button.getAttribute('aria-describedby')"), 'colour-mode-help colour-hint');
    await driver.press('Escape');
    expect(await driver.evaluate(_open), isFalse);
    expect(await driver.evaluate(_csp), isEmpty);
  });
}

Future<void> _waitFor(GateDriver driver, String expression) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    if (await driver.evaluate(expression) == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('${driver.name} did not satisfy $expression');
}
