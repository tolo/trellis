import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  group('ProjectGenerator', () {
    late InMemoryFileWriter writer;

    setUp(() {
      writer = InMemoryFileWriter();
    });

    test('generates all 10 expected files', () async {
      final generator = ProjectGenerator(projectName: 'test_app', writer: writer);
      await generator.generate();

      expect(writer.files, hasLength(10));
      expect(
        writer.files.keys,
        containsAll([
          'pubspec.yaml',
          'bin/server.dart',
          'lib/handlers.dart',
          'templates/layouts/base.html',
          'templates/pages/index.html',
          'templates/partials/nav.html',
          'templates/partials/htmx.html',
          'static/styles.css',
          '.gitignore',
          'analysis_options.yaml',
        ]),
      );
    });

    test('pubspec.yaml contains project name and dependencies', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final pubspec = writer.files['pubspec.yaml']!;
      expect(pubspec, contains('name: my_app'));
      expect(pubspec, contains('trellis:'));
      expect(pubspec, contains('trellis_shelf:'));
      expect(pubspec, contains('trellis_dev:'));
      expect(pubspec, contains('shelf:'));
      expect(pubspec, contains('shelf_router:'));
      expect(pubspec, contains('shelf_static:'));
    });

    test('server.dart imports project and demonstrates middleware', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final server = writer.files['bin/server.dart']!;
      expect(server, contains("import 'package:my_app/handlers.dart'"));
      expect(server, contains('trellisSecurityHeaders'));
      expect(server, contains('trellisEngine'));
      expect(server, contains('devMiddleware'));
      expect(server, contains('trellisCsrf'));
      expect(server, contains('CSRF_SECRET'));
      expect(server, contains('--dev'));
    });

    test('handlers.dart uses trellis_shelf helpers and greet endpoint', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final handlers = writer.files['lib/handlers.dart']!;
      expect(handlers, contains('renderPage'));
      expect(handlers, contains("import 'package:trellis_shelf/trellis_shelf.dart'"));
      expect(handlers, contains('isHtmxRequest'));
      expect(handlers, contains('renderFragment'));
      expect(handlers, contains('greet'));
      expect(handlers, contains('status'));
    });

    test('index page uses tl:extends, tl:define, and HTMX with CSRF', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final index = writer.files['templates/pages/index.html']!;
      expect(index, contains('tl:extends="layouts/base.html"'));
      expect(index, contains('tl:define="content"'));
      expect(index, contains('tl:each'));
      expect(index, contains('tl:text'));
      expect(index, contains('hx-post="/greet"'));
      expect(index, contains('hx-target="#greeting-result"'));
      expect(index, contains('hx-swap="innerHTML"'));
      expect(index, contains('_csrf'));
      expect(index, contains(r'tl:attr="value=${csrfToken}"'));
    });

    test('base layout uses tl:insert, SRI, and CSRF header', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final base = writer.files['templates/layouts/base.html']!;
      expect(base, contains('tl:define="content"'));
      expect(base, contains('tl:insert="~{partials/nav.html :: nav}"'));
      expect(base, contains('integrity="sha384-'));
      expect(base, contains('crossorigin="anonymous"'));
      expect(base, contains('csrf-token'));
      expect(base, contains('X-CSRF-Token'));
      expect(base, contains('htmx:configRequest'));
    });

    test('nav partial defines a tl:fragment', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final nav = writer.files['templates/partials/nav.html']!;
      expect(nav, contains('tl:fragment="nav"'));
    });

    test('all generated files have non-empty content', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      for (final entry in writer.files.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} should not be empty');
      }
    });
  });
}
