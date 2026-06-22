import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dev/src/dev_middleware.dart';

/// Creates a dev-mode loader over a fresh temp dir, registered for teardown.
FileSystemLoader _loaderFor(Directory dir) => FileSystemLoader(dir.path, devMode: true);

Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('trellis_dev_validate_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void _writeTemplate(Directory dir, String name, String content) {
  File('${dir.path}/$name.html').writeAsStringSync(content);
}

void main() {
  group('validateLoadedTemplates', () {
    test('reports errors with bin/validate format and attribute suffix', () {
      final dir = _tempDir();
      _writeTemplate(dir, 'broken', '<div tl:if=""></div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final sink = StringBuffer();
      validateLoadedTemplates(loader, TemplateValidator(), {}, sink);

      // The location is a reconstructed path (basePath/name.ext), matching the
      // validate CLI so the `path:line:` prefix resolves to a file.
      expect(sink.toString().trim(), '${dir.path}/broken.html:1: error: Expression value cannot be empty (tl:if)');
    });

    test('reports unknown attributes as warnings', () {
      final dir = _tempDir();
      _writeTemplate(dir, 'page', '<div tl:bogus="x"></div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final sink = StringBuffer();
      validateLoadedTemplates(loader, TemplateValidator(), {}, sink);

      expect(sink.toString(), contains('page.html:1: warning: Unknown trellis attribute "tl:bogus" (tl:bogus)'));
    });

    test('reports each duplicate-content template under its own path', () {
      final dir = _tempDir();
      _writeTemplate(dir, 'a', '<div tl:if=""></div>');
      _writeTemplate(dir, 'b', '<div tl:if=""></div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final sink = StringBuffer();
      validateLoadedTemplates(loader, TemplateValidator(), {}, sink);

      final out = sink.toString();
      expect(out, contains('a.html:1: error: Expression value cannot be empty (tl:if)'));
      expect(out, contains('b.html:1: error: Expression value cannot be empty (tl:if)'));
    });

    test('emits nothing for valid templates', () {
      final dir = _tempDir();
      _writeTemplate(dir, 'ok', '<div tl:text="\${name}">x</div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final sink = StringBuffer();
      validateLoadedTemplates(loader, TemplateValidator(), {}, sink);

      expect(sink.toString(), isEmpty);
    });

    test('caches by source so an unchanged template is reported only once', () {
      final dir = _tempDir();
      _writeTemplate(dir, 'broken', '<div tl:if=""></div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final cache = <String, List<ValidationError>>{};
      final sink = StringBuffer();
      validateLoadedTemplates(loader, TemplateValidator(), cache, sink);
      final afterFirst = sink.length;

      // Re-scan with the same cache: source unchanged, so nothing new is written.
      validateLoadedTemplates(loader, TemplateValidator(), cache, sink);
      expect(sink.length, afterFirst);
    });

    test('re-validates and reports when a template changes', () {
      final dir = _tempDir();
      _writeTemplate(dir, 'page', '<div tl:text="\${name}">x</div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final cache = <String, List<ValidationError>>{};
      final sink = StringBuffer();
      validateLoadedTemplates(loader, TemplateValidator(), cache, sink);
      expect(sink.toString(), isEmpty);

      // Introduce an error; the new source misses the cache and is reported.
      _writeTemplate(dir, 'page', '<div tl:if=""></div>');
      validateLoadedTemplates(loader, TemplateValidator(), cache, sink);
      expect(sink.toString(), contains('page.html:1: error: Expression value cannot be empty (tl:if)'));
    });

    test('honours a custom-prefix validator', () {
      final dir = _tempDir();
      _writeTemplate(dir, 'page', '<div data-tl-if=""></div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final sink = StringBuffer();
      validateLoadedTemplates(loader, TemplateValidator(prefix: 'data-tl'), {}, sink);

      expect(sink.toString(), contains('page.html:1: error: Expression value cannot be empty (data-tl-if)'));
    });
  });

  group('devMiddleware validation wiring', () {
    test('validates templates at startup when validate is true', () {
      final dir = _tempDir();
      _writeTemplate(dir, 'broken', '<div tl:if=""></div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final sink = StringBuffer();
      devMiddleware(loader, validationSink: sink);

      expect(sink.toString(), contains('broken.html:1: error: Expression value cannot be empty (tl:if)'));
    });

    test('re-validates on a watched file change', () async {
      final dir = _tempDir();
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final sink = StringBuffer();
      // Registers the on-change subscription; dir is empty so startup is silent.
      devMiddleware(loader, validationSink: sink);
      expect(sink.toString(), isEmpty);

      // Observe the watcher event ourselves; the middleware's listener (added
      // first) runs its synchronous re-scan before this completer resolves.
      final changed = loader.changes!.first;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      _writeTemplate(dir, 'broken', '<div tl:if=""></div>');
      await changed.timeout(const Duration(seconds: 5));

      expect(sink.toString(), contains('broken.html:1: error: Expression value cannot be empty (tl:if)'));
    });

    test('skips validation when validate is false', () {
      final dir = _tempDir();
      _writeTemplate(dir, 'broken', '<div tl:if=""></div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final sink = StringBuffer();
      devMiddleware(loader, validate: false, validationSink: sink);

      expect(sink.toString(), isEmpty);
    });

    test('validation does not interfere with request handling', () async {
      final dir = _tempDir();
      _writeTemplate(dir, 'broken', '<div tl:if=""></div>');
      final loader = _loaderFor(dir);
      addTearDown(loader.close);

      final middleware = devMiddleware(loader, validationSink: StringBuffer());
      final handler = middleware((_) => Response.ok('app'));
      final response = await handler(Request('GET', Uri.parse('http://localhost/page')));

      expect(await response.readAsString(), 'app');
    });
  });
}
