import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
import '../../../tool/ui_gate/firefox.dart';
import '../tool/src/gallery.dart';

void main() {
  late HttpServer server;
  late ChromeDriver driver;

  setUp(() async {
    server = await shelf_io.serve(galleryHandler(Directory.current), InternetAddress.loopbackIPv4, 0);
    driver = await ChromeDriver.launch();
    await driver.viewport(390, 844);
  });

  tearDown(() async {
    await driver.close();
    await server.close(force: true);
  });

  Future<void> waitFor(String expression) async {
    for (var attempt = 0; attempt < 150; attempt++) {
      if (await driver.evaluate(expression) == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('Timed out waiting for $expression');
  }

  const count = "document.querySelectorAll('#toaster > tl-toast').length";
  Future<void> add(String button, int expected) async {
    await driver.pointer(button, click: true);
    await waitFor('$count === $expected');
  }

  test('tabs display the selected panel with scripts disabled', () async {
    final panels = await driver.probe.evaluate(
      Uri.parse('http://127.0.0.1:${server.port}/components/tabs'),
      r'''(() => ({
        scriptDisabled: typeof customElements.get('tl-tabs') === 'undefined',
        visible: [...document.querySelectorAll('[role=tabpanel]')]
          .filter(panel => panel.getBoundingClientRect().height > 0).map(panel => panel.id),
      }))()''',
      width: 390,
      height: 844,
      disableScripts: true,
    );
    expect(panels, {
      'scriptDisabled': true,
      'visible': ['horizontal-panel-account', 'vertical-panel-email'],
    });
  });

  test('an out-of-band toast joins the live region and behaves', () async {
    await driver.open(Uri.parse('http://127.0.0.1:${server.port}/components/toast'));
    expect(
      await driver.evaluate("document.querySelector('#toaster[role=region][aria-live=polite]').children.length"),
      0,
    );
    await add('#toast-add', 1);
    await add('#toast-add', 2);
    expect(
      await driver.evaluate('''(() => {
        const [first, second] = [...document.querySelectorAll('#toaster .trellis-toast')];
        return first.getBoundingClientRect().bottom <= second.getBoundingClientRect().top
          && document.querySelectorAll('#toaster').length === 1;
      })()'''),
      isTrue,
    );
    await driver.pointer('#toaster > tl-toast:nth-child(2) button', click: true);
    expect(await driver.evaluate(count), 1);

    await add('#toast-timed', 2);
    await add('#toast-timed', 3);
    await driver.pointer('#toaster > tl-toast:nth-child(2) [data-slot=toast]');
    await driver.evaluate("document.querySelector('#toaster > tl-toast:nth-child(3) button').focus()");
    await Future<void>.delayed(const Duration(milliseconds: 5250));
    expect(
      await driver.evaluate(
        '''$count === 3 && document.querySelector('#toaster > tl-toast:nth-child(2):hover') !== null
        && document.activeElement.closest('tl-toast') === document.querySelector('#toaster > tl-toast:nth-child(3)')''',
      ),
      isTrue,
      reason: 'The hovered and focused toasts must both outlast their timer.',
    );
    await driver.pointer('#toast-add');
    await driver.evaluate('document.activeElement.blur()');
    await Future<void>.delayed(const Duration(milliseconds: 5000));
    await waitFor('$count === 1');
    expect(await driver.evaluate("document.querySelector('#toaster > tl-toast').dataset.duration"), '0');
    expect(await driver.evaluate('window.__trellisCsp.violations'), isEmpty);

    final loadedPages = driver.requests.where((url) => Uri.parse(url).path == '/components/toast').length;
    await driver.pointer('#navigate', click: true);
    await waitFor("location.pathname === '/components/button'");
    await driver.history(-1);
    await waitFor("location.pathname === '/components/toast' && document.querySelector('#toaster') !== null");
    expect(await driver.evaluate(count), 0);
    expect(
      driver.requests.where((url) => Uri.parse(url).path == '/components/toast').length,
      loadedPages,
      reason: 'Back must restore the saved snapshot instead of fetching a fresh empty page.',
    );
  });
  test('cancelled touch lets an expired toast timer finish after the main thread is busy', () async {
    await driver.open(Uri.parse('http://127.0.0.1:${server.port}/components/toast'));
    expect(
      await driver.evaluate(r'''new Promise(resolve => {
        const viewport = document.getElementById('toaster');
        const observeArrival = new MutationObserver(() => {
          const toast = viewport.querySelector('tl-toast');
          if (!toast) return;
          observeArrival.disconnect();
          const deadline = performance.now() + 60;
          // The timer is due, but cannot run until this browser task returns.
          while (performance.now() < deadline) {}
          const pointer = {bubbles: true, pointerType: 'touch', pointerId: 1, isPrimary: true};
          toast.dispatchEvent(new PointerEvent('pointerdown', pointer));
          toast.dispatchEvent(new PointerEvent('pointercancel', pointer));
          resolve(toast.isConnected);
        });
        observeArrival.observe(viewport, {childList: true});
        htmx.ajax('GET', '/demo/toast?duration=40', {target: '#demo', swap: 'none'});
      })'''),
      isTrue,
    );
    await waitFor('$count === 0');
  });

  for (final name in ['Chrome', 'Firefox']) {
    test('$name trusted touch dismisses only the rightward-swiped toast', () async {
      final touchDriver = name == 'Chrome' ? driver : await FirefoxDriver.launch();
      if (touchDriver != driver) addTearDown(touchDriver.close);
      await touchDriver.viewport(390, 844);
      await touchDriver.open(Uri.parse('http://127.0.0.1:${server.port}/components/toast'));
      expect(await touchDriver.media(coarse: true), isTrue);
      for (var index = 1; index <= 3; index++) {
        await touchDriver.pointer('#toast-add', click: true);
        final inserted = await touchDriver.evaluate('''(async () => {
          for (let attempt = 0; attempt < 60; attempt++) {
            if ($count === $index) return true;
            await new Promise(requestAnimationFrame);
          }
          return false;
        })()''');
        expect(inserted, true, reason: 'HTMX inserted toast $index');
      }
      await touchDriver.evaluate("""(() => {
        window.toastSequence = [...document.querySelectorAll('#toaster > tl-toast')];
        window.touchStarts = [];
        window.touchCancels = 0;
        const viewport = document.getElementById('toaster');
        viewport.addEventListener('pointerdown', event => touchStarts.push({
          pointer: event.pointerType, trusted: event.isTrusted,
        }));
        viewport.addEventListener('pointercancel', () => touchCancels++);
        document.body.style.minHeight = '1800px';
      })()""");
      const target = '#toaster > tl-toast:nth-child(2) [data-slot=toast]';
      await touchDriver.dragTouch(target, dx: -85, dy: 0);
      await touchDriver.dragTouch(target, dx: 21, dy: 0);
      if (touchDriver is ChromeDriver) {
        await touchDriver.evaluate('''
          document.addEventListener('scrollend', () => { window.toastScrollEnded = true; }, {once: true})
        ''');
      }
      await touchDriver.dragTouch(target, dx: 12, dy: -115);
      expect(await touchDriver.evaluate(count), 3);
      expect(
        await touchDriver.evaluate("getComputedStyle(document.querySelector('$target')).touchAction"),
        contains('pan-y'),
      );
      if (touchDriver is ChromeDriver) {
        // Chrome can keep scrolling after the diagonal touch ends.
        await waitFor('window.toastScrollEnded === true && scrollY > 0');
        final cancels = await touchDriver.evaluate('window.touchCancels') as int;
        await touchDriver.dragTouch(target, dx: 86, dy: 0, cancel: true);
        expect(await touchDriver.evaluate('window.touchCancels'), cancels + 1);
        expect(await touchDriver.evaluate(count), 3);
      }
      await touchDriver.dragTouch(target, dx: 86, dy: 4);
      expect(await touchDriver.evaluate(count), 2);
      expect(
        await touchDriver.evaluate("""(() => {
          const [first, last] = document.getElementById('toaster').children;
          return first === toastSequence[0] && last === toastSequence[2] &&
            first.querySelector('[data-slot=toast]').getBoundingClientRect().bottom <=
            last.querySelector('[data-slot=toast]').getBoundingClientRect().top;
        })()"""),
        true,
      );
      final starts = await touchDriver.evaluate('window.touchStarts') as List;
      expect(starts, hasLength(name == 'Chrome' ? 5 : 4));
      expect(starts, everyElement({'pointer': 'touch', 'trusted': true}));
      await touchDriver.pointer('#toaster [data-slot=toast-close]', click: true);
      expect(await touchDriver.evaluate(count), 1);
      expect(await touchDriver.evaluate('window.__trellisCsp.violations'), isEmpty);
    }, tags: name == 'Firefox' ? 'ui-gate' : null);
  }
}
