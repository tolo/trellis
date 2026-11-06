// Top-level rendering of parameterised fragments by bare name (ADR-014 §3).
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

  group('rest-parameter fragment rendered top-level', () {
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

  group('bare name in all four APIs', () {
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

  group('parameters from the context', () {
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

    test('the strict error names the fragment and that the parameter is resolved from the render context', () {
      const message =
          'Fragment "toast": parameter "title" is resolved from the render context: '
          'Undefined variable: "title"';
      Matcher missingTitle() => throwsA(isA<ExpressionException>().having((e) => e.message, 'message', message));

      expect(() => engine.renderFragment(_toast, fragment: 'toast', context: {'type': 'error'}), missingTitle());
      expect(
        () =>
            engine.renderFragments('$_note$_toast', fragments: ['note', 'toast'], context: {'type': 'e', 'text': 't'}),
        missingTitle(),
      );
    });

    test('the annotated strict error keeps the evaluator stack trace', () {
      Object? thrown;
      StackTrace? trace;
      try {
        engine.renderFragment(_toast, fragment: 'toast', context: {'type': 'error'});
      } on ExpressionException catch (e, st) {
        thrown = e;
        trace = st;
      }
      expect(thrown, isA<ExpressionException>());
      expect(trace.toString(), contains('_evalVariable'));
    });

    test('an undefined variable that is not a declared parameter keeps the plain error', () {
      const source = r'<p tl:fragment="note(text)" tl:text="${text} + ${other}">n</p>';
      expect(
        () => engine.renderFragment(source, fragment: 'note', context: {'text': 'hi'}),
        throwsA(isA<ExpressionException>().having((e) => e.message, 'message', 'Undefined variable: "other"')),
      );
    });
  });

  test('the rendered fragment is fully processed', () {
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

  group('parameterless fragments render exactly as before', () {
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

  group('directives on the render root act as they would in place', () {
    const leaf = r'<b tl:fragment="leaf(y)" tl:text="${y}">L</b>';
    const alias = r'<div tl:fragment="w(x)" tl:replace="leaf(${x})"></div>';

    test('tl:replace renders the target, in all four APIs', () async {
      final eng = withTemplates({'ui.html': '$leaf$alias'});
      const ctx = {'x': 9, 'y': 1};

      expect(eng.renderFragment('$leaf$alias', fragment: 'w', context: ctx), '<b>9</b>');
      expect(await eng.renderFileFragment('ui.html', fragment: 'w', context: ctx), '<b>9</b>');
      expect(eng.renderFragments('$leaf$alias', fragments: ['w', 'leaf'], context: ctx), '<b>9</b><b>1</b>');
      expect(await eng.renderFileFragments('ui.html', fragments: ['leaf', 'w'], context: ctx), '<b>1</b><b>9</b>');
    });

    test('a rest-forwarding alias passes its own attributes to the target', () {
      // The root's rest map is empty (no invoking host), but the alias's literal hx-swap-oob is a host attribute, which
      // a rest-parameter target captures and spreads exactly as it does for an in-template invocation.
      const source =
          r'<div tl:fragment="toast(type, ...attrs)" tl:attrs="${attrs}" tl:classappend="${type}">T</div>'
          r'<div tl:fragment="toastOob(...r)" tl:replace="toast(${t})" hx-swap-oob="true"></div>';

      expect(
        engine.renderFragment(source, fragment: 'toastOob', context: {'t': 'error'}),
        '<div hx-swap-oob="true" class="error">T</div>',
      );
    });

    test('a parameterised tl:each root renders one element per item', () {
      expect(
        engine.renderFragment(
          r'<div tl:fragment="c(xs)" tl:each="v : ${xs}" tl:text="${v}">x</div>',
          fragment: 'c',
          context: {
            'xs': [1, 2],
          },
        ),
        '<div>1</div><div>2</div>',
      );
    });

    test('tl:if false, tl:unless true and tl:remove="all" render nothing, and renderFragments skips them', () {
      for (final directive in [r'tl:if="${false}"', r'tl:unless="${true}"', 'tl:remove="all"']) {
        final source = '<p tl:fragment="gone" $directive>X</p><i tl:fragment="kept">K</i>';

        expect(
          engine.renderFragment(source, fragment: 'gone', context: {}),
          '',
          reason: directive,
        );
        expect(engine.renderFragments(source, fragments: ['gone', 'kept', 'gone'], context: {}), '<i>K</i>');
      }
    });

    test('tl:remove="tag" and a tl:block root render their processed children', () {
      const children = r'<b>k</b><i tl:text="${1}">x</i>';
      const expected = '<b>k</b><i>1</i>';

      expect(
        engine.renderFragment('<div tl:fragment="c" tl:remove="tag">$children</div>', fragment: 'c', context: {}),
        expected,
      );
      expect(
        engine.renderFragment('<tl:block tl:fragment="c">$children</tl:block>', fragment: 'c', context: {}),
        expected,
      );
    });

    test('only the root and its tl:each copies are exempt: a nested parameterised definition is still removed', () {
      const helper = '<p tl:fragment="helper(z)">H</p>';

      expect(
        engine.renderFragment('<tl:block tl:fragment="c">$helper<i>k</i></tl:block>', fragment: 'c', context: {}),
        '<i>k</i>',
      );
      expect(
        engine.renderFragment(
          r'<div tl:fragment="c" tl:each="v : ${xs}">'
          '$helper<i>k</i></div>',
          fragment: 'c',
          context: {
            'xs': [1, 2],
          },
        ),
        '<div><i>k</i></div><div><i>k</i></div>',
      );
    });

    test('a root tl:replace still works when the fragment is invoked from a page, same-file and cross-file', () {
      final eng = withTemplates({'ui.html': '$leaf$alias'});

      expect(eng.render('$leaf$alias<p tl:replace="w(7)">h</p>', {}), contains('<b>7</b>'));
      expect(
        eng.render('<p tl:replace="~{ui.html :: w(7)}">h</p>', {}),
        allOf(contains('<b>7</b>'), isNot(contains('<p'))),
      );
    });
  });

  group('bare in-template invocation is unchanged', () {
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

  group('a name with arguments throws and names the bare name', () {
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

  group('name edge forms, through renderFragment and renderFragments', () {
    const ctx = {'type': 'error', 'title': 'Saved', 'text': 'hi'};

    String one(String name) => engine.renderFragment('$_toast$_note', fragment: name, context: ctx);
    String many(String name) => engine.renderFragments('$_toast$_note', fragments: [name], context: ctx);

    for (final name in [' toast ', 'toast()', 'toast ( )', ' toast\t(\n) ']) {
      test("'${name.replaceAll('\n', r'\n').replaceAll('\t', r'\t')}' reads as the bare name", () {
        expect(one(name), _toastOut);
        expect(many(name), _toastOut);
      });
    }

    // An unbalanced `toast(` is read as arguments, not as a bare name with a stray paren.
    for (final name in ['toast ( a )', 'toast(', 'toast ()x']) {
      test("'$name' is rejected as arguments, naming the bare name, not as not-found", () {
        for (final call in [() => one(name), () => many(name)]) {
          expect(
            call,
            throwsA(
              isA<TemplateException>()
                  .having((e) => e, 'type', isNot(isA<FragmentNotFoundException>()))
                  .having((e) => e.message, 'message', allOf(contains('"$name"'), contains('bare name "toast"'))),
            ),
          );
        }
      });
    }

    test('an unknown name is not found, with or without an empty ()', () {
      for (final name in ['nope', ' nope ', 'nope()', 'nope ( )']) {
        for (final call in [() => one(name), () => many(name)]) {
          expect(
            call,
            throwsA(isA<FragmentNotFoundException>().having((e) => e.fragmentName, 'name', contains('nope'))),
          );
        }
      }
    });

    test('arguments on an unknown name are rejected before lookup', () {
      expect(
        () => one('nope ( x )'),
        throwsA(isA<TemplateException>().having((e) => e, 'type', isNot(isA<FragmentNotFoundException>()))),
      );
    });

    test('a stray closing paren is part of the name, so it is not found', () {
      expect(() => one('toast)'), throwsA(isA<FragmentNotFoundException>()));
    });
  });

  group('unknown name', () {
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

  group('two fragments sharing a name', () {
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

  test('renderFragments reads one shared context', () {
    final html = engine.renderFragments(
      r'<i tl:fragment="a(title)" tl:text="${title}">a</i><u tl:fragment="b(title)" tl:text="${title}">b</u>',
      fragments: ['a', 'b'],
      context: {'title': 'Shared'},
    );
    expect(html, '<i>Shared</i><u>Shared</u>');
  });

  group('lookup runs on the resolved tl:extends document', () {
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

  test('slot regions render their fallback in a top-level component', () {
    final html = engine.renderFragment(
      r'<dialog tl:fragment="dlg(title)"><h2 tl:text="${title}">T</h2><div tl:slot>Body</div>'
      r'<footer tl:slot="footer">Close</footer></dialog>',
      fragment: 'dlg',
      context: {'title': 'Hi'},
    );
    expect(html, '<dialog><h2>Hi</h2><div>Body</div><footer>Close</footer></dialog>');
  });

  test('one toast definition serves in-page, bare-name and stacking out-of-band use', () async {
    // htmx 2 inserts only the children of a non-outerHTML out-of-band element, so a stacking toast needs a wrapper;
    // it stays thin by delegating to the one toast definition with its own parameters as arguments.
    const stack =
        r'<div tl:fragment="toastStack(type, title)" hx-swap-oob="beforeend:#toasts">'
        r'<div tl:replace="toast(${type}, ${title})"></div></div>';
    final eng = withTemplates({
      'ui.html': '$_toast$stack',
      'page.html': "<div tl:replace=\"~{ui.html :: toast('error', \${msg})}\"></div>",
    });
    const ctx = {'type': 'error', 'title': 'Saved'};
    final inPage = await eng.renderFile('page.html', {'msg': 'Saved'});
    final bare = await eng.renderFileFragments('ui.html', fragments: ['toast'], context: ctx);
    final stacked = await eng.renderFileFragments('ui.html', fragments: ['toastStack'], context: ctx);

    expect(bare, _toastOut);
    expect(inPage, contains(bare));
    expect(RegExp('<div').allMatches(inPage), hasLength(1), reason: 'the page holds only the replaced toast');
    expect(stacked, '<div hx-swap-oob="beforeend:#toasts">$bare</div>');
  });
}
