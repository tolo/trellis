import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
import '../tool/src/gallery.dart';

void main() {
  late Uri page;
  late ChromeDriver driver;
  const dialog = "document.getElementById('right-sheet')";
  const trigger = "document.getElementById('open-right')";
  const open = "$dialog.matches(':modal') && $trigger.getAttribute('aria-expanded') === 'true'";
  const containedFocus = '$dialog.contains(document.activeElement)';
  const closed = "!$dialog.open && $trigger.getAttribute('aria-expanded') === 'false'";
  const close = '#right-sheet [data-dialog-close]';

  setUpAll(() async {
    final gallery = galleryHandler(Directory.current);
    final server = await shelf_io.serve(
      (request) => request.requestedUri.path == '/demo/sheet-status'
          ? Response.ok('Changes saved.', headers: {'content-type': 'text/html; charset=utf-8'})
          : gallery(request),
      InternetAddress.loopbackIPv4,
      0,
    );
    page = Uri.parse('http://127.0.0.1:${server.port}/components/sheet');
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
  Future<void> openRight() async {
    await click('#open-right');
    await waitFor('$open && $containedFocus');
    await waitFor("$dialog.getAnimations().every(animation => animation.playState !== 'running')");
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

  test('each side slides from its edge for pointer and keyboard and keeps focus inside', () async {
    await driver.open(page);
    for (final (side, offset) in [('right', 'x'), ('top', 'y'), ('bottom', 'y'), ('left', 'x')]) {
      final panel = "document.getElementById('$side-sheet')";
      final opener = '#open-$side';
      expect(await driver.evaluate('$panel.open'), isFalse);
      for (final key in <String?>[null, 'Enter']) {
        if (key == null) {
          await click(opener);
        } else {
          await driver.evaluate("document.querySelector('$opener').focus()");
          await driver.press(key);
        }
        final slide =
            await driver.evaluate('''(() => {
          const panel = $panel;
          const animation = panel.getAnimations().find(animation => animation.animationName === 'trellis-sheet-enter');
          if (!animation) return null;
          animation.pause();
          animation.currentTime = 0;
          const matrix = new DOMMatrix(getComputedStyle(panel).transform);
          const displacement = '$offset' === 'x' ? matrix.m41 : matrix.m42;
          animation.finish();
          const box = panel.getBoundingClientRect();
          const gap = {left: box.left, right: innerWidth - box.right, top: box.top, bottom: innerHeight - box.bottom};
          const fillsEdge = '$offset' === 'x' ? Math.abs(box.height - innerHeight) < 1 :
            Math.abs(box.width - innerWidth) < 1;
          return [displacement, gap['$side'], fillsEdge, panel.matches(':modal'), panel.getAttribute('aria-modal'),
            document.getElementById(panel.getAttribute('aria-labelledby')).textContent.trim(), document.activeElement.id];
        })()''')
                as List?;
        expect(slide, isNotNull, reason: '$side $key slide');
        expect(slide![0], side == 'top' || side == 'left' ? lessThan(-20) : greaterThan(20));
        expect(slide.sublist(1), [0, true, true, 'true', 'Page links', '$side-jump'], reason: '$side $key');
        await driver.evaluate("document.getElementById('swap').focus()");
        expect(await driver.evaluate('$panel.contains(document.activeElement)'), isTrue);
        await driver.press('Escape');
        await waitFor("!$panel.open && document.activeElement === document.querySelector('$opener')");
      }
    }

    await openRight();
    await reverseTab();
    expect(await driver.evaluate("document.activeElement.matches('$close')"), isTrue);
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'right-jump');
  });

  test('Sheet wraps backwards from the first control in sequential focus order', () async {
    await driver.open(page);
    await openRight();
    await driver.evaluate(r'''(() => {
      const first = document.getElementById('right-next');
      first.tabIndex = 1;
      first.focus();
    })()''');
    await reverseTab();
    expect(await driver.evaluate("document.activeElement.matches('$close')"), isTrue);
  });

  test('Sheet wraps in both directions when a selected radio ends the tab order', () async {
    await driver.open(page);
    await openRight();
    await driver.evaluate('''(() => {
      const selected = document.createElement('input');
      selected.type = 'radio';
      selected.name = 'layout';
      selected.checked = true;
      selected.id = 'selected-layout';
      const alternative = selected.cloneNode();
      alternative.id = 'alternative-layout';
      alternative.checked = false;
      $dialog.append(selected, alternative);
      selected.focus();
    })()''');
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'right-jump');
    await reverseTab();
    expect(await driver.evaluate('document.activeElement.id'), 'selected-layout');
    await driver.evaluate("document.getElementById('alternative-layout').focus()");
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'right-jump');
  });

  test('Sheet ignores controls hidden inside a closed disclosure when wrapping focus', () async {
    await driver.open(page);
    await openRight();
    await driver.evaluate('''(() => {
      const disclosure = document.createElement('details');
      disclosure.innerHTML = '<summary>More</summary><button tabindex="1">Hidden action</button>';
      $dialog.prepend(disclosure);
      disclosure.querySelector('summary').focus();
    })()''');
    await reverseTab();
    expect(await driver.evaluate("document.activeElement.matches('$close')"), isTrue);
  });

  test('Sheet wraps focus through a trailing editable region with no explicit tabindex', () async {
    await driver.open(page);
    await openRight();
    await driver.evaluate('''(() => {
      const editor = document.createElement('div');
      editor.contentEditable = 'true';
      editor.id = 'sheet-editor';
      editor.innerHTML = '<span contenteditable="true">Editable notes</span>';
      $dialog.append(editor);
      editor.focus();
    })()''');
    expect(await driver.evaluate('document.activeElement.id'), 'sheet-editor');
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'right-jump');
    await reverseTab();
    expect(await driver.evaluate('document.activeElement.id'), 'sheet-editor');
    await driver.evaluate("document.getElementById('sheet-editor').tabIndex = -1");
    await driver.evaluate("document.getElementById('right-jump').focus()");
    await reverseTab();
    expect(await driver.evaluate("document.activeElement.matches('$close')"), isTrue);
  });

  test('Sheet wraps past controls made inert by CSS', () async {
    await driver.open(page);
    await openRight();
    await driver.evaluate('''(() => {
      const section = document.createElement('section');
      section.style.interactivity = 'inert';
      section.innerHTML = '<button>Inactive control</button>';
      $dialog.append(section);
      document.querySelector('$close').focus();
    })()''');
    expect(await driver.evaluate("document.activeElement.matches('$close')"), isTrue);
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'right-jump');
    await reverseTab();
    expect(await driver.evaluate("document.activeElement.matches('$close')"), isTrue);
  });

  test('Escape, Close and backdrop update state and restore trigger focus', () async {
    await driver.open(page);
    for (final action in ['escape', 'close', 'backdrop']) {
      await openRight();
      if (action == 'escape') {
        await driver.press('Escape');
      } else if (action == 'close') {
        await click(close);
      } else {
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
      await waitFor('$closed && document.activeElement === $trigger');
    }
  });

  test('links close the Sheet without returning focus to the trigger', () async {
    await driver.open(page);
    await openRight();
    await driver.evaluate('''(() => {
      window.restored = 0;
      $trigger.addEventListener('focus', () => window.restored++);
    })()''');
    await driver.press('Enter');
    await waitFor("$closed && location.hash === '#destination' && document.activeElement.id === 'destination'");
    expect(await driver.evaluate('window.restored'), 0);

    await openRight();
    // A real cross-page navigation would otherwise lose the old document's probe.
    await driver.evaluate(r'''(() => {
      sessionStorage.setItem('sheet-link-restored', 'no');
      document.getElementById('open-right').addEventListener('focus',
        () => sessionStorage.setItem('sheet-link-restored', 'yes'));
    })()''');
    await click('#right-next');
    await waitFor("location.pathname === '/components/button'");
    expect(await driver.evaluate("sessionStorage.getItem('sheet-link-restored')"), 'no');
  });

  test('reduced motion opens and dismisses immediately with focus', () async {
    await driver.open(page);
    expect(await driver.media(reducedMotion: true), isTrue);
    await click('#open-right');
    expect(await driver.evaluate('[$open, $containedFocus, $dialog.getAnimations().length]'), [true, true, 0]);
    await click(close);
    expect(await driver.evaluate('[$closed, document.activeElement === $trigger]'), [true, true]);
  });

  test('a content-only HTMX swap retains the modal and recovers focus once', () async {
    await driver.open(page);
    await openRight();
    await driver.evaluate('''(() => {
      window.originalSheet = $dialog;
      window.closeCount = 0;
      $dialog.addEventListener('close', () => window.closeCount++);
    })()''');
    await click('#update-sheet');
    await waitFor("document.getElementById('updated-sheet') !== null && $containedFocus");
    expect(
      await driver.evaluate('[$dialog === window.originalSheet, $open, !!document.querySelector("#update-sheet")]'),
      [true, true, false],
    );
    await driver.evaluate("document.querySelector('$close').focus()");
    await driver.press('Tab');
    expect(await driver.evaluate('document.activeElement.id'), 'right-jump');
    await driver.press('Escape');
    await waitFor('$closed && document.activeElement === $trigger && window.closeCount === 1');
    expect(await driver.evaluate('window.__trellisCsp.violations'), isEmpty);
  });

  test('a plain-text HTMX replacement recovers focus inside the same Sheet', () async {
    await driver.open(page);
    await openRight();
    await driver.evaluate(r'''(() => {
      const update = document.getElementById('update-sheet');
      update.removeAttribute('hx-select');
      update.focus();
      window.originalSheet = document.getElementById('right-sheet');
      window.updateSettled = false;
      htmx.ajax('GET', '/demo/sheet-status', {source: update, target: update, swap: 'outerHTML settle:0ms'})
        .then(() => window.updateSettled = true);
    })()''');
    await waitFor(
      "window.updateSettled && document.getElementById('sheet-swap').textContent.includes('Changes saved.')",
    );
    expect(
      await driver.evaluate('[$dialog === window.originalSheet, $open, !!document.querySelector("#update-sheet")]'),
      [true, true, false],
    );
    await waitFor(containedFocus);
  });

  test('the inner Popover stays above the Sheet and closes first', () async {
    await driver.open(page);
    await openRight();
    await click('#sheet-options-trigger');
    const popup = "document.getElementById('sheet-options')";
    await waitFor("$popup.matches(':popover-open') && $popup.style.left.endsWith('px')");
    await waitFor("$popup.getAnimations().every(animation => animation.playState !== 'running')");
    expect(
      await driver.evaluate('''(() => {
      const target = document.getElementById('sheet-page-size'), box = target.getBoundingClientRect();
      return document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2) === target;
    })()'''),
      isTrue,
    );
    await click('#sheet-page-size');
    expect(await driver.evaluate('document.activeElement.id'), 'sheet-page-size');
    await driver.press('Escape');
    await waitFor("$open && !$popup.matches(':popover-open') && document.activeElement.id === 'sheet-options-trigger'");
    await driver.press('Escape');
    await waitFor(closed);
    await openRight();
    await click('#sheet-options-trigger');
    await waitFor("$popup.matches(':popover-open')");
    await click(close);
    await waitFor("$closed && !$popup.matches(':popover-open') && !$popup.hasAttribute('style')");
    await openRight();
    expect(await driver.evaluate("$popup.matches(':popover-open')"), isFalse);
  });

  test('links stay visible and reachable in flow without script or suite assets', () async {
    for (final block in ['javascript', 'suite script', 'suite assets']) {
      await driver.probe.command('Network.setBlockedURLs', {
        'urls': switch (block) {
          'suite script' => ['*/trellis-ui/trellis-ui.js'],
          'suite assets' => ['*/trellis-ui/*'],
          _ => <String>[],
        },
      });
      await driver.probe.evaluate(page, 'true', width: 390, height: 844, disableScripts: block == 'javascript');
      expect(
        await driver.evaluate('''(() => {
        const link = document.getElementById('right-jump');
        return [$dialog.matches(':modal'), getComputedStyle($dialog).position, link.getBoundingClientRect().height > 0,
          typeof customElements.get('tl-dialog'), document.documentElement.scrollWidth === innerWidth];
      })()'''),
        [false, 'static', true, 'undefined', true],
        reason: block,
      );
      await driver.evaluate("document.getElementById('right-jump').focus()");
      expect(await driver.evaluate('document.activeElement.id'), 'right-jump', reason: block);
      await driver.press('Enter');
      await waitFor("location.hash === '#destination'");
    }
  });

  test('700 px opens modally, 701 px shows the original content inline and narrowing closes it', () async {
    await driver.viewport(700, 900);
    await driver.open(page);
    const inline = "document.getElementById('inline-sheet')";
    const link = "document.getElementById('inline-link')";
    await click('#open-inline');
    await waitFor("$inline.matches(':modal')");
    await driver.evaluate('window.originalLink = $link');
    await driver.viewport(701, 900);
    await waitFor("$inline.open && !$inline.matches(':modal') && getComputedStyle($inline).position === 'static'");
    expect(
      await driver.evaluate(
        '[$link === window.originalLink, $link.getBoundingClientRect().width > 0,'
        " document.querySelector('#inline-sheet [data-dialog-close]').hidden]",
      ),
      [true, true, true],
    );
    await driver.evaluate("document.getElementById('swap').focus()");
    expect(await driver.evaluate('document.activeElement.id'), 'swap');
    await driver.viewport(700, 900);
    await waitFor("!$inline.open && document.getElementById('open-inline').checkVisibility()");
    await click('#open-inline');
    await waitFor("$inline.matches(':modal') && $link === window.originalLink");
  });
}
