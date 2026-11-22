import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
import '../../../tool/ui_gate/firefox.dart';
import '../tool/src/gallery.dart';

const _modal = "document.querySelector('#palette').matches(':modal')";
const _focused = 'document.activeElement.id';
const _options =
    "Array.from(document.querySelectorAll('#palette [role=option]:not([hidden])'), option => option.textContent.trim())";

void main() {
  late Uri gallery;
  Future<void> Function()? holdOptions;
  setUpAll(() async {
    final handler = galleryHandler(Directory.current);
    final server = await shelf_io.serve(
      (request) async {
        if (request.requestedUri.path == '/demo/options') await holdOptions?.call();
        return handler(request);
      },
      InternetAddress.loopbackIPv4,
      0,
    );
    gallery = Uri.parse('http://127.0.0.1:${server.port}/components/command-palette');
    addTearDown(() => server.close(force: true));
  });

  test('Firefox opens pending combobox results after the browser window is backgrounded', () async {
    final requested = Completer<void>();
    final respond = Completer<void>();
    holdOptions = () {
      requested.complete();
      return respond.future;
    };
    addTearDown(() {
      holdOptions = null;
      if (!respond.isCompleted) respond.complete();
    });

    final driver = await FirefoxDriver.launch();
    addTearDown(driver.close);
    await driver.viewport(768, 900);
    await driver.open(gallery.resolve('/components/combobox'));
    await driver.evaluate(r'''(() => {
      const input = document.getElementById('fruit');
      window.optionRequests = 0;
      input.addEventListener('htmx:beforeRequest', () => window.optionRequests++);
      input.focus();
    })()''');
    await driver.type('ap');
    await requested.future.timeout(const Duration(seconds: 5));
    await _background(driver, 'fruit');
    respond.complete();
    await _waitFor(driver, "document.querySelector('#component [role=status]').textContent === '2 results available'");
    expect(
      await driver.evaluate(r'''(() => {
        const input = document.getElementById('fruit');
        return [window.optionRequests, document.getElementById('fruit-popup').matches(':popover-open'),
          input.getAttribute('aria-expanded'), input.value];
      })()'''),
      [1, true, 'true', 'ap'],
    );
    await driver.press('ArrowDown');
    expect(await driver.evaluate("document.activeElement.getAttribute('aria-activedescendant')"), 'fruit-option-0');
    await driver.press('Tab');
    expect(await driver.evaluate(_focused), 'after');
    expect(await driver.evaluate("document.querySelector('#fruit-popup').matches(':popover-open')"), isFalse);
  });

  test('Firefox keeps open palette results while the browser window is backgrounded', () async {
    final driver = await FirefoxDriver.launch();
    addTearDown(driver.close);
    await driver.open(gallery);
    await driver.pointer('#open-palette', click: true);
    await driver.type('zzz');
    const results = "document.getElementById('palette-query-popup').matches(':popover-open')";
    expect(await driver.evaluate(results), isTrue);

    await _background(driver, 'palette-query');
    expect(await driver.evaluate(results), isTrue);
    await driver.press('Escape');
    await _waitFor(driver, "!$_modal && $_focused === 'open-palette'");
    expect(await driver.evaluate(results), isFalse);
  });

  for (final (name, launch) in [('Chrome', ChromeDriver.launch), ('Firefox', FirefoxDriver.launch)]) {
    test('$name palette filters, selects and restores real focus after swaps and cancellation', () async {
      final driver = await launch();
      addTearDown(driver.close);
      await driver.open(gallery);
      final Future<void> Function(String, {required bool command}) shortcut = switch (driver) {
        ChromeDriver() => driver.pressShortcut,
        FirefoxDriver() => driver.pressShortcut,
        _ => throw StateError('Unexpected gallery browser'),
      };

      await driver.evaluate(r'''(() => {
        window.chosen = [];
        document.addEventListener('tl-select', event => window.chosen.push(event.detail.value));
        const controls = document.createElement('div');
        controls.innerHTML = '<input id="editable"><textarea id="notes"></textarea>' +
          '<div contenteditable><span tabindex="0" id="editable-child">Editable</span></div>' +
          '<button id="handled">Handled</button><dialog id="other"><button autofocus>Other modal</button></dialog>';
        document.body.append(controls);
        document.querySelector('#handled').addEventListener('keydown', event => event.preventDefault());
        window.addEventListener('keydown', event => {
          if (event.key.toLowerCase() === 'k') window.shortcut = [event.isTrusted, event.defaultPrevented];
        });
      })()''');
      Future<void> pressShortcut({bool command = false}) => shortcut('k', command: command);
      Future<void> focus(String id) => driver.evaluate("document.getElementById('$id').focus()");
      Future<void> dismissPalette(String key, String opener) async {
        // Native close listeners can restore focus after the dialog leaves the top layer.
        await driver.evaluate(r'''(() => {
          window.paletteClosed = false;
          document.getElementById('palette').addEventListener('close', event => {
            window.paletteClosed = event.isTrusted;
          }, { once: true });
        })()''');
        await driver.press(key);
        await _waitFor(driver, "window.paletteClosed && !$_modal && $_focused === '$opener'");
      }

      await driver.pointer('#open-palette', click: true);
      expect(await driver.evaluate(_modal), isTrue);
      expect(await driver.evaluate(_focused), 'palette-query');
      await driver.type('AP');
      expect(await driver.evaluate(_options), ['Apple', 'Apricot']);
      await driver.press('ArrowDown');
      await driver.press('ArrowDown');
      expect(
        await driver.evaluate("document.activeElement.getAttribute('aria-activedescendant')"),
        'palette-query-option-1',
      );
      await driver.press('ArrowUp');
      expect(
        await driver.evaluate("document.activeElement.getAttribute('aria-activedescendant')"),
        'palette-query-option-0',
      );
      await dismissPalette('Enter', 'open-palette');
      expect(await driver.evaluate('window.chosen'), ['apple']);

      await focus('palette-opener');
      await pressShortcut(command: Platform.isMacOS);
      expect(await driver.evaluate('window.shortcut'), [true, true]);
      expect(await driver.evaluate(_focused), 'palette-query');
      await driver.type('BAN');
      expect(await driver.evaluate(_options), ['Banana']);
      await dismissPalette('Escape', 'palette-opener');
      await pressShortcut(command: Platform.isMacOS);
      expect(await driver.evaluate('document.activeElement.value'), isEmpty);
      expect(await driver.evaluate("document.activeElement.getAttribute('aria-expanded')"), 'false');
      await dismissPalette('Escape', 'palette-opener');

      for (final id in ['editable', 'notes', 'editable-child', 'handled']) {
        await focus(id);
        expect(await driver.evaluate(_focused), id);
        await pressShortcut(command: Platform.isMacOS);
        expect(await driver.evaluate(_modal), isFalse, reason: id);
        expect(await driver.evaluate('window.shortcut'), [true, id == 'handled'], reason: id);
      }
      await driver.evaluate("document.getElementById('other').showModal()");
      await pressShortcut(command: Platform.isMacOS);
      expect(await driver.evaluate(_modal), isFalse);
      await driver.press('Escape');

      await focus('palette-opener');
      await shortcut('m', command: Platform.isMacOS);
      expect(await driver.evaluate(_modal), isFalse);
      expect(await driver.evaluate(_focused), 'second-palette-query');
      await driver.type('banana');
      await driver.press('ArrowDown');
      await driver.press('Enter');
      await _waitFor(driver, "!document.getElementById('second-palette').open && $_focused === 'palette-opener'");
      expect(await driver.evaluate('window.chosen'), ['apple', 'banana']);

      final before = await driver.listeners();
      await driver.evaluate("window.oldRegion = document.getElementById('demo')");
      await driver.pointer('#swap', click: true);
      await _waitFor(driver, '!window.oldRegion.isConnected && !!document.querySelector("#open-palette")');
      expect(await driver.listeners(), before);
      await focus('palette-opener');
      await pressShortcut(command: Platform.isMacOS);
      expect(await driver.evaluate(_focused), 'palette-query');
      await driver.type('zzz');
      expect(await driver.evaluate("document.querySelector('#palette [role=status]').innerText"), 'No results');

      await driver.evaluate("document.getElementById('navigate').click()");
      await _waitFor(driver, "location.pathname === '/components/button'");
      await driver.history(-1);
      await _waitFor(
        driver,
        "location.pathname === '/components/command-palette' && !!document.querySelector('#open-palette')",
      );
      expect(await driver.evaluate(_modal), isFalse);
      expect(await driver.evaluate("document.getElementById('palette-query').defaultValue"), isEmpty);
      await focus('palette-opener');
      await pressShortcut(command: Platform.isMacOS);
      expect(await driver.evaluate('document.activeElement.value'), isEmpty);
      expect(await driver.evaluate('window.__trellisCsp.violations'), isEmpty);
    });
  }
}

Future<void> _background(FirefoxDriver driver, String activeId) async {
  await driver.evaluate(r'''(() => {
    window.contenderBlur = null;
    window.addEventListener('keyup', () => requestAnimationFrame(() => {
      window.addEventListener('blur', event => {
        window.contenderBlur = {
          trusted: event.isTrusted,
          visible: !document.hidden,
          focused: document.hasFocus(),
          active: document.activeElement.id,
        };
      }, {once: true});
      if (!window.open('/components/button', 'focus-contender', 'popup,width=260,height=180')) {
        window.contenderBlur = {error: 'Firefox blocked the focus contender'};
      }
    }), {once: true});
  })()''');
  // Native End reactivates the source window while only moving the combobox caret.
  await driver.press('End');
  await _waitFor(driver, 'window.contenderBlur !== null');
  expect(await driver.evaluate('window.contenderBlur'), {
    'trusted': true,
    'visible': true,
    'focused': false,
    'active': activeId,
  });
}

Future<void> _waitFor(GateDriver driver, String expression) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  do {
    if (await driver.evaluate(expression) == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  } while (DateTime.now().isBefore(deadline));
  fail('${driver.name} did not reach $expression');
}
