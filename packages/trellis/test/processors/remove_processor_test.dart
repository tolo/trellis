import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Remove processor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    group('mode: all', () {
      test('removes element and children', () {
        final result = render('<div><p tl:remove="all">gone</p><p>kept</p></div>', {});
        expect(result, isNot(contains('gone')));
        expect(result, contains('kept'));
      });

      test('static keyword without quotes', () {
        final result = render('<div><p tl:remove="all">gone</p></div>', {});
        expect(result, isNot(contains('gone')));
        expect(result, isNot(contains('<p>')));
      });

      test('quoted expression', () {
        final result = render("<div><p tl:remove=\"'all'\">gone</p></div>", {});
        expect(result, isNot(contains('gone')));
      });
    });

    group('mode: body', () {
      test('keeps element tag, removes children', () {
        final result = render('<div><p tl:remove="body"><span>child</span></p></div>', {});
        expect(result, contains('<p></p>'));
        expect(result, isNot(contains('child')));
        expect(result, isNot(contains('span')));
      });
    });

    group('mode: tag', () {
      test('removes tag, promotes children to parent', () {
        final result = render('<div><p tl:remove="tag"><span>inner</span></p></div>', {});
        expect(result, contains('<span>inner</span>'));
        expect(result, isNot(contains('<p>')));
      });

      test('promotes text nodes too', () {
        final result = render('<div><p tl:remove="tag">text<span>elem</span></p></div>', {});
        expect(result, contains('text'));
        expect(result, contains('<span>elem</span>'));
        expect(result, isNot(contains('<p>')));
      });

      test('processes the children it keeps', () {
        final result = render(r'<main><div tl:remove="tag">a<p><b tl:text="${x}">raw</b></p></div></main>', {'x': 1});
        expect(result, contains('<main>a<p><b>1</b></p></main>'));
      });

      test('processes children with a tl:with on the same element', () {
        final result = render(r'<main><div tl:with="y=${x}" tl:remove="tag"><b tl:text="${y}">raw</b></div></main>', {
          'x': 1,
        });
        expect(result, contains('<main><b>1</b></main>'));
      });

      test('processes children that expand with tl:each', () {
        final result = render(r'<main><div tl:remove="tag"><i tl:each="v : ${vs}" tl:text="${v}">x</i></div></main>', {
          'vs': ['a', 'b'],
        });
        expect(result, contains('<main><i>a</i><i>b</i></main>'));
      });

      test('processes children when an expression resolves to tag', () {
        final result = render(
          r'''<main><div tl:remove="${u} ? 'tag' : 'none'"><b tl:text="${x}">raw</b></div></main>''',
          {'u': true, 'x': 1},
        );
        expect(result, contains('<main><b>1</b></main>'));
      });

      test('processes the children of each tl:each item it unwraps', () {
        final result = render(r'<main><div tl:each="v : ${vs}" tl:remove="tag"><b tl:text="${v}">x</b></div></main>', {
          'vs': ['a', 'b'],
        });
        expect(result, contains('<main><b>a</b><b>b</b></main>'));
      });

      test('leaves tl:utext output unprocessed', () {
        final result = render(r'<main><div tl:utext="${html}" tl:remove="tag">x</div></main>', {
          'html': r'<b tl:text="${secret}">safe</b>',
          'secret': 'LEAKED',
        });
        expect(result, contains(r'<main><b tl:text="${secret}">safe</b></main>'));
      });

      test('processes tl:insert content once when it unwraps the host', () {
        final result =
            Trellis(
              loader: MapLoader({'parts': r'<p tl:fragment="f"><span tl:utext="${html}">x</span></p>'}),
              cache: false,
            ).render('<main><div tl:insert="~{parts :: f}" tl:remove="tag"></div></main>', {
              'html': r'<b tl:text="${secret}">safe</b>',
              'secret': 'LEAKED',
            });
        expect(result, contains(r'<main><span><b tl:text="${secret}">safe</b></span></main>'));
      });

      group('on a fragment root', () {
        const parts = r'<div tl:fragment="f" tl:remove="tag"><b tl:text="${x}">raw</b></div>';
        late Trellis e;

        setUp(() {
          e = Trellis(loader: MapLoader({'parts': parts}), cache: false);
        });

        test('invoked with tl:insert', () {
          final result = e.render('<main><section tl:insert="~{parts :: f}">old</section></main>', {'x': 1});
          expect(result, contains('<main><section><b>1</b></section></main>'));
        });

        test('invoked with tl:replace', () {
          final result = e.render('<main><section tl:replace="~{parts :: f}">old</section></main>', {'x': 1});
          expect(result, contains('<main><b>1</b></main>'));
        });
      });
    });

    group('mode: all-but-first', () {
      test('keeps first element child, removes rest', () {
        final result = render('<div tl:remove="all-but-first"><p>first</p><p>second</p><p>third</p></div>', {});
        expect(result, contains('first'));
        expect(result, isNot(contains('second')));
        expect(result, isNot(contains('third')));
      });

      test('single child preserved', () {
        final result = render('<div tl:remove="all-but-first"><p>only</p></div>', {});
        expect(result, contains('only'));
      });

      test('no children — no change', () {
        final result = render('<div tl:remove="all-but-first"></div>', {});
        expect(result, contains('<div></div>'));
      });
    });

    group('mode: none', () {
      test('no change', () {
        final result = render('<div tl:remove="none"><p>kept</p></div>', {});
        expect(result, contains('<p>kept</p>'));
      });
    });

    group('dynamic expression', () {
      test('ternary resolves to all — element removed', () {
        final result = render(r'''<div><p tl:remove="${hide} ? 'all' : 'none'">content</p></div>''', {'hide': true});
        expect(result, isNot(contains('content')));
      });

      test('ternary resolves to none — element kept', () {
        final result = render(r'''<div><p tl:remove="${hide} ? 'all' : 'none'">content</p></div>''', {'hide': false});
        expect(result, contains('content'));
      });
    });

    group('error handling', () {
      test('invalid mode throws TemplateException', () {
        expect(
          () => render("<div tl:remove=\"'invalid'\">x</div>", {}),
          throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('Invalid tl:remove'))),
        );
      });
    });

    group('attribute cleanup', () {
      test('tl:remove not in output for mode body', () {
        final result = render('<div tl:remove="body"><p>x</p></div>', {});
        expect(result, isNot(contains('tl:remove')));
      });

      test('tl:remove not in output for mode none', () {
        final result = render('<div tl:remove="none"><p>x</p></div>', {});
        expect(result, isNot(contains('tl:remove')));
      });

      test('tl:remove not in output for mode all-but-first', () {
        final result = render('<div tl:remove="all-but-first"><p>x</p></div>', {});
        expect(result, isNot(contains('tl:remove')));
      });
    });

    group('interaction with other processors', () {
      test('tl:text + tl:remove="body" — text set then cleared', () {
        final result = render(r'<p tl:text="${val}" tl:remove="body">default</p>', {'val': 'hello'});
        // tl:text runs first (step 5), sets content to "hello"
        // tl:remove="body" runs later (step 7), clears all children
        expect(result, contains('<p></p>'));
        expect(result, isNot(contains('hello')));
      });
    });
  });
}
