import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
import '../tool/src/gallery.dart';

void main() {
  late Uri page;
  late ChromeDriver driver;

  setUpAll(() async {
    final server = await shelf_io.serve(galleryHandler(Directory.current), InternetAddress.loopbackIPv4, 0);
    page = Uri.parse('http://127.0.0.1:${server.port}/components/accordion');
    addTearDown(() => server.close(force: true));
  });
  setUp(() async {
    driver = await ChromeDriver.launch();
    addTearDown(driver.close);
  });

  Future<Object?> openItems(String group) =>
      driver.evaluate("Array.from(document.querySelectorAll('#$group > details[open]'), item => item.id)");

  Future<void> focusSummary(String item) => driver.evaluate("document.querySelector('#$item > summary').focus()");

  test('click, Enter and Space toggle native summaries independently', () async {
    for (final key in <String?>[null, 'Enter', ' ']) {
      await driver.open(page);
      expect(await openItems('multiple'), ['multiple-first']);
      const summary = '#multiple-second > summary';
      const visible = "document.querySelector('#multiple-link').checkVisibility()";
      expect(await driver.evaluate(visible), isFalse);
      Future<void> toggle() => key == null ? driver.pointer(summary, click: true) : driver.press(key);
      if (key != null) await focusSummary('multiple-second');
      await toggle();
      expect(await openItems('multiple'), ['multiple-first', 'multiple-second'], reason: 'open via $key');
      expect(await driver.evaluate(visible), isTrue);
      await toggle();
      expect(await openItems('multiple'), ['multiple-first'], reason: 'close via $key');
      expect(await driver.evaluate(visible), isFalse);
    }
  });

  test('a text-fragment link reveals a closed answer', () async {
    final answer = Uri.parse('$page#:~:text=Check%20the%20return%20window');
    final revealed = await driver.probe.evaluate(
      answer,
      r'''new Promise(resolve => {
        const deadline = performance.now() + 1500;
        function check() {
          const visible = document.querySelector('#multiple-link').checkVisibility();
          if (visible || performance.now() >= deadline) resolve(visible);
          else requestAnimationFrame(check);
        }
        check();
      })''',
      width: 390,
      height: 844,
    );
    expect(revealed, isTrue);
    expect(await openItems('multiple'), ['multiple-first', 'multiple-second']);
  });

  test('opening an item closes its namesake without affecting another group', () async {
    await driver.open(page);
    expect(await openItems('single'), ['single-first']);
    expect(await openItems('independent'), ['independent-first']);
    await driver.pointer('#single-second > summary', click: true);
    expect(await openItems('single'), ['single-second']);
    expect(await openItems('independent'), ['independent-first']);
    expect(await openItems('multiple'), ['multiple-first']);
  });

  test('the light gallery paints a contrasting outline on keyboard focus', () async {
    await driver.open(page);
    expect(await driver.media(reducedMotion: true), isTrue);
    await focusSummary('multiple-first');
    await driver.press('Tab');
    final contrast = await driver.evaluate(r'''(() => {
      const trigger = document.querySelector('#multiple-second > summary');
      const styles = getComputedStyle(trigger);
      if (document.activeElement !== trigger || !trigger.matches(':focus-visible') ||
          styles.outlineStyle === 'none' || parseFloat(styles.outlineWidth) === 0) return 0;
      const context = document.createElement('canvas').getContext('2d');
      function luminance(color) {
        context.fillStyle = color;
        context.fillRect(0, 0, 1, 1);
        const rgb = [...context.getImageData(0, 0, 1, 1).data].slice(0, 3).map(value => {
          const channel = value / 255;
          return channel <= .04045 ? channel / 12.92 : ((channel + .055) / 1.055) ** 2.4;
        });
        return rgb[0] * .2126 + rgb[1] * .7152 + rgb[2] * .0722;
      }
      const outline = luminance(styles.outlineColor);
      const background = luminance(getComputedStyle(document.body).backgroundColor);
      return (Math.max(outline, background) + .05) / (Math.min(outline, background) + .05);
    })()''');
    expect(contrast, greaterThanOrEqualTo(3));
  });

  for (final disableScripts in [true, false]) {
    final fallback = disableScripts ? 'scripts disabled' : 'suite assets blocked';
    test('both groups expose reachable destination links with $fallback', () async {
      if (!disableScripts) {
        await driver.probe.command('Network.setBlockedURLs', {
          'urls': ['*/trellis-ui/*'],
        });
      }
      for (final mode in ['multiple', 'single']) {
        final loading = await driver.probe.evaluate(
          page,
          r'''[typeof htmx, typeof customElements.get('tl-dialog'),
            getComputedStyle(document.documentElement).getPropertyValue('--ring') !== '']''',
          width: 390,
          height: 844,
          disableScripts: disableScripts,
        );
        expect(loading, [disableScripts ? 'undefined' : 'object', 'undefined', disableScripts]);
        // Tab from the first summary through its text-only panel.
        await focusSummary('$mode-first');
        await driver.press('Tab');
        expect(await driver.evaluate('document.activeElement.parentElement.id'), '$mode-second');
        await driver.press('Enter');
        expect(await openItems(mode), mode == 'single' ? ['single-second'] : ['multiple-first', 'multiple-second']);
        await driver.press('Tab');
        expect(await driver.evaluate('document.activeElement.id'), '$mode-link');
        await driver.press('Enter');
        expect(await driver.evaluate('location.hash'), '#$mode-destination');
      }
    });
  }
}
