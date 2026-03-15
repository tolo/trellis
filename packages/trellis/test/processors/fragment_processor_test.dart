import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Fragment processor', () {
    group('tl:fragment definition', () {
      test('tl:fragment attribute removed from output', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render('<div tl:fragment="header">Header Content</div>', {});
        expect(result, isNot(contains('tl:fragment')));
        expect(result, contains('Header Content'));
      });
    });

    group('tl:insert same-file', () {
      test('inserts fragment content inside host element', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<div tl:fragment="header"><h1>Header</h1></div>'
          '<main><div tl:insert="header"></div></main>',
          {},
        );
        expect(result, contains('<div><h1>Header</h1></div>'));
      });

      test('host element preserved with tl:insert', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<nav tl:fragment="menu"><a>Link</a></nav>'
          '<div class="container"><section tl:insert="menu">old content</section></div>',
          {},
        );
        // Host <section> is preserved, content replaced with fragment's children
        expect(result, contains('<section>'));
        expect(result, contains('<a>Link</a>'));
        expect(result, isNot(contains('old content')));
      });
    });

    group('tl:replace same-file', () {
      test('replaces host element with fragment', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<header tl:fragment="hdr"><h1>Title</h1></header>'
          '<main><div tl:replace="hdr">placeholder</div></main>',
          {},
        );
        // <div> replaced by <header>
        expect(result, contains('<header><h1>Title</h1></header>'));
        expect(result, isNot(contains('placeholder')));
      });

      test('host element removed with tl:replace', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<span tl:fragment="tag">content</span>'
          '<div tl:replace="tag">old</div>',
          {},
        );
        // The <div> should not appear — replaced by <span>
        expect(result, contains('<span>content</span>'));
      });
    });

    group('cross-file tl:insert', () {
      test('loads fragment from another template', () {
        final engine = Trellis(
          loader: MapLoader({'layout': '<header tl:fragment="hdr"><h1>Layout Header</h1></header>'}),
          cache: false,
        );
        final result = engine.render('<div tl:insert="~{layout :: hdr}"></div>', {});
        expect(result, contains('<h1>Layout Header</h1>'));
      });
    });

    group('cross-file tl:replace', () {
      test('replaces host with cross-file fragment', () {
        final engine = Trellis(
          loader: MapLoader({'components': '<nav tl:fragment="sidebar"><ul><li>Item</li></ul></nav>'}),
          cache: false,
        );
        final result = engine.render('<div tl:replace="~{components :: sidebar}">placeholder</div>', {});
        expect(result, contains('<nav><ul><li>Item</li></ul></nav>'));
        expect(result, isNot(contains('placeholder')));
      });
    });

    group('fragment processing', () {
      test('included fragment tl:text is evaluated', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<span tl:fragment="greeting"><b tl:text="\${name}">x</b></span>'
          '<div tl:insert="greeting"></div>',
          {'name': 'Alice'},
        );
        expect(result, contains('<b>Alice</b>'));
      });

      test('included fragment tl:if is evaluated', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<div tl:fragment="cond"><p tl:if="\${show}">Visible</p></div>'
          '<section tl:insert="cond"></section>',
          {'show': false},
        );
        expect(result, isNot(contains('Visible')));
      });

      test('cross-file fragment expressions evaluated with current context', () {
        final engine = Trellis(
          loader: MapLoader({'partials': '<div tl:fragment="user"><span tl:text="\${username}">x</span></div>'}),
          cache: false,
        );
        final result = engine.render('<div tl:insert="~{partials :: user}"></div>', {'username': 'Bob'});
        expect(result, contains('<span>Bob</span>'));
      });
    });

    group('fragment not found', () {
      test('same-file fragment not found throws FragmentNotFoundException', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        expect(
          () => engine.render('<div tl:insert="nonexistent"></div>', {}),
          throwsA(isA<FragmentNotFoundException>()),
        );
      });

      test('cross-file fragment not found throws FragmentNotFoundException', () {
        final engine = Trellis(loader: MapLoader({'layout': '<div>No fragments here</div>'}), cache: false);
        expect(
          () => engine.render('<div tl:insert="~{layout :: missing}"></div>', {}),
          throwsA(isA<FragmentNotFoundException>()),
        );
      });

      test('cross-file template not found throws TemplateNotFoundException', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        expect(
          () => engine.render('<div tl:insert="~{nonexistent :: hdr}"></div>', {}),
          throwsA(isA<TemplateNotFoundException>()),
        );
      });
    });

    group('depth guard', () {
      test('recursive inclusion throws TemplateException with cycle detection', () {
        final engine = Trellis(
          loader: MapLoader({
            'recursive': '<div tl:fragment="loop"><div tl:insert="~{recursive :: loop}"></div></div>',
          }),
          cache: false,
        );
        expect(
          () => engine.render('<div tl:insert="~{recursive :: loop}"></div>', {}),
          throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('cycle detected'))),
        );
      });
    });

    group('multiple fragments', () {
      test('insert specific fragment from template with multiple', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<div tl:fragment="a">Alpha</div>'
          '<div tl:fragment="b">Beta</div>'
          '<section tl:insert="b"></section>',
          {},
        );
        expect(result, contains('<section>Beta</section>'));
      });
    });

    group('nested fragment inclusion', () {
      test('fragment A includes fragment B', () {
        final engine = Trellis(
          loader: MapLoader({'inner': '<span tl:fragment="deep">Deep Content</span>'}),
          cache: false,
        );
        final result = engine.render(
          '<div tl:fragment="outer"><div tl:insert="~{inner :: deep}"></div></div>'
          '<section tl:insert="outer"></section>',
          {},
        );
        expect(result, contains('Deep Content'));
      });

      test('cross-file fragment can include same-file fragment', () {
        final engine = Trellis(
          loader: MapLoader({
            'components':
                '<div tl:fragment="outer"><section tl:insert="inner"></section></div>'
                '<p tl:fragment="inner">Inner Content</p>',
          }),
          cache: false,
        );
        final result = engine.render('<main tl:insert="~{components :: outer}"></main>', {});
        expect(result, contains('<section>Inner Content</section>'));
      });
    });

    group('attribute removal', () {
      test('tl:insert removed from output', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<div tl:fragment="f">Content</div>'
          '<div tl:insert="f"></div>',
          {},
        );
        expect(result, isNot(contains('tl:insert')));
      });

      test('tl:replace removed from output', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<div tl:fragment="f">Content</div>'
          '<div tl:replace="f"></div>',
          {},
        );
        expect(result, isNot(contains('tl:replace')));
      });

      test('tl:fragment removed from included fragment output', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<div tl:fragment="f">Content</div>'
          '<div tl:insert="f"></div>',
          {},
        );
        expect(result, isNot(contains('tl:fragment')));
      });
    });

    group('parameterized fragments — same-file', () {
      test('single param bound in fragment scope', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          r'<span tl:fragment="greeting(name)"><b tl:text="${name}">x</b></span>'
          r'<div tl:insert="greeting(${user})"></div>',
          {'user': 'Alice'},
        );
        expect(result, contains('<b>Alice</b>'));
      });

      test('two params bound correctly', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          r'<div tl:fragment="card(title, body)"><h2 tl:text="${title}">t</h2><p tl:text="${body}">b</p></div>'
          r'<section tl:insert="card(${heading}, ${content})"></section>',
          {'heading': 'Hello', 'content': 'World'},
        );
        expect(result, contains('<h2>Hello</h2>'));
        expect(result, contains('<p>World</p>'));
      });

      test('string literal as argument', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          r'<span tl:fragment="label(text)"><b tl:text="${text}">x</b></span>'
          '<div tl:insert="label(\'hello\')"></div>',
          {},
        );
        expect(result, contains('<b>hello</b>'));
      });

      test('arithmetic expression as argument', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          r'<span tl:fragment="num(val)"><b tl:text="${val}">x</b></span>'
          r'<div tl:insert="num(${a + b})"></div>',
          {'a': 3, 'b': 4},
        );
        expect(result, contains('<b>7</b>'));
      });

      test('missing arg gets null', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<div tl:fragment="card(a, b)"><span tl:text="\${a}">x</span><span tl:text="\${b}">y</span></div>'
          '<section tl:insert="card(\${x})"></section>',
          {'x': 'first'},
        );
        expect(result, contains('<span>first</span>'));
        // b is null -> empty string
        expect(result, contains('<span></span>'));
      });

      test('extra args ignored', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          r'<span tl:fragment="single(a)"><b tl:text="${a}">x</b></span>'
          r'<div tl:insert="single(${x}, ${y})"></div>',
          {'x': 'kept', 'y': 'ignored'},
        );
        expect(result, contains('<b>kept</b>'));
      });

      test('empty parens equivalent to no params', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<span tl:fragment="simple()">Content</span>'
          '<div tl:insert="simple()"></div>',
          {},
        );
        expect(result, contains('Content'));
      });

      test('tl:fragment="name()" element is NOT removed from DOM output', () {
        // name() must behave like name — the element stays in rendered output
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render('<div><span tl:fragment="header()">Header</span></div>', {});
        expect(result, contains('Header'));
        expect(result, contains('<span'));
      });

      test('v0.1 syntax still works (no parens)', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<span tl:fragment="header">Header</span>'
          '<div tl:insert="header"></div>',
          {},
        );
        expect(result, contains('Header'));
      });

      test('tl:replace with params', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          r'<span tl:fragment="tag(label)"><b tl:text="${label}">x</b></span>'
          r'<div tl:replace="tag(${val})">placeholder</div>',
          {'val': 'replaced'},
        );
        expect(result, contains('<b>replaced</b>'));
        expect(result, isNot(contains('placeholder')));
      });

      test('comma inside expression not treated as arg separator', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          r'<span tl:fragment="show(val)"><b tl:text="${val}">x</b></span>'
          r'<div tl:insert="show(${flag ? 1 : 2})"></div>',
          {'flag': true},
        );
        // Ternary with comma-like syntax: the ?: is inside ${}, not a param separator
        expect(result, contains('<b>1</b>'));
      });

      test('comma inside string literal arg not treated as separator', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          r'<span tl:fragment="msg(text)"><b tl:text="${text}">x</b></span>'
          '<div tl:insert="msg(\'hello, world\')"></div>',
          {},
        );
        expect(result, contains('<b>hello, world</b>'));
      });
    });

    group('parameterized fragments — cross-file', () {
      test('basic cross-file with param', () {
        final engine = Trellis(
          loader: MapLoader({'components': r'<span tl:fragment="badge(text)"><b tl:text="${text}">x</b></span>'}),
          cache: false,
        );
        final result = engine.render(r'<div tl:insert="~{components :: badge(${label})}"></div>', {'label': 'New'});
        expect(result, contains('<b>New</b>'));
      });

      test('cross-file with two params', () {
        final engine = Trellis(
          loader: MapLoader({
            'cards': r'<div tl:fragment="card(t, b)"><h3 tl:text="${t}">x</h3><p tl:text="${b}">y</p></div>',
          }),
          cache: false,
        );
        final result = engine.render(r'<section tl:insert="~{cards :: card(${title}, ${body})}"></section>', {
          'title': 'Hi',
          'body': 'There',
        });
        expect(result, contains('<h3>Hi</h3>'));
        expect(result, contains('<p>There</p>'));
      });

      test('cross-file missing arg gets null', () {
        final engine = Trellis(
          loader: MapLoader({
            'tmpl': '<div tl:fragment="item(a, b)"><span tl:text="\${a}">x</span><span tl:text="\${b}">y</span></div>',
          }),
          cache: false,
        );
        final result = engine.render(r'<div tl:insert="~{tmpl :: item(${x})}"></div>', {'x': 'val'});
        expect(result, contains('<span>val</span>'));
        // b is null -> empty string
        expect(result, contains('<span></span>'));
      });

      test('cross-file tl:replace with params', () {
        final engine = Trellis(
          loader: MapLoader({'parts': r'<span tl:fragment="tag(v)"><b tl:text="${v}">x</b></span>'}),
          cache: false,
        );
        final result = engine.render(r'<div tl:replace="~{parts :: tag(${val})}">old</div>', {'val': 'new'});
        expect(result, contains('<b>new</b>'));
        expect(result, isNot(contains('old')));
      });

      test('cross-file no params backward compat', () {
        final engine = Trellis(
          loader: MapLoader({'layout': '<header tl:fragment="hdr"><h1>Title</h1></header>'}),
          cache: false,
        );
        final result = engine.render('<div tl:insert="~{layout :: hdr}"></div>', {});
        expect(result, contains('<h1>Title</h1>'));
      });
    });

    group('CSS selector targeting — same-file', () {
      test('#id selector selects element by id', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<div id="hero"><h1>Hero</h1></div>'
          '<section tl:insert="#hero"></section>',
          {},
        );
        expect(result, contains('<section><h1>Hero</h1></section>'));
      });

      test('.class selector selects element by class', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<p class="tagline">Welcome</p>'
          '<div tl:insert=".tagline"></div>',
          {},
        );
        expect(result, contains('Welcome'));
      });

      test('tl:replace with #id selector', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<nav id="main-nav"><a>Link</a></nav>'
          '<div tl:replace="#main-nav">placeholder</div>',
          {},
        );
        expect(result, contains('<nav id="main-nav"><a>Link</a></nav>'));
        expect(result, isNot(contains('placeholder')));
      });

      test('#id not found throws FragmentNotFoundException', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        expect(
          () => engine.render('<div tl:insert="#nonexistent"></div>', {}),
          throwsA(isA<FragmentNotFoundException>()),
        );
      });

      test('.class not found throws FragmentNotFoundException', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        expect(() => engine.render('<div tl:insert=".missing"></div>', {}), throwsA(isA<FragmentNotFoundException>()));
      });

      test('tag name fallback when no named fragment matches', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          '<footer><p>Footer content</p></footer>'
          '<div tl:insert="footer"></div>',
          {},
        );
        expect(result, contains('Footer content'));
      });

      test('named fragment takes precedence over tag name', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        // Fragment named "footer" should win over <footer> tag
        final result = engine.render(
          '<footer><p>Tag footer</p></footer>'
          '<span tl:fragment="footer">Named footer</span>'
          '<div tl:insert="footer"></div>',
          {},
        );
        expect(result, contains('Named footer'));
      });

      test('expressions evaluated in CSS selector fragment', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        final result = engine.render(
          r'<div id="greeting"><b tl:text="${name}">x</b></div>'
          '<section tl:insert="#greeting"></section>',
          {'name': 'Alice'},
        );
        expect(result, contains('<b>Alice</b>'));
      });
    });

    group('CSS selector targeting — cross-file', () {
      test('cross-file #id selector', () {
        final engine = Trellis(
          loader: MapLoader({'layout': '<header id="hdr"><h1>Header</h1></header>'}),
          cache: false,
        );
        final result = engine.render('<div tl:insert="~{layout :: #hdr}"></div>', {});
        expect(result, contains('<h1>Header</h1>'));
      });

      test('cross-file .class selector', () {
        final engine = Trellis(loader: MapLoader({'ui': '<div class="card"><p>Card</p></div>'}), cache: false);
        final result = engine.render('<section tl:insert="~{ui :: .card}"></section>', {});
        expect(result, contains('<p>Card</p>'));
      });

      test('cross-file tag name selector', () {
        final engine = Trellis(loader: MapLoader({'parts': '<footer><p>Footer</p></footer>'}), cache: false);
        final result = engine.render('<div tl:insert="~{parts :: footer}"></div>', {});
        expect(result, contains('Footer'));
      });

      test('cross-file tl:replace with #id selector', () {
        final engine = Trellis(loader: MapLoader({'comps': '<nav id="nav"><a>Nav</a></nav>'}), cache: false);
        final result = engine.render('<div tl:replace="~{comps :: #nav}">old</div>', {});
        expect(result, contains('<nav id="nav"><a>Nav</a></nav>'));
        expect(result, isNot(contains('old')));
      });

      test('cross-file CSS selector not found throws', () {
        final engine = Trellis(loader: MapLoader({'tmpl': '<div>No matching elements</div>'}), cache: false);
        expect(
          () => engine.render('<div tl:insert="~{tmpl :: #missing}"></div>', {}),
          throwsA(isA<FragmentNotFoundException>()),
        );
      });

      test('cross-file expressions evaluated with CSS selector fragment', () {
        final engine = Trellis(
          loader: MapLoader({'parts': r'<div id="user"><span tl:text="${name}">x</span></div>'}),
          cache: false,
        );
        final result = engine.render('<div tl:insert="~{parts :: #user}"></div>', {'name': 'Bob'});
        expect(result, contains('<span>Bob</span>'));
      });
    });

    group('cycle detection', () {
      test('self-inclusion (A includes A) detected as cycle', () {
        final engine = Trellis(
          loader: MapLoader({'self': '<div tl:fragment="card"><div tl:insert="~{self :: card}"></div></div>'}),
          cache: false,
        );
        expect(
          () => engine.render('<div tl:insert="~{self :: card}"></div>', {}),
          throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('cycle detected'))),
        );
      });

      test('mutual cycle (A includes B, B includes A) detected', () {
        final engine = Trellis(
          loader: MapLoader({
            'a': '<div tl:fragment="fa"><div tl:insert="~{b :: fb}"></div></div>',
            'b': '<div tl:fragment="fb"><div tl:insert="~{a :: fa}"></div></div>',
          }),
          cache: false,
        );
        expect(
          () => engine.render('<div tl:insert="~{a :: fa}"></div>', {}),
          throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('cycle detected'))),
        );
      });

      test('cycle path included in error message', () {
        final engine = Trellis(
          loader: MapLoader({
            'x': '<div tl:fragment="fx"><div tl:insert="~{y :: fy}"></div></div>',
            'y': '<div tl:fragment="fy"><div tl:insert="~{x :: fx}"></div></div>',
          }),
          cache: false,
        );
        expect(
          () => engine.render('<div tl:insert="~{x :: fx}"></div>', {}),
          throwsA(
            isA<TemplateException>().having((e) => e.message, 'message', allOf(contains('x::fx'), contains('y::fy'))),
          ),
        );
      });

      test('non-cyclic deep nesting works', () {
        // A includes B includes C — no cycle, should work
        final engine = Trellis(
          loader: MapLoader({
            'a': '<div tl:fragment="fa"><span>A:<div tl:insert="~{b :: fb}"></div></span></div>',
            'b': '<div tl:fragment="fb"><span>B:<div tl:insert="~{c :: fc}"></div></span></div>',
            'c': '<div tl:fragment="fc">C</div>',
          }),
          cache: false,
        );
        final result = engine.render('<div tl:insert="~{a :: fa}"></div>', {});
        expect(result, contains('A:'));
        expect(result, contains('B:'));
        expect(result, contains('C'));
      });

      test('same fragment used in multiple places (non-cyclic) works', () {
        // Using same fragment twice is not a cycle
        final engine = Trellis(loader: MapLoader({'shared': '<span tl:fragment="item">Item</span>'}), cache: false);
        final result = engine.render(
          '<div tl:insert="~{shared :: item}"></div>'
          '<section tl:insert="~{shared :: item}"></section>',
          {},
        );
        expect(result, contains('<div>Item</div>'));
        expect(result, contains('<section>Item</section>'));
      });

      test('depth guard still triggers for non-cyclic deep nesting beyond limit', () {
        // Build a chain of 33+ unique fragments (no cycle, but exceeds depth)
        final templates = <String, String>{};
        for (var i = 0; i < 34; i++) {
          final next = i < 33 ? '<div tl:insert="~{t${i + 1} :: f${i + 1}}"></div>' : 'leaf';
          templates['t$i'] = '<div tl:fragment="f$i">$next</div>';
        }
        final engine = Trellis(loader: MapLoader(templates), cache: false);
        expect(
          () => engine.render('<div tl:insert="~{t0 :: f0}"></div>', {}),
          throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('depth exceeded'))),
        );
      });
    });

    group('tl:replace pipeline short-circuit', () {
      test('no double-processing: tl:text on host not applied after tl:replace', () {
        final engine = Trellis(loader: MapLoader({}), cache: false);
        // The host has tl:text="${msg}" and tl:replace="frag". After replacement,
        // only the fragment content should appear — the host tl:text must not run.
        final result = engine.render(
          '<p tl:fragment="frag">FragContent</p>'
          '<div tl:replace="frag" tl:text="\${msg}">host</div>',
          {'msg': 'SHOULD_NOT_APPEAR'},
        );
        expect(result, contains('FragContent'));
        expect(result, isNot(contains('SHOULD_NOT_APPEAR')));
        expect(result, isNot(contains('tl:replace')));
      });
    });
  });
}
