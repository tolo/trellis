import 'package:trellis/trellis.dart';
import 'package:test/test.dart';

void main() {
  group('Trellis engine', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    test('renders plain HTML unchanged', () {
      final result = engine.render('<p>Hello</p>', {});
      expect(result, contains('<p>Hello</p>'));
    });

    test('render with tl:text end-to-end', () {
      final result = engine.render(r'<h1 tl:text="${title}">Default</h1>', {'title': 'Welcome'});
      expect(result, contains('<h1>Welcome</h1>'));
      expect(result, isNot(contains('tl:text')));
    });

    test('render with tl:utext end-to-end', () {
      final result = engine.render(r'<div tl:utext="${content}">placeholder</div>', {
        'content': '<strong>Hello</strong>',
      });
      expect(result, contains('<div><strong>Hello</strong></div>'));
      expect(result, isNot(contains('tl:utext')));
    });

    test('renderFragment with tl:text', () {
      final result = engine.renderFragment(
        r'<div><p tl:fragment="greeting" tl:text="${msg}">hi</p></div>',
        fragment: 'greeting',
        context: {'msg': 'Hello!'},
      );
      expect(result, contains('<p>Hello!</p>'));
      expect(result, isNot(contains('tl:text')));
      expect(result, isNot(contains('tl:fragment')));
    });
  });

  group('renderFile', () {
    test('loads and renders from MapLoader', () async {
      final engine = Trellis(loader: MapLoader({'home': r'<h1 tl:text="${title}">x</h1>'}), cache: false);
      final result = await engine.renderFile('home', {'title': 'Home'});
      expect(result, contains('<h1>Home</h1>'));
    });

    test('missing template throws TemplateNotFoundException', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);
      expect(() => engine.renderFile('missing', {}), throwsA(isA<TemplateNotFoundException>()));
    });
  });

  group('renderFileFragment', () {
    test('loads file and extracts fragment', () async {
      final engine = Trellis(
        loader: MapLoader({'page': r'<div><p tl:fragment="msg" tl:text="${text}">x</p></div>'}),
        cache: false,
      );
      final result = await engine.renderFileFragment('page', fragment: 'msg', context: {'text': 'Hi'});
      expect(result, contains('<p>Hi</p>'));
      expect(result, isNot(contains('tl:fragment')));
    });

    test('missing fragment throws FragmentNotFoundException', () async {
      final engine = Trellis(loader: MapLoader({'page': '<div><p>no fragment</p></div>'}), cache: false);
      expect(
        () => engine.renderFileFragment('page', fragment: 'nope', context: {}),
        throwsA(isA<FragmentNotFoundException>()),
      );
    });
  });

  group('fragment not found', () {
    test('throws FragmentNotFoundException (not ArgumentError)', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);
      expect(
        () => engine.renderFragment('<div></div>', fragment: 'missing', context: {}),
        throwsA(isA<FragmentNotFoundException>()),
      );
      expect(
        () => engine.renderFragment('<div></div>', fragment: 'missing', context: {}),
        isNot(throwsA(isA<ArgumentError>())),
      );
    });
  });

  group('caching', () {
    test('cache on: renders correctly on repeated calls', () {
      final engine = Trellis(loader: MapLoader({}), cache: true);
      final template = r'<p tl:text="${x}">default</p>';
      final r1 = engine.render(template, {'x': 'first'});
      final r2 = engine.render(template, {'x': 'second'});
      expect(r1, contains('<p>first</p>'));
      expect(r2, contains('<p>second</p>'));
    });

    test('cache off: renders correctly on repeated calls', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);
      final template = r'<p tl:text="${x}">default</p>';
      final r1 = engine.render(template, {'x': 'a'});
      final r2 = engine.render(template, {'x': 'b'});
      expect(r1, contains('<p>a</p>'));
      expect(r2, contains('<p>b</p>'));
    });

    test('LRU eviction: least-recently-used entry evicted when maxCacheSize exceeded', () {
      final engine = Trellis(loader: MapLoader({}), cache: true, maxCacheSize: 3);
      // Fill cache with 3 entries.
      final t1 = r'<p tl:text="${x}">1</p>';
      final t2 = r'<p tl:text="${x}">2</p>';
      final t3 = r'<p tl:text="${x}">3</p>';
      engine.render(t1, {'x': 'a'});
      engine.render(t2, {'x': 'b'});
      engine.render(t3, {'x': 'c'});
      // Re-access t1 to make it MRU; t2 becomes the least-recently-used.
      engine.render(t1, {'x': 'a2'});
      // Adding a 4th entry should evict LRU (t2), not t1.
      final t4 = r'<p tl:text="${x}">4</p>';
      engine.render(t4, {'x': 'd'});
      // t1, t3, t4 should still render correctly (cache hit).
      expect(engine.render(t1, {'x': 'first'}), contains('<p>first</p>'));
      expect(engine.render(t3, {'x': 'third'}), contains('<p>third</p>'));
      expect(engine.render(t4, {'x': 'fourth'}), contains('<p>fourth</p>'));
    });

    test('deep clone isolation: cached DOM not mutated', () {
      final engine = Trellis(loader: MapLoader({}), cache: true);
      final template = r'<p tl:text="${x}">default</p>';
      engine.render(template, {'x': 'first'});
      final r2 = engine.render(template, {'x': 'second'});
      // If deep clone is broken, the second render would see mutated DOM.
      expect(r2, contains('<p>second</p>'));
      expect(r2, isNot(contains('first')));
    });
  });

  group('custom prefix', () {
    test('processes data-tl:text instead of tl:text', () {
      final engine = Trellis(loader: MapLoader({}), cache: false, prefix: 'data-tl');
      final result = engine.render(r'<p data-tl:text="${x}">default</p>', {'x': 'custom'});
      expect(result, contains('<p>custom</p>'));
      expect(result, isNot(contains('data-tl:text')));
    });

    test('ignores tl:text with different prefix', () {
      final engine = Trellis(loader: MapLoader({}), cache: false, prefix: 'data-tl');
      final result = engine.render(r'<p tl:text="${x}">default</p>', {'x': 'ignored'});
      // tl:text should be left as-is since prefix is data-tl.
      expect(result, contains('default'));
    });
  });

  group('output cleanliness', () {
    test('all tl:* attributes stripped', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);
      final result = engine.render(r'<div tl:if="${show}" tl:text="${msg}" tl:class="${cls}">x</div>', {
        'show': true,
        'msg': 'hi',
        'cls': 'active',
      });
      expect(result, isNot(contains('tl:')));
    });

    test('pass-through: no tl:* means output unchanged', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);
      final result = engine.render('<p class="x">Hello</p>', {});
      expect(result, contains('<p class="x">Hello</p>'));
    });
  });

  group('full integration', () {
    test('tl:if + tl:each + tl:text + tl:attr combined', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);
      final template = r'''
<div>
  <ul tl:if="${showList}">
    <li tl:each="item : ${items}" tl:text="${item}" tl:attr="data-idx=${itemStat.index}">x</li>
  </ul>
</div>''';
      final result = engine.render(template, {
        'showList': true,
        'items': ['A', 'B', 'C'],
      });
      expect(result, contains('<ul>'));
      expect(result, contains('data-idx="0"'));
      expect(result, contains('>A</li>'));
      expect(result, contains('data-idx="1"'));
      expect(result, contains('>B</li>'));
      expect(result, contains('data-idx="2"'));
      expect(result, contains('>C</li>'));
      expect(result, isNot(contains('tl:')));
    });

    test('tl:if false removes entire block', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);
      final result = engine.render(r'<div><p tl:if="${show}">hidden</p><p>visible</p></div>', {'show': false});
      expect(result, isNot(contains('hidden')));
      expect(result, contains('visible'));
    });
  });

  group('filters', () {
    test('built-in filter works without registration', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);
      final result = engine.render(r'<p tl:text="${name | upper}">x</p>', {'name': 'hello'});
      expect(result, contains('<p>HELLO</p>'));
    });

    test('custom filter registered and invoked in template', () {
      final engine = Trellis(
        loader: MapLoader({}),
        cache: false,
        filters: {'shout': (v) => '$v!!!'},
      );
      final result = engine.render(r'<p tl:text="${msg | shout}">x</p>', {'msg': 'hi'});
      expect(result, contains('<p>hi!!!</p>'));
    });

    test('custom filter overrides built-in', () {
      final engine = Trellis(
        loader: MapLoader({}),
        cache: false,
        filters: {'upper': (v) => 'OVERRIDE'},
      );
      final result = engine.render(r'<p tl:text="${name | upper}">x</p>', {'name': 'hello'});
      expect(result, contains('<p>OVERRIDE</p>'));
    });

    test('unregistered filter throws ExpressionException at render time', () {
      final engine = Trellis(loader: MapLoader({}), cache: false);
      expect(
        () => engine.render(r'<p tl:text="${name | nonexistent}">x</p>', {'name': 'hello'}),
        throwsA(isA<ExpressionException>()),
      );
    });
  });
}
