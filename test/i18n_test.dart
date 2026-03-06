import 'package:html/parser.dart' as html_parser;
import 'package:test/test.dart';
import 'package:trellis/src/processor.dart';
import 'package:trellis/trellis.dart';

void main() {
  final messages = MapMessageSource(messages: {
    'en': {
      'welcome': 'Welcome!',
      'greeting': 'Hello, {0}!',
      'greeting.formal': 'Good day, {0}.',
      'multi': '{0} has {1} items',
      'truthy.msg': 'yes',
    },
    'fr': {
      'welcome': 'Bienvenue!',
      'greeting': 'Bonjour, {0}!',
    },
  });

  group('ExpressionEvaluator i18n', () {
    test('#{welcome} resolves from MapMessageSource', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en');
      expect(e.evaluate('#{welcome}', {}), 'Welcome!');
    });

    test(r'#{greeting(${name})} resolves with parameter interpolation', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en');
      expect(e.evaluate(r'#{greeting(${name})}', {'name': 'Alice'}), 'Hello, Alice!');
    });

    test("#{greeting('Alice')} resolves with literal parameter", () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en');
      expect(e.evaluate("#{greeting('Alice')}", {}), 'Hello, Alice!');
    });

    test('#{greeting.formal} — flat key lookup with dot [D08]', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en');
      expect(
        e.evaluate("#{greeting.formal('Sir')}", {}),
        'Good day, Sir.',
      );
    });

    test('#{missing.key} — no MessageSource, lenient: returns key', () {
      final e = ExpressionEvaluator();
      expect(e.evaluate('#{missing.key}', {}), 'missing.key');
    });

    test('#{missing.key} — no MessageSource, strict: throws', () {
      final e = ExpressionEvaluator(strict: true);
      expect(
        () => e.evaluate('#{missing.key}', {}),
        throwsA(isA<ExpressionException>().having(
          (e) => e.toString(),
          'message',
          contains('No MessageSource configured'),
        )),
      );
    });

    test('#{missing.key} — MessageSource configured but key not found, lenient: returns key', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en');
      expect(e.evaluate('#{not.a.real.key}', {}), 'not.a.real.key');
    });

    test('#{missing.key} — MessageSource configured but key not found, strict: throws', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en', strict: true);
      expect(
        () => e.evaluate('#{not.a.real.key}', {}),
        throwsA(isA<ExpressionException>().having(
          (e) => e.toString(),
          'message',
          contains('not found'),
        )),
      );
    });

    test('locale override via _locale context key', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en');
      expect(e.evaluate('#{welcome}', {'_locale': 'fr'}), 'Bienvenue!');
    });

    test('default locale from evaluator constructor', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'fr');
      expect(e.evaluate('#{welcome}', {}), 'Bienvenue!');
    });

    test('{0}, {1} positional replacement', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en');
      expect(
        e.evaluate(r"#{multi('Alice', 3)}", {}),
        'Alice has 3 items',
      );
    });

    test('{0} with null arg -> empty string replacement', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en');
      expect(e.evaluate('#{greeting(null)}', {}), 'Hello, !');
    });

    test('#{key} in truthiness context — resolved non-empty string is truthy', () {
      final e = ExpressionEvaluator(messageSource: messages, locale: 'en');
      // Use ternary to test truthiness
      expect(e.evaluate('#{truthy.msg} ? true : false', {}), true);
    });

    test(r"string concatenation: ${'Hello ' + #{name}}", () {
      final src = MapMessageSource(messages: {
        'en': {'name': 'World'},
      });
      final e = ExpressionEvaluator(messageSource: src, locale: 'en');
      expect(e.evaluate(r"${'Hello ' + #{name}}", {}), 'Hello World');
    });

    test('no locale configured — uses first available', () {
      final e = ExpressionEvaluator(messageSource: messages);
      // No locale set, should fall back to first available ('en')
      expect(e.evaluate('#{welcome}', {}), 'Welcome!');
    });
  });

  group('DomProcessor i18n integration', () {
    DomProcessor createProcessor({
      MessageSource? messageSource,
      String? locale,
      bool strict = false,
    }) {
      return DomProcessor(
        prefix: 'tl',
        separator: ':',
        loader: MapLoader({}),
        messageSource: messageSource,
        locale: locale,
        strict: strict,
      );
    }

    test('tl:text="#{welcome}" renders resolved message', () {
      final dp = createProcessor(messageSource: messages, locale: 'en');
      final doc = html_parser.parse('<p tl:text="#{welcome}">old</p>');
      dp.collectFragments(doc);
      dp.process(doc.body!.children.first, {});
      expect(doc.body!.querySelector('p')!.text, 'Welcome!');
    });

    test('tl:attr="title=#{welcome}" resolves in attribute context', () {
      final dp = createProcessor(messageSource: messages, locale: 'en');
      final doc = html_parser.parse('<p tl:attr="title=#{welcome}">text</p>');
      dp.collectFragments(doc);
      dp.process(doc.body!.children.first, {});
      expect(doc.body!.querySelector('p')!.attributes['title'], 'Welcome!');
    });

    test('tl:if="#{truthy.msg}" — truthiness check on resolved string', () {
      final dp = createProcessor(messageSource: messages, locale: 'en');
      final doc = html_parser.parse(
        '<div><p tl:if="#{truthy.msg}">visible</p></div>',
      );
      dp.collectFragments(doc);
      dp.process(doc.body!.children.first, {});
      expect(doc.body!.querySelector('p'), isNotNull);
    });

    test('inline [[#{key}]] renders resolved message', () {
      final dp = createProcessor(messageSource: messages, locale: 'en');
      final doc = html_parser.parse(
        '<p tl:inline="text">Hello [[#{welcome}]]</p>',
      );
      dp.collectFragments(doc);
      dp.process(doc.body!.children.first, {});
      expect(doc.body!.querySelector('p')!.text, 'Hello Welcome!');
    });

    test('_locale context key overrides default locale', () {
      final dp = createProcessor(messageSource: messages, locale: 'en');
      final doc = html_parser.parse('<p tl:text="#{welcome}">old</p>');
      dp.collectFragments(doc);
      dp.process(doc.body!.children.first, {'_locale': 'fr'});
      expect(doc.body!.querySelector('p')!.text, 'Bienvenue!');
    });

    test(r'parameterized tl:text="#{greeting(${name})}"', () {
      final dp = createProcessor(messageSource: messages, locale: 'en');
      final doc = html_parser.parse(
        '<p tl:text="#{greeting(\${name})}">old</p>',
      );
      dp.collectFragments(doc);
      dp.process(doc.body!.children.first, {'name': 'Bob'});
      expect(doc.body!.querySelector('p')!.text, 'Hello, Bob!');
    });
  });
}
