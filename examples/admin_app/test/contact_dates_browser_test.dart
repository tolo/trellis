@Tags(['ui-gate'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:trellis_admin_example/admin_app.dart';

import '../../../tool/ui_gate/driver.dart';
import '../../../tool/ui_gate/firefox.dart';
import 'fixtures.dart';

const _dates = {'appointment_date': '2026-11-18', 'range_start': '2026-11-23', 'range_end': '2026-11-27'};
const _single = 'contact-appointment-calendar';
const _range = 'contact-range-calendar';
const _idle = 'document.querySelector(".htmx-request, .htmx-swapping, .htmx-settling") === null';
const _mounted = '''
  document.querySelectorAll('[data-date-picker]').length === 2 &&
  [...document.querySelectorAll('[data-date-picker]')].every(root =>
    root.querySelectorAll('calendar-date, calendar-range').length === 1 &&
    root.querySelector('calendar-month')?.shadowRoot?.querySelector('table'))
''';

void main() {
  for (final (name, launch) in [('Chrome', ChromeDriver.launch), ('Firefox', FirefoxDriver.launch)]) {
    group(name, () {
      test('calendar selection saves dates and both HTMX history paths remount the saved markup', () async {
        final browser = await _DateBrowser.launch(await launch());
        await browser.openEdit();
        await browser.enterNativeDate('appointment_date', '2026-11-16');
        await browser.openCalendar(_single);
        expect(await browser.calendarValue(_single), '2026-11-16');
        await browser.expectLocalized(_single);
        await browser.pick(_single, '2026-11-18');
        await browser.waitFor("document.querySelector('[name=appointment_date]').value === '2026-11-18'");
        await browser.expectCalendarClean(_single);
        await browser.closeCalendar(_single);

        await browser.openCalendar(_range);
        await browser.expectLocalized(_range);
        await browser.pick(_range, '2026-11-23');
        expect(await browser.values(), [_dates.values.first, '', ''], reason: 'a tentative range stays provisional');
        await browser.pick(_range, '2026-11-27');
        await browser.waitFor("document.querySelector('[name=range_end]').value === '2026-11-27'");
        await browser.expectCalendarClean(_range);
        await browser.closeCalendar(_range);
        await browser.save(_dates);
        await browser.openEdit();
        await browser.expectSaved();
        final beforeUrl = await browser.path();

        await browser.openCalendar(_single);
        await browser.pick(_single, '2026-11-21');
        await browser.waitFor("document.querySelector('[name=appointment_date]').value === '2026-11-21'");
        await browser.closeCalendar(_single);
        await browser.cancelEdit();
        await browser.eval('(() => {window.beforeSortCalendar = document.querySelector("calendar-date");})()');
        await browser.click('#sort-email');
        await browser.waitFor("location.search.includes('sort=email') && $_idle && ($_mounted)");
        final sortedUrl = await browser.path();
        expect(sortedUrl, isNot(beforeUrl));
        expect(
          await browser.eval('!window.beforeSortCalendar.isConnected'),
          isTrue,
          reason: 'the recipe outside the swapped list was rebuilt after saving history',
        );
        await browser.expectSaved();
        await browser.expectPristineCache(beforeUrl);

        for (final (delta, path, cachedPath) in [(-1, beforeUrl, sortedUrl), (1, sortedUrl, beforeUrl)]) {
          final before = browser.exchanges.length;
          await browser.eval('(() => {window.beforeHistoryCalendar = document.querySelector("calendar-date");})()');
          await browser.driver.history(delta);
          await browser.waitFor(
            'location.pathname + location.search === ${jsonEncode(path)} && !window.beforeHistoryCalendar.isConnected && ($_mounted)',
          );
          expect(browser.exchanges.skip(before), isEmpty, reason: 'history restored a cache hit without an Edit fetch');
          await browser.expectSaved();
          await browser.expectPristineCache(cachedPath);
          await browser.probeRestoredCalendar();
          await browser.expectClean();
        }

        await browser.openEdit();
        await browser.expectSaved();
        await browser.exerciseOneChange();
        await browser.cancelEdit();

        await browser.eval('sessionStorage.removeItem("htmx-history-cache")');
        final beforeMiss = browser.exchanges.length;
        await browser.driver.history(-1);
        await browser.waitFor(
          'location.pathname + location.search === ${jsonEncode(beforeUrl)} && '
          'document.querySelector("#dialog-host").children.length === 0 && ($_idle)',
        );
        final miss = browser.exchanges.skip(beforeMiss).singleWhere((entry) => entry.historyRestore);
        expect((miss.method, miss.url, miss.status), ('GET', beforeUrl, 200));
        await browser.openEdit();
        await browser.expectSaved();
        await browser.openCalendar(_single);
        expect(await browser.calendarValue(_single), _dates.values.first);
        await browser.expectClean();
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('an HTTP 404 for Cally leaves three labelled date inputs that submit through Edit', () async {
        final browser = await _DateBrowser.launch(await launch(), missingVendor: true);
        await browser.openEdit(enhanced: false);
        expect(browser.exchanges.where((entry) => entry.url == callyAsset).map((entry) => entry.status), [404]);
        expect(await browser.eval('document.querySelectorAll("calendar-date, calendar-range").length'), 0);
        expect(
          await browser.eval('''
            [...document.querySelectorAll('#contact-form input[type=date]')].map(input =>
              [input.name, input.labels[0].textContent.trim(), input.checkVisibility(), !input.disabled])
          '''),
          [
            ['appointment_date', 'Appointment date', true, true],
            ['range_start', 'Start date', true, true],
            ['range_end', 'End date', true, true],
          ],
        );
        expect(
          await browser.eval('''
            [...document.querySelectorAll('[data-calendar] button')].map(button => button.checkVisibility())
          '''),
          [false, false],
        );
        for (final entry in _dates.entries) {
          await browser.enterNativeDate(entry.key, entry.value);
        }
        await browser.save(_dates);
        await browser.openEdit(enhanced: false);
        expect(await browser.values(attributes: true), _dates.values.toList());
        await browser.expectClean();
        await browser.expectAxe();
      }, timeout: const Timeout(Duration(minutes: 2)));
    });
  }
}

typedef _Exchange = ({String method, String url, int status, bool htmx, bool historyRestore, Map<String, String> form});

final class _DateBrowser {
  _DateBrowser(this.driver);

  final GateDriver driver;
  final exchanges = <_Exchange>[];

  static Future<_DateBrowser> launch(GateDriver driver, {bool missingVendor = false}) async {
    final browser = _DateBrowser(driver);
    addTearDown(driver.close);
    final app = createAdminApp(Directory.current, csrfSecret: 'date-recipe-test');
    addTearDown(app.close);
    final server = await shelf_io.serve(
      (request) async {
        final isMutation = request.method == 'PUT' || request.method == 'POST';
        final body = isMutation ? await request.readAsString() : '';
        final uri = request.requestedUri;
        final path = uri.path;
        final response = missingVendor && path == callyAsset
            ? Response.notFound('Cally fixture 404')
            : await app.handler(isMutation ? request.change(body: body) : request);
        if (path.startsWith('/contacts') || path == callyAsset) {
          browser.exchanges.add((
            url: uri.hasQuery ? '$path?${uri.query}' : path,
            method: request.method,
            status: response.statusCode,
            htmx: request.headers['hx-request'] == 'true',
            historyRestore: request.headers['hx-history-restore-request'] == 'true',
            form: Uri.splitQueryString(body),
          ));
        }
        return response;
      },
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() async {
      print('${driver.name} ${missingVendor ? 'vendor 404' : 'calendar and history'} requests: ${browser.exchanges}');
      await server.close(force: true);
    });
    await driver.viewport(390, 844);
    await driver.open(Uri.parse('http://127.0.0.1:${server.port}/contacts'));
    await browser.waitFor("typeof htmx === 'object' && customElements.get('tl-popover') !== undefined");
    return browser;
  }

  Future<Object?> eval(String js) => driver.evaluate(js);

  Future<String> path() async => await eval('location.pathname + location.search') as String;

  Future<void> waitFor(String expression) async {
    for (var i = 0; i < 200; i++) {
      if (await eval(expression) == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final actual = await eval('''
      ({
        path: location.pathname + location.search,
        active: document.activeElement?.id,
        calendars: [...document.querySelectorAll('calendar-date, calendar-range')].map(node => node.value),
        fields: [...document.querySelectorAll('input[type=date]')].map(node => node.value),
        modal: document.querySelector('dialog:modal')?.id,
        csp: window.__uiGate.violations
      })
    ''');
    fail('${driver.name} waiting for $expression. Page: $actual. Requests: $exchanges');
  }

  Future<void> click(String selector) => driver.pointer(selector, click: true);

  Future<void> openEdit({bool enhanced = true}) async {
    final before = exchanges.length;
    await click('#actions-1-trigger');
    await waitFor(
      "document.querySelector('#actions-1:popover-open') && document.activeElement.textContent.trim() === 'Edit'",
    );
    await driver.press('Enter');
    final mounted = enhanced ? ' && ($_mounted)' : '';
    await waitFor("document.querySelector('#edit-1:modal') && $_idle$mounted");
    final edit = exchanges.skip(before).single;
    expect((edit.method, Uri.parse(edit.url).path, edit.status, edit.htmx), ('GET', '/contacts/1/edit', 200, true));
  }

  Future<void> cancelEdit() async {
    await click('#edit-1 button[data-dialog-close]');
    await waitFor("document.querySelector('#edit-1:not([open])') !== null");
  }

  Future<void> openCalendar(String id) async {
    final preceding = id == _single ? 'contact-appointment-date' : 'contact-range-end';
    await eval("document.getElementById('$preceding').focus()");
    for (var step = 0; step < 5 && await eval('document.activeElement.id') != '$id-trigger'; step++) {
      await driver.press('Tab');
    }
    expect(await eval('document.activeElement.id'), '$id-trigger');
    await driver.press('Enter');
    await waitFor("document.querySelector('#$id:popover-open[style]') !== null");
    expect(
      await eval('''
        (() => {
          const popup = document.getElementById('$id');
          const box = popup.getBoundingClientRect();
          return popup.contains(document.activeElement) &&
            box.left >= 0 && box.top >= 0 && box.right <= innerWidth && box.bottom <= innerHeight &&
            document.documentElement.scrollWidth === document.documentElement.clientWidth;
        })()
      '''),
      isTrue,
      reason: '${driver.name} $id must contain focus and fit at 390px',
    );
  }

  Future<void> closeCalendar(String id) async {
    await driver.press('Escape');
    await waitFor("""
      document.querySelector('#edit-1:modal') !== null && document.getElementById('$id-trigger') === document.activeElement &&
      document.querySelector('#$id:popover-open') === null
    """);
  }

  Future<void> pick(String id, String date) async {
    final day = int.parse(date.substring(8));
    await eval("document.querySelector('#$id calendar-month').parentElement.focusedDate = '$date'");
    await waitFor('''
      (() => {
        const day = document.querySelector('#$id calendar-month').shadowRoot.querySelector('button[tabindex="0"]');
        return day?.textContent.trim() === '$day' && day.getAttribute('aria-label') === '$day november';
      })()
    ''');
    await eval("document.querySelector('#$id calendar-month').parentElement.focus({target:'day'})");
    expect(
      await eval("document.querySelector('#$id calendar-month').shadowRoot.activeElement?.textContent.trim()"),
      '$day',
    );
    await driver.press('Enter');
  }

  Future<void> expectLocalized(String id) async {
    final calendar =
        await eval('''
      (() => {
        const month = document.querySelector('#$id calendar-month');
        return [
          month.parentElement.locale,
          month.parentElement.firstDayOfWeek,
          month.shadowRoot.querySelector('thead th span').textContent,
          month.shadowRoot.querySelector('button[tabindex="0"]').getAttribute('aria-label'),
        ];
      })()
    ''')
            as List;
    expect(calendar.take(2), ['sv-SE', 1]);
    expect(calendar[2], contains('måndag'));
    expect(calendar[3], matches(RegExp(r'^\d+ [a-zåäö]+$')));
  }

  Future<Object?> values({bool attributes = false}) => eval('''
    [...document.querySelectorAll('#contact-form input[type=date]')].map(input =>
      ${attributes ? 'input.getAttribute("value")' : 'input.value'})
  ''');

  Future<Object?> calendarValue(String id) => eval("document.querySelector('#$id calendar-month').parentElement.value");

  Future<void> expectSaved() async {
    expect(await values(), _dates.values.toList());
    expect(await values(attributes: true), _dates.values.toList());
    expect(await calendarValue(_single), _dates.values.first);
    expect(await calendarValue(_range), _dates.values.skip(1).join('/'));
  }

  Future<void> expectPristineCache(String path) async {
    final snapshot = await eval('''
      (() => {
        const item = JSON.parse(sessionStorage.getItem('htmx-history-cache') || '[]').find(entry => entry.url === ${jsonEncode(path)});
        if (!item) return null;
        const page = new DOMParser().parseFromString(item.content, 'text/html');
        return {
          dates: [...page.querySelectorAll('#contact-form input[type=date]')].map(input => input.getAttribute('value')),
          transient: page.querySelectorAll(
            '#edit-1[open], [data-date-picker] [popover][style], [data-date-picker] [popover][data-open], calendar-month, [data-calendar]:not([hidden])'
          ).length
        };
      })()
    ''');
    expect(snapshot, {'dates': _dates.values.toList(), 'transient': 0}, reason: path);
  }

  Future<void> probeRestoredCalendar() async {
    final before = exchanges.length;
    await eval("document.getElementById('edit-1').showModal()");
    await exerciseOneChange();
    await cancelEdit();
    expect(exchanges.skip(before), isEmpty, reason: 'the restored component works before requesting another Edit');
  }

  Future<void> exerciseOneChange() async {
    await eval('''
      (() => {
        window.dateUpdates = 0;
        document.querySelector('[name=appointment_date]').addEventListener('change', () => window.dateUpdates++);
      })()
    ''');
    await openCalendar(_single);
    await pick(_single, '2026-11-22');
    await waitFor("document.querySelector('[name=appointment_date]').value === '2026-11-22'");
    expect(await eval('window.dateUpdates'), 1);
    await expectCalendarClean(_single);
    await closeCalendar(_single);
  }

  Future<void> save(Map<String, String> dates) async {
    final before = exchanges.length;
    await click('#save-contact');
    await waitFor("document.querySelector('#dialog-host').children.length === 0 && $_idle");
    final save = exchanges.skip(before).single;
    expect((save.method, Uri.parse(save.url).path, save.status, save.htmx), ('PUT', '/contacts/1', 200, true));
    expect({for (final key in dates.keys) key: save.form[key]}, dates);
  }

  Future<void> enterNativeDate(String name, String iso) async {
    await eval("document.querySelector('[name=$name]').focus()");
    final parts = iso.split('-');
    // Native field segments follow the recording host or browser locale, independent of Cally's locale.
    final digits = driver.name == 'chrome' ? '00${parts.join()}' : parts[1] + parts[2] + parts[0];
    if (driver is FirefoxDriver) {
      // Keep native date entry in one WebDriver action sequence and one context activation.
      await driver.type(digits);
    } else {
      for (final digit in digits.split('')) {
        await driver.press(digit);
      }
    }
    expect(await eval("document.querySelector('[name=$name]').value"), iso, reason: '${driver.name} $name');
  }

  Future<void> expectCalendarClean(String id) async {
    await waitFor('''
      document.querySelector('#$id calendar-month').shadowRoot.activeElement?.getAttribute('aria-pressed') === 'true' &&
      document.getElementById('$id').getAnimations().every(animation => animation.playState !== 'running')
    ''');
    final focus =
        await eval('''
      (() => {
        const panel = document.getElementById('$id');
        const day = panel.querySelector('calendar-month').shadowRoot.activeElement;
        const cell = day.getBoundingClientRect(), box = panel.getBoundingClientRect();
        return {
          visible: day.matches(':focus-visible'),
          document: document.hasFocus(),
          inside: cell.left >= box.left && cell.right <= box.right && cell.top >= box.top && cell.bottom <= box.bottom,
          day: day.getAttribute('aria-label')
        };
      })()
    ''')
            as Map;
    expect(focus['visible'], isTrue, reason: '${driver.name} $id focus: $focus');
    expect(focus['inside'], isTrue, reason: '${driver.name} $id clipping: $focus');
    await expectClean();
    await expectAxe();
  }

  Future<void> expectAxe() async {
    // Axe includes CSS-inert exit paint in its full-page contrast audit.
    await waitFor("document.querySelector('[data-trellis-overlay-exit]') === null");
    final axe = File('../../tool/ui_gate/vendor/axe.min.js').readAsStringSync();
    await eval('(() => {if (!globalThis.axe) {$axe} return true;})()');
    expect(
      await eval('''
        axe.run(document.body, {
          runOnly: {type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']}
        }).then(report => report.violations.map(rule => rule.id + ': ' + rule.nodes.map(node => node.target.join(' '))))
      '''),
      isEmpty,
      reason: driver.name,
    );
  }

  Future<void> expectClean() async {
    expect(await eval('window.__uiGate.violations'), isEmpty, reason: driver.name);
  }
}
