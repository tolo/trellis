import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  group('DartFrogProjectGenerator', () {
    late InMemoryFileWriter writer;
    late DartFrogProjectGenerator generator;

    setUp(() async {
      writer = InMemoryFileWriter();
      generator = DartFrogProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();
    });

    test('generates all expected files', () {
      final expectedFiles = [
        'pubspec.yaml',
        'dart_frog.yaml',
        '.gitignore',
        'analysis_options.yaml',
        'routes/_middleware.dart',
        'routes/index.dart',
        'routes/todos/index.dart',
        'templates/layouts/base.html',
        'templates/pages/index.html',
        'templates/partials/nav.html',
        'templates/partials/todo_list.html',
        'public/styles.css',
      ];

      for (final path in expectedFiles) {
        expect(writer.files.containsKey(path), isTrue, reason: '$path should be generated');
      }
    });

    test('generates exactly 12 files', () {
      expect(writer.files.length, 12);
    });

    test('all files have non-empty content', () {
      for (final entry in writer.files.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key} should not be empty');
      }
    });

    group('pubspec.yaml', () {
      late String content;
      setUp(() => content = writer.files['pubspec.yaml']!);

      test('contains project name', () {
        expect(content, contains('name: my_app'));
      });

      test('depends on dart_frog', () {
        expect(content, contains('dart_frog:'));
      });

      test('depends on trellis', () {
        expect(content, contains('trellis:'));
      });

      test('depends on trellis_dart_frog', () {
        expect(content, contains('trellis_dart_frog:'));
      });

      test('depends on trellis_dev', () {
        expect(content, contains('trellis_dev:'));
      });

      test('does not depend on trellis_shelf directly', () {
        // trellis_shelf is a transitive dep via trellis_dart_frog
        expect(content, isNot(contains('trellis_shelf:')));
      });
    });

    group('dart_frog.yaml', () {
      late String content;
      setUp(() => content = writer.files['dart_frog.yaml']!);

      test('contains project name', () {
        expect(content, contains('my_app'));
      });
    });

    group('routes/_middleware.dart', () {
      late String content;
      setUp(() => content = writer.files['routes/_middleware.dart']!);

      test('imports dart_frog', () {
        expect(content, contains("import 'package:dart_frog/dart_frog.dart'"));
      });

      test('imports trellis', () {
        expect(content, contains("import 'package:trellis/trellis.dart'"));
      });

      test('imports trellis_dart_frog', () {
        expect(content, contains("import 'package:trellis_dart_frog/trellis_dart_frog.dart'"));
      });

      test('uses trellisProvider', () {
        expect(content, contains('trellisProvider'));
      });

      test('uses trellisSecurityHeaders', () {
        expect(content, contains('trellisSecurityHeaders'));
      });

      test('uses trellisCsrf', () {
        expect(content, contains('trellisCsrf'));
      });

      test('uses devMiddleware', () {
        expect(content, contains('devMiddleware'));
      });

      test('reads CSRF_SECRET from environment', () {
        expect(content, contains('CSRF_SECRET'));
      });

      test('reads DEV from environment', () {
        expect(content, contains("'DEV'"));
      });

      test('contains project name in default CSRF secret', () {
        expect(content, contains('my_app-dev-secret'));
      });
    });

    group('routes/index.dart', () {
      late String content;
      setUp(() => content = writer.files['routes/index.dart']!);

      test('imports trellis_dart_frog', () {
        expect(content, contains("import 'package:trellis_dart_frog/trellis_dart_frog.dart'"));
      });

      test('uses onRequest handler signature', () {
        expect(content, contains('onRequest(RequestContext context)'));
      });

      test('uses renderPage', () {
        expect(content, contains('renderPage'));
      });

      test('renders index page template', () {
        expect(content, contains("'pages/index.html'"));
      });

      test('contains project name in welcome message', () {
        expect(content, contains('my_app'));
      });

      test('passes features list to context', () {
        expect(content, contains("'features'"));
      });
    });

    group('routes/todos/index.dart', () {
      late String content;
      setUp(() => content = writer.files['routes/todos/index.dart']!);

      test('uses onRequest handler signature', () {
        expect(content, contains('onRequest(RequestContext context)'));
      });

      test('uses renderFragment', () {
        expect(content, contains('renderFragment'));
      });

      test('references todo-list fragment', () {
        expect(content, contains("'todo-list'"));
      });

      test('references todo_list partial template', () {
        expect(content, contains("'partials/todo_list.html'"));
      });

      test('has in-memory todos list', () {
        expect(content, contains('_todos'));
      });

      test('handles POST via _add', () {
        expect(content, contains('HttpMethod.post'));
      });

      test('handles PUT via _toggle', () {
        expect(content, contains('HttpMethod.put'));
      });

      test('handles DELETE via _remove', () {
        expect(content, contains('HttpMethod.delete'));
      });

      test('reads request body for mutations', () {
        expect(content, contains('context.request.body()'));
      });

      test('uses Uri.splitQueryString for form data', () {
        expect(content, contains('Uri.splitQueryString'));
      });
    });

    group('templates/layouts/base.html', () {
      late String content;
      setUp(() => content = writer.files['templates/layouts/base.html']!);

      test('is valid HTML with DOCTYPE', () {
        expect(content, contains('<!DOCTYPE html>'));
      });

      test('uses tl:extends anchor for tl:define', () {
        expect(content, contains('tl:define="content"'));
      });

      test('inserts nav partial', () {
        expect(content, contains('tl:insert'));
        expect(content, contains('nav.html'));
      });

      test('has HTMX CDN script with SRI integrity', () {
        expect(content, contains('htmx.org'));
        expect(content, contains('integrity='));
      });

      test('has CSRF meta tag', () {
        expect(content, contains('csrf-token'));
        expect(content, contains('csrfToken'));
      });

      test('has htmx:configRequest script for CSRF header', () {
        expect(content, contains('htmx:configRequest'));
        expect(content, contains('X-CSRF-Token'));
      });

      test('contains project name', () {
        expect(content, contains('my_app'));
      });

      test('links to Dart Frog', () {
        expect(content, contains('Dart Frog'));
      });
    });

    group('templates/pages/index.html', () {
      late String content;
      setUp(() => content = writer.files['templates/pages/index.html']!);

      test('uses tl:extends', () {
        expect(content, contains('tl:extends'));
      });

      test('uses tl:define for content', () {
        expect(content, contains('tl:define="content"'));
      });

      test('uses tl:each for features', () {
        expect(content, contains('tl:each'));
        expect(content, contains('features'));
      });

      test('uses tl:text for message', () {
        expect(content, contains('tl:text'));
        expect(content, contains('message'));
      });

      test('has HTMX todo form', () {
        expect(content, contains('hx-post="/todos"'));
      });

      test('has CSRF hidden field', () {
        expect(content, contains('_csrf'));
        expect(content, contains('csrfToken'));
      });

      test('todo list container triggers hx-get on load', () {
        expect(content, contains('hx-get="/todos"'));
        expect(content, contains('hx-trigger="load"'));
      });
    });

    group('templates/partials/nav.html', () {
      late String content;
      setUp(() => content = writer.files['templates/partials/nav.html']!);

      test('defines nav fragment', () {
        expect(content, contains('tl:fragment="nav"'));
      });

      test('contains home link', () {
        expect(content, contains('href="/"'));
      });
    });

    group('templates/partials/todo_list.html', () {
      late String content;
      setUp(() => content = writer.files['templates/partials/todo_list.html']!);

      test('defines todo-list fragment', () {
        expect(content, contains('tl:fragment="todo-list"'));
      });

      test('uses tl:each for todos', () {
        expect(content, contains('tl:each'));
        expect(content, contains('todos'));
      });

      test('has hx-put for toggle', () {
        expect(content, contains('hx-put="/todos"'));
      });

      test('has hx-delete for remove', () {
        expect(content, contains('hx-delete="/todos"'));
      });

      test('passes todo id and CSRF in hx-vals', () {
        expect(content, contains('hx-vals'));
        expect(content, contains('todo.id'));
        expect(content, contains('csrfToken'));
      });

      test('has empty state message', () {
        expect(content, contains('placeholder'));
      });

      test('uses conditional done class via tl:class', () {
        expect(content, contains('tl:class'));
        expect(content, contains("'done'"));
      });
    });

    group('project name variation', () {
      test('different project name reflected in files', () async {
        final w2 = InMemoryFileWriter();
        final g2 = DartFrogProjectGenerator(projectName: 'todo_app', writer: w2);
        await g2.generate();

        expect(w2.files['pubspec.yaml'], contains('name: todo_app'));
        expect(w2.files['dart_frog.yaml'], contains('todo_app'));
        expect(w2.files['routes/_middleware.dart'], contains('todo_app-dev-secret'));
        expect(w2.files['templates/layouts/base.html'], contains('todo_app'));
        expect(w2.files['routes/index.dart'], contains('todo_app'));
      });
    });
  });
}
