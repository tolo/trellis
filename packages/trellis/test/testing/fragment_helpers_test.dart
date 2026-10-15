import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis/testing.dart';

void main() {
  group('testFragment', () {
    late Trellis engine;

    setUp(() {
      engine = testEngine(
        templates: {
          'nav':
              '<nav>'
              '<a tl:fragment="mainNav" tl:each="item : \${items}" tl:href="@{\${item.url}}" tl:text="\${item.label}">link</a>'
              '</nav>',
          'simple': '<div tl:fragment="greeting"><p tl:text="\${msg}">x</p></div>',
        },
      );
    });

    test('renders named fragment from in-memory template', () {
      final html = testFragment(engine, 'simple', 'greeting', {'msg': 'Hello'});
      expect(html, hasElement('p', withText: 'Hello'));
    });

    test('renders fragment with correct context', () {
      final html = testFragment(engine, 'simple', 'greeting', {'msg': 'World'});
      expect(html, hasElement('p', withText: 'World'));
    });

    test('throws FragmentNotFoundException for missing fragment', () {
      expect(() => testFragment(engine, 'simple', 'nonexistent', {}), throwsA(isA<FragmentNotFoundException>()));
    });

    test('throws TemplateNotFoundException for missing template', () {
      expect(() => testFragment(engine, 'missing_template', 'greeting', {}), throwsA(isA<TemplateNotFoundException>()));
    });
  });

  group('testFragmentFile', () {
    late Trellis engine;

    setUp(() {
      engine = testEngine(templates: {'partials/nav': '<nav tl:fragment="main"><a href="/home">Home</a></nav>'});
    });

    test('renders fragment from file-based template (using MapLoader)', () async {
      final html = await testFragmentFile(engine, 'partials/nav', 'main', {});
      expect(html, hasElement('a', withText: 'Home'));
    });

    test('throws TemplateNotFoundException for missing template', () async {
      await expectLater(testFragmentFile(engine, 'nonexistent', 'main', {}), throwsA(isA<TemplateNotFoundException>()));
    });

    test('throws FragmentNotFoundException for missing fragment', () async {
      await expectLater(
        testFragmentFile(engine, 'partials/nav', 'nonexistent', {}),
        throwsA(isA<FragmentNotFoundException>()),
      );
    });
  });

  group('parameterised fragments by bare name', () {
    const toast = r'<div tl:fragment="toast(type, title)" tl:classappend="${type}"><b tl:text="${title}">T</b></div>';
    const ctx = {'type': 'error', 'title': 'Saved'};
    late Trellis engine;

    setUp(() {
      engine = testEngine(templates: {'ui': toast});
    });

    test('testFragment resolves parameters from the context', () {
      expect(testFragment(engine, 'ui', 'toast', ctx), '<div class="error"><b>Saved</b></div>');
    });

    test('testFragmentFile resolves parameters from the context', () async {
      expect(await testFragmentFile(engine, 'ui', 'toast', ctx), '<div class="error"><b>Saved</b></div>');
    });

    test('a name with arguments throws TemplateException', () async {
      expect(() => testFragment(engine, 'ui', 'toast(type, title)', ctx), throwsA(isA<TemplateException>()));
      await expectLater(testFragmentFile(engine, 'ui', 'toast(type, title)', ctx), throwsA(isA<TemplateException>()));
    });
  });
}
