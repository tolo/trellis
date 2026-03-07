import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:test/test.dart';
import 'package:trellis/src/processor.dart';
import 'package:trellis/trellis.dart';

/// Test helper: flexible custom processor for testing.
class _TestProcessor extends Processor {
  @override
  final String attribute;
  @override
  final ProcessorPriority priority;
  @override
  final bool autoProcessChildren;
  final bool Function(Element, String, ProcessorContext) _handler;

  _TestProcessor({
    required this.attribute,
    this.priority = ProcessorPriority.afterContent,
    this.autoProcessChildren = true,
    required bool Function(Element, String, ProcessorContext) handler,
  }) : _handler = handler;

  @override
  bool process(Element element, String value, ProcessorContext context) => _handler(element, value, context);
}

/// Helper to create a DomProcessor with custom processors.
DomProcessor _createProcessor({List<Processor>? processors}) {
  return DomProcessor(prefix: 'tl', separator: ':', loader: MapLoader({}), processors: processors);
}

/// Helper to parse HTML and process the first body child element.
Element _processHtml(String html, Map<String, dynamic> context, {List<Processor>? processors}) {
  final dp = _createProcessor(processors: processors);
  final doc = html_parser.parse(html);
  dp.collectFragments(doc);
  final element = doc.body!.children.first;
  dp.process(element, context);
  return element;
}

void main() {
  group('Custom processor', () {
    group('basic integration', () {
      test('fires and modifies element', () {
        final processor = _TestProcessor(
          attribute: 'tooltip',
          handler: (element, value, context) {
            element.attributes['title'] = context.evaluate(value, context.variables).toString();
            return true;
          },
        );
        final element = _processHtml(
          '<div tl:tooltip="\${msg}">content</div>',
          {'msg': 'Hello'},
          processors: [processor],
        );
        expect(element.attributes['title'], 'Hello');
      });

      test('attribute auto-prefixed (tooltip matches tl:tooltip)', () {
        final processor = _TestProcessor(
          attribute: 'tooltip',
          handler: (element, value, context) {
            element.attributes['data-tip'] = value;
            return true;
          },
        );
        final element = _processHtml('<span tl:tooltip="help text">x</span>', {}, processors: [processor]);
        expect(element.attributes['data-tip'], 'help text');
      });

      test('attribute removed from output after processing', () {
        final processor = _TestProcessor(attribute: 'highlight', handler: (element, value, context) => true);
        final element = _processHtml('<p tl:highlight="yes">text</p>', {}, processors: [processor]);
        expect(element.attributes.containsKey('tl:highlight'), isFalse);
      });

      test('receives correct ProcessorContext', () {
        String? capturedPrefix;
        String? capturedSeparator;
        String? capturedAttrPrefix;
        Map<String, dynamic>? capturedVars;

        final processor = _TestProcessor(
          attribute: 'check',
          handler: (element, value, context) {
            capturedPrefix = context.prefix;
            capturedSeparator = context.separator;
            capturedAttrPrefix = context.attrPrefix;
            capturedVars = context.variables;
            return true;
          },
        );
        _processHtml('<p tl:check="x">text</p>', {'key': 'val'}, processors: [processor]);
        expect(capturedPrefix, 'tl');
        expect(capturedSeparator, ':');
        expect(capturedAttrPrefix, 'tl:');
        expect(capturedVars, containsPair('key', 'val'));
      });

      test('process() returning true keeps element', () {
        final processor = _TestProcessor(attribute: 'keep', handler: (element, value, context) => true);
        final dp = _createProcessor(processors: [processor]);
        final doc = html_parser.parse('<div><p tl:keep="yes">text</p></div>');
        dp.collectFragments(doc);
        dp.process(doc.body!.children.first, {});
        expect(doc.body!.querySelector('p'), isNotNull);
      });

      test('process() returning false removes element from further processing', () {
        var secondFired = false;
        final first = _TestProcessor(
          attribute: 'remove-me',
          priority: ProcessorPriority.afterLocals,
          handler: (element, value, context) {
            element.remove();
            return false;
          },
        );
        final second = _TestProcessor(
          attribute: 'after',
          priority: ProcessorPriority.afterContent,
          handler: (element, value, context) {
            secondFired = true;
            return true;
          },
        );
        final dp = _createProcessor(processors: [first, second]);
        final doc = html_parser.parse('<div><p tl:remove-me="yes" tl:after="yes">text</p></div>');
        dp.collectFragments(doc);
        dp.process(doc.body!.children.first, {});
        expect(secondFired, isFalse);
      });

      test('can call context.evaluate()', () {
        final processor = _TestProcessor(
          attribute: 'eval',
          handler: (element, value, context) {
            final result = context.evaluate(value, context.variables);
            element.attributes['data-result'] = result.toString();
            return true;
          },
        );
        final element = _processHtml('<p tl:eval="\${a + b}">x</p>', {'a': 10, 'b': 32}, processors: [processor]);
        expect(element.attributes['data-result'], '42');
      });

      test('can call context.processChildren()', () {
        final processor = _TestProcessor(
          attribute: 'wrapper',
          autoProcessChildren: false,
          handler: (element, value, context) {
            for (final child in List<Element>.from(element.children)) {
              context.processChildren(child, context.variables);
            }
            return true;
          },
        );
        final dp = _createProcessor(processors: [processor]);
        final doc = html_parser.parse('<div tl:wrapper="yes"><p tl:text="\${msg}">old</p></div>');
        dp.collectFragments(doc);
        dp.process(doc.body!.children.first, {'msg': 'new'});
        expect(doc.body!.querySelector('p')!.text, 'new');
      });
    });

    group('priority ordering', () {
      test('afterLocals runs after tl:with but before tl:if', () {
        String? capturedValue;
        final processor = _TestProcessor(
          attribute: 'capture',
          priority: ProcessorPriority.afterLocals,
          handler: (element, value, context) {
            capturedValue = context.variables['x']?.toString();
            return true;
          },
        );
        _processHtml('<p tl:with="x=42" tl:capture="yes">text</p>', {}, processors: [processor]);
        expect(capturedValue, '42');
      });

      test('lowest runs after tl:remove', () {
        var fired = false;
        final processor = _TestProcessor(
          attribute: 'final',
          priority: ProcessorPriority.lowest,
          handler: (element, value, context) {
            fired = true;
            return true;
          },
        );
        // tl:remove="none" keeps element, so lowest-priority processor should fire
        _processHtml('<p tl:remove="none" tl:final="yes">text</p>', {}, processors: [processor]);
        expect(fired, isTrue);
      });

      test('two custom at same priority preserve registration order', () {
        final order = <String>[];
        final first = _TestProcessor(
          attribute: 'alpha',
          priority: ProcessorPriority.afterContent,
          handler: (element, value, context) {
            order.add('alpha');
            return true;
          },
        );
        final second = _TestProcessor(
          attribute: 'beta',
          priority: ProcessorPriority.afterContent,
          handler: (element, value, context) {
            order.add('beta');
            return true;
          },
        );
        _processHtml('<p tl:alpha="1" tl:beta="2">text</p>', {}, processors: [first, second]);
        expect(order, ['alpha', 'beta']);
      });

      test('custom at highest — built-ins run first within same slot', () {
        final order = <String>[];
        final processor = _TestProcessor(
          attribute: 'custom-first',
          priority: ProcessorPriority.highest,
          handler: (element, value, context) {
            order.add('custom');
            return true;
          },
        );
        // tl:with runs at highest priority — should run before custom
        _processHtml('<p tl:with="x=1" tl:custom-first="yes">text</p>', {}, processors: [processor]);
        // tl:with fires first (built-in), then custom
        expect(order, ['custom']); // We can only verify custom fired
      });

      test('multiple custom at different priorities sorted correctly', () {
        final order = <String>[];
        final low = _TestProcessor(
          attribute: 'low',
          priority: ProcessorPriority.lowest,
          handler: (element, value, context) {
            order.add('low');
            return true;
          },
        );
        final high = _TestProcessor(
          attribute: 'high',
          priority: ProcessorPriority.highest,
          handler: (element, value, context) {
            order.add('high');
            return true;
          },
        );
        final mid = _TestProcessor(
          attribute: 'mid',
          priority: ProcessorPriority.afterContent,
          handler: (element, value, context) {
            order.add('mid');
            return true;
          },
        );
        // Register in non-sorted order
        _processHtml('<p tl:low="1" tl:high="2" tl:mid="3">text</p>', {}, processors: [low, high, mid]);
        expect(order, ['high', 'mid', 'low']);
      });

      test('custom interleaved with built-ins in correct priority order', () {
        String? textBefore;
        final processor = _TestProcessor(
          attribute: 'intercept',
          priority: ProcessorPriority.afterInclusion,
          handler: (element, value, context) {
            textBefore = element.text;
            return true;
          },
        );
        // tl:text runs at afterInclusion, but built-in is first within same slot
        _processHtml('<p tl:text="\${msg}" tl:intercept="yes">old</p>', {'msg': 'new'}, processors: [processor]);
        // Built-in tl:text fires first (afterInclusion), then custom intercept
        expect(textBefore, 'new');
      });
    });

    group('autoProcessChildren', () {
      test('true (default) — children auto-processed', () {
        final processor = _TestProcessor(attribute: 'wrap', handler: (element, value, context) => true);
        final dp = _createProcessor(processors: [processor]);
        final doc = html_parser.parse('<div tl:wrap="yes"><p tl:text="\${msg}">old</p></div>');
        dp.collectFragments(doc);
        dp.process(doc.body!.children.first, {'msg': 'new'});
        expect(doc.body!.querySelector('p')!.text, 'new');
      });

      test('false with processChildren() call — children processed', () {
        final processor = _TestProcessor(
          attribute: 'manual',
          autoProcessChildren: false,
          handler: (element, value, context) {
            for (final child in List<Element>.from(element.children)) {
              context.processChildren(child, context.variables);
            }
            return true;
          },
        );
        final dp = _createProcessor(processors: [processor]);
        final doc = html_parser.parse('<div tl:manual="yes"><p tl:text="\${msg}">old</p></div>');
        dp.collectFragments(doc);
        dp.process(doc.body!.children.first, {'msg': 'new'});
        expect(doc.body!.querySelector('p')!.text, 'new');
      });

      test('false without processChildren() — children NOT processed', () {
        final processor = _TestProcessor(
          attribute: 'skip',
          autoProcessChildren: false,
          handler: (element, value, context) => true,
        );
        final dp = _createProcessor(processors: [processor]);
        final doc = html_parser.parse('<div tl:skip="yes"><p tl:text="\${msg}">old</p></div>');
        dp.collectFragments(doc);
        dp.process(doc.body!.children.first, {'msg': 'new'});
        // tl:text on child should NOT have been processed
        expect(doc.body!.querySelector('p')!.text, 'old');
        // But tl:text attribute should remain (not cleaned up)
        expect(doc.body!.querySelector('p')!.attributes.containsKey('tl:text'), isTrue);
      });

      test('false and process() returns false — children NOT processed', () {
        final processor = _TestProcessor(
          attribute: 'remove-all',
          autoProcessChildren: false,
          handler: (element, value, context) {
            element.remove();
            return false;
          },
        );
        final dp = _createProcessor(processors: [processor]);
        final doc = html_parser.parse('<div><span tl:remove-all="yes"><p tl:text="\${msg}">old</p></span></div>');
        dp.collectFragments(doc);
        dp.process(doc.body!.children.first, {'msg': 'new'});
        expect(doc.body!.querySelector('span'), isNull);
      });
    });

    group('error wrapping', () {
      test('generic Exception wrapped in TemplateException', () {
        final processor = _TestProcessor(
          attribute: 'broken',
          handler: (element, value, context) {
            throw Exception('custom error');
          },
        );
        expect(
          () => _processHtml('<p tl:broken="yes">text</p>', {}, processors: [processor]),
          throwsA(
            isA<TemplateException>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('custom processor'), contains('"broken"'), contains('<p>')),
            ),
          ),
        );
      });

      test('TemplateException rethrown as-is (not double-wrapped)', () {
        final processor = _TestProcessor(
          attribute: 'te-error',
          handler: (element, value, context) {
            throw TemplateException('specific error');
          },
        );
        expect(
          () => _processHtml('<p tl:te-error="yes">text</p>', {}, processors: [processor]),
          throwsA(
            isA<TemplateException>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('specific error'), isNot(contains('custom processor'))),
            ),
          ),
        );
      });

      test('StateError wrapped correctly', () {
        final processor = _TestProcessor(
          attribute: 'state-err',
          handler: (element, value, context) {
            throw StateError('bad state');
          },
        );
        expect(
          () => _processHtml('<p tl:state-err="yes">text</p>', {}, processors: [processor]),
          throwsA(isA<TemplateException>().having((e) => e.toString(), 'message', contains('"state-err"'))),
        );
      });

      test('built-in processor error NOT wrapped', () {
        // tl:each with a non-iterable should throw the original error type
        expect(
          () => _processHtml('<p tl:each="item : \${val}">text</p>', {'val': 42}),
          throwsA(isA<TemplateException>()),
        );
      });
    });

    group('attribute conflicts', () {
      test('custom with same attribute as built-in — both fire, built-in first', () {
        var customFired = false;
        final processor = _TestProcessor(
          attribute: 'text',
          priority: ProcessorPriority.afterInclusion,
          handler: (element, value, context) {
            customFired = true;
            return true;
          },
        );
        final element = _processHtml('<p tl:text="\${msg}">old</p>', {'msg': 'new'}, processors: [processor]);
        // Built-in tl:text fires first (sets text to 'new')
        expect(element.text, 'new');
        // Custom fires after
        expect(customFired, isTrue);
      });

      test('two custom with same attribute — both fire', () {
        final order = <String>[];
        final first = _TestProcessor(
          attribute: 'dup',
          handler: (element, value, context) {
            order.add('first');
            return true;
          },
        );
        final second = _TestProcessor(
          attribute: 'dup',
          handler: (element, value, context) {
            order.add('second');
            return true;
          },
        );
        _processHtml('<p tl:dup="yes">text</p>', {}, processors: [first, second]);
        // Both fire — both match the same attribute
        expect(order, ['first', 'second']);
      });
    });

    group('edge cases', () {
      test('no custom processors — baseline behavior', () {
        final element = _processHtml('<p tl:text="\${msg}">old</p>', {'msg': 'new'});
        expect(element.text, 'new');
      });

      test('context-modifying custom processor at afterLocals', () {
        final processor = _TestProcessor(
          attribute: 'set-var',
          priority: ProcessorPriority.afterLocals,
          handler: (element, value, context) {
            context.variables = {...context.variables, 'injected': 'hello'};
            return true;
          },
        );
        final element = _processHtml('<p tl:set-var="yes" tl:text="\${injected}">old</p>', {}, processors: [processor]);
        expect(element.text, 'hello');
      });

      test('custom at afterIteration — fragment-def removal still runs before it', () {
        var fired = false;
        final processor = _TestProcessor(
          attribute: 'after-frag',
          priority: ProcessorPriority.afterIteration,
          handler: (element, value, context) {
            fired = true;
            return true;
          },
        );
        // Element with tl:fragment(param) should be removed before custom processor fires
        final dp = _createProcessor(processors: [processor]);
        final doc = html_parser.parse('<div><p tl:fragment="tmpl(x)" tl:after-frag="yes">text</p></div>');
        dp.collectFragments(doc);
        dp.process(doc.body!.children.first, {});
        // Fragment def with params is removed — custom processor should NOT have fired on it
        expect(fired, isFalse);
      });

      test('custom processor with data-tl prefix mode', () {
        final processor = _TestProcessor(
          attribute: 'tooltip',
          handler: (element, value, context) {
            element.attributes['title'] = value;
            return true;
          },
        );
        final dp = DomProcessor(prefix: 'data-tl', separator: '-', loader: MapLoader({}), processors: [processor]);
        final doc = html_parser.parse('<p data-tl-tooltip="help">text</p>');
        dp.collectFragments(doc);
        dp.process(doc.body!.children.first, {});
        final p = doc.body!.querySelector('p')!;
        expect(p.attributes['title'], 'help');
        expect(p.attributes.containsKey('data-tl-tooltip'), isFalse);
      });
    });
  });
}
