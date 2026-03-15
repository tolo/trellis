import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:test/test.dart';
import 'package:trellis/src/dialect.dart';
import 'package:trellis/src/exceptions.dart';
import 'package:trellis/src/loaders/map_loader.dart';
import 'package:trellis/src/processor.dart';
import 'package:trellis/src/processor_api.dart';

/// Parse HTML, collect fragments on the DomProcessor, process body, return body.
Element _processBody(String html, Map<String, dynamic> context, DomProcessor dp) {
  final doc = html_parser.parse(html);
  dp.collectFragments(doc);
  final body = doc.body!;
  dp.process(body, context);
  return body;
}

DomProcessor _dp({
  List<Dialect>? dialects,
  bool includeStandard = true,
  Map<String, Function>? filters,
  List<Processor>? processors,
  bool strict = false,
}) {
  return DomProcessor(
    prefix: 'tl',
    separator: ':',
    loader: MapLoader({}),
    dialects: dialects,
    includeStandard: includeStandard,
    filters: filters,
    processors: processors,
    strict: strict,
  );
}

void main() {
  group('StandardDialect', () {
    test('name returns Standard', () {
      expect(StandardDialect().name, equals('Standard'));
    });

    test('processors returns 13 built-in processors', () {
      expect(StandardDialect().processors, hasLength(13));
    });

    test('processors contains all expected types', () {
      final attributes = StandardDialect().processors.map((p) => p.attribute).toSet();
      expect(
        attributes,
        containsAll([
          'with',
          'object',
          'if',
          'unless',
          'switch',
          'each',
          'insert',
          'replace',
          'text',
          'utext',
          'inline',
          'attr',
          'remove',
        ]),
      );
    });

    test('filters returns 4 built-in filters', () {
      final filters = StandardDialect().filters;
      expect(filters, hasLength(4));
      expect(filters.keys, containsAll(['upper', 'lower', 'trim', 'length']));
    });

    test('filters work correctly', () {
      final filters = StandardDialect().filters;
      expect((filters['upper']! as Function)('hello'), equals('HELLO'));
      expect((filters['lower']! as Function)('HELLO'), equals('hello'));
      expect((filters['trim']! as Function)('  hi  '), equals('hi'));
      expect((filters['length']! as Function)('abc'), equals(3));
    });
  });

  group('Custom Dialect', () {
    test('dialect with empty processors and filters is valid', () {
      final dialect = _EmptyDialect();
      expect(dialect.name, equals('Empty'));
      expect(dialect.processors, isEmpty);
      expect(dialect.filters, isEmpty);
    });
  });

  group('Dialect composition', () {
    test('single user dialect — processors participate in pipeline', () {
      final log = <String>[];
      final dialect = _TestDialect(
        name: 'Test',
        testProcessors: [
          _TestProcessor(
            attribute: 'greet',
            priority: ProcessorPriority.afterContent,
            handler: (el, val, ctx) {
              log.add('greet');
              el.text = 'Hello!';
              return true;
            },
          ),
        ],
      );
      final dp = _dp(dialects: [dialect]);
      final body = _processBody('<div tl:greet="x">old</div>', {}, dp);
      expect(body.innerHtml, equals('<div>Hello!</div>'));
      expect(log, equals(['greet']));
    });

    test('two user dialects — processors from both fire, ordered by dialect list position', () {
      final log = <String>[];
      final d1 = _TestDialect(
        name: 'D1',
        testProcessors: [
          _TestProcessor(
            attribute: 'mark',
            priority: ProcessorPriority.afterContent,
            handler: (el, val, ctx) {
              log.add('d1-mark');
              el.attributes['data-d1'] = 'true';
              return true;
            },
          ),
        ],
      );
      final d2 = _TestDialect(
        name: 'D2',
        testProcessors: [
          _TestProcessor(
            attribute: 'mark',
            priority: ProcessorPriority.afterContent,
            handler: (el, val, ctx) {
              log.add('d2-mark');
              el.attributes['data-d2'] = 'true';
              return true;
            },
          ),
        ],
      );
      final dp = _dp(dialects: [d1, d2]);
      final body = _processBody('<div tl:mark="x">text</div>', {}, dp);
      // Both fire; d1 before d2 (registration order)
      expect(log, equals(['d1-mark', 'd2-mark']));
      expect(body.querySelector('div')!.attributes['data-d1'], equals('true'));
      expect(body.querySelector('div')!.attributes['data-d2'], equals('true'));
    });

    test('dialect with filters only — filters available in expressions', () {
      final dialect = _TestDialect(
        name: 'FilterOnly',
        testProcessors: [],
        testFilters: {'exclaim': (dynamic v) => '$v!'},
      );
      final dp = _dp(dialects: [dialect]);
      final body = _processBody('<span tl:text="\${name | exclaim}">x</span>', {'name': 'World'}, dp);
      expect(body.querySelector('span')!.text, equals('World!'));
    });

    test('dialect filter + engine-level filter same name — engine-level wins', () {
      final dialect = _TestDialect(name: 'D1', testProcessors: [], testFilters: {'fmt': (dynamic v) => 'dialect:$v'});
      final dp = _dp(dialects: [dialect], filters: {'fmt': (dynamic v) => 'engine:$v'});
      final body = _processBody('<span tl:text="\${x | fmt}">x</span>', {'x': 'val'}, dp);
      expect(body.querySelector('span')!.text, equals('engine:val'));
    });

    test('two dialects with same filter name — later dialect wins', () {
      final d1 = _TestDialect(name: 'D1', testProcessors: [], testFilters: {'fmt': (dynamic v) => 'd1:$v'});
      final d2 = _TestDialect(name: 'D2', testProcessors: [], testFilters: {'fmt': (dynamic v) => 'd2:$v'});
      final dp = _dp(dialects: [d1, d2]);
      final body = _processBody('<span tl:text="\${x | fmt}">x</span>', {'x': 'val'}, dp);
      expect(body.querySelector('span')!.text, equals('d2:val'));
    });

    test('StandardDialect + user dialect — standard processors run first at same priority', () {
      final log = <String>[];
      final dialect = _TestDialect(
        name: 'Custom',
        testProcessors: [
          _TestProcessor(
            attribute: 'custom',
            priority: ProcessorPriority.afterInclusion,
            handler: (el, val, ctx) {
              log.add('custom:${el.text}');
              return true;
            },
          ),
        ],
      );
      final dp = _dp(dialects: [dialect]);
      final body = _processBody('<span tl:text="\${msg}" tl:custom="x">old</span>', {'msg': 'hello'}, dp);
      // tl:text (standard, afterInclusion) runs before tl:custom (afterInclusion)
      expect(log, equals(['custom:hello']));
      expect(body.querySelector('span')!.text, equals('hello'));
    });

    test('user dialect processor at afterContent — runs after tl:text but before tl:attr', () {
      final dialect = _TestDialect(
        name: 'D',
        testProcessors: [
          _TestProcessor(
            attribute: 'stamp',
            priority: ProcessorPriority.afterContent,
            handler: (el, val, ctx) {
              el.attributes['data-stamped'] = el.text;
              return true;
            },
          ),
        ],
      );
      final dp = _dp(dialects: [dialect]);
      final body = _processBody('<span tl:text="\${msg}" tl:stamp="x">old</span>', {'msg': 'done'}, dp);
      expect(body.querySelector('span')!.attributes['data-stamped'], equals('done'));
    });
  });

  group('includeStandard: false', () {
    test('tl:text NOT processed — content preserved', () {
      final dp = _dp(includeStandard: false);
      final body = _processBody('<span tl:text="\${name}">prototype</span>', {'name': 'Alice'}, dp);
      // No processors fire; content stays as-is
      expect(body.querySelector('span')!.text, equals('prototype'));
    });

    test('built-in filters NOT available — no processor to trigger them', () {
      final dp = _dp(includeStandard: false);
      final body = _processBody('<span tl:text="\${name | upper}">x</span>', {'name': 'hi'}, dp);
      // No text processor fires, so template left as-is
      expect(body.querySelector('span')!.text, equals('x'));
    });

    test('includeStandard: false + user dialect — only user dialect active', () {
      final dialect = _TestDialect(
        name: 'Custom',
        testProcessors: [
          _TestProcessor(
            attribute: 'greet',
            priority: ProcessorPriority.afterContent,
            handler: (el, val, ctx) {
              el.text = 'Custom!';
              return true;
            },
          ),
        ],
      );
      final dp = _dp(includeStandard: false, dialects: [dialect]);
      final body = _processBody('<div tl:greet="x" tl:text="\${name}">old</div>', {'name': 'Alice'}, dp);
      // tl:greet fires (user dialect), tl:text does NOT (no standard)
      expect(body.querySelector('div')!.text, equals('Custom!'));
    });

    test('includeStandard: false + no dialects + no processors — template as-is', () {
      final dp = _dp(includeStandard: false);
      final body = _processBody('<div tl:text="\${x}">proto</div>', {'x': 'val'}, dp);
      expect(body.querySelector('div')!.text, equals('proto'));
      // tl:text attribute cleaned up by infrastructure
      expect(body.querySelector('div')!.attributes.containsKey('tl:text'), isFalse);
    });

    test('includeStandard: false + engine-level filters — engine filters work', () {
      final dialect = _TestDialect(
        name: 'WithShow',
        testProcessors: [
          _TestProcessor(
            attribute: 'show',
            priority: ProcessorPriority.afterContent,
            handler: (el, val, ctx) {
              final result = ctx.evaluate(val, ctx.variables);
              el.text = result?.toString() ?? '';
              return true;
            },
          ),
        ],
      );
      final dp = _dp(includeStandard: false, dialects: [dialect], filters: {'exclaim': (dynamic v) => '$v!'});
      final body = _processBody('<span tl:show="\${name | exclaim}">x</span>', {'name': 'hi'}, dp);
      expect(body.querySelector('span')!.text, equals('hi!'));
    });
  });

  group('Attribute conflict across dialects', () {
    test('user dialect processor with same attribute as standard — both fire, standard first', () {
      final log = <String>[];
      final dialect = _TestDialect(
        name: 'Override',
        testProcessors: [
          _TestProcessor(
            attribute: 'text',
            priority: ProcessorPriority.afterInclusion,
            handler: (el, val, ctx) {
              log.add('custom-text:${el.text}');
              return true;
            },
          ),
        ],
      );
      final dp = _dp(dialects: [dialect]);
      _processBody('<span tl:text="\${msg}">old</span>', {'msg': 'hello'}, dp);
      // Standard TextProcessor fires first (sets text to 'hello'),
      // then custom 'text' processor fires (sees 'hello')
      expect(log, equals(['custom-text:hello']));
    });

    test('two user dialect processors same attribute same priority — ordered by dialect list position', () {
      final log = <String>[];
      final d1 = _TestDialect(
        name: 'D1',
        testProcessors: [
          _TestProcessor(
            attribute: 'tag',
            priority: ProcessorPriority.lowest,
            handler: (el, val, ctx) {
              log.add('d1');
              return true;
            },
          ),
        ],
      );
      final d2 = _TestDialect(
        name: 'D2',
        testProcessors: [
          _TestProcessor(
            attribute: 'tag',
            priority: ProcessorPriority.lowest,
            handler: (el, val, ctx) {
              log.add('d2');
              return true;
            },
          ),
        ],
      );
      final dp = _dp(dialects: [d1, d2]);
      _processBody('<div tl:tag="x">text</div>', {}, dp);
      expect(log, equals(['d1', 'd2']));
    });
  });

  group('Error wrapping for dialect processors', () {
    test('user dialect processor that throws — wrapped in TemplateException', () {
      final dialect = _TestDialect(
        name: 'Bad',
        testProcessors: [
          _TestProcessor(
            attribute: 'boom',
            priority: ProcessorPriority.afterContent,
            handler: (el, val, ctx) => throw StateError('oops'),
          ),
        ],
      );
      final dp = _dp(dialects: [dialect]);
      final doc = html_parser.parse('<div tl:boom="x">text</div>');
      dp.collectFragments(doc);
      expect(
        () => dp.process(doc.body!, {}),
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('boom'))),
      );
    });

    test('StandardDialect processor error — NOT wrapped', () {
      final dp = _dp(strict: true);
      final doc = html_parser.parse('<span tl:text="\${missing}">x</span>');
      dp.collectFragments(doc);
      // Strict mode: undefined variable throws ExpressionException directly
      expect(() => dp.process(doc.body!, {}), throwsA(isA<ExpressionException>()));
    });
  });
}

// --- Test helpers ---

class _EmptyDialect extends Dialect {
  @override
  String get name => 'Empty';
  @override
  List<Processor> get processors => const [];
}

class _TestDialect extends Dialect {
  @override
  final String name;
  final List<Processor> testProcessors;
  final Map<String, Function> testFilters;

  _TestDialect({required this.name, required this.testProcessors, this.testFilters = const {}});

  @override
  List<Processor> get processors => testProcessors;
  @override
  Map<String, Function> get filters => testFilters;
}

class _TestProcessor extends Processor {
  @override
  final String attribute;
  @override
  final ProcessorPriority priority;
  final bool Function(Element, String, ProcessorContext) handler;

  _TestProcessor({required this.attribute, this.priority = ProcessorPriority.afterContent, required this.handler});

  @override
  final bool autoProcessChildren = true;

  @override
  bool process(Element element, String value, ProcessorContext context) => handler(element, value, context);
}
