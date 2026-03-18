import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  group('RelicProjectGenerator', () {
    late InMemoryFileWriter writer;
    late RelicProjectGenerator generator;

    setUp(() async {
      writer = InMemoryFileWriter();
      generator = RelicProjectGenerator(projectName: 'my_app', writer: writer);
      await generator.generate();
    });

    test('generates all expected files', () {
      final expectedFiles = [
        'pubspec.yaml',
        '.gitignore',
        'analysis_options.yaml',
        'bin/server.dart',
        'lib/handlers.dart',
        'templates/base.html',
        'templates/index.html',
        'templates/about.html',
        'static/styles.css',
      ];

      for (final path in expectedFiles) {
        expect(writer.files.containsKey(path), isTrue, reason: '$path should be generated');
      }
    });

    test('generates exactly 9 files', () {
      expect(writer.files.length, 9);
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

      test('depends on relic', () {
        expect(content, contains('relic:'));
      });

      test('depends on trellis', () {
        expect(content, contains('trellis:'));
      });

      test('depends on trellis_relic', () {
        expect(content, contains('trellis_relic:'));
      });

      test('does not depend on shelf or dart_frog', () {
        expect(content, isNot(contains('trellis_shelf:')));
        expect(content, isNot(contains('dart_frog:')));
      });
    });

    group('bin/server.dart', () {
      late String content;
      setUp(() => content = writer.files['bin/server.dart']!);

      test('imports relic', () {
        expect(content, contains("import 'package:relic/relic.dart'"));
      });

      test('imports trellis', () {
        expect(content, contains("import 'package:trellis/trellis.dart'"));
      });

      test('imports trellis_relic', () {
        expect(content, contains("import 'package:trellis_relic/trellis_relic.dart'"));
      });

      test('imports handlers from project package', () {
        expect(content, contains("import 'package:my_app/handlers.dart'"));
      });

      test('creates Trellis engine', () {
        expect(content, contains('Trellis('));
        expect(content, contains('FileSystemLoader'));
      });

      test('creates RelicApp', () {
        expect(content, contains('RelicApp()'));
      });

      test('uses trellisSecurityHeaders', () {
        expect(content, contains('trellisSecurityHeaders'));
      });

      test('configures CSP for HTMX CDN script', () {
        expect(content, contains('CspBuilder'));
        expect(content, contains('https://cdn.jsdelivr.net'));
        expect(content, contains('trellisSecurityHeaders(csp: csp)'));
      });

      test('registers page routes', () {
        expect(content, contains("..get('/'"));
        expect(content, contains("..get('/about'"));
      });

      test('registers counter endpoints', () {
        expect(content, contains("..post('/counter/increment'"));
        expect(content, contains("..post('/counter/decrement'"));
        expect(content, contains("..post('/counter/reset'"));
      });

      test('serves static CSS', () {
        expect(content, contains("..get('/styles.css'"));
      });

      test('serves on port 8080', () {
        expect(content, contains('port: 8080'));
      });

      test('contains project name in startup message', () {
        expect(content, contains('my_app running at'));
      });
    });

    group('lib/handlers.dart', () {
      late String content;
      setUp(() => content = writer.files['lib/handlers.dart']!);

      test('imports trellis_relic', () {
        expect(content, contains("import 'package:trellis_relic/trellis_relic.dart'"));
      });

      test('uses explicit engine parameter pattern', () {
        expect(content, contains('Request request, Trellis engine'));
      });

      test('uses isHtmxRequest for detection', () {
        expect(content, contains('isHtmxRequest'));
      });

      test('uses renderPage for full pages', () {
        expect(content, contains('renderPage'));
      });

      test('uses renderFragment for HTMX', () {
        expect(content, contains('renderFragment'));
      });

      test('has counter state', () {
        expect(content, contains('_counter'));
      });

      test('has all five handler functions', () {
        expect(content, contains('homePage'));
        expect(content, contains('aboutPage'));
        expect(content, contains('incrementCounter'));
        expect(content, contains('decrementCounter'));
        expect(content, contains('resetCounter'));
      });
    });

    group('templates/base.html', () {
      late String content;
      setUp(() => content = writer.files['templates/base.html']!);

      test('is valid HTML with DOCTYPE', () {
        expect(content, contains('<!DOCTYPE html>'));
      });

      test('uses tl:define for content block', () {
        expect(content, contains('tl:define="content"'));
      });

      test('has HTMX CDN script', () {
        expect(content, contains('htmx.org'));
      });

      test('has HTMX navigation links', () {
        expect(content, contains('hx-get'));
        expect(content, contains('hx-target="#content"'));
        expect(content, contains('hx-push-url="true"'));
      });

      test('does not have CSRF meta tag', () {
        // Relic has no CSRF — no form body parser
        expect(content, isNot(contains('csrf-token')));
      });

      test('contains project name', () {
        expect(content, contains('my_app'));
      });

      test('links to Relic', () {
        expect(content, contains('Relic'));
      });
    });

    group('templates/index.html', () {
      late String content;
      setUp(() => content = writer.files['templates/index.html']!);

      test('uses tl:extends', () {
        expect(content, contains('tl:extends="base.html"'));
      });

      test('uses tl:define for content', () {
        expect(content, contains('tl:define="content"'));
      });

      test('has page-content fragment', () {
        expect(content, contains('tl:fragment="page-content"'));
      });

      test('has counter fragment', () {
        expect(content, contains('tl:fragment="counter"'));
      });

      test('has HTMX counter buttons', () {
        expect(content, contains('hx-post="/counter/increment"'));
        expect(content, contains('hx-post="/counter/decrement"'));
        expect(content, contains('hx-post="/counter/reset"'));
      });

      test('uses tl:text for counter display', () {
        expect(content, contains(r'tl:text="${count}"'));
      });

      test('uses tl:classappend for disabled state', () {
        expect(content, contains('tl:classappend'));
        expect(content, contains('isZero'));
      });
    });

    group('templates/about.html', () {
      late String content;
      setUp(() => content = writer.files['templates/about.html']!);

      test('uses tl:extends', () {
        expect(content, contains('tl:extends="base.html"'));
      });

      test('has page-content fragment', () {
        expect(content, contains('tl:fragment="page-content"'));
      });

      test('explains Relic no-DI pattern', () {
        expect(content, contains('No-DI'));
      });

      test('explains middleware scoping', () {
        expect(content, contains('Middleware Scoping'));
      });
    });

    group('project name variation', () {
      test('different project name reflected in files', () async {
        final w2 = InMemoryFileWriter();
        final g2 = RelicProjectGenerator(projectName: 'counter_app', writer: w2);
        await g2.generate();

        expect(w2.files['pubspec.yaml'], contains('name: counter_app'));
        expect(w2.files['bin/server.dart'], contains('counter_app'));
        expect(w2.files['templates/base.html'], contains('counter_app'));
      });
    });
  });
}
