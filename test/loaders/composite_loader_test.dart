import 'package:test/test.dart';
import 'package:trellis/src/exceptions.dart';
import 'package:trellis/src/loaders/composite_loader.dart';
import 'package:trellis/src/loaders/map_loader.dart';
import 'package:trellis/src/loaders/template_loader.dart';

void main() {
  group('CompositeLoader', () {
    group('constructor', () {
      test('rejects empty delegate list', () {
        expect(
          () => CompositeLoader([]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts single delegate', () {
        final loader = CompositeLoader([MapLoader({'a': '<p>A</p>'})]);
        expect(loader.delegates, hasLength(1));
      });
    });

    group('load (async)', () {
      test('returns result from first delegate that has the template', () async {
        final loader = CompositeLoader([
          MapLoader({'page': '<p>First</p>'}),
          MapLoader({'page': '<p>Second</p>'}),
        ]);
        expect(await loader.load('page'), equals('<p>First</p>'));
      });

      test('falls back to second delegate when first throws TemplateNotFoundException', () async {
        final loader = CompositeLoader([
          MapLoader({}),
          MapLoader({'page': '<p>Fallback</p>'}),
        ]);
        expect(await loader.load('page'), equals('<p>Fallback</p>'));
      });

      test('falls back through multiple delegates', () async {
        final loader = CompositeLoader([
          MapLoader({}),
          MapLoader({}),
          MapLoader({'page': '<p>Third</p>'}),
        ]);
        expect(await loader.load('page'), equals('<p>Third</p>'));
      });

      test('throws TemplateNotFoundException when all delegates fail', () async {
        final loader = CompositeLoader([
          MapLoader({}),
          MapLoader({}),
        ]);
        expect(
          () => loader.load('missing'),
          throwsA(isA<TemplateNotFoundException>()),
        );
      });

      test('propagates non-TemplateNotFoundException errors immediately', () async {
        final loader = CompositeLoader([
          _ThrowingLoader(TemplateSecurityException('Path traversal detected')),
          MapLoader({'page': '<p>Should not reach</p>'}),
        ]);
        expect(
          () => loader.load('page'),
          throwsA(isA<TemplateSecurityException>()),
        );
      });

      test('propagates TemplateException (non-404) immediately', () async {
        final loader = CompositeLoader([
          _ThrowingLoader(TemplateException('Disk error')),
          MapLoader({'page': '<p>Fallback</p>'}),
        ]);
        expect(
          () => loader.load('page'),
          throwsA(
            isA<TemplateException>().having(
              (e) => e.message,
              'message',
              'Disk error',
            ),
          ),
        );
      });
    });

    group('loadSync', () {
      test('returns result from first delegate that has the template', () {
        final loader = CompositeLoader([
          MapLoader({'page': '<p>First</p>'}),
          MapLoader({'page': '<p>Second</p>'}),
        ]);
        expect(loader.loadSync('page'), equals('<p>First</p>'));
      });

      test('falls back when first delegate throws TemplateNotFoundException', () {
        final loader = CompositeLoader([
          MapLoader({}),
          MapLoader({'page': '<p>Fallback</p>'}),
        ]);
        expect(loader.loadSync('page'), equals('<p>Fallback</p>'));
      });

      test('throws TemplateNotFoundException when all delegates fail', () {
        final loader = CompositeLoader([
          MapLoader({}),
          MapLoader({}),
        ]);
        expect(
          () => loader.loadSync('missing'),
          throwsA(isA<TemplateNotFoundException>()),
        );
      });

      test('skips delegates that return null from loadSync', () {
        final loader = CompositeLoader([
          _NullSyncLoader(),
          MapLoader({'page': '<p>Sync fallback</p>'}),
        ]);
        expect(loader.loadSync('page'), equals('<p>Sync fallback</p>'));
      });

      test('throws TemplateNotFoundException when all return null or not found', () {
        final loader = CompositeLoader([
          _NullSyncLoader(),
          MapLoader({}),
        ]);
        expect(
          () => loader.loadSync('missing'),
          throwsA(isA<TemplateNotFoundException>()),
        );
      });

      test('propagates non-TemplateNotFoundException errors immediately', () {
        final loader = CompositeLoader([
          _ThrowingSyncLoader(TemplateSecurityException('Security violation')),
          MapLoader({'page': '<p>Fallback</p>'}),
        ]);
        expect(
          () => loader.loadSync('page'),
          throwsA(isA<TemplateSecurityException>()),
        );
      });
    });

    group('delegate ordering', () {
      test('first matching delegate wins — order matters', () async {
        final loader = CompositeLoader([
          MapLoader({'shared': '<p>From A</p>'}),
          MapLoader({'shared': '<p>From B</p>'}),
        ]);
        expect(await loader.load('shared'), equals('<p>From A</p>'));
      });

      test('different templates in different delegates', () async {
        final loader = CompositeLoader([
          MapLoader({'a': '<p>A</p>'}),
          MapLoader({'b': '<p>B</p>'}),
        ]);
        expect(await loader.load('a'), equals('<p>A</p>'));
        expect(await loader.load('b'), equals('<p>B</p>'));
      });
    });
  });
}

/// A loader that always throws a specific exception on load.
class _ThrowingLoader implements TemplateLoader {
  final Exception error;
  _ThrowingLoader(this.error);

  @override
  Future<String> load(String name) => throw error;

  @override
  String? loadSync(String name) => throw error;
}

/// A loader that always throws on sync load.
class _ThrowingSyncLoader implements TemplateLoader {
  final Exception error;
  _ThrowingSyncLoader(this.error);

  @override
  Future<String> load(String name) async => throw error;

  @override
  String? loadSync(String name) => throw error;
}

/// A loader that returns null from loadSync (sync not supported).
class _NullSyncLoader implements TemplateLoader {
  @override
  Future<String> load(String name) async => throw TemplateNotFoundException(name);

  @override
  String? loadSync(String name) => null;
}
