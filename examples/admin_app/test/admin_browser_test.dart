import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:trellis_admin_example/admin_app.dart';

import '../../../test/browser_reflow_probe.dart';
import '../../../tool/ui_gate/driver.dart';
import 'fixtures.dart';

typedef _Exchange = ({String path, String method, bool htmx, int status});

void main() {
  if (BrowserProbe.locateChrome() == null) requireChromeInCi('Admin browser journeys');
  late _Browser browser;

  setUp(() async {
    browser = _Browser(await ChromeDriver.launch());
    addTearDown(browser.driver.close);
  });

  Future<Uri> serve({Directory? root, Future<void> Function(Uri)? beforeResponse}) async {
    final app = createAdminApp(root ?? Directory.current, csrfSecret: 'browser-test-secret');
    addTearDown(app.close);
    final server = await shelf_io.serve(
      (request) async {
        await beforeResponse?.call(request.requestedUri);
        final response = await app.handler(request);
        final path = request.requestedUri.path;
        if (path == '/' || path.startsWith('/contacts') || path == '/companies') {
          browser.exchanges.add((
            path: path,
            method: request.method,
            htmx: request.headers['hx-request'] == 'true',
            status: response.statusCode,
          ));
        }
        return response;
      },
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    return Uri.parse('http://127.0.0.1:${server.port}/');
  }

  Future<void> open(Uri base) async {
    await browser.driver.open(base);
    await browser.waitFor("typeof htmx === 'object' && customElements.get('tl-dropdown-menu') !== undefined");
    await browser.rememberShell();
  }

  test('filter, sort and paging swap only the list region', () async {
    final base = await serve();
    await open(base);
    await browser.proveList(base);
  });

  test('Back and Forward restore the applied search and status filters', () async {
    await open(await serve());
    const query = "new URL(location.href).searchParams.get('q')";
    const search = "document.getElementById('contact-query').value";
    await browser.listSwap(() => browser.typeOver('#contact-query', 'Ada'), "$query === 'Ada'");
    expect(await browser.eval('document.activeElement.id'), 'contact-query');
    await browser.listSwap(() => browser.driver.type(' Morgan'), "$query === 'Ada Morgan'");

    await browser.driver.history(-1);
    await browser.waitFor("$query === 'Ada' && !document.querySelector('.htmx-settling')");
    expect(await browser.eval(search), 'Ada');
    await browser.driver.history(1);
    await browser.waitFor("$query === 'Ada Morgan' && !document.querySelector('.htmx-settling')");
    expect(await browser.eval(search), 'Ada Morgan');
    await browser.rememberShell();

    const status = "new URL(location.href).searchParams.get('status')";
    const select = "document.getElementById('contact-status').value";
    // Native select menus commit typed choices differently across platforms.
    Future<void> changeStatus(String value) => browser.listSwap(() async {
      await browser.eval('''(() => {
        const status = document.getElementById('contact-status');
        status.value = ${jsonEncode(value)};
        status.dispatchEvent(new Event('change', { bubbles: true }));
      })()''');
    }, '$status === ${jsonEncode(value)}');

    await changeStatus('active');
    expect(await browser.rows(), ['Ada Morgan']);
    await changeStatus('pending');
    expect(await browser.rows(), isEmpty);

    await browser.driver.history(-1);
    await browser.waitFor("$status === 'active' && !document.querySelector('.htmx-settling')");
    expect(await browser.eval(select), 'active');
    expect(await browser.eval(search), 'Ada Morgan');
    expect(await browser.rows(), ['Ada Morgan']);
    await browser.driver.history(1);
    await browser.waitFor("$status === 'pending' && !document.querySelector('.htmx-settling')");
    expect(await browser.eval(select), 'pending');
    expect(await browser.eval(search), 'Ada Morgan');
    expect(await browser.rows(), isEmpty);
  });

  test('a newer query is sent after an in-flight live filter', () async {
    final firstRequest = Completer<void>();
    final releaseFirstResponse = Completer<void>();
    await open(
      await serve(
        beforeResponse: (uri) async {
          if (uri.path == '/contacts' && uri.queryParameters['q'] == 'example') {
            firstRequest.complete();
            await releaseFirstResponse.future;
          }
        },
      ),
    );
    try {
      await browser.typeOver('#contact-query', 'example');
      await firstRequest.future.timeout(const Duration(seconds: 5));
      await browser.driver.type('.test Ada');
      // Let the input debounce fire while the first request still owns the form.
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } finally {
      releaseFirstResponse.complete();
    }

    await browser.waitFor("new URL(location.href).searchParams.get('q') === 'example.test Ada'");
    expect(await browser.rows(), isEmpty);
    expect(await browser.eval('document.activeElement.id'), 'contact-query');
  });

  test('create and edit in a dialog with validation errors, focus and toast', () async {
    await open(await serve());
    await browser.proveCreateAndEdit();
  });

  test('delete asks for confirmation and never leaves an empty page', () async {
    await open(await serve());
    await browser.proveDelete();
  });

  test('company combobox and summary tab', () async {
    await open(await serve());
    await browser.proveCompanyAndSummary(active: 12, pending: 7, archived: 4);
  });

  test('the whole journey raises no CSP violation', () async {
    final documents = <String?>[];
    final subscription = browser.driver.probe.events.listen((event) {
      if (event['method'] != 'Network.responseReceived') return;
      final params = event['params'] as Map<String, Object?>;
      if (params['type'] != 'Document') return;
      final response = params['response'] as Map<String, Object?>;
      final headers = response['headers'] as Map<String, Object?>;
      documents.add(
        Map.fromEntries(
              headers.entries.map((entry) => MapEntry(entry.key.toLowerCase(), entry.value)),
            )['content-security-policy']
            as String?,
      );
    });
    addTearDown(subscription.cancel);
    final base = await serve();
    await open(base);
    await browser.expectCleanPage(base);
    // A closed popup keeps its CSSOM attributes until the suite prepares the swap.
    await browser.click('#actions-1-trigger');
    await browser.waitFor("document.querySelector('#actions-1:popover-open[style]') !== null");
    await browser.driver.press('Escape');
    expect(await browser.eval("document.querySelector('#actions-1[style]:not(:popover-open)') !== null"), isTrue);
    await browser.proveList(base);
    await browser.resetList();
    await browser.expectCleanPage(base);
    await browser.proveCreateAndEdit();
    await browser.proveCompanyAndSummary(active: 12, pending: 8, archived: 4);
    await browser.proveDelete();
    await browser.expectCleanPage(base);
    expect(documents, hasLength(1), reason: 'HTMX interactions and Back stay in one document');

    final loaded = browser.driver.probe.events.firstWhere((event) => event['method'] == 'Page.loadEventFired');
    await browser.driver.probe.command('Page.reload');
    await loaded.timeout(const Duration(seconds: 10));
    await browser.waitFor("typeof htmx === 'object' && document.querySelectorAll('tbody tr').length === 8");
    await browser.expectCleanPage(base);
    expect(documents, hasLength(2));
    for (final policy in documents) {
      expectStrictPolicy(policy);
    }

    final htmxRequests = browser.driver.requests.map(Uri.parse).where((url) => url.path.endsWith('htmx.min.js'));
    expect(htmxRequests, isNotEmpty);
    expect(htmxRequests.every((url) => url == base.resolve(htmxAsset)), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a pasted theme block restyles the app', () async {
    final original = await Directory.systemTemp.createTemp('trellis-admin-default-');
    addTearDown(() => original.delete(recursive: true));
    final themed = await Directory.systemTemp.createTemp('trellis-admin-theme-');
    addTearDown(() => themed.delete(recursive: true));
    await copyAppFiles(original);
    await copyAppFiles(themed);
    final stylesheet = File('${themed.path}/static/app.css');
    await stylesheet.writeAsString('''
:root { --primary: #13588c; --radius: 0px; }
.dark { --primary: #e4a938; --radius: 0px; }
''', mode: FileMode.append);

    final unchanged = await serve(root: original);
    final customized = await serve(root: themed);
    Future<List<Object?>> measure(Uri base, {required bool dark}) async {
      await open(base);
      expect(await browser.driver.media(reducedMotion: true), isTrue);
      if (dark) await browser.eval("document.documentElement.classList.add('dark')");
      return (await browser.eval(r'''(async () => {
        const button = document.querySelector('#new-contact');
        // A loaded theme or media change can start a color transition before
        // the next computed-style read. Measure once that transition settles.
        getComputedStyle(button).backgroundColor;
        await Promise.allSettled(button.getAnimations().map(animation => animation.finished));
        const style = selector => getComputedStyle(document.querySelector(selector));
        return [
          getComputedStyle(button).backgroundColor,
          style('#directory-panel-contacts .trellis-card').borderTopLeftRadius,
          style('#contact-query').borderTopLeftRadius
        ];
      })()''')
          as List<Object?>);
    }

    for (final (dark, color) in [(false, 'rgb(19, 88, 140)'), (true, 'rgb(228, 169, 56)')]) {
      final before = await measure(unchanged, dark: dark);
      final after = await measure(customized, dark: dark);
      expect(after, [color, '0px', '0px'], reason: dark ? 'dark block' : 'root block');
      for (var index = 0; index < after.length; index++) {
        expect(before[index], isNot(after[index]), reason: 'applying the block must change computed property $index');
      }
    }
  });

  test('the primary action keeps readable contrast as its palette is inverted', () async {
    await open(await serve());
    final result =
        await browser.eval(r'''(async () => {
      const button = document.getElementById('new-contact');
      const style = getComputedStyle(button);
      await Promise.allSettled(button.getAnimations().map(animation => animation.finished));
      const canvas = document.createElement('canvas');
      canvas.width = canvas.height = 1;
      const ink = canvas.getContext('2d');
      const luminance = color => {
        ink.fillStyle = color;
        ink.fillRect(0, 0, 1, 1);
        const [r, g, b] = [...ink.getImageData(0, 0, 1, 1).data].slice(0, 3).map(channel => {
          const srgb = channel / 255;
          return srgb <= .04045 ? srgb / 12.92 : ((srgb + .055) / 1.055) ** 2.4;
        });
        return r * .2126 + g * .7152 + b * .0722;
      };
      const measure = () => {
        const foreground = luminance(style.color), background = luminance(style.backgroundColor);
        return (Math.max(foreground, background) + .05) / (Math.min(foreground, background) + .05);
      };
      const before = [style.color, style.backgroundColor];
      document.documentElement.classList.add('dark');
      const samples = [measure()];
      // Sample the interpolation independently of the wall clock and frame rate.
      const transitions = button.getAnimations().filter(animation => animation instanceof CSSTransition);
      for (const transition of transitions) transition.pause();
      for (const point of [.2, .3, .4, .5, .6, .7, .8]) {
        for (const transition of transitions) transition.currentTime = transition.effect.getTiming().duration * point;
        samples.push(measure());
      }
      for (const transition of transitions) transition.finish();
      samples.push(measure());
      return {minimum: Math.min(...samples), changed: before[0] !== style.color && before[1] !== style.backgroundColor};
    })()''')
            as Map<String, dynamic>;

    expect(result['changed'], isTrue, reason: 'the light and dark palettes both reached the button');
    expect(
      result['minimum'],
      greaterThanOrEqualTo(4.5),
      reason: 'the primary action remains readable through the change',
    );
  });

  test('a narrow keyboard edit keeps the restored row action visible', () async {
    await browser.driver.viewport(390, 844);
    await open(await serve());
    Future<void> tabTo(String id, int limit) async {
      for (var i = 0; i < limit && await browser.eval('document.activeElement.id') != id; i++) {
        await browser.driver.press('Tab');
      }
      expect(await browser.eval('document.activeElement.id'), id);
    }

    await tabTo('actions-1-trigger', 25);
    const actionVisible = r'''(() => {
      const action = document.getElementById('actions-1-trigger');
      const bounds = action.getBoundingClientRect();
      const clip = action.closest('.trellis-table-container').getBoundingClientRect();
      return action === document.activeElement && action.matches(':focus-visible') &&
        bounds.left >= clip.left - 1 && bounds.right <= clip.right + 1 &&
        document.elementFromPoint(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)?.closest('button') === action;
    })()''';
    expect(await browser.eval(actionVisible), isTrue, reason: 'traversing the table reveals its focused action');
    await browser.driver.press('Enter');
    await browser.waitFor(
      "document.querySelector('#actions-1:popover-open') !== null && document.activeElement.textContent.trim() === 'Edit'",
    );
    await browser.action(
      () => browser.driver.press('Enter'),
      'GET',
      '/contacts/1/edit',
      "document.querySelector('#edit-1:modal') !== null",
    );
    for (final id in [
      'contact-appointment-date',
      'contact-appointment-calendar-trigger',
      'contact-range-start',
      'contact-range-end',
      'contact-range-calendar-trigger',
      'save-contact',
    ]) {
      await tabTo(id, 5);
    }
    await browser.save('edit-1', keyboard: true);
    await browser.expectToast('Contact updated');
    expect(await browser.eval(actionVisible), isTrue, reason: 'the replaced table must reveal the restored focus');
  });

  test('the contact table scrolls within the page at 390px', () async {
    await browser.driver.viewport(390, 844);
    await open(await serve());
    expect(
      await browser.eval(r'''(() => {
      const container = document.querySelector('.trellis-table-container');
      const bounds = container.getBoundingClientRect();
      return bounds.x >= 0 && bounds.right <= document.documentElement.clientWidth &&
        document.documentElement.scrollWidth === document.documentElement.clientWidth &&
        container.scrollWidth > container.clientWidth && getComputedStyle(container).overflowX === 'auto';
    })()'''),
      isTrue,
    );
  });
}

final class _Browser {
  _Browser(this.driver);

  final ChromeDriver driver;
  final exchanges = <_Exchange>[];

  Future<Object?> eval(String expression) => driver.evaluate(expression);

  Future<void> waitFor(String expression) async {
    for (var attempt = 0; attempt < 250; attempt++) {
      if (await eval(expression) == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final state = await eval(r'''({
      active: [document.activeElement.tagName, document.activeElement.id],
      modal: document.querySelector('dialog:modal')?.id,
      invalid: [...document.querySelectorAll('[aria-invalid=true]')].map(el => el.id),
      requests: [...document.querySelectorAll('.htmx-request, .htmx-swapping, .htmx-settling')].map(el => el.id),
      url: location.href,
      popovers: [...document.querySelectorAll(':popover-open')].map(el => el.id),
      errors: window.__trellisCsp?.violations
    })''');
    fail('Timed out waiting for $expression. Page: $state. Exchanges: $exchanges');
  }

  Future<void> click(String selector) => driver.pointer(selector, click: true);

  Future<void> typeOver(String selector, String text) async {
    await click(selector);
    expect(
      await eval('document.activeElement.matches(${jsonEncode(selector)})'),
      isTrue,
      reason:
          'typing into $selector, active: ${await eval('[document.activeElement.tagName, document.activeElement.id]')}',
    );
    await eval('document.activeElement.select()');
    if (text.isEmpty) {
      await driver.press('Backspace');
    } else {
      await driver.type(text);
    }
  }

  Future<void> action(Future<void> Function() input, String method, String path, String settled) async {
    final before = exchanges.length;
    await input();
    await waitFor('!document.querySelector(".htmx-request, .htmx-swapping, .htmx-settling") && ($settled)');
    expect(exchanges.skip(before), [(method: method, path: path, htmx: true, status: 200)]);
  }

  Future<List<Object?>> rows() async =>
      (await eval(r'''
    [...document.querySelectorAll('tbody tr[data-contact-id] td:first-child')].map(cell => cell.textContent.trim())
  ''')
          as List<Object?>);

  Future<void> listSwap(Future<void> Function() input, String queryCondition) async {
    await eval("window.previousList = document.getElementById('contact-list')");
    await action(input, 'GET', '/contacts', '$_shellUnchanged && !previousList.isConnected && ($queryCondition)');
  }

  static const _shellUnchanged = '''
    window.header === document.querySelector('h1') &&
    window.contactsPanel === document.getElementById('directory-panel-contacts') &&
    window.summaryPanel === document.getElementById('directory-panel-summary')
  ''';

  Future<void> proveList(Uri base) async {
    expect(await rows(), hasLength(8));
    await eval("window.searchBeforeFilter = document.getElementById('contact-query')");
    await listSwap(() => typeOver('#contact-query', 'example.test'), "location.search.includes('q=example.test')");
    expect(
      await eval("document.getElementById('contact-query') === window.searchBeforeFilter"),
      isTrue,
      reason: 'live filtering must keep the field the user is typing into',
    );
    expect(await eval('document.activeElement.id'), 'contact-query');
    await driver.press('Tab');
    expect(await eval('document.activeElement.id'), 'contact-status');
    // Native typeahead commits a selection in headless Chrome on macOS.
    await listSwap(() => driver.press('a'), "location.search.includes('status=active')");
    await listSwap(() => click('#sort-email'), "location.search.includes('sort=email')");
    expect(await eval("document.querySelectorAll('th[aria-sort]').length"), 1);
    expect(await eval("document.querySelector('th[aria-sort=ascending] a').id"), 'sort-email');
    await listSwap(() => click('a[aria-label="Page 2"]'), "location.search.includes('page=2')");
    expect(await eval("[...document.querySelectorAll('[aria-current=page]')].map(node => node.textContent)"), ['2']);
    expect(await rows(), ['Eden Ross', 'Emilia Cruz', 'Finn Patel', 'Hana Ito']);
    final url = Uri.parse(await eval('location.href') as String);
    expect(url.queryParameters, {'q': 'example.test', 'status': 'active', 'sort': 'email', 'dir': 'asc', 'page': '2'});
    final plain = await http.get(base.resolve('/contacts?${url.query}'));
    expect(plain.statusCode, 200);
    expect(
      parse(plain.body).querySelectorAll('tbody tr[data-contact-id] td:first-child').map((cell) => cell.text.trim()),
      await rows(),
    );

    await listSwap(() => typeOver('#contact-query', 'unmatched'), "location.search.includes('q=unmatched')");
    expect(await rows(), isEmpty);
    expect(await eval("document.querySelector('#contact-filter [name=page]').value"), '1');
    expect(
      await eval("document.querySelector('#contact-list [role=status]').textContent"),
      'No contacts match these filters.',
    );
    await driver.history(-1);
    await waitFor(
      "location.href === ${jsonEncode(url.toString())} && document.querySelectorAll('tbody tr').length === 4",
    );
    expect(await rows(), ['Eden Ross', 'Emilia Cruz', 'Finn Patel', 'Hana Ito']);
    expect(await eval("document.getElementById('contact-query').value"), 'example.test');
    expect(await eval('window.header !== undefined'), isTrue, reason: 'Back must restore in this document');
  }

  Future<void> resetList() async {
    // The filter, status, sort and page actions each pushed a separate entry.
    await driver.history(-4);
    await waitFor("location.pathname === '/' && document.querySelectorAll('tbody tr').length === 8");
    await rememberShell();
  }

  Future<void> rememberShell() async {
    await eval('''(() => {
      window.header = document.querySelector('h1');
      window.contactsPanel = document.getElementById('directory-panel-contacts');
      window.summaryPanel = document.getElementById('directory-panel-summary');
    })()''');
  }

  Future<void> openNew() => action(
    () => click('#new-contact'),
    'GET',
    '/contacts/new',
    "document.querySelector('#new-contact-dialog:modal') !== null",
  );

  Future<void> menu(int id, {required String item}) async {
    final trigger = '#actions-$id-trigger';
    await click(trigger);
    await waitFor(
      "document.querySelector('#actions-$id:popover-open') !== null && document.activeElement.textContent === 'Edit'",
    );
    if (item == 'delete') await driver.press('ArrowDown');
    expect(await eval('document.activeElement.textContent'), item == 'delete' ? 'Delete' : 'Edit');
    await action(
      () => driver.press('Enter'),
      'GET',
      '/contacts/$id/$item',
      "document.querySelector('#$item-$id:modal') !== null && !document.querySelector('#actions-$id').matches(':popover-open')",
    );
  }

  Future<void> save(String dialog, {String? invalid, bool keyboard = false}) => action(
    keyboard ? () => driver.press('Enter') : () => click('#save-contact'),
    dialog == 'new-contact-dialog' ? 'POST' : 'PUT',
    dialog == 'new-contact-dialog' ? '/contacts' : '/contacts/${dialog.substring('edit-'.length)}',
    invalid == null
        ? "document.getElementById('$dialog') === null"
        : "document.querySelector('#$dialog:modal #$invalid[aria-invalid=true]') === document.activeElement",
  );

  Future<void> errors(Map<String, String> expected) async {
    expect(
      await eval(r'''(() => {
      const dialog = document.querySelector('dialog:modal');
      return Object.fromEntries([...dialog.querySelectorAll('[aria-invalid=true]')].map(input => {
        const error = document.getElementById(input.getAttribute('aria-describedby').trim());
        return [input.id, error.getClientRects().length ? error.textContent.trim() : null];
      }));
    })()'''),
      expected,
    );
    expect(await eval('document.activeElement.id'), expected.keys.first);
    expect(await eval("document.querySelectorAll('dialog:modal').length"), 1);
  }

  Future<void> chooseCompany(String text, String label, String value) async {
    await action(
      () => typeOver('#contact-company', text),
      'GET',
      '/companies',
      "document.querySelector('#contact-company-popup:popover-open [role=option]')?.textContent === ${jsonEncode(label)}",
    );
    expect(await eval("document.querySelectorAll('#contact-company-popup [role=option]').length"), 1);
    await driver.press('ArrowDown');
    await driver.press('Enter');
    expect(await eval("document.getElementById('contact-company').value"), label);
    expect(await eval("document.querySelector('#contact-form input[name=company]').value"), value);
    expect(await eval("document.querySelector('#contact-company-popup').matches(':popover-open')"), false);
  }

  Future<void> expectToast(String title) async {
    expect(await eval("document.getElementById('toaster').getAttribute('aria-live')"), 'polite');
    expect(
      await eval(r"document.querySelector('#toaster tl-toast:last-child [data-slot=toast-title]').textContent"),
      title,
    );
  }

  Future<void> proveCreateAndEdit() async {
    await openNew();
    await save('new-contact-dialog', invalid: 'contact-name');
    await errors({
      'contact-name': 'Enter a name.',
      'contact-email': 'Enter a valid email address.',
      'contact-company': 'Choose a company from the suggestions.',
    });
    await typeOver('#contact-name', validContact['name']!);
    await typeOver('#contact-email', 'bad-address');
    await chooseCompany('ac', 'Acme Studio', 'acme');
    await save('new-contact-dialog', invalid: 'contact-email', keyboard: true);
    await errors({'contact-email': 'Enter a valid email address.'});
    await typeOver('#contact-email', 'ADA.MORGAN@example.test');
    await save('new-contact-dialog', invalid: 'contact-email');
    await errors({'contact-email': 'That email address already belongs to a contact.'});
    await typeOver('#contact-email', validContact['email']!);
    await save('new-contact-dialog');
    expect((await rows()).first, 'A Aaron Example');
    expect(await statusCount('active'), '13');
    expect(await eval('document.activeElement.id'), 'new-contact');
    await expectToast('Contact created');

    await menu(1, item: 'edit');
    expect(await eval("document.getElementById('contact-name').value"), 'Ada Morgan');
    expect(await eval("document.getElementById('contact-email').value"), 'ada.morgan@example.test');
    expect(await eval("document.getElementById('contact-company').value"), 'Acme Studio');
    expect(await eval("document.getElementById('contact-edit-status').value"), 'active');
    await typeOver('#contact-name', 'Ada Moreno');
    for (final id in ['contact-email', 'contact-company', 'contact-edit-status']) {
      await driver.press('Tab');
      expect(await eval('document.activeElement.id'), id);
    }
    await driver.press('p');
    await save('edit-1');
    expect(await rows(), contains('Ada Moreno'));
    expect(await statusCount('active'), '12');
    expect(await statusCount('pending'), '8');
    await expectToast('Contact updated');
  }

  Future<String> statusCount(String status) async =>
      (await eval("document.querySelector('#directory-panel-summary #count-$status').textContent")) as String;

  Future<void> summary(int active, int pending, int archived) async {
    await click('#directory-tab-summary');
    expect(await eval("document.getElementById('directory-tab-summary').getAttribute('aria-selected')"), 'true');
    expect(await eval("document.getElementById('directory-panel-summary').hidden"), isFalse);
    expect(await eval("document.querySelectorAll('#contact-summary').length"), 1);
    expect(
      await eval(
        "[...document.querySelectorAll('#directory-panel-summary #contact-summary dd')].map(node => Number(node.textContent))",
      ),
      [active, pending, archived],
    );
  }

  Future<void> proveCompanyAndSummary({required int active, required int pending, required int archived}) async {
    await summary(active, pending, archived);
    await click('#directory-tab-contacts');
    await menu(2, item: 'edit');
    await action(
      () => typeOver('#contact-company', 'Unknown company'),
      'GET',
      '/companies',
      "document.querySelector('#contact-company-popup:popover-open [data-slot=combobox-empty]:not([hidden])') !== null",
    );
    await save('edit-2', invalid: 'contact-company');
    await errors({'contact-company': 'Choose a company from the suggestions.'});
    expect(await eval("document.getElementById('contact-company').value"), 'Unknown company');
    await chooseCompany('ac', 'Acme Studio', 'acme');
    await driver.press('Tab');
    expect(await eval('document.activeElement.id'), 'contact-edit-status');
    await driver.press('p');
    await save('edit-2');
    expect(
      await eval("document.querySelector('tr[data-contact-id=\"2\"] td:nth-child(3)').textContent"),
      'Acme Studio',
    );
    await summary(active - 1, pending + 1, archived);
    await click('#directory-tab-contacts');
  }

  Future<void> confirmDelete(int id) =>
      action(() => driver.press('Enter'), 'DELETE', '/contacts/$id', "document.getElementById('delete-$id') === null");

  Future<void> proveDelete() async {
    final activeBefore = int.parse(await statusCount('active'));
    // Contact 3 remains Active across the edit journey.
    await menu(3, item: 'delete');
    expect(await eval("document.querySelector('#delete-3:modal').getAttribute('role')"), 'alertdialog');
    expect(await eval("document.getElementById('delete-3-title').textContent"), 'Delete Anika Rao?');
    expect(await eval('document.activeElement.textContent.trim()'), 'Cancel');
    final before = exchanges.length;
    await driver.press('Enter');
    await waitFor("!document.getElementById('delete-3').open && document.activeElement.id === 'actions-3-trigger'");
    expect(exchanges, hasLength(before));
    expect(await rows(), contains('Anika Rao'));

    await menu(3, item: 'delete');
    await driver.press('Tab');
    expect(await eval('document.activeElement.id'), 'confirm-delete');
    await confirmDelete(3);
    expect(await rows(), isNot(contains('Anika Rao')));
    expect(await statusCount('active'), (activeBefore - 1).toString());
    await expectToast('Contact deleted');

    await listSwap(() => click('a[aria-label="Page 3"]'), "location.search.includes('page=3')");
    // Remove tail rows in the same way an operator would until only one remains.
    for (var remaining = (await rows()).length; remaining > 1; remaining--) {
      final id = int.parse(await eval("document.querySelector('tbody tr:last-child').dataset.contactId") as String);
      await menu(id, item: 'delete');
      await driver.press('Tab');
      await confirmDelete(id);
      expect(await rows(), hasLength(remaining - 1));
    }
    final last = int.parse(await eval("document.querySelector('tbody tr').dataset.contactId") as String);
    await menu(last, item: 'delete');
    await driver.press('Tab');
    await confirmDelete(last);
    expect(await rows(), hasLength(8));
    expect(await eval("document.querySelector('[aria-current=page]').textContent"), '2');
    expect(Uri.parse(await eval('location.href') as String).queryParameters['page'], '2');
  }

  Future<void> expectCleanPage(Uri base) async {
    expect(await driver.probe.securityPolicyViolations(), isEmpty);
    expect(await eval("document.querySelectorAll('script:not([src]), style, [style]').length"), 0);
    expect(await eval("document.querySelector('script[src*=htmx]').src"), base.resolve(htmxAsset).toString());
  }
}
