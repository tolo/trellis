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
        'routes/about.dart',
        'lib/counter_state.dart',
        'routes/counter/increment.dart',
        'routes/counter/decrement.dart',
        'routes/counter/reset.dart',
        'templates/layouts/base.html',
        'templates/pages/index.html',
        'templates/pages/about.html',
        'templates/partials/nav.html',
        'public/styles.css',
      ];

      for (final path in expectedFiles) {
        expect(writer.files.containsKey(path), isTrue, reason: '$path should be generated');
      }
    });

    test('generates exactly 16 files', () {
      expect(writer.files.length, 16);
    });

    test('all files have non-empty content', () {
      for (final entry in writer.files.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key} should not be empty');
      }
    });

    group('pubspec.yaml', () {
      late String content;

      setUp(() => content = writer.files['pubspec.yaml']!);

      test('contains project name and dependencies', () {
        expect(content, contains('name: my_app'));
        expect(content, contains('dart_frog:'));
        expect(content, contains('trellis:'));
        expect(content, contains('trellis_dart_frog:'));
        expect(content, contains('trellis_dev:'));
      });
    });

    group('routes/_middleware.dart', () {
      late String content;

      setUp(() => content = writer.files['routes/_middleware.dart']!);

      test('configures provider, security, csrf, and hot reload', () {
        expect(content, contains('trellisProvider'));
        expect(content, contains('trellisSecurityHeaders'));
        expect(content, contains('trellisCsrf'));
        expect(content, contains('devMiddleware'));
        expect(content, contains('fromShelfMiddleware'));
        expect(content, contains('CSRF_SECRET'));
        expect(content, contains("'DEV'"));
      });
    });

    group('routes/index.dart', () {
      late String content;

      setUp(() => content = writer.files['routes/index.dart']!);

      test('renders the page-content fragment for HTMX navigation', () {
        expect(content, contains('homeContext()'));
        expect(content, contains("htmxFragment: 'page-content'"));
        expect(content, contains('package:my_app/counter_state.dart'));
      });
    });

    group('routes/about.dart', () {
      late String content;

      setUp(() => content = writer.files['routes/about.dart']!);

      test('renders the about page with HTMX fragment fallback', () {
        expect(content, contains("'pages/about.html'"));
        expect(content, contains("htmxFragment: 'page-content'"));
        expect(content, contains("'title': 'About'"));
      });
    });

    group('lib/counter_state.dart', () {
      late String content;

      setUp(() => content = writer.files['lib/counter_state.dart']!);

      test('defines shared counter state and home context', () {
        expect(content, contains('int _counter = 0;'));
        expect(content, contains('counterContext()'));
        expect(content, contains('homeContext()'));
        expect(content, contains('incrementCounter()'));
        expect(content, contains('decrementCounter()'));
        expect(content, contains('resetCounter()'));
      });
    });

    group('counter mutation routes', () {
      test('increment route posts and renders counter fragment', () {
        final content = writer.files['routes/counter/increment.dart']!;
        expect(content, contains('package:my_app/counter_state.dart'));
        expect(content, contains('HttpMethod.post'));
        expect(content, contains('incrementCounter();'));
        expect(content, contains("'counter'"));
      });

      test('decrement route posts and renders counter fragment', () {
        final content = writer.files['routes/counter/decrement.dart']!;
        expect(content, contains('package:my_app/counter_state.dart'));
        expect(content, contains('HttpMethod.post'));
        expect(content, contains('decrementCounter();'));
        expect(content, contains("'counter'"));
      });

      test('reset route posts and renders counter fragment', () {
        final content = writer.files['routes/counter/reset.dart']!;
        expect(content, contains('package:my_app/counter_state.dart'));
        expect(content, contains('HttpMethod.post'));
        expect(content, contains('resetCounter();'));
        expect(content, contains("'counter'"));
      });
    });

    group('templates/layouts/base.html', () {
      late String content;

      setUp(() => content = writer.files['templates/layouts/base.html']!);

      test('provides SPA shell, HTMX, and CSRF meta tag', () {
        expect(content, contains('<!DOCTYPE html>'));
        expect(content, contains('id="content"'));
        expect(content, contains('csrf-token'));
        expect(content, contains('htmx:configRequest'));
        expect(content, contains('nav.html'));
        expect(content, contains('Dart Frog'));
      });
    });

    group('templates/pages/index.html', () {
      late String content;

      setUp(() => content = writer.files['templates/pages/index.html']!);

      test('uses counter and page-content fragments', () {
        expect(content, contains('tl:fragment="page-content"'));
        expect(content, contains('tl:fragment="counter"'));
        expect(content, contains('hx-post="/counter/increment"'));
        expect(content, contains('hx-post="/counter/decrement"'));
        expect(content, contains('hx-post="/counter/reset"'));
        expect(content, contains(r'tl:attr="value=${csrfToken}"'));
      });
    });

    group('templates/pages/about.html', () {
      late String content;

      setUp(() => content = writer.files['templates/pages/about.html']!);

      test('explains Dart Frog-specific patterns', () {
        expect(content, contains('Provider-Based Dependency Injection'));
        expect(content, contains('File-Based Routing'));
        expect(content, contains('Middleware Chain'));
        expect(content, contains('CSRF Protection'));
        expect(content, contains('Dev Hot Reload'));
      });
    });

    group('templates/partials/nav.html', () {
      late String content;

      setUp(() => content = writer.files['templates/partials/nav.html']!);

      test('uses HTMX SPA navigation links', () {
        expect(content, contains('tl:fragment="nav"'));
        expect(content, contains('hx-get="/about"'));
        expect(content, contains('hx-target="#content"'));
        expect(content, contains('hx-push-url="true"'));
      });
    });
  });
}
