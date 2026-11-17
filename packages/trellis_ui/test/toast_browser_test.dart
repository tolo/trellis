import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
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
}
