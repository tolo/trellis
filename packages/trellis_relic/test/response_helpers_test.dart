import 'package:mocktail/mocktail.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

class MockRequest extends Mock implements Request {}

Request makeRequest({Map<String, Iterable<String>>? headers}) {
  final req = MockRequest();
  final h = Headers.fromMap(headers ?? {});
  when(() => req.headers).thenReturn(h);
  return req;
}

const _pageTemplate = '''
<html>
  <body>
    <h1 tl:text="\${title}">Title</h1>
    <div tl:fragment="content" tl:text="\${msg}">Content</div>
    <div tl:fragment="sidebar" tl:text="\${side}">Sidebar</div>
  </body>
</html>
''';

void main() {
  late Trellis engine;

  setUp(() {
    engine = Trellis(loader: MapLoader({'page': _pageTemplate}));
  });

  group('renderPage', () {
    test('renders full page with correct content', () async {
      final req = makeRequest();
      final response = await renderPage(
        req,
        engine,
        'page',
        {'title': 'Hello', 'msg': 'World', 'side': 'Nav'},
      );
      final body = await response.readAsString();
      expect(body, contains('Hello'));
      expect(body, contains('<html'));
    });

    test('returns text/html content type', () async {
      final req = makeRequest();
      final response = await renderPage(req, engine, 'page', {'title': 'T', 'msg': 'M', 'side': 'S'});
      expect(response.body.bodyType?.mimeType.primaryType, equals('text'));
      expect(response.body.bodyType?.mimeType.subType, equals('html'));
    });

    test('renders fragment for HTMX request when htmxFragment specified', () async {
      final req = makeRequest(headers: {'HX-Request': ['true']});
      final response = await renderPage(
        req,
        engine,
        'page',
        {'title': 'T', 'msg': 'FragContent', 'side': 'S'},
        htmxFragment: 'content',
      );
      final body = await response.readAsString();
      expect(body, contains('FragContent'));
      expect(body, isNot(contains('<html')));
    });

    test('renders full page for non-HTMX request even when htmxFragment specified', () async {
      final req = makeRequest();
      final response = await renderPage(
        req,
        engine,
        'page',
        {'title': 'T', 'msg': 'M', 'side': 'S'},
        htmxFragment: 'content',
      );
      final body = await response.readAsString();
      expect(body, contains('<html'));
    });

    test('renders full page when htmxFragment is null (HTMX request)', () async {
      final req = makeRequest(headers: {'HX-Request': ['true']});
      final response = await renderPage(req, engine, 'page', {'title': 'T', 'msg': 'M', 'side': 'S'});
      final body = await response.readAsString();
      expect(body, contains('<html'));
    });
  });

  group('renderFragment', () {
    test('renders single named fragment', () async {
      final req = makeRequest();
      final response = await renderFragment(
        req,
        engine,
        'page',
        'content',
        {'title': 'T', 'msg': 'FragMsg', 'side': 'S'},
      );
      final body = await response.readAsString();
      expect(body, contains('FragMsg'));
    });

    test('fragment output does not contain html wrapper', () async {
      final req = makeRequest();
      final response = await renderFragment(req, engine, 'page', 'content', {'title': 'T', 'msg': 'M', 'side': 'S'});
      final body = await response.readAsString();
      expect(body, isNot(contains('<html')));
    });

    test('returns text/html content type', () async {
      final req = makeRequest();
      final response = await renderFragment(req, engine, 'page', 'content', {'title': 'T', 'msg': 'M', 'side': 'S'});
      expect(response.body.bodyType?.mimeType.primaryType, equals('text'));
      expect(response.body.bodyType?.mimeType.subType, equals('html'));
    });
  });

  group('renderOobFragments', () {
    test('renders multiple fragments concatenated', () async {
      final req = makeRequest();
      final response = await renderOobFragments(
        req,
        engine,
        'page',
        ['content', 'sidebar'],
        {'title': 'T', 'msg': 'ContentText', 'side': 'SideText'},
      );
      final body = await response.readAsString();
      expect(body, contains('ContentText'));
      expect(body, contains('SideText'));
    });

    test('both fragment contents are present in output', () async {
      final req = makeRequest();
      final response = await renderOobFragments(
        req,
        engine,
        'page',
        ['content', 'sidebar'],
        {'title': 'T', 'msg': 'Alpha', 'side': 'Beta'},
      );
      final body = await response.readAsString();
      expect(body, contains('Alpha'));
      expect(body, contains('Beta'));
    });

    test('output does not contain html wrapper', () async {
      final req = makeRequest();
      final response = await renderOobFragments(
        req,
        engine,
        'page',
        ['content', 'sidebar'],
        {'title': 'T', 'msg': 'M', 'side': 'S'},
      );
      final body = await response.readAsString();
      expect(body, isNot(contains('<html')));
    });
  });
}
