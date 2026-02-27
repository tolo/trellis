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
      test('recursive inclusion throws TemplateException at max depth', () {
        final engine = Trellis(
          loader: MapLoader({
            'recursive': '<div tl:fragment="loop"><div tl:insert="~{recursive :: loop}"></div></div>',
          }),
          cache: false,
        );
        expect(
          () => engine.render('<div tl:insert="~{recursive :: loop}"></div>', {}),
          throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('depth exceeded'))),
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
