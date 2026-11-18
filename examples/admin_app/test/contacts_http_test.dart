import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis_admin_example/admin_app.dart';

import 'fixtures.dart';

void main() {
  late Handler handler;

  setUp(() {
    final app = createAdminApp(Directory.current, csrfSecret: 'http-test-secret');
    handler = app.handler;
    addTearDown(app.close);
  });

  Future<Response> request(
    String path, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Map<String, String>? fields,
  }) async {
    return handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: headers,
        body: fields == null ? null : formBody(fields),
      ),
    );
  }

  Future<Map<String, String>> session() async {
    final page = await request('/');
    return mutationHeaders(page.headers['set-cookie']!, await page.readAsString());
  }

  List<String> names(Element page) =>
      page.querySelectorAll('tbody tr[data-contact-id] td:first-child').map((cell) => cell.text.trim()).toList();

  test('responses carry the strict policy and the page links the suite, htmx and indicator assets', () async {
    final page = await request('/');
    expect(page.statusCode, 200);
    expectStrictPolicy(page.headers['content-security-policy']);
    final document = parse(await page.readAsString());
    expect(document.querySelectorAll('script').map((script) => script.attributes['src']), [
      htmxAsset,
      '/trellis-ui/trellis-ui.js',
    ]);
    expect(document.querySelectorAll('link[rel=stylesheet]').map((link) => link.attributes['href']), [
      '/trellis-ui/trellis-ui.css',
      '/trellis-ui/htmx-indicator.css',
      '/app.css',
    ]);
    expect(
      document.querySelector('meta[name=htmx-config]')!.attributes['content'],
      allOf(contains('"allowEval":false'), contains('"includeIndicatorStyles":false')),
    );
    final fragment = await request('/contacts', headers: {'hx-request': 'true'});
    expect(fragment.statusCode, 200);
    expectStrictPolicy(fragment.headers['content-security-policy']);

    for (final entry in {...suiteAssets, htmxAsset: 'text/javascript'}.entries) {
      final asset = await request(entry.key);
      expect(asset.statusCode, 200, reason: entry.key);
      expectStrictPolicy(asset.headers['content-security-policy']);
      expect(asset.headers['content-type'], startsWith(entry.value), reason: entry.key);
      expect(await asset.read().expand((chunk) => chunk).length, greaterThan(0), reason: entry.key);
    }
  });

  test(
    'the list filters, sorts and pages, falls back on bad parameters and renders the same rows for a page load and a swap',
    () async {
      final page = parse(await (await request('/')).readAsString());
      expect(names(page.body!), [
        'Ada Morgan',
        'Amir Shah',
        'Anika Rao',
        'Aria Chen',
        'Avery Ruiz',
        'Ben Nolan',
        'Camille Roy',
        'Daniel Kim',
      ]);
      expect(page.querySelectorAll('thead th').map((cell) => cell.text.trim().split(RegExp(r'\s+')).first), [
        'Name',
        'Email',
        'Company',
        'Status',
        'Actions',
      ]);
      expect(page.querySelector('th[aria-sort=ascending] #sort-name'), isNotNull);
      final response = await request(
        '/contacts?q=example.test&status=active&sort=email&dir=desc&page=2',
        headers: {'hx-request': 'true'},
      );
      expect(response.statusCode, 200);
      final swap = parseFragment(await response.readAsString());
      expect(swap.children.single.id, 'contact-list');
      expect(names(swap.children.single), ['Aria Chen', 'Anika Rao', 'Amir Shah', 'Ada Morgan']);
      expect(swap.querySelectorAll('[aria-sort]').single.querySelector('#sort-email'), isNotNull);
      expect(swap.querySelector('th[aria-sort=descending]'), isNotNull);
      expect(swap.querySelectorAll('[aria-current=page]').single.text, '2');
      final url = response.headers['hx-push-url']!;
      expect(Uri.parse(url).queryParameters, {
        'q': 'example.test',
        'status': 'active',
        'sort': 'email',
        'dir': 'desc',
        'page': '2',
      });
      expect(names(parse(await (await request(url)).readAsString()).body!), names(swap.children.single));

      final restored = await request(url, headers: {'hx-request': 'true', 'hx-history-restore-request': 'true'});
      expect(parse(await restored.readAsString()).querySelector('#directory'), isNotNull);
      final fallback = await request(
        '/contacts?status=oops&sort=bad&dir=wrong&page=90',
        headers: {'hx-request': 'true'},
      );
      expect(Uri.parse(fallback.headers['hx-push-url']!).queryParameters, {
        'q': '',
        'status': '',
        'sort': 'name',
        'dir': 'asc',
        'page': '3',
      });
      expect(names(parseFragment(await fallback.readAsString()).children.single), [
        'Luca Rossi',
        'Maya Singh',
        'Nina Soto',
        'Owen Clarke',
        'Riley Moss',
        'Sam Reed',
        'Zoe Lane',
      ]);
      final empty = parseFragment(
        await (await request('/contacts?q=unmatched', headers: {'hx-request': 'true'})).readAsString(),
      );
      expect(empty.querySelector('#contact-list [role=status]')?.text, 'No contacts match these filters.');
      expect(empty.querySelector('table'), isNull);
    },
  );

  test('validation re-renders the dialog with linked errors and a valid save answers the full response set', () async {
    final headers = await session();
    final rejected = await request(
      '/contacts',
      method: 'POST',
      headers: headers,
      fields: {'name': '', 'email': 'wrong', 'q': 'Unknown', 'status': 'active'},
    );
    expect(rejected.statusCode, 200);
    expect(rejected.headers['hx-retarget'], isNull);
    final dialog = parseFragment(await rejected.readAsString());
    expect(dialog.querySelector('dialog[open]')?.id, 'new-contact-dialog');
    expect(dialog.querySelector('#contact-name[autofocus]'), isNotNull);
    expect(dialog.querySelectorAll('[aria-invalid=true]').map((field) => field.id), [
      'contact-name',
      'contact-email',
      'contact-company',
    ]);
    for (final (field, message) in [
      ('contact-name', 'Enter a name.'),
      ('contact-email', 'Enter a valid email address.'),
      ('contact-company', 'Choose a company from the suggestions.'),
    ]) {
      final description = dialog.querySelector('#$field')!.attributes['aria-describedby']!.trim();
      expect(dialog.querySelector('#$description[role=alert]')?.text, message);
    }
    final saved = await request('/contacts', method: 'POST', headers: headers, fields: validContact);
    expect(saved.statusCode, 200);
    expect(saved.headers['hx-retarget'], '#contact-list');
    expect(saved.headers['hx-reswap'], 'outerHTML focus-scroll:true');
    final payload = parseFragment(await saved.readAsString());
    expect(names(payload.children.first).first, 'A Aaron Example');
    expect(payload.querySelector('#dialog-host[hx-swap-oob]')?.children, isEmpty);
    expect(payload.querySelector('#contact-summary[hx-swap-oob] #count-active')?.text, '13');
    expect(payload.querySelector('#toaster[hx-swap-oob]')?.text, contains('Contact created'));

    final sortedLast = await request(
      '/contacts?sort=name&dir=asc&page=1',
      method: 'POST',
      headers: headers,
      fields: {...validContact, 'name': 'Zora Example', 'email': 'zora@example.test'},
    );
    expect(Uri.parse(sortedLast.headers['hx-push-url']!).queryParameters['page'], '4');
    expect(names(parseFragment(await sortedLast.readAsString()).children.first).last, 'Zora Example');
  });

  test('unknown ids answer 404 and a tokenless mutation answers 403 and changes nothing', () async {
    final headers = await session();
    for (final (method, path) in [
      ('GET', '/contacts/404/edit'),
      ('GET', '/contacts/404/delete'),
      ('PUT', '/contacts/404'),
      ('DELETE', '/contacts/404'),
    ]) {
      final response = await request(
        path,
        method: method,
        headers: headers,
        fields: method == 'PUT' ? validContact : null,
      );
      expect(response.statusCode, 404, reason: '$method $path');
      expect(parseFragment(await response.readAsString()).querySelector('dialog'), isNull);
    }
    final tokenless = await request(
      '/contacts',
      method: 'POST',
      headers: {'cookie': headers['cookie']!},
      fields: validContact,
    );
    expect(tokenless.statusCode, 403);
    final page = parse(await (await request('/')).readAsString());
    expect(page.querySelector('#count-active')?.text, '12');
    expect(names(page.body!).first, 'Ada Morgan');
  });

  test('malformed contact forms leave records unchanged and unknown edits return 404', () async {
    final headers = await session();
    for (final (method, path, status) in [
      ('PUT', '/contacts/404', 404),
      ('POST', '/contacts', 400),
      ('PUT', '/contacts/1', 400),
    ]) {
      for (final body in <Object>[
        'name=%',
        <int>[0xff],
      ]) {
        final response = await handler(
          Request(method, Uri.parse('http://localhost$path'), headers: headers, body: body),
        );
        expect(response.statusCode, status, reason: '$method $path');
        expect(parseFragment(await response.readAsString()).querySelector('dialog'), isNull);
      }
    }
    final page = parse(await (await request('/')).readAsString());
    expect(page.querySelector('#count-active')?.text, '12');
    expect(names(page.body!).first, 'Ada Morgan');
  });
}
