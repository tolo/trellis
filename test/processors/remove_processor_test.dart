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
