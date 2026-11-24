import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../tool/ui_gate/driver.dart';
import '../../../tool/ui_gate/firefox.dart';
import '../tool/src/gallery.dart';

void main() {
  for (final (name, launch) in [('Chrome', ChromeDriver.launch), ('Firefox', FirefoxDriver.launch)]) {
    group(name, () {
      late GateDriver driver;
      late HttpServer server;

      setUp(() async {
        final gallery = galleryHandler(Directory.current);
        server = await shelf_io.serve(
          (request) => request.url.path == 'exit-test.svg'
              ? Response.ok(
                  '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="red"/></svg>',
                  headers: {'content-type': 'image/svg+xml', 'cache-control': 'no-store'},
                )
              : gallery(request),
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(() => server.close(force: true));
        driver = await launch();
        addTearDown(driver.close);
        await driver.viewport(900, 760);
      });

      Future<void> waitFor(String expression) async {
        for (var attempt = 0; attempt < 140; attempt++) {
          if (await driver.evaluate(expression) == true) return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        fail('Timed out waiting for $expression');
      }

      const exit =
          "document.querySelector('[data-trellis-overlay-exit]:is(:popover-open, [data-trellis-overlay-exit=native])')";
      const csp = 'window.__trellisCsp.violations';

      Future<void> open(String subject) async {
        await driver.open(Uri.parse('http://127.0.0.1:${server.port}/components/$subject'));
        await waitFor('typeof htmx !== "undefined"');
      }

      Future<void> click(String selector) => driver.pointer(selector, click: true);

      Future<void> openPanel(String trigger, String selector) async {
        await click(trigger);
        await waitFor("$selector?.hasAttribute('data-open') === true");
        await driver.evaluate('Promise.allSettled($selector.getAnimations().map(animation => animation.finished))');
      }

      Future<void> armExitProbe(String selector) async {
        await driver.evaluate('''(() => {
          const surface = $selector;
          const geometry = node => {
            const { left, top, width, height } = node.getBoundingClientRect();
            return { left, top, width, height };
          };
          const before = geometry(surface);
          window.exitObservation = null;
          surface.addEventListener('beforetoggle', function observe(event) {
            if (event.newState !== 'closed') return;
            surface.removeEventListener('beforetoggle', observe);
            requestAnimationFrame(() => {
              const layer = $exit;
              if (!layer) {
                window.exitObservation = {painted: false};
                return;
              }
              const after = geometry(layer);
              const alignment = Object.keys(before).every(key => Math.abs(before[key] - after[key]) < 2);
              const centerX = after.left + after.width / 2;
              const centerY = after.top + after.height / 2;
              const animated = layer.getAnimations().some(animation => animation.playState === 'running');
              const paint = getComputedStyle(layer);
              window.exitObservation = {
                painted: alignment && animated && Number(paint.opacity) > 0 &&
                  getComputedStyle(layer, '::backdrop').backdropFilter === 'none' &&
                  after.width > 0 && after.height > 0,
                inert: (layer === surface ? paint.interactivity === 'inert' :
                  layer.inert && layer.getAttribute('aria-hidden') === 'true') &&
                  !layer.contains(document.elementFromPoint(centerX, centerY)) &&
                  !layer.contains(document.activeElement),
                isolated: layer === surface || !layer.querySelector('[id], [popover], tl-popover, tl-dropdown-menu'),
              };
            });
          });
        })()''');
      }

      Future<void> expectExit() async {
        await waitFor('window.exitObservation !== null');
        expect(await driver.evaluate('window.exitObservation'), {'painted': true, 'inert': true, 'isolated': true});
        await waitFor('$exit === null');
        expect(await driver.evaluate(csp), isEmpty);
      }

      for (final (name, trigger, panel, isDialog) in [
        ('dialog', '#open-dialog', '#example-dialog', true),
        ('sheet', '#open-right', '#right-sheet', true),
        ('popover', '#options-trigger', '#options', false),
        ('dropdown-menu', '#menu-trigger', '#menu', false),
      ]) {
        final opened = "document.querySelector('$panel${isDialog ? ':modal' : ':popover-open'}')";
        test('$name dismisses immediately and paints a short exit', () async {
          await open(name);
          await openPanel(trigger, opened);
          await armExitProbe(opened);
          await driver.press('Escape');
          await waitFor("$opened === null && document.activeElement.matches('$trigger')");
          await expectExit();
        });
      }

      test('the dialog close button and backdrop preserve the same exit', () async {
        const panel = "document.querySelector('#example-dialog:modal')";
        for (final action in ['#dialog-save', '#open-dialog']) {
          await open('dialog');
          await openPanel('#open-dialog', panel);
          await armExitProbe(panel);
          await click(action);
          await waitFor("$panel === null && document.activeElement.id === 'open-dialog'");
          await expectExit();
        }
      });

      test('an action selected before the menu is positioned has no exit layer', () async {
        await open('dropdown-menu');
        final observation = await driver.evaluate(r"""
          (async () => {
            const menu = document.getElementById('menu');
            const trigger = document.getElementById('menu-trigger');
            menu.showPopover({source: trigger});
            const positioned = menu.hasAttribute('style');
            document.getElementById('menu-billing').click();
            await new Promise(requestAnimationFrame);
            return {
              positioned,
              closed: !menu.matches(':popover-open'),
              painted: !!document.querySelector('[data-trellis-overlay-exit]')
            };
          })()
        """);
        expect(observation, {'positioned': false, 'closed': true, 'painted': false});
      });

      test('closing a partially entered Popover retains its painted rectangle', () async {
        await open('popover');
        const panel = "document.querySelector('#options:popover-open')";
        // Pause the real entry animation before it completes, independent of input latency.
        await driver.evaluate("""
          (() => {
            const popup = document.getElementById('options');
            popup.addEventListener('toggle', () => {
              if (!popup.matches(':popover-open')) return;
              for (const animation of popup.getAnimations()) {
                animation.pause();
                animation.currentTime = 40;
              }
              window.entryPaused = true;
            });
          })()
        """);
        await click('#options-trigger');
        await waitFor('window.entryPaused === true');
        final opacity = await driver.evaluate('Number(getComputedStyle($panel).opacity)') as num;
        expect(opacity, greaterThan(0));
        expect(opacity, lessThan(1));
        await armExitProbe(panel);
        await driver.press('Escape');
        await waitFor("$panel === null && document.activeElement.id === 'options-trigger'");
        await expectExit();
      });

      test('an unrelated infinite animation cannot retain a closing dialog', () async {
        await open('dialog');
        const panel = "document.querySelector('#example-dialog:modal')";
        await openPanel('#open-dialog', panel);
        await driver.evaluate("""
          (() => {
            window.appAnimation = $panel.animate([{textIndent: '0px'}, {textIndent: '0px'}],
              {duration: 2000, iterations: Infinity});
          })()
        """);
        await driver.press('Escape');
        await waitFor("$panel === null && document.activeElement.id === 'open-dialog'");
        await waitFor('$exit === null');
        expect(await driver.evaluate("getComputedStyle(document.getElementById('example-dialog')).display"), 'none');
      });

      test('light dismissal paints the Popover without intercepting the outside click', () async {
        await open('popover');
        const panel = "document.querySelector('#options:popover-open')";
        await openPanel('#options-trigger', panel);
        await armExitProbe(panel);
        await driver.evaluate("""
          document.getElementById('outside').addEventListener('click', () => { window.outsideClicked = true; })
        """);
        await click('#outside');
        await waitFor('$panel === null && window.outsideClicked === true');
        await expectExit();
      });

      test('exit preserves rendered slot text and values without mounting another component', () async {
        await open('dialog');
        const panel = "document.querySelector('#example-dialog:modal')";
        await openPanel('#open-dialog', panel);
        await driver.evaluate(r"""
          (() => {
            window.slotMounts = 0;
            customElements.define('app-overlay-control', class extends HTMLElement {
              connectedCallback() { window.slotMounts++; }
            });
            const form = document.createElement('form');
            const component = document.createElement('app-overlay-control');
            component.innerHTML = '<p id="app-label">Selected team</p>' +
              '<input id="app-input" name="team" value="Initial" aria-labelledby="app-label">';
            form.append(component);
            document.getElementById('example-dialog').append(form);
            document.getElementById('app-input').value = 'Edited team';
            const image = new Image();
            image.src = '/exit-test.svg';
            const blank = document.createElement('canvas');
            blank.width = 0;
            blank.style.width = '42px';
            blank.style.height = '12px';
            const colors = document.createElement('select');
            colors.multiple = true;
            colors.append(...['Red', 'Green', 'Blue'].map(color => new Option(color)));
            colors.options[0].selected = true;
            colors.options[2].selected = true;
            form.append(image, blank, colors);
            return image.decode();
          })()
        """);
        await driver.evaluate("""
          (() => {
            const dialog = $panel;
            dialog.addEventListener('beforetoggle', ({newState}) => {
              if (newState !== 'closed') return;
              requestAnimationFrame(() => {
                const layer = $exit;
                const field = layer?.querySelector('input[value=Initial]') ??
                  [...(layer?.querySelectorAll('input') || [])].find(input => input.value === 'Edited team');
                const original = layer === dialog;
                const image = layer?.querySelector(original ? 'img' : 'canvas');
                window.slotExit = {
                  label: layer?.textContent.includes('Selected team'),
                  field: field?.value,
                  original,
                  detachedFromForm: field?.form === null && field?.name === '',
                  liveComponents: window.slotMounts,
                  idOccurrences: document.querySelectorAll('#app-input').length,
                  activeContent: !!layer?.querySelector('app-overlay-control, form, img'),
                  renderedImage: original ? image?.naturalWidth === 8 :
                    image?.getContext('2d').getImageData(0, 0, 1, 1).data[0] === 255,
                  colors: [...(layer?.querySelector('select')?.selectedOptions ?? [])].map(option => option.text),
                  blankWidth: layer?.querySelector('canvas:last-of-type')?.getBoundingClientRect().width,
                };
              });
            });
          })()
        """);
        await driver.press('Escape');
        await waitFor('window.slotExit !== undefined');
        final native =
            await driver.evaluate("CSS.supports('overlay', 'auto') && CSS.supports('interactivity', 'inert')") == true;
        expect(await driver.evaluate('window.slotExit'), {
          'label': true,
          'field': 'Edited team',
          'original': native,
          'detachedFromForm': !native,
          'liveComponents': 1,
          'idOccurrences': 1,
          'activeContent': native,
          'renderedImage': true,
          'colors': ['Red', 'Blue'],
          'blankWidth': closeTo(42, .5),
        });
        await waitFor('$exit === null');
        expect(driver.requests.where((request) => Uri.parse(request).path == '/exit-test.svg'), hasLength(1));
        expect(await driver.evaluate(csp), isEmpty);
      });

      test('reduced motion suppresses exit without delaying focus', () async {
        for (final (name, trigger, panel) in [
          ('dialog', '#open-dialog', '#example-dialog:modal'),
          ('sheet', '#open-right', '#right-sheet:modal'),
          ('popover', '#options-trigger', '#options:popover-open'),
          ('dropdown-menu', '#menu-trigger', '#menu:popover-open'),
        ]) {
          final opened = 'document.querySelector("$panel")';
          await open(name);
          expect(await driver.media(reducedMotion: true), isTrue);
          await openPanel(trigger, opened);
          await armExitProbe(opened);
          await driver.press('Escape');
          await waitFor("$opened === null && document.activeElement.matches('$trigger')");
          await waitFor('window.exitObservation !== null');
          expect(await driver.evaluate('window.exitObservation'), {'painted': false}, reason: name);
        }
      });

      test('a popup exits beyond a transformed and clipping Sheet, then Escape closes the Sheet', () async {
        await open('sheet');
        await openPanel('#open-right', "document.querySelector('#right-sheet:modal')");
        await driver.evaluate('''(() => {
          const sheet = document.getElementById('right-sheet');
          sheet.style.transform = 'translateX(-28px)';
          sheet.style.overflow = 'hidden';
          sheet.style.width = '195px';
        })()''');
        const popup = "document.querySelector('#sheet-options:popover-open')";
        await openPanel('#sheet-options-trigger', popup);
        expect(
          await driver.evaluate(
            "$popup.getBoundingClientRect().left < document.getElementById('right-sheet').getBoundingClientRect().left",
          ),
          isTrue,
          reason: 'Exercise the part of the popup that its ancestor would clip.',
        );
        await armExitProbe(popup);
        await driver.press('Escape');
        await waitFor("$popup === null && document.activeElement.id === 'sheet-options-trigger'");
        expect(await driver.evaluate("!!document.querySelector('#right-sheet:modal')"), isTrue);
        await expectExit();
        await driver.press('Escape');
        await waitFor("!document.querySelector('#right-sheet:modal') && document.activeElement.id === 'open-right'");
      });

      test('a Sheet link takes focus to its destination while the Sheet exits', () async {
        await open('sheet');
        const panel = "document.querySelector('#right-sheet:modal')";
        await openPanel('#open-right', panel);
        await armExitProbe(panel);
        await click('#right-jump');
        await waitFor("document.activeElement.id === 'destination' && $panel === null");
        await expectExit();
      });

      test('reopen and real HTMX swaps and history discard overlay exit layers', () async {
        await open('dropdown-menu');
        const panel = "document.querySelector('#menu:popover-open')";
        await openPanel('#menu-trigger', panel);
        await driver.evaluate('''(() => {
          const trigger = document.getElementById('menu-trigger');
          const menu = $panel;
          menu.hidePopover();
          menu.showPopover({source: trigger});
        })()''');
        await waitFor("$panel && document.activeElement.id === 'menu-profile'");
        expect(await driver.evaluate('$exit === null'), isTrue);

        await click('#menu-services-trigger');
        await waitFor("!!document.querySelector('#menu-services:popover-open')");
        await driver.evaluate("document.getElementById('swap').click()");
        await waitFor('''document.querySelector('#menu-trigger').getAttribute('aria-expanded') === 'false' &&
          !document.getElementById('menu').hasAttribute('style') && !document.getElementById('menu-services').hasAttribute('style')
          && $exit === null''');
        await openPanel('#menu-trigger', panel);
        await click('#menu-services-trigger');
        await waitFor("!!document.querySelector('#menu-services:popover-open')");
        await driver.evaluate('''(() => {
          document.getElementById('menu-services').hidePopover();
          document.getElementById('navigate').click();
        })()''');
        await waitFor("location.pathname === '/components/button'");
        await driver.history(-1);
        await waitFor("location.pathname === '/components/dropdown-menu' && !!document.querySelector('#menu-trigger')");
        expect(
          await driver.evaluate(
            "!document.querySelector('#menu:popover-open, #menu-services:popover-open, [data-trellis-overlay-exit], #menu[style], #menu-services[style]')",
          ),
          isTrue,
        );
        expect(await driver.evaluate(csp), isEmpty);
      });
    }, tags: name == 'Firefox' ? 'ui-gate' : null);
  }
}
