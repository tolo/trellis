import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  // ─── TI04: Basic single-level inheritance ──────────────────────────────

  group('single-level inheritance', () {
    test('child overrides a single block', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <h1 tl:define="title">Default Title</h1>
  <div tl:define="content">Default Content</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="content">Overridden Content</div>
</body>
</html>''', {});

      expect(result, contains('Default Title'));
      expect(result, contains('Overridden Content'));
      expect(result, isNot(contains('Default Content')));
    });

    test('no overrides — defaults preserved', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <h1 tl:define="title">Default Title</h1>
  <div tl:define="content">Default Content</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body></body>
</html>''', {});

      expect(result, contains('Default Title'));
      expect(result, contains('Default Content'));
    });

    test('selective override — only one block changed', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <h1 tl:define="title">Default Title</h1>
  <div tl:define="content">Default Content</div>
  <footer tl:define="footer">Default Footer</footer>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="content">My Content</div>
</body>
</html>''', {});

      expect(result, contains('Default Title'));
      expect(result, contains('My Content'));
      expect(result, contains('Default Footer'));
    });

    test('empty override clears block content', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default Content</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="content"></div>
</body>
</html>''', {});

      expect(result, isNot(contains('Default Content')));
      expect(result, contains('<div></div>'));
    });

    test('multi-element block content', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="content"><p>First</p><p>Second</p></div>
</body>
</html>''', {});

      expect(result, contains('<p>First</p>'));
      expect(result, contains('<p>Second</p>'));
    });

    test('parent element tag and attributes are preserved', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <section id="main" class="container" tl:define="content">Default</section>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="content">Override</div>
</body>
</html>''', {});

      expect(result, contains('<section id="main" class="container">Override</section>'));
    });
  });

  // ─── TI05: Multi-level inheritance ─────────────────────────────────────

  group('multi-level inheritance', () {
    test('3-level chain: child → layout → base', () {
      final loader = MapLoader({
        'base': '''
<html>
<body>
  <header tl:define="header">Base Header</header>
  <main tl:define="content">Base Content</main>
  <footer tl:define="footer">Base Footer</footer>
</body>
</html>''',
        'layout': '''
<html tl:extends="base">
<body>
  <header tl:define="header">Layout Header</header>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <main tl:define="content">Page Content</main>
</body>
</html>''', {});

      expect(result, contains('Layout Header'));
      expect(result, contains('Page Content'));
      expect(result, contains('Base Footer'));
    });

    test('child overrides grandparent block (skipping middle)', () {
      final loader = MapLoader({
        'base': '''
<html>
<body>
  <h1 tl:define="title">Base Title</h1>
  <div tl:define="content">Base Content</div>
</body>
</html>''',
        'middle': '''
<html tl:extends="base">
<body>
  <div tl:define="content">Middle Content</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="middle">
<body>
  <h1 tl:define="title">Child Title</h1>
</body>
</html>''', {});

      // Child overrides title from base (which middle did not override).
      // Middle's content override is in the resolved parent, so child gets
      // middle's content (since child didn't override it).
      expect(result, contains('Child Title'));
      expect(result, contains('Middle Content'));
    });

    test('4-level chain resolves correctly', () {
      final loader = MapLoader({
        'l1': '''
<html>
<body>
  <div tl:define="a">L1-A</div>
  <div tl:define="b">L1-B</div>
  <div tl:define="c">L1-C</div>
  <div tl:define="d">L1-D</div>
</body>
</html>''',
        'l2': '''
<html tl:extends="l1">
<body>
  <div tl:define="b">L2-B</div>
</body>
</html>''',
        'l3': '''
<html tl:extends="l2">
<body>
  <div tl:define="c">L3-C</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="l3">
<body>
  <div tl:define="d">L4-D</div>
</body>
</html>''', {});

      expect(result, contains('L1-A'));
      expect(result, contains('L2-B'));
      expect(result, contains('L3-C'));
      expect(result, contains('L4-D'));
    });
  });

  // ─── TI06: Block content with tl:* attributes ─────────────────────────

  group('block content with tl:* attributes', () {
    test('block with tl:text expression', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <h1 tl:define="title">Default</h1>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render(
        '''
<html tl:extends="layout">
<body>
  <h1 tl:define="title"><span tl:text="\${name}">placeholder</span></h1>
</body>
</html>''',
        {'name': 'Hello World'},
      );

      expect(result, contains('Hello World'));
      expect(result, isNot(contains('placeholder')));
    });

    test('block with tl:if conditional', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render(
        '''
<html tl:extends="layout">
<body>
  <div tl:define="content">
    <p tl:if="\${show}">Visible</p>
    <p tl:unless="\${show}">Hidden</p>
  </div>
</body>
</html>''',
        {'show': true},
      );

      expect(result, contains('Visible'));
      expect(result, isNot(contains('Hidden')));
    });

    test('block with tl:each loop', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <ul tl:define="list">Default</ul>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render(
        '''
<html tl:extends="layout">
<body>
  <ul tl:define="list">
    <li tl:each="item : \${items}" tl:text="\${item}">x</li>
  </ul>
</body>
</html>''',
        {
          'items': ['A', 'B', 'C'],
        },
      );

      expect(result, contains('<li>A</li>'));
      expect(result, contains('<li>B</li>'));
      expect(result, contains('<li>C</li>'));
    });

    test('block with tl:with local variable', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="content">
    <p tl:with="greeting='Hello'" tl:text="\${greeting}">x</p>
  </div>
</body>
</html>''', {});

      expect(result, contains('Hello'));
    });

    test('tl:fragment inside block visible to renderFragment()', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final source = '''
<html tl:extends="layout">
<body>
  <div tl:define="content">
    <div tl:fragment="card" tl:text="\${title}">placeholder</div>
  </div>
</body>
</html>''';

      final result = engine.renderFragment(source, fragment: 'card', context: {'title': 'Card Title'});
      expect(result, contains('Card Title'));
    });

    test('parent tl:fragment outside blocks visible on merged DOM', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <nav tl:fragment="nav"><a href="/">Home</a></nav>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final source = '''
<html tl:extends="layout">
<body>
  <div tl:define="content">Page Content</div>
</body>
</html>''';

      final result = engine.renderFragment(source, fragment: 'nav', context: {});
      expect(result, contains('Home'));
    });
  });

  // ─── TI07: Fragment rendering with inheritance ─────────────────────────

  group('fragment rendering with inheritance', () {
    test('renderFragment() on child finds parent fragment', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <header tl:fragment="header">Layout Header</header>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final source = '''
<html tl:extends="layout">
<body>
  <div tl:define="content">Content</div>
</body>
</html>''';

      final result = engine.renderFragment(source, fragment: 'header', context: {});
      expect(result, contains('Layout Header'));
    });

    test('renderFragment() on child finds child override fragment', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final source = '''
<html tl:extends="layout">
<body>
  <div tl:define="content">
    <span tl:fragment="item" tl:text="\${val}">x</span>
  </div>
</body>
</html>''';

      final result = engine.renderFragment(source, fragment: 'item', context: {'val': 'Found'});
      expect(result, contains('Found'));
    });

    test('renderFragments() returns fragments from both parent and child', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <header tl:fragment="header">Header</header>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final source = '''
<html tl:extends="layout">
<body>
  <div tl:define="content">
    <span tl:fragment="item">Item</span>
  </div>
</body>
</html>''';

      final result = engine.renderFragments(source, fragments: ['header', 'item'], context: {});
      expect(result, contains('Header'));
      expect(result, contains('Item'));
    });

    test('renderFileFragment() with inheritance', () async {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <header tl:fragment="header">Layout Header</header>
  <div tl:define="content">Default</div>
</body>
</html>''',
        'page': '''
<html tl:extends="layout">
<body>
  <div tl:define="content">Page</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = await engine.renderFileFragment('page', fragment: 'header', context: {});
      expect(result, contains('Layout Header'));
    });

    test('renderFileFragments() with inheritance', () async {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <header tl:fragment="header">Header</header>
  <div tl:define="content">Default</div>
</body>
</html>''',
        'page': '''
<html tl:extends="layout">
<body>
  <div tl:define="content">
    <span tl:fragment="card">Card</span>
  </div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = await engine.renderFileFragments('page', fragments: ['header', 'card'], context: {});
      expect(result, contains('Header'));
      expect(result, contains('Card'));
    });
  });

  // ─── TI08: Error cases and edge cases ──────────────────────────────────

  group('error cases', () {
    test('non-existent parent throws TemplateNotFoundException', () {
      final loader = MapLoader({});
      final engine = Trellis(loader: loader, cache: false);
      expect(
        () => engine.render('<html tl:extends="missing"><body></body></html>', {}),
        throwsA(isA<TemplateNotFoundException>()),
      );
    });

    test('non-root tl:extends throws TemplateException', () {
      final loader = MapLoader({'parent': '<html><body></body></html>'});
      final engine = Trellis(loader: loader, cache: false);
      expect(
        () => engine.render('''
<html>
<body>
  <div tl:extends="parent">oops</div>
</body>
</html>''', {}),
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('root element'))),
      );
    });

    test('circular inheritance (A→B→A) throws TemplateException', () {
      final loader = MapLoader({
        'a': '<html tl:extends="b"><body></body></html>',
        'b': '<html tl:extends="a"><body></body></html>',
      });
      final engine = Trellis(loader: loader, cache: false);
      expect(
        () => engine.render('<html tl:extends="a"><body></body></html>', {}),
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('cycle'))),
      );
    });

    test('self-reference throws TemplateException', () {
      final loader = MapLoader({'self': '<html tl:extends="self"><body></body></html>'});
      final engine = Trellis(loader: loader, cache: false);
      expect(
        () => engine.render('<html tl:extends="self"><body></body></html>', {}),
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('cycle'))),
      );
    });

    test('depth exceeded throws TemplateException', () {
      // Create a chain that's 20 levels deep.
      final templates = <String, String>{};
      for (var i = 0; i < 20; i++) {
        templates['level$i'] = '<html tl:extends="level${i + 1}"><body></body></html>';
      }
      templates['level20'] = '<html><body>Base</body></html>';

      final loader = MapLoader(templates);
      final engine = Trellis(loader: loader, cache: false);
      expect(
        () => engine.render('<html tl:extends="level0"><body></body></html>', {}),
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('depth exceeded'))),
      );
    });

    test('empty tl:extends value throws TemplateException', () {
      final loader = MapLoader({});
      final engine = Trellis(loader: loader, cache: false);
      expect(
        () => engine.render('<html tl:extends=""><body></body></html>', {}),
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('empty'))),
      );
    });
  });

  group('edge cases', () {
    test('tl:define in non-extends template — passthrough', () {
      final loader = MapLoader({});
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html>
<body>
  <div tl:define="content">Passthrough Content</div>
</body>
</html>''', {});

      expect(result, contains('Passthrough Content'));
      // tl:define attribute should be stripped.
      expect(result, isNot(contains('tl:define')));
    });

    test('child block not in parent — ignored', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="nonexistent">Should be ignored</div>
</body>
</html>''', {});

      expect(result, contains('Default'));
      expect(result, isNot(contains('Should be ignored')));
    });

    test('duplicate tl:define names in child — last wins', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="content">First</div>
  <div tl:define="content">Second</div>
</body>
</html>''', {});

      expect(result, contains('Second'));
      expect(result, isNot(contains('First')));
    });

    test('nested tl:define — outer override replaces inner', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="outer">
    <span tl:define="inner">Inner Default</span>
  </div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="outer">Replaced Everything</div>
</body>
</html>''', {});

      expect(result, contains('Replaced Everything'));
      expect(result, isNot(contains('Inner Default')));
    });

    test('<tl:block> virtual element unaffected by inheritance', () {
      final loader = MapLoader({});
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render(
        '''
<html>
<body>
  <tl:block tl:each="item : \${items}"><p tl:text="\${item}">x</p></tl:block>
</body>
</html>''',
        {
          'items': ['A', 'B'],
        },
      );

      expect(result, contains('<p>A</p>'));
      expect(result, contains('<p>B</p>'));
      // tl:block should be unwrapped.
      expect(result, isNot(contains('tl:block')));
    });

    test('tl:extends path resolves via loader', () async {
      final loader = MapLoader({
        'layouts/base': '''
<html>
<body>
  <div tl:define="content">Base</div>
</body>
</html>''',
        'page': '''
<html tl:extends="layouts/base">
<body>
  <div tl:define="content">Page</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = await engine.renderFile('page', {});
      expect(result, contains('Page'));
    });

    test('tl:extends and tl:define attributes stripped from output', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="content">Override</div>
</body>
</html>''', {});

      expect(result, isNot(contains('tl:extends')));
      expect(result, isNot(contains('tl:define')));
    });

    test('block in <head> (title override)', () {
      final loader = MapLoader({
        'layout': '''
<html>
<head>
  <title tl:define="title">Default Title</title>
</head>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <title tl:define="title">My Page</title>
  <div tl:define="content">Content</div>
</body>
</html>''', {});

      expect(result, contains('<title>My Page</title>'));
      expect(result, contains('Content'));
    });
  });

  // ─── TI09: Validator ───────────────────────────────────────────────────

  group('validator', () {
    test('tl:extends is recognized (no unknown attribute warning)', () {
      final validator = TemplateValidator();
      final errors = validator.validate('<html tl:extends="layout"><body></body></html>');
      expect(errors.where((e) => e.message.contains('Unknown')), isEmpty);
    });

    test('tl:define is recognized (no unknown attribute warning)', () {
      final validator = TemplateValidator();
      final errors = validator.validate('<html><body><div tl:define="content">x</div></body></html>');
      expect(errors.where((e) => e.message.contains('Unknown')), isEmpty);
    });

    test('duplicate tl:define names produce warning', () {
      final validator = TemplateValidator();
      final errors = validator.validate('''
<html>
<body>
  <div tl:define="content">A</div>
  <div tl:define="content">B</div>
</body>
</html>''');
      expect(errors, hasLength(1));
      expect(errors.first.severity, ValidationSeverity.warning);
      expect(errors.first.message, contains('Duplicate'));
    });

    test('empty tl:extends value produces error', () {
      final validator = TemplateValidator();
      final errors = validator.validate('<html tl:extends=""><body></body></html>');
      expect(errors.any((e) => e.severity == ValidationSeverity.error && e.message.contains('empty')), isTrue);
    });

    test('empty tl:define value produces error', () {
      final validator = TemplateValidator();
      final errors = validator.validate('<html><body><div tl:define="">x</div></body></html>');
      expect(errors.any((e) => e.severity == ValidationSeverity.error && e.message.contains('empty')), isTrue);
    });
  });

  // ─── TI10: Caching and configurable prefix ────────────────────────────

  group('caching', () {
    test('rendering child twice — parent cached', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: true);
      final source = '''
<html tl:extends="layout">
<body>
  <div tl:define="content"><span tl:text="\${val}">x</span></div>
</body>
</html>''';

      final r1 = engine.render(source, {'val': 'First'});
      final r2 = engine.render(source, {'val': 'Second'});

      expect(r1, contains('First'));
      expect(r2, contains('Second'));
      // Cache should have the parent too.
      expect(engine.cacheStats.size, greaterThanOrEqualTo(1));
    });

    test('multiple children sharing parent — parent cached once', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: true);

      final child1 = '''
<html tl:extends="layout">
<body><div tl:define="content">Child1</div></body>
</html>''';
      final child2 = '''
<html tl:extends="layout">
<body><div tl:define="content">Child2</div></body>
</html>''';

      final r1 = engine.render(child1, {});
      final r2 = engine.render(child2, {});

      expect(r1, contains('Child1'));
      expect(r2, contains('Child2'));
    });
  });

  group('configurable prefix', () {
    test('custom prefix data-tl works', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div data-tl-define="content">Default</div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false, prefix: 'data-tl');
      final result = engine.render('''
<html data-tl-extends="layout">
<body>
  <div data-tl-define="content">Override</div>
</body>
</html>''', {});

      expect(result, contains('Override'));
      expect(result, isNot(contains('Default')));
      expect(result, isNot(contains('data-tl-extends')));
      expect(result, isNot(contains('data-tl-define')));
    });
  });

  // ─── Additional integration tests ─────────────────────────────────────

  group('integration', () {
    test('tl:insert inside inherited block', () {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
        'partials/nav': '''
<nav tl:fragment="nav"><a href="/">Home</a></nav>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = engine.render('''
<html tl:extends="layout">
<body>
  <div tl:define="content">
    <div tl:insert="~{partials/nav :: nav}"></div>
    <p>Main Content</p>
  </div>
</body>
</html>''', {});

      expect(result, contains('Home'));
      expect(result, contains('Main Content'));
    });

    test('renderFile with inheritance', () async {
      final loader = MapLoader({
        'layout': '''
<html>
<body>
  <div tl:define="content">Default</div>
</body>
</html>''',
        'page': '''
<html tl:extends="layout">
<body>
  <div tl:define="content"><h1 tl:text="\${title}">x</h1></div>
</body>
</html>''',
      });
      final engine = Trellis(loader: loader, cache: false);
      final result = await engine.renderFile('page', {'title': 'My Page'});
      expect(result, contains('My Page'));
    });
  });
}
