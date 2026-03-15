import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

import 'package:trellis_shelf/src/request_context.dart';

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
        'csrf-page': '<form><input tl:attr="value=\${csrfToken}" type="hidden"></form>',
      }),
    );
  });

  Request makeRequest({Map<String, String>? headers, Map<String, Object>? context}) {
    return Request(
      'GET',
      Uri.parse('http://localhost/'),
      headers: headers,
      context: {
        // Inject engine into context (simulating trellisEngine middleware)
        'trellis_shelf.engine': engine,
        ...?context,
      },
    );
  }

  group('renderPage', () {
    test('renders full page', () async {
      final response = await renderPage(makeRequest(), 'page', {'title': 'Hello', 'msg': 'World', 'side': 'Nav'});
      final body = await response.readAsString();
      expect(body, contains('Hello'));
      expect(body, contains('<html>'));
      expect(response.headers['content-type'], 'text/html; charset=utf-8');
    });

    test('renders fragment for HTMX request when htmxFragment specified', () async {
      final request = makeRequest(headers: {'hx-request': 'true'});
      final response = await renderPage(request, 'page', {
        'title': 'T',
        'msg': 'Partial',
        'side': 'S',
      }, htmxFragment: 'content');
      final body = await response.readAsString();
      expect(body, contains('Partial'));
      expect(body, isNot(contains('<html>')));
    });

    test('renders full page for non-HTMX request even when htmxFragment specified', () async {
      final response = await renderPage(makeRequest(), 'page', {
        'title': 'T',
        'msg': 'Full',
        'side': 'S',
      }, htmxFragment: 'content');
      final body = await response.readAsString();
      expect(body, contains('<html>'));
    });
  });

  group('renderFragment', () {
    test('renders single named fragment', () async {
      final response = await renderFragment(makeRequest(), 'page', 'content', {'msg': 'Fragment'});
      final body = await response.readAsString();
      expect(body, contains('Fragment'));
      expect(body, isNot(contains('<html>')));
    });
  });

  group('renderOobFragments', () {
    test('renders multiple fragments concatenated', () async {
      final response = await renderOobFragments(
        makeRequest(),
        'page',
        ['content', 'sidebar'],
        {'msg': 'C', 'side': 'S'},
      );
      final body = await response.readAsString();
      expect(body, contains('C'));
      expect(body, contains('S'));
    });
  });

  group('context merging', () {
    test('CSRF token is merged into template context', () async {
      final request = makeRequest(context: {csrfTokenContextKey: 'test-token-123'});
      final response = await renderPage(request, 'csrf-page', {});
      final body = await response.readAsString();
      expect(body, contains('test-token-123'));
    });

    test('CSRF token overwrites caller-provided value', () async {
      final request = makeRequest(context: {csrfTokenContextKey: 'real-token'});
      final response = await renderPage(request, 'csrf-page', {'csrfToken': 'caller-token'});
      final body = await response.readAsString();
      expect(body, contains('real-token'));
      expect(body, isNot(contains('caller-token')));
    });

    test('works without CSRF token in context', () async {
      final response = await renderPage(makeRequest(), 'page', {'title': 'Hello', 'msg': 'World', 'side': 'Nav'});
      expect(response.statusCode, 200);
    });
  });

  group('error handling', () {
    test('throws StateError when engine not in context', () async {
      final request = Request('GET', Uri.parse('http://localhost/'));
      expect(() => renderPage(request, 'page', {}), throwsStateError);
    });
  });
}
