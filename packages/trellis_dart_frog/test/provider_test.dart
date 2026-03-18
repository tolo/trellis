import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

import 'test_utils.dart';

void main() {
  late Trellis engine;

  setUp(() {
    engine = Trellis(loader: MapLoader({'page': '<html><body>Hello</body></html>'}));
  });

  group('trellisProvider', () {
    test('makes engine available via context.read<Trellis>()', () async {
      final handler = const Pipeline().addMiddleware(trellisProvider(engine)).addHandler((context) async {
        final e = context.read<Trellis>();
        return Response(body: e.runtimeType.toString());
      });

      final response = await testGet(handler);
      expect(response.statusCode, 200);
      expect(response.body, 'Trellis');
    });

    test('engine is same object identity (hashCode matches)', () async {
      final handler = const Pipeline().addMiddleware(trellisProvider(engine)).addHandler((context) async {
        final e = context.read<Trellis>();
        return Response(body: e.hashCode.toString());
      });

      final response = await testGet(handler);
      expect(response.body, engine.hashCode.toString());
    });

    test('multiple providers coexist in chain', () async {
      final handler = const Pipeline()
          .addMiddleware(trellisProvider(engine))
          .addMiddleware(provider<String>((_) => 'hello'))
          .addHandler((context) async {
            final e = context.read<Trellis>();
            final s = context.read<String>();
            return Response(body: '${e.runtimeType}:$s');
          });

      final response = await testGet(handler);
      expect(response.body, 'Trellis:hello');
    });

    test('throws StateError when provider not applied', () async {
      final handler = const Pipeline().addHandler((context) async {
        try {
          context.read<Trellis>();
          return Response(body: 'no-error');
        } on StateError {
          return Response(statusCode: 500, body: 'state-error');
        }
      });

      final response = await testGet(handler);
      expect(response.body, 'state-error');
    });
  });
}
