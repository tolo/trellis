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
    addTearDown(() => server.close(force: true));
    driver = await ChromeDriver.launch();
    addTearDown(driver.close);
  });

  Future<void> waitFor(String expression) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (await driver.evaluate(expression) == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('Timed out waiting for $expression');
  }

  Future<void> open(String page) async {
    await driver.viewport(1440, 900);
    await driver.open(Uri.parse('http://127.0.0.1:${server.port}/components/$page'));
    await waitFor("customElements.get('tl-dialog') !== undefined && typeof htmx !== 'undefined'");
  }

  Future<void> click(String selector) => driver.pointer(selector, click: true);
  Future<void> clickServerDialog(String selector) async {
    await driver.evaluate(r'''(() => {
      window.serverDialogSettled = false;
      document.getElementById('dialog-response').addEventListener(
        'htmx:afterSettle', () => {window.serverDialogSettled = true;}, {once: true});
    })()''');
    await click(selector);
    await waitFor('window.serverDialogSettled');
  }

  Future<void> focus(String selector) async {
    await driver.evaluate("document.querySelector('$selector').focus()");
  }

  Future<void> backdrop() async {
    for (final type in ['mousePressed', 'mouseReleased']) {
      await driver.probe.command('Input.dispatchMouseEvent', {
        'type': type,
        'button': 'left',
        'x': 4,
        'y': 4,
        'clickCount': 1,
      });
    }
  }

  Future<void> reverseTab() async {
    for (final type in ['keyDown', 'keyUp']) {
      await driver.probe.command('Input.dispatchKeyEvent', {
        'type': type,
        'key': 'Tab',
        'code': 'Tab',
        'windowsVirtualKeyCode': 9,
        'modifiers': 8,
      });
    }
  }

  Future<void> expectOnlyModal(String id) async {
    await waitFor("document.querySelector('#$id:modal[data-open]') !== null");
    expect(await driver.evaluate("document.querySelectorAll('dialog:modal').length"), 1);
    expect(await driver.evaluate("document.getElementById('$id').contains(document.activeElement)"), true);
    await focus('#swap');
    expect(
      await driver.evaluate("document.getElementById('$id').contains(document.activeElement)"),
      true,
      reason: 'The page behind the dialog must be inert',
    );
  }

  test('dialog opens modally, traps focus, returns it and dismisses on Escape and backdrop', () async {
    await open('dialog');
    await click('#open-dialog');
    await expectOnlyModal('example-dialog');
    expect(
      await driver.evaluate(r'''(() => {
        const dialog = document.querySelector('#example-dialog');
        return ['aria-labelledby','aria-describedby'].map(attr =>
          document.getElementById(dialog.getAttribute(attr)).textContent);
      })()'''),
      ['Edit profile', 'Update your public profile.'],
    );
    expect(await driver.evaluate('document.activeElement.id'), 'dialog-name');
    for (final id in ['dialog-email', 'dialog-cancel', 'dialog-save']) {
      await driver.press('Tab');
      expect(await driver.evaluate('document.activeElement.id'), id);
    }
    await driver.press('Tab');
    expect(await driver.evaluate("document.activeElement.getAttribute('data-slot')"), 'dialog-close');
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'dialog-name');
    await reverseTab();
    expect(await driver.evaluate("document.activeElement.getAttribute('data-slot')"), 'dialog-close');
    await driver.press('Escape');
    await waitFor(
      "document.querySelector('#example-dialog[data-closed]:not([open])') && document.activeElement.id === 'open-dialog'",
    );

    await driver.press('Enter');
    await expectOnlyModal('example-dialog');
    await click('#dialog-email');
    expect(await driver.evaluate("document.querySelector('#example-dialog').matches(':modal')"), true);
    await backdrop();
    await waitFor(
      "document.querySelector('#example-dialog[data-closed]:not([open])') && document.activeElement.id === 'open-dialog'",
    );
  });

  test('an open dialog removed by a swap returns focus to its opener', () async {
    await open('dialog');
    await clickServerDialog('#load-dialog');
    await expectOnlyModal('server-dialog');
    await clickServerDialog('#remove-server-dialog');
    await waitFor("!document.getElementById('server-dialog') && document.activeElement.id === 'load-dialog'");
  });

  test('a server-rendered open dialog is modal on load and after a swap and is closed in history', () async {
    await open('dialog?open=1');
    await expectOnlyModal('example-dialog');
    await driver.press('Escape');
    await waitFor("!document.getElementById('example-dialog').open");

    await clickServerDialog('#load-dialog');
    await expectOnlyModal('server-dialog');
    await driver.evaluate("window.previousDialog = document.getElementById('server-dialog')");
    await clickServerDialog('#replace-server-dialog');
    await waitFor("!previousDialog.isConnected && document.getElementById('server-dialog') !== previousDialog");
    await expectOnlyModal('server-dialog');

    // Native modality makes the boosted link inert while the dialog is open.
    await driver.evaluate("document.getElementById('navigate').click()");
    await waitFor("location.pathname === '/components/button' && !document.getElementById('server-dialog')");
    await driver.history(-1);
    await waitFor(
      "location.pathname === '/components/dialog' && document.querySelector('#server-dialog[data-closed]:not([open])') !== null",
    );
    expect(await driver.evaluate("document.querySelectorAll('dialog:modal').length"), 0);
  });

  test('alert dialog focuses Cancel and ignores backdrop clicks', () async {
    await open('alert-dialog');
    await click('#open-alert');
    await expectOnlyModal('example-alert');
    expect(await driver.evaluate("document.activeElement.getAttribute('data-slot')"), 'alert-dialog-cancel');
    await backdrop();
    expect(await driver.evaluate("document.querySelector('#example-alert[role=alertdialog]').matches(':modal')"), true);
    expect(await driver.evaluate("document.querySelector('#example-alert [data-slot=dialog-close]')"), isNull);
    await driver.press('Escape');
    await waitFor("!document.getElementById('example-alert').open && document.activeElement.id === 'open-alert'");

    await driver.press('Enter');
    await expectOnlyModal('example-alert');
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'confirm-alert');
    await driver.press('Enter');
    await waitFor(
      "!document.getElementById('example-alert').open && document.getElementById('alert-result').textContent === ''",
    );
    expect(await driver.evaluate('document.activeElement.id'), 'open-alert');
  });

  test('a menu item opens a server-rendered alert dialog', () async {
    await open('dropdown-menu');
    await focus('#menu-trigger');
    await driver.press('ArrowDown');
    await waitFor("document.getElementById('menu-trigger').getAttribute('aria-expanded') === 'true'");
    await focus('#menu-alert');
    await driver.press('Enter');
    await expectOnlyModal('menu-alert-dialog');
    expect(await driver.evaluate("document.activeElement.getAttribute('data-slot')"), 'alert-dialog-cancel');
    expect(await driver.evaluate("document.getElementById('menu-trigger').getAttribute('aria-expanded')"), 'false');
    await driver.press('Escape');
    await waitFor("!document.getElementById('menu-alert-dialog').open && document.activeElement.id === 'menu-trigger'");
  });
}
