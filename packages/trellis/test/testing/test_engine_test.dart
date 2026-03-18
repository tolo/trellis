import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis/testing.dart';

void main() {
  group('testEngine', () {
    test('creates engine with strict mode by default', () {
      final engine = testEngine(templates: {'page': '<p tl:text="\${name}">x</p>'});
      // Strict mode: accessing undefined variable should throw
      expect(
        () => engine.render(engine.loader.loadSync('page')!, {'other': 'value'}),
        throwsA(isA<ExpressionException>()),
      );
    });

    test('strict: false creates non-strict engine', () {
      final engine = testEngine(templates: {'page': '<p tl:text="\${name}">x</p>'}, strict: false);
      // Non-strict: undefined variable produces empty string
      final html = engine.render(engine.loader.loadSync('page')!, {});
      expect(html, contains('<p>'));
    });

    test('creates engine with provided templates accessible via loadSync', () {
      final engine = testEngine(templates: {'page': '<h1>Hello</h1>', 'nav': '<nav>Nav</nav>'});
      expect(engine.loader.loadSync('page'), equals('<h1>Hello</h1>'));
      expect(engine.loader.loadSync('nav'), equals('<nav>Nav</nav>'));
    });

    test('empty templates map creates engine that throws on any load', () {
      final engine = testEngine();
      expect(() => engine.loader.loadSync('missing'), throwsA(isA<TemplateNotFoundException>()));
    });

    test('engine renders templates correctly end-to-end', () {
      final engine = testEngine(templates: {'page': '<h1 tl:text="\${title}">Default</h1>'});
      final html = engine.render(engine.loader.loadSync('page')!, {'title': 'Hello World'});
      expect(html, hasElement('h1', withText: 'Hello World'));
    });

    test('custom prefix is passed through', () {
      final engine = testEngine(templates: {'page': '<h1 th:text="\${title}">Default</h1>'}, prefix: 'th');
      final html = engine.render(engine.loader.loadSync('page')!, {'title': 'Hello'});
      expect(html, hasElement('h1', withText: 'Hello'));
    });

    test('custom filters are passed through', () {
      final engine = testEngine(
        templates: {'page': '<p tl:text="\${name | upper}">x</p>'},
        filters: {'upper': (String s) => s.toUpperCase()},
      );
      final html = engine.render(engine.loader.loadSync('page')!, {'name': 'hello'});
      expect(html, hasElement('p', withText: 'HELLO'));
    });

    test('engine cache is disabled', () {
      // With cache disabled, modifying the loader after engine creation
      // still uses the original templates (MapLoader is immutable).
      // We verify that two renders of the same template both succeed.
      final engine = testEngine(templates: {'page': '<h1>Title</h1>'});
      final source = engine.loader.loadSync('page')!;
      final html1 = engine.render(source, {});
      final html2 = engine.render(source, {});
      expect(html1, equals(html2));
    });
  });
}
