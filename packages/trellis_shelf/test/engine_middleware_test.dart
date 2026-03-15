import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() {
  group('trellisEngine middleware', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}));
    });

    test('injects engine into request context', () async {
      Trellis? receivedEngine;

      final handler = const Pipeline().addMiddleware(trellisEngine(engine)).addHandler((request) {
        receivedEngine = getEngine(request);
        return Response.ok('ok');
      });

      await handler(Request('GET', Uri.parse('http://localhost/')));
      expect(receivedEngine, isNotNull);
    });

    test('injected engine is same object identity', () async {
      Trellis? receivedEngine;

      final handler = const Pipeline().addMiddleware(trellisEngine(engine)).addHandler((request) {
        receivedEngine = getEngine(request);
        return Response.ok('ok');
      });

      await handler(Request('GET', Uri.parse('http://localhost/')));
      expect(identical(receivedEngine, engine), isTrue);
    });

    test('preserves existing request context', () async {
      Map<String, Object>? receivedContext;

      final handler = const Pipeline()
          .addMiddleware((inner) {
            return (request) {
              return inner(request.change(context: {'existing': 'value'}));
            };
          })
          .addMiddleware(trellisEngine(engine))
          .addHandler((request) {
            receivedContext = request.context;
            return Response.ok('ok');
          });

      await handler(Request('GET', Uri.parse('http://localhost/')));
      expect(receivedContext!['existing'], 'value');
      expect(getEngine(Request('GET', Uri.parse('http://localhost/'), context: receivedContext!)), isNotNull);
    });

    test('passes through response unchanged', () async {
      final handler = const Pipeline().addMiddleware(trellisEngine(engine)).addHandler((request) {
        return Response.ok('hello', headers: {'x-custom': 'test'});
      });

      final response = await handler(Request('GET', Uri.parse('http://localhost/')));
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'hello');
      expect(response.headers['x-custom'], 'test');
    });
  });

  group('getEngine', () {
    test('throws StateError when engine not in context', () {
      final request = Request('GET', Uri.parse('http://localhost/'));
      expect(() => getEngine(request), throwsStateError);
    });

    test('StateError message mentions trellisEngine middleware', () {
      final request = Request('GET', Uri.parse('http://localhost/'));
      expect(
        () => getEngine(request),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('trellisEngine()'))),
      );
    });
  });
}
