import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
import '../tool/src/gallery.dart';

void main() {
  late Uri gallery;
  late ChromeDriver driver;
  const trigger = '#options-trigger';
  const triggerNode = "document.querySelector('$trigger')";
  const panel = "document.querySelector('#options')";
  const open = "$panel.matches(':popover-open')";
  const placed = "$open && $panel.style.left.endsWith('px')";
  const focused = '$panel.contains(document.activeElement)';
  const expanded = "$triggerNode.getAttribute('aria-expanded')";
  const closed = "!$open && $expanded === 'false'";
  const noCsp = 'window.__trellisCsp.violations';

  setUpAll(() async {
    final server = await shelf_io.serve(galleryHandler(Directory.current), InternetAddress.loopbackIPv4, 0);
    gallery = Uri.parse('http://127.0.0.1:${server.port}/components/popover');
    addTearDown(() => server.close(force: true));
  });

  setUp(() async {
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

  Future<void> click(String selector) => driver.pointer(selector, click: true);
  Future<void> waitForPlacement() async {
    await waitFor(placed);
    await waitFor("$panel.getAnimations().every(animation => animation.playState !== 'running')");
  }

  Future<Map<String, Object?>> geometry() async =>
      (await driver.evaluate('''(() => {
        const a = $triggerNode.getBoundingClientRect(), p = $panel.getBoundingClientRect();
        return {
          top: a.top - p.bottom, right: p.left - a.right, bottom: p.top - a.bottom, left: a.left - p.right,
          sameLeft: p.left - a.left, sameBottom: p.bottom - a.bottom,
          sameCenterX: (p.left + p.right - a.left - a.right) / 2,
          inside: p.left >= 3.9 && p.top >= 3.9 && p.right <= innerWidth - 3.9 && p.bottom <= innerHeight - 3.9,
          width: p.width, height: p.height, resolvedSide: $panel.dataset.side,
          heightCap: parseFloat($panel.style.getPropertyValue('--available-height')), viewport: innerHeight,
          scrollable: $panel.scrollHeight > $panel.clientHeight,
        };
      })()''')
              as Map)
          .cast<String, Object?>();

  test('click, Enter and Space open the native panel at the configured offset and focus inside', () async {
    for (final key in <String?>[null, 'Enter', ' ']) {
      await driver.open(gallery);
      expect(await driver.evaluate(closed), isTrue);
      if (key == null) {
        await click(trigger);
      } else {
        await driver.evaluate('$triggerNode.focus()');
        await driver.press(key);
      }
      await waitForPlacement();
      final box = await geometry();
      expect(box['bottom'], closeTo(8, 1), reason: '$key: $box');
      expect(box['sameLeft'], closeTo(0, 1), reason: '$key: $box');
      expect(box['width'], greaterThan(100));
      expect(box['height'], greaterThan(50));
      expect(await driver.evaluate(focused), isTrue);
      expect(await driver.evaluate(expanded), 'true');
      await driver.press('Tab');
      expect(await driver.evaluate('document.activeElement.id'), 'page-size');
      expect(await driver.evaluate(noCsp), isEmpty);
    }
  });

  test('a canceled native opening leaves the trigger and panel collapsed', () async {
    await driver.open(gallery);
    await driver.evaluate('''(() => {
      $panel.addEventListener('beforetoggle', event => {
        window.canceledOpening = event.newState === 'open';
        event.preventDefault();
      }, {once: true});
    })()''');
    await click(trigger);
    expect(await driver.evaluate('window.canceledOpening'), isTrue);
    expect(await driver.evaluate("[$open, $expanded, $panel.hasAttribute('data-open')]"), [false, 'false', false]);
    await click(trigger);
    await waitForPlacement();
    expect(await driver.evaluate(expanded), 'true');
  });

  test('Escape and outside pointer dismissal return focus, including from a focusable outside control', () async {
    await driver.open(gallery);
    for (final outside in [null, 'h1', '#outside', '#before']) {
      await click(trigger);
      await waitFor(placed);
      if (outside == null) {
        await driver.press('Escape');
      } else {
        await click(outside);
      }
      await waitFor('$closed && document.activeElement === $triggerNode');
    }
    expect(await driver.evaluate('location.hash'), '#after');
    expect(await driver.evaluate(noCsp), isEmpty);
  });

  test('Tab closes the panel when focus leaves it and preserves the newly focused control', () async {
    await driver.open(gallery);
    await click(trigger);
    await waitFor('$placed && $focused');
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'page-size');
    await driver.press('Tab');
    await waitFor("$closed && document.activeElement.id === 'after'");

    await click(trigger);
    await waitFor('$placed && $focused');
    for (final type in ['keyDown', 'keyUp']) {
      await driver.probe.command('Input.dispatchKeyEvent', {
        'type': type,
        'key': 'Tab',
        'code': 'Tab',
        'windowsVirtualKeyCode': 9,
        'modifiers': 8,
      });
    }
    await waitFor('$closed && document.activeElement === $triggerNode');
  });

  test('each side flips at its edge and repositions without losing alignment or internal scroll', () async {
    const opposite = {'top': 'bottom', 'right': 'left', 'bottom': 'top', 'left': 'right'};
    for (final (side, align, edge) in [
      ('top', 'center', '4px auto auto 400px'),
      ('right', 'end', '400px 4px auto auto'),
      ('bottom', 'center', 'auto auto 4px 400px'),
      ('left', 'end', '400px auto auto 4px'),
    ]) {
      await driver.viewport(1000, 900);
      await driver.open(gallery);
      // Reconnect the same server-rendered component with different author options.
      await driver.evaluate('''(() => {
        const old = document.querySelector('tl-popover'), fresh = old.cloneNode(true);
        fresh.dataset.side = '$side';
        fresh.dataset.align = '$align';
        old.replaceWith(fresh);
        const host = document.querySelector('#component');
        host.style.position = 'fixed';
        host.style.margin = '0';
        host.style.inset = '380px auto auto 400px';
      })()''');
      await click(trigger);
      await waitForPlacement();
      final natural = await geometry();
      expect(natural['resolvedSide'], side, reason: '$natural');
      expect(natural[side], closeTo(8, 1), reason: '$natural');
      final alignment = align == 'center' ? 'sameCenterX' : 'sameBottom';
      expect(natural[alignment], closeTo(0, 1), reason: '$side: $natural');

      await driver.evaluate("document.querySelector('#component').style.inset = '$edge'");
      // Dispatching a resize while changing the fixture's position uses the same tracking path as resizing the viewport.
      await driver.evaluate("window.dispatchEvent(new Event('resize'))");
      await waitForPlacement();
      final flipped = await geometry();
      final flippedSide = opposite[side]!;
      expect(flipped['resolvedSide'], flippedSide, reason: '$flipped');
      expect(flipped[flippedSide], closeTo(8, 1), reason: '$flipped');
      expect(flipped['inside'], isTrue, reason: '$flipped');
      expect(await driver.evaluate(noCsp), isEmpty);
    }

    await driver.open(gallery);
    await driver.evaluate(r'''(() => {
      const host = document.querySelector('#component');
      host.style.position = 'fixed';
      host.style.margin = '0';
      host.style.inset = 'calc(50vh - 18px) auto auto 40px';
    })()''');
    await click(trigger);
    await waitForPlacement();
    final natural = await geometry();
    await driver.viewport(390, 215);
    await waitFor(
      '$panel.scrollHeight > $panel.clientHeight && $panel.getBoundingClientRect().bottom <= innerHeight - 3',
    );
    final clamped = await geometry();
    expect(clamped['scrollable'], isTrue, reason: '$clamped');
    expect(clamped['inside'], isTrue, reason: '$clamped');
    expect(clamped['height'], lessThan(natural['height'] as num));
    await driver.evaluate('$panel.scrollTop = 20');
    await driver.evaluate('new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))');
    expect(await driver.evaluate('$panel.scrollTop'), greaterThan(0));
    await driver.viewport(1000, 900);
    await waitFor('$panel.scrollHeight === $panel.clientHeight');
    // A viewport change can restart placement animation after the scrollbar disappears.
    await waitForPlacement();
    expect((await geometry())['height'], closeTo(natural['height'] as num, 1));
    expect(await driver.evaluate(noCsp), isEmpty);

    await driver.evaluate(r'''(() => {
      const host = document.querySelector('#component');
      host.style.position = 'absolute';
      host.style.inset = '380px auto auto 40px';
      document.body.style.minHeight = '200vh';
      scrollTo(0, 160);
    })()''');
    await waitFor('Math.abs($panel.getBoundingClientRect().top - $triggerNode.getBoundingClientRect().bottom - 8) < 1');

    await driver.evaluate('''(() => {
      const content = document.createElement('div');
      content.style.flex = '0 0 150vh';
      $panel.append(content);
      scrollTo(0, 800);
    })()''');
    await waitFor("$triggerNode.getBoundingClientRect().bottom < 0 && $panel.style.top === '4px'");
    await waitForPlacement();
    final offscreen = await geometry();
    expect(offscreen['inside'], isTrue, reason: '$offscreen');
    expect(offscreen['scrollable'], isTrue, reason: '$offscreen');
    expect(offscreen['heightCap'], lessThanOrEqualTo((offscreen['viewport'] as num) - 8));
  });

  test('HTMX swaps and history close a positioned panel and restore clean, reusable markup', () async {
    await driver.open(gallery);
    await click(trigger);
    await waitFor(placed);
    await driver.evaluate('''(() => {
      window.oldPanel = $panel;
      document.body.addEventListener('htmx:beforeSwap', () => {
        window.openAtSwap = $placed;
      }, {capture: true, once: true});
      document.querySelector('#swap').click();
    })()''');
    await waitFor(
      "!window.oldPanel.isConnected && !document.querySelector('#demo').classList.contains('htmx-settling')",
    );
    expect(await driver.evaluate('window.openAtSwap'), isTrue);
    expect(await driver.evaluate("window.oldPanel.matches(':popover-open,[data-open],[style]')"), isFalse);
    expect(await driver.evaluate("$closed && !$panel.hasAttribute('style')"), isTrue);
    await click(trigger);
    await waitFor(placed);
    await driver.evaluate(r'''(() => {
      const result = document.createElement('div');
      result.id = 'history-result';
      document.querySelector('main').append(result);
      const navigation = document.createElement('button');
      navigation.setAttribute('hx-get', '/components/button');
      navigation.setAttribute('hx-target', '#history-result');
      navigation.setAttribute('hx-select', 'h1');
      navigation.setAttribute('hx-push-url', 'true');
      document.querySelector('main').append(navigation);
      htmx.process(navigation);
      // The swap is outside the popup. Only beforeHistorySave can close it here.
      document.body.addEventListener('htmx:beforeHistorySave', () => {
        window.openAtSave = document.querySelector('#options').matches(':popover-open[style]');
      }, {capture: true, once: true});
      navigation.click();
    })()''');
    await waitFor(
      "location.pathname === '/components/button' && document.querySelector('#history-result > h1') !== null",
    );
    expect(await driver.evaluate('window.openAtSave'), isTrue);
    expect(await driver.evaluate("$closed && !$panel.hasAttribute('style')"), isTrue);
    expect(
      await driver.evaluate(r'''(() => {
        const entry = JSON.parse(sessionStorage.getItem('htmx-history-cache')).find(e => e.url === '/components/popover');
        const snapshot = new DOMParser().parseFromString(entry.content, 'text/html');
        return !!snapshot.querySelector('#options[data-closed]:not([style],[data-open])') &&
          snapshot.querySelector('#options-trigger').getAttribute('aria-expanded') === 'false';
      })()'''),
      isTrue,
    );
    await driver.history(-1);
    await waitFor("location.pathname === '/components/popover' && $panel !== null");
    expect(await driver.evaluate("$closed && !$panel.hasAttribute('style')"), isTrue);
    await driver.evaluate('''(() => {
      window.opens = 0;
      $panel.addEventListener('beforetoggle', e => { if (e.newState === 'open') window.opens++; });
    })()''');
    await click(trigger);
    await waitFor('$placed && $focused');
    expect(await driver.evaluate('window.opens'), 1);
    expect(await driver.evaluate(noCsp), isEmpty);
  });

  test('HTMX can replace just the trigger while its panel is open', () async {
    await driver.open(gallery);
    await click(trigger);
    await waitForPlacement();
    await driver.evaluate('''(async () => {
      window.oldTrigger = $triggerNode;
      window.originalPanel = $panel;
      await htmx.ajax('GET', '/components/popover', {
        target: window.oldTrigger, select: '$trigger', swap: 'outerHTML'
      });
    })()''');
    await waitFor("!window.oldTrigger.isConnected && !$triggerNode.classList.contains('htmx-settling')");
    expect(await driver.evaluate('$panel === window.originalPanel'), isTrue);
    expect(await driver.evaluate("$closed && !$panel.hasAttribute('style')"), isTrue);
    await driver.evaluate('''(() => {
      window.opens = 0;
      $panel.addEventListener('beforetoggle', e => { if (e.newState === 'open') window.opens++; });
    })()''');
    await click(trigger);
    await waitFor('$placed && $focused');
    expect(await driver.evaluate('window.opens'), 1);
    expect(await driver.evaluate(expanded), 'true');
    await driver.evaluate('''(() => {
      $triggerNode.style.marginInlineStart = '24px';
      window.dispatchEvent(new Event('resize'));
    })()''');
    await waitForPlacement();
    expect((await geometry())['sameLeft'], closeTo(0, 1));
    expect(await driver.evaluate(noCsp), isEmpty);
  });

  test('without JavaScript the visible trigger cannot show the panel', () async {
    expect(
      await driver.probe.evaluate(
        gallery,
        '''
        (() => {
          const button = $triggerNode;
          if (button.textContent.trim() !== 'Options' || !button.getBoundingClientRect().height) return false;
          button.click();
          return !$open && $panel.getBoundingClientRect().height === 0;
        })()
      ''',
        width: 390,
        height: 800,
        disableScripts: true,
      ),
      isTrue,
    );
  });
}
