// Top-level rendering of parameterised fragments by bare name (ADR-014 AC-06,
// prd.md#top-level-rendering-of-parameterised-fragments).
import 'package:test/test.dart';
import 'package:trellis/testing.dart';
import 'package:trellis/trellis.dart';

const _toast = r'<div tl:fragment="toast(type, title)" tl:classappend="${type}"><b tl:text="${title}">T</b></div>';
const _note = r'<p tl:fragment="note(text)" tl:text="${text}">n</p>';
const _toastOut = '<div class="error"><b>Saved</b></div>';

Matcher _templateException(String containing) =>
    throwsA(isA<TemplateException>().having((e) => e.toString(), 'message', contains(containing)));

void main() {
  late Trellis engine;

  Trellis withTemplates(Map<String, String> templates, {bool strict = true}) =>
      testEngine(templates: templates, strict: strict);

  setUp(() => engine = withTemplates({'ui.html': '$_toast$_note'}));

  group('rest-parameter fragment rendered top-level (S06)', () {
    const source =
        r'<label tl:fragment="field(label, name, ...attrs)"><span tl:text="${label}">L</span>'
        r'<input type="text" tl:attr="name=${name}" tl:attrs="${attrs}"></label>';
    const expected = '<label><span>Email</span><input type="text" name="email"></label>';

    test('renders processed with an empty rest map', () {
      expect(engine.renderFragment(source, fragment: 'field', context: {'label': 'Email', 'name': 'email'}), expected);
    });

    test('the rest map is empty even when the context holds a same-named key', () {
      expect(
        engine.renderFragment(
          source,
          fragment: 'field',
          context: {
            'label': 'Email',
            'name': 'email',
            'attrs': {'type': 'x'},
          },
        ),
        expected,
      );
    });
  });

  group('bare name in all four APIs (S10)', () {
    const ctx = {'type': 'error', 'title': 'Saved', 'text': 'hi'};

    test('renderFragment and renderFileFragment', () async {
      expect(engine.renderFragment('$_toast$_note', fragment: 'toast', context: ctx), _toastOut);
      expect(await engine.renderFileFragment('ui.html', fragment: 'toast', context: ctx), _toastOut);
    });

    test('renderFragments and renderFileFragments, in requested order', () async {
      const expected = '$_toastOut<p>hi</p>';
      expect(engine.renderFragments('$_toast$_note', fragments: ['toast', 'note'], context: ctx), expected);
      expect(await engine.renderFileFragments('ui.html', fragments: ['toast', 'note'], context: ctx), expected);
      expect(
        engine.renderFragments('$_toast$_note', fragments: ['note', 'toast'], context: ctx),
        '<p>hi</p>$_toastOut',
      );
    });
  });

  group('parameters from the context (S11)', () {
    test('resolve from same-named keys', () {
      expect(engine.renderFragment(_toast, fragment: 'toast', context: {'type': 'error', 'title': 'Saved'}), _toastOut);
    });

    test('an absent key is null on a lenient engine', () {
      final lenient = withTemplates({}, strict: false);
      expect(
        lenient.renderFragment(_toast, fragment: 'toast', context: {'type': 'error'}),
        '<div class="error"><b></b></div>',
      );
    });

    test('an absent key throws the undefined-variable error in strict mode', () {
      expect(
        () => engine.renderFragment(_toast, fragment: 'toast', context: {'type': 'error'}),
        throwsA(isA<ExpressionException>()),
      );
    });
  });

  test('the rendered fragment is fully processed (S12)', () {
    const source =
        r'<section tl:fragment="panel(title, items)" tl:attr="data-t=${title}">'
        r'<h2 tl:if="${title}" tl:text="${title}">T</h2>'
        r'<ul><li tl:each="i : ${items}" tl:text="${i}">i</li></ul>'
        r'<div tl:utext="${raw}">r</div>'
        r'<div tl:replace="note(${title})">n</div></section>'
        r'<p tl:fragment="note(text)" tl:text="${text}">n</p>';
    final html = engine.renderFragment(
      source,
      fragment: 'panel',
      context: {
        'title': 'Hello',
        'items': ['a', 'b'],
        'raw': '<i>x</i>',
      },
    );
    expect(
      html,
      '<section data-t="Hello"><h2>Hello</h2><ul><li>a</li><li>b</li></ul><div><i>x</i></div><p>Hello</p></section>',
    );
    expect(html, isNot(contains('tl:')));
    expect(html, isNot(contains(r'${')));
  });

  group('parameterless fragments render exactly as before (S13)', () {
    const source =
        '<ul tl:fragment="todo-list"><li tl:each="t : \${todos}" tl:text="\${t}">t</li></ul>'
        '<h2 tl:fragment="todo-list-header">Todos</h2>';
    const ctx = {
      'todos': ['a', 'b'],
    };

    test('literals captured from the engine before the change', () {
      expect(engine.renderFragment(source, fragment: 'todo-list', context: ctx), '<ul><li>a</li><li>b</li></ul>');
      expect(engine.renderFragment(source, fragment: 'todo-list-header', context: ctx), '<h2>Todos</h2>');
      expect(
        engine.renderFragments(source, fragments: ['todo-list', 'todo-list-header'], context: ctx),
        '<ul><li>a</li><li>b</li></ul><h2>Todos</h2>',
      );
    });

    test('a name that is only a prefix of another does not match', () {
      expect(
        () => engine.renderFragment('<h2 tl:fragment="todo-list-header">x</h2>', fragment: 'todo-list', context: {}),
        throwsA(isA<FragmentNotFoundException>()),
      );
    });
  });

  group('bare in-template invocation is unchanged (S14)', () {
    test('unpassed parameters bind to null and the context is not read', () {
      final lenient = withTemplates({}, strict: false);
      final html = lenient.render(
        '$_toast<div tl:replace="toast"></div><div tl:replace="toast(\'warn\', \${t})"></div>',
        {'type': 'error', 'title': 'Ctx', 't': 'Passed'},
      );
      expect(html, contains('<div><b></b></div>'));
      expect(html, contains('<div class="warn"><b>Passed</b></div>'));
      expect(html, isNot(contains('error')));
      expect(html, isNot(contains('Ctx')));
    });
  });

  group('a name with arguments throws and names the bare name (S15)', () {
    for (final value in ['toast(type, title)', "toast('error', \${x})", "toast('error')"]) {
      test(value, () async {
        const ctx = {'x': 1};
        expect(() => engine.renderFragment(_toast, fragment: value, context: ctx), _templateException('"toast"'));
        expect(
          () => engine.renderFileFragment('ui.html', fragment: value, context: ctx),
          _templateException('"toast"'),
        );
        expect(
          () => engine.renderFragments('$_toast$_note', fragments: ['note', value], context: ctx),
          _templateException('"toast"'),
        );
        expect(
          () => engine.renderFileFragments('ui.html', fragments: ['note', value], context: ctx),
          _templateException('"toast"'),
        );
      });
    }

    test('an empty () is read as the bare name', () {
      const source = '<header tl:fragment="header()"><h1>H</h1></header>$_toast';
      expect(
        engine.renderFragment(source, fragment: 'header()', context: {}),
        engine.renderFragment(source, fragment: 'header', context: {}),
      );
      expect(engine.renderFragment(source, fragment: 'header()', context: {}), '<header><h1>H</h1></header>');
    });
  });

  group('unknown name (S16)', () {
    test('renderFragment throws FragmentNotFoundException naming it', () {
      expect(
        () => engine.renderFragment(_toast, fragment: 'nope', context: {}),
        throwsA(isA<FragmentNotFoundException>().having((e) => e.toString(), 'message', contains('nope'))),
      );
    });

    test('renderFragments fails fast with no partial output', () {
      expect(
        () => engine.renderFragments(_toast, fragments: ['toast', 'nope'], context: {'type': 't', 'title': 'x'}),
        throwsA(isA<FragmentNotFoundException>().having((e) => e.toString(), 'message', contains('nope'))),
      );
    });
  });

  group('two fragments sharing a name (S17)', () {
    const parameterless = '<i tl:fragment="toast">A</i>';
    const parameterised = '<u tl:fragment="toast(type)">B</u>';

    test('top-level renders the first in document order; in-template resolves the last', () {
      final lenient = withTemplates({}, strict: false);
      const page = '<div tl:replace="toast"></div>';
      const ab = '$parameterless$parameterised';
      const ba = '$parameterised$parameterless';

      expect(lenient.renderFragment(ab, fragment: 'toast', context: {}), '<i>A</i>');
      expect(lenient.renderFragment(ba, fragment: 'toast', context: {}), '<u>B</u>');
      expect(lenient.render('$ab$page', {}), contains('<u>B</u>'));
      expect(lenient.render('$ba$page', {}), contains('<i>A</i>'));
    });
  });

  test('renderFragments reads one shared context (S18)', () {
    final html = engine.renderFragments(
      r'<i tl:fragment="a(title)" tl:text="${title}">a</i><u tl:fragment="b(title)" tl:text="${title}">b</u>',
      fragments: ['a', 'b'],
      context: {'title': 'Shared'},
    );
    expect(html, '<i>Shared</i><u>Shared</u>');
  });

  group('lookup runs on the resolved tl:extends document (S19)', () {
    test('fragment declared in an overriding block', () {
      final eng = withTemplates({'layout.html': '<html><body><main tl:define="content">default</main></body></html>'});
      final html = eng.renderFragment(
        '<html tl:extends="layout.html"><body><main tl:define="content">$_toast</main></body></html>',
        fragment: 'toast',
        context: {'type': 'error', 'title': 'Saved'},
      );
      expect(html, _toastOut);
    });

    test('fragment declared in the layout itself', () {
      final eng = withTemplates({
        'layout.html': '<html><body>$_toast<main tl:define="content">default</main></body></html>',
      });
      final html = eng.renderFragment(
        '<html tl:extends="layout.html"><body><main tl:define="content">x</main></body></html>',
        fragment: 'toast',
        context: {'type': 'error', 'title': 'Saved'},
      );
      expect(html, _toastOut);
    });
  });

  test('slot regions render their fallback in a top-level component (S20)', () {
    final html = engine.renderFragment(
      r'<dialog tl:fragment="dlg(title)"><h2 tl:text="${title}">T</h2><div tl:slot>Body</div>'
      r'<footer tl:slot="footer">Close</footer></dialog>',
      fragment: 'dlg',
      context: {'title': 'Hi'},
    );
    expect(html, '<dialog><h2>Hi</h2><div>Body</div><footer>Close</footer></dialog>');
  });

  test('one toast definition serves both in-page and out-of-band use (S22)', () async {
    final eng = withTemplates({
      'ui.html': _toast,
      'page.html': "<div tl:replace=\"~{ui.html :: toast('error', \${msg})}\"></div>",
    });
    final inPage = await eng.renderFile('page.html', {'msg': 'Saved'});
    final oob = await eng.renderFileFragments(
      'ui.html',
      fragments: ['toast'],
      context: {'type': 'error', 'title': 'Saved'},
    );
    expect(oob, _toastOut);
    expect(inPage, contains(oob));
    expect(RegExp('<div').allMatches(inPage), hasLength(1), reason: 'the page holds only the replaced toast');
  });
}
