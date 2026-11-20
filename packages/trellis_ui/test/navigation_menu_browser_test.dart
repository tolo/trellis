import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
import '../tool/src/gallery.dart';

void main() {
  late Uri page;
  late ChromeDriver driver;
  const onlyGuides = "[...document.querySelectorAll('#component :popover-open')].map(p => p.id).join() === 'guides'";
  const onlyReference =
      "[...document.querySelectorAll('#component :popover-open')].map(p => p.id).join() === 'reference'";
  const closed = "document.querySelector('#component :popover-open') === null";

  setUpAll(() async {
    final server = await shelf_io.serve(galleryHandler(Directory.current), InternetAddress.loopbackIPv4, 0);
    page = Uri.parse('http://127.0.0.1:${server.port}/preview/components/navigation-menu');
    addTearDown(() => server.close(force: true));
  });
  setUp(() async {
    driver = await ChromeDriver.launch();
    addTearDown(driver.close);
  });

  Future<void> focus(String id) => driver.evaluate("document.getElementById('$id').focus()");

  Future<void> waitFor(String expression) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    do {
      if (await driver.evaluate(expression) == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    } while (DateTime.now().isBefore(deadline));
    fail('Condition did not become true: $expression');
  }

  test('click, Enter, Space and Arrow Down open a disclosure beside its trigger', () async {
    for (final key in [null, 'Enter', ' ', 'ArrowDown']) {
      await driver.open(page);
      await focus('guides-trigger');
      expect(await driver.evaluate(closed), isTrue);
      if (key == null) {
        await driver.pointer('#guides-trigger', click: true);
      } else {
        await driver.press(key);
      }
      await waitFor(onlyGuides);
      expect(
        await driver.evaluate(r'''(() => {
          const trigger = document.getElementById('guides-trigger');
          const panel = document.getElementById('guides').getBoundingClientRect();
          const anchor = trigger.getBoundingClientRect();
          return trigger.parentElement.open && panel.top - anchor.bottom === 4 &&
            panel.left === anchor.left && panel.right <= innerWidth;
        })()'''),
        isTrue,
        reason: 'placement and expanded state after ${key ?? 'click'}',
      );
      if (key == 'ArrowDown') {
        expect(await driver.evaluate('document.activeElement.id'), 'nav-overview');
      }
    }
  });

  test('hover keeps focus, crosses into the panel, switches and dismisses after leaving', () async {
    await driver.open(page);
    await focus('nav-home');
    await driver.pointer('#guides-trigger');
    expect(await driver.evaluate(closed), isTrue, reason: 'the first pointer entry starts the open delay');
    await waitFor(onlyGuides);
    expect(await driver.evaluate('document.activeElement.id'), 'nav-home');
    await driver.pointer('#nav-accordion');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(await driver.evaluate(onlyGuides), isTrue);
    await driver.pointer('#reference-trigger');
    await waitFor(onlyReference);
    await driver.press('Escape');
    await waitFor("$closed && document.activeElement.id === 'reference-trigger'");
    await driver.pointer('h1');
    await driver.pointer('#guides-trigger');
    await waitFor(onlyGuides);
    await driver.pointer('h1');
    expect(await driver.evaluate(onlyGuides), isTrue, reason: 'leaving starts the close delay');
    await waitFor(closed);
  });

  test('Tab enters ordinary links, switches to the next group and Escape returns focus', () async {
    await driver.open(page);
    await focus('guides-trigger');
    await driver.press('Enter');
    await waitFor(onlyGuides);
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'nav-overview');
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'nav-accordion');
    await driver.press('Tab');
    await waitFor("$onlyReference && document.activeElement.id === 'reference-trigger'");
    await driver.press('ArrowDown');
    expect(await driver.evaluate('document.activeElement.id'), 'nav-components');
    await driver.press('Escape');
    await waitFor("$closed && document.activeElement.id === 'reference-trigger'");
  });

  test('leaving the menu with Tab lets the next focused control remain visible', () async {
    await driver.viewport(320, 844);
    await driver.open(page);
    await focus('reference-trigger');
    await driver.press('ArrowDown');
    await waitFor(onlyReference);
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'nav-table');
    await driver.press('Tab');
    await waitFor("$closed && document.activeElement.id === 'swap'");
    expect(
      await driver.evaluate(r'''(() => {
      const button = document.activeElement;
      const box = button.getBoundingClientRect();
      return document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2) === button;
    })()'''),
      isTrue,
    );
  });

  test('marks the exact prefixed URL and activates a different destination with the keyboard', () async {
    await driver.open(page);
    const currentLinks =
        "[...document.querySelectorAll('#component [aria-current]')].map(link => [link.id, "
        "link.getAttribute('aria-current'), link.getAttribute('href')])";
    expect(await driver.evaluate(currentLinks), [
      ['nav-overview', 'page', '/preview/components/navigation-menu'],
    ]);
    await focus('guides-trigger');
    await driver.press('Enter');
    await driver.press('Tab');
    await driver.press('Tab');
    await driver.press('Enter');
    await waitFor(
      "location.pathname === '/preview/components/accordion' && document.querySelector('h1').textContent === 'Accordion'",
    );
    await driver.open(page.replace(queryParameters: {'unlisted': '1'}));
    expect(await driver.evaluate(currentLinks), isEmpty);
  });

  for (final disableScripts in [true, false]) {
    final fallback = disableScripts ? 'scripting disabled' : 'suite assets blocked';
    test('all native destinations are in the keyboard order with $fallback', () async {
      if (!disableScripts) {
        await driver.probe.command('Network.setBlockedURLs', {
          'urls': ['*/trellis-ui/*'],
        });
      }
      final loading = await driver.probe.evaluate(
        page,
        r'''[typeof htmx, document.querySelectorAll('#component [popover]').length,
          Boolean(getComputedStyle(document.documentElement).getPropertyValue('--ring'))]''',
        width: 390,
        height: 844,
        disableScripts: disableScripts,
      );
      expect(loading, [disableScripts ? 'undefined' : 'object', 0, disableScripts]);
      await focus('nav-home');
      for (final id in [
        'guides-trigger',
        'nav-overview',
        'nav-accordion',
        'reference-trigger',
        'nav-components',
        'nav-table',
      ]) {
        await driver.press('Tab');
        expect(await driver.evaluate('document.activeElement.id'), id);
        if (id.endsWith('-trigger')) await driver.press('Enter');
      }
      expect(await driver.evaluate("document.querySelector('[aria-current=page]').id"), 'nav-overview');
      await driver.press('Enter');
      await waitFor("location.pathname === '/preview/components/table'");
    });
  }

  test('a late suite load preserves an open native disclosure and its focused link', () async {
    await driver.probe.command('Network.setBlockedURLs', {
      'urls': ['*/trellis-ui/trellis-ui.js'],
    });
    await driver.open(page);
    await focus('guides-trigger');
    await driver.press('Enter');
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'nav-overview');
    expect(await driver.evaluate("document.getElementById('nav-overview').checkVisibility()"), isTrue);
    await driver.probe.command('Network.setBlockedURLs', {'urls': []});
    await driver.evaluate(r'''new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = '/trellis-ui/trellis-ui.js';
      script.onload = resolve;
      script.onerror = reject;
      document.head.append(script);
    })''');
    expect(await driver.evaluate(onlyGuides), isTrue);
    expect(await driver.evaluate("document.getElementById('nav-overview').checkVisibility()"), isTrue);
    expect(await driver.evaluate('document.activeElement.id'), 'nav-overview');
    expect(await driver.evaluate('window.__uiGate.violations'), isEmpty);
  });

  test('HTMX swap and history remove open state, old positioning and delayed hover work', () async {
    await driver.open(page);
    await focus('guides-trigger');
    await driver.press('Enter');
    await waitFor(onlyGuides);
    final listeners = await driver.listeners();
    await driver.evaluate(r'''(() => {
      window.oldPanel = document.getElementById('guides');
      window.oldTrigger = document.getElementById('reference-trigger');
      window.oldReference = window.oldTrigger.nextElementSibling;
      window.oldMenu = document.querySelector('tl-navigation-menu');
      window.durations = [];
      window.oldPanel.addEventListener('beforetoggle', e => window.durations.push(e.newState));
      window.oldTrigger.parentElement.dispatchEvent(new PointerEvent('pointerenter', {pointerType: 'mouse'}));
      document.getElementById('swap').click();
    })()''');
    await waitFor("!window.oldMenu.isConnected && document.querySelector('#component tl-navigation-menu') !== null");
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(
      await driver.evaluate(
        r'''[...window.durations, window.oldPanel.hasAttribute('style'),
      window.oldPanel.parentElement.open, window.oldReference.parentElement.open, document.querySelectorAll('#component details[open]').length]''',
      ),
      ['closed', false, false, false, 0],
    );
    expect(await driver.listeners(), listeners);
    await driver.evaluate(r'''(() => {
      window.opens = 0;
      document.getElementById('guides').addEventListener('beforetoggle', e => {
        if (e.newState === 'open') window.opens++;
      });
      document.getElementById('guides-trigger').focus();
    })()''');
    await driver.press('Enter');
    await waitFor(onlyGuides);
    expect(await driver.evaluate('window.opens'), 1);
    await driver.evaluate("document.getElementById('navigate').click()");
    await waitFor("location.pathname === '/preview/components/breadcrumb'");
    await driver.history(-1);
    await waitFor(
      "location.pathname === '/preview/components/navigation-menu' && document.getElementById('guides') !== null",
    );
    expect(
      await driver.evaluate(
        "document.querySelectorAll('#component details[open], #component [data-trellis-popup]:is([style],[data-side],[data-align])').length",
      ),
      0,
    );
    await focus('guides-trigger');
    await driver.press('Enter');
    await waitFor(onlyGuides);
    expect(await driver.evaluate('window.__uiGate.violations'), isEmpty);
  });
}
