import 'package:test/test.dart';
import 'package:trellis/testing.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis/src/processors/fragment_processor.dart' show parseFragmentDef;

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

  group('tl:slot', () {
    String render(String template, {Map<String, String> files = const {}, Map<String, dynamic> context = const {}}) {
      final out = testEngine(templates: files).render(template, context);
      return out.replaceFirst('<html><head></head><body>', '').replaceFirst('</body></html>', '');
    }

    Matcher throwsSlotError(Pattern message) =>
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains(message)));

    const dlg = '<dialog tl:fragment="dlg"><footer tl:slot="footer"><button>Close</button></footer></dialog>';

    group('caller-side filling', () {
      test('named slot filled: region kept, marker discarded, fallback gone [S01]', () {
        final out = render('$dlg<div tl:replace="dlg"><span tl:slot="footer"><b>Delete</b></span></div>');
        expect(out, endsWith('<dialog><footer><b>Delete</b></footer></dialog>'));
        expect(out, isNot(contains('<span')));
        expect(out, isNot(contains('tl:slot')));
        // Only the fragment definition itself still shows the fallback.
        expect('Close'.allMatches(out), hasLength(1));
      });

      test('unfilled named slot keeps fallback; pretty-printed whitespace is not anonymous content [S02]', () {
        final out = render(
          '<div tl:fragment="dlg"><div tl:slot>Body</div><footer tl:slot="footer">F</footer></div>'
          '<div tl:replace="dlg">\n  <span tl:slot="footer">Mine</span>\n</div>',
        );
        expect(out, endsWith('<div><div>Body</div><footer>Mine</footer></div>'));
      });

      test('anonymous slot filled by unmarked children [S03]', () {
        final out = render(
          '<div tl:fragment="dlg"><div tl:slot>Body</div></div>'
          '<div tl:replace="dlg"><p>This cannot be undone.</p></div>',
        );
        expect(out, endsWith('<div><div><p>This cannot be undone.</p></div></div>'));
      });

      test('tl:insert keeps its host and grafts the same way', () {
        final out = render('$dlg<section tl:insert="dlg"><i tl:slot="footer">X</i></section>');
        expect(out, endsWith('<section><footer>X</footer></section>'));
      });

      test('multiple markers for one slot concatenate in document order [S05]', () {
        final out = render(
          '<div tl:fragment="f"><footer tl:slot="footer">-</footer></div>'
          '<div tl:replace="f"><span tl:slot="footer">A</span><span tl:slot="footer">B</span></div>',
        );
        expect(out, endsWith('<div><footer>AB</footer></div>'));
      });

      test('tl:block marker is wrapper-free; a plain tl:block is whole anonymous content [S06]', () {
        final out = render(
          '<div tl:fragment="f"><main tl:slot>Body</main><footer tl:slot="footer">-</footer></div>'
          '<div tl:replace="f"><tl:block tl:slot="footer"><button>Del</button><button>Cancel</button></tl:block>'
          '<tl:block><em>x</em></tl:block></div>',
        );
        expect(
          out,
          endsWith('<div><main><em>x</em></main><footer><button>Del</button><button>Cancel</button></footer></div>'),
        );
      });

      test('a marker nested deeper than a direct child is inert [S07]', () {
        final out = render(
          '<div tl:fragment="f"><main tl:slot>Body</main><footer tl:slot="footer">Fallback</footer></div>'
          '<div tl:replace="f"><div><span tl:slot="footer">X</span></div></div>',
        );
        expect(out, endsWith('<div><main><div><span>X</span></div></main><footer>Fallback</footer></div>'));
        expect(out, isNot(contains('tl:slot')));
      });

      test('a comment on the host neither fills nor displaces the anonymous fallback', () {
        final out = render(
          '<div tl:fragment="f"><main tl:slot>Body</main></div><div tl:replace="f"><!-- body goes here --></div>',
        );
        expect(out, endsWith('<div><main>Body</main></div>'));
      });

      test('a truthy marker with no children clears the fallback', () {
        final out = render(
          '<div tl:fragment="f"><footer tl:slot="footer">Fallback</footer></div>'
          '<div tl:replace="f"><span tl:slot="footer"></span></div>',
        );
        expect(out, endsWith('<div><footer></footer></div>'));
      });

      test('a non-breaking space is anonymous content, not pretty-printing whitespace', () {
        final out = render('<div tl:fragment="f"><main tl:slot>Body</main></div><div tl:replace="f">&nbsp;</div>');
        expect(out, endsWith('<div><main>&nbsp;</main></div>'));
      });
    });

    group('marker gating', () {
      const field = '<label tl:fragment="field(label)"><span tl:slot="hint">Default hint</span></label>';

      String field_({required bool showHint, String attr = 'tl:if'}) => render(
        '$field<div tl:replace="field(\'Email\')"><span tl:slot="hint" $attr="\${showHint}">Custom</span></div>',
        context: {'showHint': showHint},
      );

      test('tl:if gates the contribution [S08]', () {
        expect(field_(showHint: false), endsWith('<label><span>Default hint</span></label>'));
        expect(field_(showHint: true), endsWith('<label><span>Custom</span></label>'));
      });

      test('tl:unless inverts [S08]', () {
        expect(field_(showHint: true, attr: 'tl:unless'), endsWith('<span>Default hint</span></label>'));
        expect(field_(showHint: false, attr: 'tl:unless'), endsWith('<span>Custom</span></label>'));
      });

      test('gating uses engine truthiness: empty string is truthy', () {
        final out = render(
          '$field<div tl:replace="field(\'E\')"><span tl:slot="hint" tl:if="\${v}">Custom</span></div>',
          context: {'v': ''},
        );
        expect(out, endsWith('<span>Custom</span></label>'));
      });

      test('gating sees fragment parameters', () {
        final out = render(
          '$field<div tl:replace="field(\'Email\')"><span tl:slot="hint" tl:if="\${label == \'Email\'}">Hit</span></div>',
        );
        expect(out, endsWith('<span>Hit</span></label>'));
      });

      test('bare marker is the only way to gate anonymous content [S16]', () {
        String run(bool show) => render(
          '<div tl:fragment="dlg"><div tl:slot>Body</div></div>'
          '<div tl:replace="dlg"><span tl:slot tl:if="\${show}">Custom</span></div>',
          context: {'show': show},
        );
        expect(run(false), endsWith('<div><div>Body</div></div>'));
        expect(run(true), endsWith('<div><div>Custom</div></div>'));
      });
    });

    group('anonymous slot via bare marker', () {
      const anon = '<div tl:fragment="dlg"><div tl:slot>Body</div></div>';

      test('bare marker fills the anonymous slot with the marker discarded [S16]', () {
        final out = render('$anon<div tl:replace="dlg"><span tl:slot><b>Hello</b></span></div>');
        expect(out, endsWith('<div><div><b>Hello</b></div></div>'));
      });

      test('bare marker and unmarked children concatenate in document order [S16]', () {
        final out = render('$anon<div tl:replace="dlg"><i>1</i><span tl:slot>2</span><i>3</i></div>');
        expect(out, endsWith('<div><div><i>1</i>2<i>3</i></div></div>'));
      });
    });

    group('scope', () {
      test('slot content resolves fragment parameters and caller variables', () {
        final out = render(
          '<div tl:fragment="card(title)"><div tl:slot>-</div></div>'
          '<div tl:replace="card(\'T\')"><p tl:text="\${title + who}">x</p></div>',
          context: {'who': '!'},
        );
        expect(out, endsWith('<div><div><p>T!</p></div></div>'));
      });

      test('region nested inside a fragment tl:each sees the loop variable [S09]', () {
        final out = render(
          '<table tl:fragment="tbl(rows)"><tbody><tr tl:each="r : \${rows}"><td tl:slot="cell">-</td></tr></tbody></table>'
          '<div tl:replace="tbl(\${rows})"><tl:block tl:slot="cell"><span tl:text="\${r.n}">x</span></tl:block></div>',
          context: {
            'rows': [
              {'n': 'a'},
              {'n': 'b'},
            ],
          },
        );
        expect(
          out,
          endsWith('<table><tbody><tr><td><span>a</span></td></tr><tr><td><span>b</span></td></tr></tbody></table>'),
        );
        expect(out, isNot(contains('tl:slot')));
      });

      test('region co-located on the fragment tl:each element [S09]', () {
        final out = render(
          '<table><tbody tl:fragment="rows(items)"><tr tl:each="r : \${items}" tl:slot="row"><td>-</td></tr></tbody></table>'
          '<table><tbody tl:replace="rows(\${rows})"><tr tl:slot="row"><td tl:text="\${r.n}">x</td></tr></tbody></table>',
          context: {
            'rows': [
              {'n': 'a'},
              {'n': 'b'},
            ],
          },
        );
        // The fixture's own definition table renders its fallback; the invoking table follows it.
        expect(out, endsWith('<table><tbody><tr><td>a</td></tr><tr><td>b</td></tr></tbody></table>'));
        expect(out, isNot(contains('tl:slot')));
      });

      test('cross-file invocation fills slots and resolves slot content against the included file first [S10]', () {
        final out = render(
          '<div tl:fragment="btn"><b>caller btn</b></div>'
          '<div tl:replace="~{ui/components.html :: dialog(\'Delete?\')}">'
          '<tl:block tl:slot="footer"><div tl:replace="btn"></div></tl:block></div>',
          files: {
            'ui/components.html':
                '<dialog tl:fragment="dialog(title)"><h2 tl:text="\${title}">T</h2>'
                '<footer tl:slot="footer">F</footer></dialog>'
                '<i tl:fragment="btn">file btn</i>',
          },
        );
        expect(out, endsWith('<dialog><h2>Delete?</h2><footer><i>file btn</i></footer></dialog>'));
      });
    });

    group('nested regions', () {
      const panel =
          '<section tl:fragment="panel"><div tl:slot="outer"><span tl:slot="inner">Inner fallback</span></div></section>';

      test('unfilled: nested region is fallback content, attribute stripped [S15a]', () {
        expect(
          render('$panel<div tl:replace="panel"></div>'),
          endsWith('<section><div><span>Inner fallback</span></div></section>'),
        );
      });

      test('filling the outer region replaces the nested fallback wholesale [S15b]', () {
        final out = render('$panel<div tl:replace="panel"><b tl:slot="outer"><p>X</p></b></div>');
        expect(out, endsWith('<section><div><p>X</p></div></section>'));
      });

      test('the nested region is not a declaration: filling it throws [S15c]', () {
        expect(
          () => render('$panel<div tl:replace="panel"><b tl:slot="inner">Y</b></div>'),
          throwsSlotError('"inner"'),
        );
      });

      test('the same name at top level and inside a fallback is not a duplicate [S15]', () {
        final out = render(
          '<section tl:fragment="p"><i tl:slot="inner">top</i><div tl:slot="outer"><i tl:slot="inner">nested</i></div></section>'
          '<div tl:replace="p"><b tl:slot="inner">Y</b></div>',
        );
        expect(out, endsWith('<section><i>Y</i><div><i>nested</i></div></section>'));
      });
    });

    group('errors', () {
      test('marker naming an undeclared slot throws [S11]', () {
        expect(
          () => render('$dlg<div tl:replace="dlg"><span tl:slot="body">X</span></div>'),
          throwsSlotError('"body"'),
        );
      });

      test('markers throw on selector-targeted and tag-name invocation [S11]', () {
        expect(
          () => render('<nav id="main-nav">N</nav><div tl:replace="#main-nav"><span tl:slot="x">X</span></div>'),
          throwsSlotError('"x"'),
        );
        expect(
          () => render('<footer>F</footer><div tl:replace="footer"><span tl:slot="x">X</span></div>'),
          throwsSlotError('"x"'),
        );
        expect(
          () => render('<nav id="main-nav">N</nav><div tl:replace="#main-nav"><span tl:slot>X</span></div>'),
          throwsSlotError('anonymous'),
        );
      });

      test('a marker throws even when its gate is false', () {
        expect(
          () => render('$dlg<div tl:replace="dlg"><span tl:slot="nope" tl:if="\${false}">X</span></div>'),
          throwsSlotError('"nope"'),
        );
      });

      test('duplicate slot names in a definition throw at invocation [S12]', () {
        expect(
          () => render('<div tl:fragment="f"><i tl:slot="x"></i><b tl:slot="x"></b></div><div tl:replace="f"></div>'),
          throwsSlotError('Duplicate tl:slot "x"'),
        );
      });

      test('duplicate anonymous slots throw [S12]', () {
        expect(
          () => render('<div tl:fragment="f"><i tl:slot></i><b tl:slot></b></div><div tl:replace="f"></div>'),
          throwsSlotError('Duplicate anonymous'),
        );
      });

      test('tl:slot on the tl:fragment root throws [S12]', () {
        expect(
          () => render('<div tl:fragment="f" tl:slot="x">F</div><div tl:replace="f"></div>'),
          throwsSlotError('fragment root'),
        );
      });

      test('an uninvoked malformed definition does not throw (AC-15)', () {
        expect(render('<div tl:fragment="f"><i tl:slot="x"></i><b tl:slot="x"></b></div>'), contains('<i></i>'));
      });

      test('another tl:* on a marker throws [S13]', () {
        expect(
          () => render('$dlg<div tl:replace="dlg"><span tl:slot="footer" tl:each="i : \${[1]}">X</span></div>'),
          throwsSlotError('tl:each'),
        );
      });

      test('a bare marker on a fragment with no anonymous slot throws; unmarked children are discarded [S17]', () {
        expect(() => render('$dlg<div tl:replace="dlg"><span tl:slot>X</span></div>'), throwsSlotError('anonymous'));
        final out = render('$dlg<div tl:replace="dlg"><p>X</p></div>');
        expect(out, endsWith('<dialog><footer><button>Close</button></footer></dialog>'));
      });
    });

    group('no-slot fragments keep today\'s semantics', () {
      // Expected strings were captured from the engine before this change (see the story's baseline run).
      const cases = <(String, String, String)>[
        (
          'tl:insert same-file',
          '<div tl:fragment="menu"><a>L</a></div><main><section tl:insert="menu">old <b>content</b></section></main>',
          '<div><a>L</a></div><main><section><a>L</a></section></main>',
        ),
        (
          'tl:replace same-file',
          '<div tl:fragment="tag"><i>T</i></div><div tl:replace="tag">old <b>x</b></div>',
          '<div><i>T</i></div><div><i>T</i></div>',
        ),
        (
          'tl:replace pretty-printed host',
          '<div tl:fragment="tag"><i>T</i></div>\n<div tl:replace="tag">\n  <p>old</p>\n</div>',
          '<div><i>T</i></div>\n<div><i>T</i></div>',
        ),
        (
          'tl:insert with args',
          '<div tl:fragment="card(t)"><h2 tl:text="\${t}">x</h2></div><div tl:insert="card(\'A\')">old<span>z</span></div>',
          '<div><h2>A</h2></div>',
        ),
        (
          '#id selector replace',
          '<aside id="nav"><b>N</b></aside><div tl:replace="#nav">old <u>x</u></div>',
          '<aside id="nav"><b>N</b></aside><aside id="nav"><b>N</b></aside>',
        ),
        (
          '#id selector insert',
          '<aside id="nav"><b>N</b></aside><div tl:insert="#nav">old <u>x</u></div>',
          '<aside id="nav"><b>N</b></aside><div><b>N</b></div>',
        ),
        (
          'tag-name replace',
          '<footer><i>F</i></footer><div tl:replace="footer">old</div>',
          '<footer><i>F</i></footer><footer><i>F</i></footer>',
        ),
        (
          'tag-name insert',
          '<footer><i>F</i></footer><div tl:insert="footer">old</div>',
          '<footer><i>F</i></footer><div><i>F</i></div>',
        ),
      ];
      for (final (name, template, expected) in cases) {
        test(name, () => expect(render(template), expected));
      }

      final files = {
        'ui.html':
            '<nav tl:fragment="menu"><a>Link</a></nav><div tl:fragment="card(t)"><h2 tl:text="\${t}">x</h2></div>'
            '<aside id="side">Side</aside>',
      };
      const crossCases = <(String, String, String)>[
        (
          'cross-file insert',
          '<section tl:insert="~{ui.html :: menu}">old</section>',
          '<section><a>Link</a></section>',
        ),
        (
          'cross-file replace with args',
          '<div tl:replace="~{ui.html :: card(\'B\')}">old <em>x</em></div>',
          '<div><h2>B</h2></div>',
        ),
        ('cross-file selector', '<div tl:replace="~{ui.html :: #side}">old</div>', '<aside id="side">Side</aside>'),
      ];
      for (final (name, template, expected) in crossCases) {
        test(name, () => expect(render(template, files: files), expected));
      }
    });

    group('natural-template degradation', () {
      const component =
          '<label tl:fragment="field(label)" class="trellis-field">\n'
          '  <span tl:text="\${label}">Label</span>\n'
          '  <input class="trellis-field-input" type="text">\n'
          '  <span class="trellis-field-hint" tl:slot="hint">Hint fallback</span>\n'
          '</label>';
      const application =
          '<div tl:replace="~{ui/components.html :: field(\'Email\')}" type="email">\n'
          '  <span tl:slot="hint">We never share your email.</span>\n'
          '</div>';

      test('both sources validate and show their placeholder text unprocessed [S14]', () {
        expect(component, isValidTemplate());
        expect(application, isValidTemplate());
        expect(component, contains('Hint fallback'));
        expect(application, contains('We never share your email.'));
      });

      test('the pair renders end to end', () {
        final out = render(application, files: {'ui/components.html': component});
        expect(out, contains('<span class="trellis-field-hint">We never share your email.</span>'));
        expect(out, isNot(contains('Hint fallback')));
      });

      test('a stray tl:slot outside any invocation is stripped, fallback kept [S14]', () {
        final out = testEngine().renderFragment(
          component.replaceFirst('field(label)', 'field'),
          fragment: 'field',
          context: {'label': 'Email'},
        );
        expect(out, contains('<span class="trellis-field-hint">Hint fallback</span>'));
        expect(out, isNot(contains('tl:slot')));
      });
    });
  });
  group('rest parameter', () {
    String render(String template, {Map<String, String> files = const {}, Map<String, dynamic> context = const {}}) {
      final out = testEngine(templates: files).render(template, context);
      return out.replaceFirst('<html><head></head><body>', '').replaceFirst('</body></html>', '');
    }

    Matcher throwsTemplate(Pattern message) =>
        throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains(message)));

    const field =
        '<label tl:fragment="field(label, name, ...attrs)">'
        r'<input type="text" tl:attr="name=${name}" tl:attrs="${attrs}"></label>';
    const card = r'<article tl:fragment="card(title, ...attrs)" tl:attrs="${attrs}" tl:text="${title}">T</article>';
    const inner =
        r'<article tl:fragment="inner(title, ...attrs)"><span tl:attrs="${attrs}" tl:text="${title}">T</span></article>';

    group('definition collection (TI01)', () {
      test('the rest entry stays the literal last paramNames entry', () {
        expect(parseFragmentDef('card(a, ...rest)').$2, ['a', '...rest']);
      });

      for (final bad in ['card(...a, ...b)', 'card(...a, b)']) {
        test('$bad throws naming the fragment, same-file, even when nothing invokes it', () {
          expect(() => render('<p tl:fragment="$bad">x</p>'), throwsTemplate('Fragment "card"'));
        });

        test('$bad throws cross-file, only once an invocation resolves the file', () {
          final files = {'ui.html': '<p tl:fragment="$bad">x</p><i tl:fragment="other">y</i>'};
          expect(render('<b>no invocation</b>', files: files), contains('no invocation'));
          expect(
            () => render('<div tl:replace="~{ui.html :: other}"></div>', files: files),
            throwsTemplate('Fragment "card"'),
          );
        });
      }

      test('a bare ... without a name throws', () {
        expect(() => render('<p tl:fragment="card(...)">x</p>'), throwsTemplate('needs a name'));
      });
    });

    group('host attribute capture (TI02, TI03)', () {
      test('caller attributes reach the inner element and overwrite the component literal [S01]', () {
        final out = render(
          '$field<div tl:replace="field(\'Email\', \'email\')" type="email" required hx-post="/validate"></div>',
        );
        expect(out, contains('<label><input type="email" required="" hx-post="/validate" name="email"></label>'));
        expect(out, isNot(contains('tl:')));
      });

      test('the rest name is the author-chosen one, never the literal ...name', () {
        final out = render(
          r'<i tl:fragment="f(...props)" tl:text="${props.a}">x</i><b tl:replace="f" a="1" b="2"></b>',
        );
        expect(out, contains('<i>1</i>'));
      });

      test('a tl:insert host keeps its directives\' results, applied once, and forwards them [S02]', () {
        // tl:insert keeps only the fragment's children, so the spread sits on an inner element to be observable.
        final template = '$inner<div class="wrap" tl:attr="data-id=\${item.id}" tl:insert="inner(\'Report\')"></div>';
        final out = render(
          template,
          context: {
            'item': {'id': 7},
          },
        );
        expect(out, contains('<div class="wrap" data-id="7"><span class="wrap" data-id="7">Report</span></div>'));
        expect(out, isNot(contains('tl:')));
      });

      test('a tl:replace host yields the identical fragment root [S02]', () {
        final template = '$card<div class="wrap" tl:attr="data-id=\${item.id}" tl:replace="card(\'Report\')"></div>';
        final out = render(
          template,
          context: {
            'item': {'id': 7},
          },
        );
        expect(out, endsWith('<article class="wrap" data-id="7">Report</article>'));
      });

      test('the host\'s own tl:attrs is forwarded in the step-0 merge order [S03]', () {
        final extra = {'data-id': 7, 'class': 'hi'};
        final out = render(
          '$card<div tl:replace="card(\'Report\')" class="wrap" tl:attrs="\${extra}"></div>',
          context: {'extra': extra},
        );
        expect(out, endsWith('<article class="wrap hi" data-id="7">Report</article>'));
      });

      test('from a tl:insert host the same entries also land on the surviving host [S03]', () {
        final out = render(
          '$inner<div tl:insert="inner(\'Report\')" class="wrap" tl:attrs="\${extra}"></div>',
          context: {
            'extra': {'data-id': 7, 'class': 'hi'},
          },
        );
        expect(out, contains('<div class="wrap hi" data-id="7"><span class="wrap hi" data-id="7">Report</span></div>'));
      });

      test('single shared merge order: shorthand overrides a spread entry, tl:* never forwarded', () {
        final out = render(
          '<i tl:fragment="f(...a)" tl:attrs="\${a}">x</i>'
          '<b tl:replace="f" class="a" hx-get="/x" disabled tl:attrs="\${m}" tl:attr="data-id=\${id}" tl:class="\${cls}"></b>',
          context: {
            'm': {'data-role': 'r', 'class': 'spread'},
            'id': 3,
            'cls': 'shorthand',
          },
        );
        expect(out, contains('<i class="shorthand" hx-get="/x" disabled="" data-role="r" data-id="3">x</i>'));
        expect(out, isNot(contains('tl:')));
      });

      test('a null attr value removes the attribute from the forwarded map', () {
        final out = render(
          '<i tl:fragment="f(...a)" tl:attrs="\${a}">x</i><b tl:replace="f" tl:attr="title=\${none}" title="t"></b>',
          context: {'none': null},
        );
        expect(out, contains('<i>x</i>'));
      });

      test('a host with no forwardable attributes yields an empty map in strict mode [S04]', () {
        final out = render(
          '<i tl:fragment="f(...a)" tl:attrs="\${a}" id="own">x</i><b tl:replace="f" tl:if="\${show}"></b>',
          context: {'show': true},
        );
        expect(out, contains('<i id="own">x</i>'));
      });
    });

    group('activation and misuse (TI04)', () {
      test('a third positional argument throws, not overwriting the forwarded map [S05]', () {
        expect(() => render('$field<div tl:replace="field(\'a\', \'b\', \'c\')"></div>'), throwsTemplate('"...attrs"'));
      });

      test('a fragment without a rest parameter still ignores extra arguments', () {
        final out = render('<b tl:fragment="g(a)" tl:text="\${a}">x</b><div tl:replace="g(1, 2, 3)"></div>');
        expect(out, contains('<b>1</b>'));
      });

      test('a non-rest invocation keeps the host\'s attribute directives inert on tl:replace', () {
        final out = render(
          '<b tl:fragment="g">frag</b><div tl:replace="g" tl:class="\${x}" tl:attr="data-x=\${x}" title="t"></div>',
          context: {'x': 'boom'},
        );
        expect(out, endsWith('<b>frag</b>'));
      });

      test('a non-rest tl:insert host keeps the ordinary attribute pass', () {
        final out = render(
          '<b tl:fragment="g">frag</b><div tl:insert="g" tl:class="\${x}" title="t"></div>',
          context: {'x': 'k'},
        );
        expect(out, contains('<div title="t" class="k">frag</div>'));
      });

      test('selector and tag-name targeting bind no rest map', () {
        final out = render('<p id="x" tl:text="\${a}">ph</p><div tl:replace="#x"></div>', context: {'a': 'ctx'});
        expect(out, contains('<p id="x">ctx</p><p id="x">ctx</p>'));
      });

      test('cross-file rest fragments capture too', () {
        final out = render(
          '<div tl:replace="~{ui.html :: field(\'L\', \'n\')}" required></div>',
          files: {'ui.html': field},
        );
        expect(out, contains('<label><input type="text" required="" name="n"></label>'));
      });
    });
  });
}
