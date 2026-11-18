import 'dart:convert';
import 'dart:io';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

// Relic builds a Request only through an adapter, so these tests drive a real
// server over loopback; that also proves what a client receives on the wire.

typedef _Reply = ({int status, List<String> setCookies, String body});

void main() {
  const secret = 'test-secret-key';
  late RelicApp app;
  late Uri base;
  var handled = 0;

  final engine = Trellis(
    loader: MapLoader({'page': '<html><body><input name="_csrf" tl:attr="value=\${csrfToken}"></body></html>'}),
  );

  Future<Response> echo(Request request) async {
    handled++;
    final form = request.mimeType == MimeType.urlEncoded ? await request.urlEncodedForm() : null;
    final note = form?.fields.raw['note'];
    return Response.ok(body: Body.fromString('token=${csrfToken(request)}${note == null ? '' : ';note=$note'}'));
  }

  setUp(() async {
    handled = 0;
    app = RelicApp()
      ..use('/', trellisCsrf(secret: secret, excludedPaths: ['/webhook']))
      ..get('/', echo)
      ..head('/', echo)
      ..options('/', echo)
      ..get('/page', (request) => renderPage(request, engine, 'page', {}))
      ..get('/with-cookie', (request) async {
        return Response.ok(
          body: Body.fromString('ok'),
          headers: Headers.build((h) => h['Set-Cookie'] = ['session=abc; Path=/']),
        );
      })
      ..post('/', echo)
      ..put('/', echo)
      ..delete('/', echo)
      ..patch('/', echo)
      ..post('/webhook', echo);
    final server = await app.serve(port: 0);
    base = Uri.parse('http://${InternetAddress.loopbackIPv4.address}:${server.port}');
  });

  tearDown(() => app.close(force: true));

  Future<_Reply> send(String method, String path, {Map<String, String> headers = const {}, Object? body}) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, base.resolve(path));
      headers.forEach(request.headers.set);
      if (body is String) request.write(body);
      if (body is List<int>) request.add(body);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return (status: response.statusCode, setCookies: response.headers['set-cookie'] ?? const [], body: text);
    } finally {
      client.close();
    }
  }

  /// GETs `/` and returns the raw token and the signed cookie value.
  Future<(String token, String cookie)> issue() async {
    final reply = await send('GET', '/');
    final cookie = reply.setCookies.single.split(';').first.substring('__csrf='.length);
    return (cookie.split('.').first, cookie);
  }

  const form = {'content-type': 'application/x-www-form-urlencoded'};

  group('safe methods', () {
    test('GET issues a signed HttpOnly SameSite=Strict cookie and exposes the raw token', () async {
      final reply = await send('GET', '/');
      expect(reply.status, 200);
      final cookie = reply.setCookies.single;
      expect(cookie, matches(RegExp(r'^__csrf=[0-9a-f]{64}\.[0-9a-f]{64}; Path=/; HttpOnly; SameSite=Strict$')));
      expect(reply.body, 'token=${cookie.substring('__csrf='.length, '__csrf='.length + 64)}');
    });

    test('GET with a valid cookie reuses its token and sets no new cookie', () async {
      final (token, cookie) = await issue();
      final reply = await send('GET', '/', headers: {'cookie': 'other=1; __csrf=$cookie'});
      expect(reply.setCookies, isEmpty);
      expect(reply.body, 'token=$token');
    });

    test('GET with a forged cookie issues a fresh token', () async {
      final (token, _) = await issue();
      final reply = await send('GET', '/', headers: {'cookie': '__csrf=$token.${'0' * 64}'});
      expect(reply.setCookies.single, isNot(contains(token)));
    });

    test('HEAD and OPTIONS pass without a token', () async {
      expect((await send('HEAD', '/')).status, 200);
      expect((await send('OPTIONS', '/')).status, 200);
    });

    test('renderPage passes the token to the template as csrfToken', () async {
      final reply = await send('GET', '/page');
      final token = reply.setCookies.single.substring('__csrf='.length, '__csrf='.length + 64);
      expect(reply.body, contains('value="$token"'));
    });

    test('keeps a Set-Cookie the handler set', () async {
      final reply = await send('GET', '/with-cookie');
      expect(reply.setCookies, hasLength(2));
      expect(reply.setCookies, contains('session=abc; Path=/'));
      expect(reply.setCookies.where((c) => c.startsWith('__csrf=')), hasLength(1));
    });
  });

  group('unsafe methods', () {
    test('POST with the form field token passes and the handler can still read the form', () async {
      final (token, cookie) = await issue();
      final reply = await send(
        'POST',
        '/',
        headers: {...form, 'cookie': '__csrf=$cookie'},
        body: 'note=hello+world&_csrf=$token',
      );
      expect(reply.status, 200);
      expect(reply.body, 'token=$token;note=hello world');
    });

    test('POST with the X-CSRF-Token header passes (HTMX path)', () async {
      final (token, cookie) = await issue();
      final reply = await send('POST', '/', headers: {'cookie': '__csrf=$cookie', 'x-csrf-token': token});
      expect(reply.status, 200);
      expect(reply.body, 'token=$token');
    });

    test('a header token wins over the form, which is left for the handler', () async {
      final (token, cookie) = await issue();
      final reply = await send(
        'POST',
        '/',
        headers: {...form, 'cookie': '__csrf=$cookie', 'x-csrf-token': token},
        body: 'note=kept',
      );
      expect(reply.status, 200);
      expect(reply.body, 'token=$token;note=kept');
    });

    Future<void> expectForbidden(Future<_Reply> reply) async {
      final r = await reply;
      expect(r.status, 403);
      expect(r.body, 'CSRF token mismatch');
    }

    test('POST without a cookie is 403', () async {
      await expectForbidden(send('POST', '/', headers: form, body: '_csrf=fake'));
    });

    test('POST without a submitted token is 403', () async {
      final (_, cookie) = await issue();
      await expectForbidden(send('POST', '/', headers: {...form, 'cookie': '__csrf=$cookie'}, body: 'note=x'));
    });

    test('POST with a wrong form token is 403', () async {
      final (_, cookie) = await issue();
      await expectForbidden(send('POST', '/', headers: {...form, 'cookie': '__csrf=$cookie'}, body: '_csrf=wrong'));
    });

    test('POST with a wrong header token is 403', () async {
      final (_, cookie) = await issue();
      await expectForbidden(send('POST', '/', headers: {'cookie': '__csrf=$cookie', 'x-csrf-token': 'wrong'}));
    });

    test('POST with a forged cookie signature is 403 even when the token matches it', () async {
      final (token, _) = await issue();
      await expectForbidden(send('POST', '/', headers: {'cookie': '__csrf=$token.${'0' * 64}', 'x-csrf-token': token}));
    });

    test('a token in a non-form body is not accepted', () async {
      final (token, cookie) = await issue();
      await expectForbidden(
        send('POST', '/', headers: {'content-type': 'text/plain', 'cookie': '__csrf=$cookie'}, body: '_csrf=$token'),
      );
    });

    for (final method in ['PUT', 'DELETE', 'PATCH']) {
      test('$method without a token is 403', () async {
        final (_, cookie) = await issue();
        await expectForbidden(send(method, '/', headers: {'cookie': '__csrf=$cookie'}));
      });
    }

    test('a form body over the default form limit never reaches the handler', () async {
      final (_, cookie) = await issue();
      handled = 0;
      // Relic stops reading at the limit and answers 413 with Connection:
      // close, but outside Windows it drops the rest of the body, so a client
      // still sending may see the connection end instead. A raw socket keeps
      // that from failing the request write.
      final size = FormLimits.defaults.maxBodySize + 1;
      final socket = await Socket.connect(base.host, base.port);
      socket
        ..write(
          'POST / HTTP/1.1\r\nHost: ${base.authority}\r\ncontent-type: application/x-www-form-urlencoded\r\n'
          'cookie: __csrf=$cookie\r\ntransfer-encoding: chunked\r\n\r\n${size.toRadixString(16)}\r\n',
        )
        ..add(List<int>.filled(size, 0x61))
        ..write('\r\n0\r\n\r\n');
      final reply = await utf8.decoder.bind(socket).join().catchError((Object _) => '');
      socket.destroy();
      expect(reply, anyOf(isEmpty, startsWith('HTTP/1.1 413')));
      expect(handled, 0);
    });

    test('a malformed form body is 400', () async {
      final (_, cookie) = await issue();
      final reply = await send('POST', '/', headers: {...form, 'cookie': '__csrf=$cookie'}, body: '_csrf=%ZZ');
      expect(reply.status, 400);
    });

    test('an excluded path skips validation', () async {
      final reply = await send('POST', '/webhook', headers: form, body: 'note=x');
      expect(reply.status, 200);
      expect(reply.body, 'token=null;note=x');
    });
  });
}
