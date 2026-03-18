import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

import 'test_utils.dart';

void main() {
  late Trellis engine;

  setUp(() {
    engine = Trellis(
      loader: MapLoader({
        'page':
            '<html><body>'
            '<h1 tl:text="\${title}">Title</h1>'
            '<div tl:fragment="content" tl:text="\${msg}">Content</div>'
            '<div tl:fragment="sidebar" tl:text="\${side}">Sidebar</div>'
            '</body></html>',
        'csrf-page': '<form><input name="_csrf" tl:attr="value=\${csrfToken}" type="hidden"></form>',
      }),
    );
  });

  Handler pageHandler(Map<String, dynamic> ctx, {String? htmxFragment}) {
    return const Pipeline()
        .addMiddleware(trellisProvider(engine))
        .addHandler((context) => renderPage(context, 'page', ctx, htmxFragment: htmxFragment));
  }

  group('renderPage', () {
    test('renders full page', () async {
      final response = await testGet(pageHandler({'title': 'Hello', 'msg': 'World', 'side': 'Nav'}));
      expect(response.body, contains('Hello'));
      expect(response.body, contains('<html>'));
    });

    test('has correct content-type', () async {
      final response = await testGet(pageHandler({'title': 'T', 'msg': 'M', 'side': 'S'}));
      expect(response.headers['content-type'], contains('text/html'));
      expect(response.headers['content-type'], contains('utf-8'));
    });

    test('renders fragment for HTMX request when htmxFragment specified', () async {
      final handler = pageHandler({'title': 'T', 'msg': 'Partial', 'side': 'S'}, htmxFragment: 'content');
      final response = await testGet(handler, headers: {'hx-request': 'true'});
      expect(response.body, contains('Partial'));
      expect(response.body, isNot(contains('<html>')));
    });

    test('renders full page for non-HTMX request even when htmxFragment specified', () async {
      final handler = pageHandler({'title': 'T', 'msg': 'Full', 'side': 'S'}, htmxFragment: 'content');
      final response = await testGet(handler);
      expect(response.body, contains('<html>'));
    });
  });

  group('renderFragment', () {
    test('renders single named fragment', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisProvider(engine))
          .addHandler((context) => renderFragment(context, 'page', 'content', {'msg': 'Fragment'}));

      final response = await testGet(handler);
      expect(response.body, contains('Fragment'));
      expect(response.body, isNot(contains('<html>')));
    });

    test('has correct content-type', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisProvider(engine))
          .addHandler((context) => renderFragment(context, 'page', 'content', {'msg': 'M'}));

      final response = await testGet(handler);
      expect(response.headers['content-type'], contains('text/html'));
    });
  });

  group('renderOobFragments', () {
    test('renders multiple fragments concatenated', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisProvider(engine))
          .addHandler(
            (context) => renderOobFragments(context, 'page', ['content', 'sidebar'], {'msg': 'C', 'side': 'S'}),
          );

      final response = await testGet(handler);
      expect(response.body, contains('C'));
      expect(response.body, contains('S'));
    });
  });

  group('context merging', () {
    test('CSRF token merged into template context when trellisCsrf applied', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisProvider(engine))
          .addMiddleware(trellisCsrf(secret: 'test-secret'))
          .addHandler((context) => renderPage(context, 'csrf-page', {}));

      final response = await testGet(handler);
      // CSRF token is a 64-char hex string rendered as form input value.
      expect(response.body, matches(RegExp(r'value="[0-9a-f]{64}"')));
    });

    test('works without CSRF token in context', () async {
      final response = await testGet(pageHandler({'title': 'Hello', 'msg': 'World', 'side': 'Nav'}));
      expect(response.statusCode, 200);
    });
  });

  group('error handling', () {
    test('throws StateError when engine not provided', () async {
      final handler = const Pipeline().addHandler((context) => renderPage(context, 'page', {}));
      // StateError propagates as 500 from the server
      final response = await testGet(handler);
      expect(response.statusCode, 500);
    });
  });
}
