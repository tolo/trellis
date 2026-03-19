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
          'templates/pages/about.html',
          'templates/partials/nav.html',
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
      expect(server, contains("..get('/about'"));
      expect(server, contains("..post('/counter/increment'"));
      expect(server, contains('CspBuilder'));
      expect(server, contains('https://cdn.jsdelivr.net'));
    });

    test('handlers.dart uses trellis_shelf helpers and counter routes', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final handlers = writer.files['lib/handlers.dart']!;
      expect(handlers, contains('renderPage'));
      expect(handlers, contains("import 'package:trellis_shelf/trellis_shelf.dart'"));
      expect(handlers, contains('renderFragment'));
      expect(handlers, contains('aboutPage'));
      expect(handlers, contains('incrementCounter'));
      expect(handlers, contains('decrementCounter'));
      expect(handlers, contains('resetCounter'));
      expect(handlers, contains('_counter'));
    });

    test('index page uses tl:extends, fragments, and HTMX counter controls', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final index = writer.files['templates/pages/index.html']!;
      expect(index, contains('tl:extends="layouts/base.html"'));
      expect(index, contains('tl:define="content"'));
      expect(index, contains('tl:each'));
      expect(index, contains('tl:text'));
      expect(index, contains('tl:fragment="page-content"'));
      expect(index, contains('tl:fragment="counter"'));
      expect(index, contains('hx-post="/counter/increment"'));
      expect(index, contains('hx-post="/counter/decrement"'));
      expect(index, contains('hx-post="/counter/reset"'));
      expect(index, contains('hx-target="#counter"'));
      expect(index, contains('hx-swap="outerHTML"'));
      expect(index, contains('_csrf'));
      expect(index, contains(r'tl:attr="value=${csrfToken}"'));
    });

    test('base layout uses tl:insert, SPA navigation shell, SRI, and CSRF header', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final base = writer.files['templates/layouts/base.html']!;
      expect(base, contains('tl:define="content"'));
      expect(base, contains('id="content"'));
      expect(base, contains('tl:insert="~{partials/nav.html :: nav}"'));
      expect(base, contains('integrity="sha384-'));
      expect(base, contains('crossorigin="anonymous"'));
      expect(base, contains('csrf-token'));
      expect(base, contains('X-CSRF-Token'));
      expect(base, contains('htmx:configRequest'));
    });

    test('nav partial defines a tl:fragment with Home and About links', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final nav = writer.files['templates/partials/nav.html']!;
      expect(nav, contains('tl:fragment="nav"'));
      expect(nav, contains('hx-get="/about"'));
      expect(nav, contains('hx-target="#content"'));
      expect(nav, contains('hx-push-url="true"'));
    });

    test('about page explains Shelf-specific patterns', () async {
      final generator = ProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();

      final about = writer.files['templates/pages/about.html']!;
      expect(about, contains('Shelf Pipeline'));
      expect(about, contains('Request Context'));
      expect(about, contains('Middleware Ordering'));
      expect(about, contains('CSRF Protection'));
      expect(about, contains('Dev Hot Reload'));
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
