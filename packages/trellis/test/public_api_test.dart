import 'package:html/dom.dart';
import 'package:test/test.dart';
import 'package:trellis/testing.dart';
import 'package:trellis/trellis.dart';

/// Custom processor for testing: uppercases element text.
class _UppercaseProcessor extends Processor {
  @override
  String get attribute => 'uppercase';
  @override
  ProcessorPriority get priority => ProcessorPriority.afterContent;
  @override
  bool process(Element element, String value, ProcessorContext context) {
    element.text = element.text.toUpperCase();
    return true;
  }
}

/// Custom dialect for testing: provides a shout processor + exclaim filter.
class _TestDialect extends Dialect {
  @override
  String get name => 'Test';
  @override
  List<Processor> get processors => [_ShoutProcessor()];
  @override
  Map<String, Function> get filters => {'exclaim': (dynamic v) => '$v!'};
}

class _ShoutProcessor extends Processor {
  @override
  String get attribute => 'shout';
  @override
  ProcessorPriority get priority => ProcessorPriority.afterContent;
  @override
  bool process(Element element, String value, ProcessorContext context) {
    element.text = element.text.toUpperCase();
    return true;
  }
}

void main() {
  group('v0.2 backward compatibility', () {
    test('minimal constructor with loader works', () {
      final engine = Trellis(loader: MapLoader({}));
      expect(engine, isNotNull);
    });

    test('v0.2 constructor with filters works', () {
      final engine = Trellis(
        loader: MapLoader({}),
        cache: false,
        strict: false,
        filters: {'upper': (dynamic v) => v?.toString().toUpperCase()},
      );
      final result = engine.render(r'<p tl:text="${name | upper}">x</p>', {'name': 'alice'});
      expect(result, contains('<p>ALICE</p>'));
    });

    test('all v0.2 parameters still accepted', () {
      final engine = Trellis(
        loader: MapLoader({}),
        cache: true,
        prefix: 'tl',
        maxCacheSize: 128,
        strict: true,
        filters: {},
      );
      expect(engine, isNotNull);
    });
  });

  group('Trellis constructor — processors', () {
    test('custom processor via Trellis constructor', () {
      final engine = Trellis(loader: MapLoader({}), cache: false, processors: [_UppercaseProcessor()]);
      final result = engine.render('<p tl:uppercase="true">hello world</p>', {});
      expect(result, contains('<p>HELLO WORLD</p>'));
    });

    test('custom processor alongside standard processors', () {
      final engine = Trellis(loader: MapLoader({}), cache: false, processors: [_UppercaseProcessor()]);
      final result = engine.render(
        '<div>'
        r'<p tl:text="${name}">x</p>'
        '<span tl:uppercase="true">quiet</span>'
        '</div>',
        {'name': 'Alice'},
      );
      expect(result, contains('<p>Alice</p>'));
      expect(result, contains('<span>QUIET</span>'));
    });
  });

  group('Trellis constructor — dialects', () {
    test('dialect with custom processor and filter', () {
      final engine = Trellis(loader: MapLoader({}), cache: false, dialects: [_TestDialect()]);
      // Test dialect processor
      final result1 = engine.render('<p tl:shout="true">hello</p>', {});
      expect(result1, contains('<p>HELLO</p>'));

      // Test dialect filter
      final result2 = engine.render(r'<p tl:text="${name | exclaim}">x</p>', {'name': 'hello'});
      expect(result2, contains('<p>hello!</p>'));
    });

    test('includeStandard: false excludes built-ins', () {
      final engine = Trellis(loader: MapLoader({}), cache: false, includeStandard: false);
      // tl:text should not be processed — left as-is (attribute cleaned up)
      final result = engine.render(r'<p tl:text="${name}">default</p>', {'name': 'Alice'});
      // Without the text processor, the element keeps its original content
      expect(result, contains('default'));
    });

    test('includeStandard: false with custom dialect only', () {
      final engine = Trellis(loader: MapLoader({}), cache: false, includeStandard: false, dialects: [_TestDialect()]);
      // Dialect processor works
      final result1 = engine.render('<p tl:shout="true">hello</p>', {});
      expect(result1, contains('<p>HELLO</p>'));

      // Standard tl:text does NOT work
      final result2 = engine.render(r'<p tl:text="${name}">default</p>', {'name': 'Alice'});
      expect(result2, contains('default'));
    });
  });

  group('Trellis constructor — i18n', () {
    test('message expression resolves from MessageSource', () {
      final engine = Trellis(
        loader: MapLoader({}),
        cache: false,
        messageSource: MapMessageSource(
          messages: {
            'en': {'greeting': 'Hello, {0}!', 'welcome': 'Welcome'},
          },
        ),
        locale: 'en',
      );
      // Simple key
      final result1 = engine.render(r'<p tl:text="#{welcome}">x</p>', {});
      expect(result1, contains('<p>Welcome</p>'));

      // Parameterized key
      final result2 = engine.render(r'<p tl:text="#{greeting(${name})}">x</p>', {'name': 'Alice'});
      expect(result2, contains('<p>Hello, Alice!</p>'));
    });

    test('locale override via context _locale', () {
      final engine = Trellis(
        loader: MapLoader({}),
        cache: false,
        messageSource: MapMessageSource(
          messages: {
            'en': {'greeting': 'Hello'},
            'fr': {'greeting': 'Bonjour'},
          },
        ),
        locale: 'en',
      );
      final result = engine.render(r'<p tl:text="#{greeting}">x</p>', {'_locale': 'fr'});
      expect(result, contains('<p>Bonjour</p>'));
    });

    test('missing key returns key in lenient mode', () {
      final engine = Trellis(
        loader: MapLoader({}),
        cache: false,
        messageSource: MapMessageSource(messages: {'en': {}}),
        locale: 'en',
      );
      final result = engine.render(r'<p tl:text="#{missing.key}">x</p>', {});
      expect(result, contains('<p>missing.key</p>'));
    });

    test('missing key throws in strict mode', () {
      final engine = Trellis(
        loader: MapLoader({}),
        cache: false,
        strict: true,
        messageSource: MapMessageSource(messages: {'en': {}}),
        locale: 'en',
      );
      expect(() => engine.render(r'<p tl:text="#{missing}">x</p>', {}), throwsA(isA<ExpressionException>()));
    });
  });

  group('full v0.3 integration', () {
    test('custom processor + dialect + filter args + i18n in one engine', () {
      final engine = Trellis(
        loader: MapLoader({}),
        cache: false,
        processors: [_UppercaseProcessor()],
        dialects: [_TestDialect()],
        filters: {'truncate': (dynamic v, List<dynamic> args) => v.toString().substring(0, args[0] as int)},
        messageSource: MapMessageSource(
          messages: {
            'en': {'title': 'Dashboard', 'greeting': 'Hello, {0}!'},
          },
        ),
        locale: 'en',
      );

      final result = engine.render(
        '<div>'
        r'<h1 tl:text="#{title}">x</h1>'
        r'<p tl:text="#{greeting(${user})}">x</p>'
        r'<span tl:text="${desc | truncate:5}">x</span>'
        '<em tl:uppercase="true">quiet</em>'
        '</div>',
        {'user': 'Alice', 'desc': 'Hello World'},
      );

      expect(result, contains('<h1>Dashboard</h1>'));
      expect(result, contains('<p>Hello, Alice!</p>'));
      expect(result, contains('<span>Hello</span>'));
      expect(result, contains('<em>QUIET</em>'));
    });
  });

  group('public API exports', () {
    test('all v0.6 types are exported', () {
      // Processor API
      expect(ProcessorPriority.values, isNotEmpty);

      // Dialect
      final dialect = StandardDialect();
      expect(dialect.name, 'Standard');
      expect(dialect.processors, isNotEmpty);
      expect(dialect.filters, isNotEmpty);

      // i18n
      final ms = MapMessageSource(
        messages: {
          'en': {'key': 'value'},
        },
      );
      expect(ms.resolve('key', locale: 'en'), 'value');

      // Loaders
      expect(() => CompositeLoader([MapLoader({})]), returnsNormally);

      // Engine with all new params
      expect(
        () => Trellis(
          loader: MapLoader({}),
          processors: [],
          dialects: [],
          includeStandard: true,
          messageSource: ms,
          locale: 'en',
        ),
        returnsNormally,
      );

      expect(TemplateValidator.new, returnsNormally);
      expect(const WarmUpResult(loaded: 0), const WarmUpResult(loaded: 0));
      expect(isValidTemplate(), isA<Matcher>());
    });
  });
}
