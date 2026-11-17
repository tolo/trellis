import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Text processor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    group('tl:text', () {
      test('replaces placeholder text with value', () {
        final result = render('<p tl:text="\${name}">placeholder</p>', {'name': 'Alice'});
        expect(result, contains('<p>Alice</p>'));
      });

      test('escapes HTML special characters', () {
        final result = render('<p tl:text="\${val}">x</p>', {'val': '<script>alert("xss")</script>'});
        expect(result, contains('&lt;script&gt;'));
        expect(result, isNot(contains('<script>')));
      });

      test('escapes ampersand', () {
        final result = render('<p tl:text="\${val}">x</p>', {'val': 'a&b'});
        expect(result, contains('a&amp;b'));
      });

      test('quotes in text content are safe (HTML5 text escaping)', () {
        // In HTML5 text content, " and ' do not need escaping (only < > & do).
        // package:html correctly follows this spec.
        final result = render('<p tl:text="\${val}">x</p>', {'val': 'a"b\'c'});
        expect(result, contains('a"b\'c'));
      });

      test('null renders empty string', () {
        final result = render('<p tl:text="\${missing}">placeholder</p>', {});
        expect(result, contains('<p></p>'));
      });

      test('non-string value calls toString()', () {
        final result = render('<p tl:text="\${num}">x</p>', {'num': 42});
        expect(result, contains('<p>42</p>'));
      });

      test('boolean toString', () {
        final result = render('<p tl:text="\${flag}">x</p>', {'flag': true});
        expect(result, contains('<p>true</p>'));
      });

      test('nested path expression', () {
        final result = render('<p tl:text="\${user.name}">x</p>', {
          'user': {'name': 'Bob'},
        });
        expect(result, contains('<p>Bob</p>'));
      });
    });

    group('tl:utext', () {
      test('inserts raw HTML', () {
        final result = render('<div tl:utext="\${html}">placeholder</div>', {'html': '<b>bold</b>'});
        expect(result, contains('<div><b>bold</b></div>'));
      });

      test('null renders empty element', () {
        final result = render('<div tl:utext="\${missing}">placeholder</div>', {});
        expect(result, contains('<div></div>'));
      });

      test('preserves HTML tags in output', () {
        final result = render('<div tl:utext="\${html}">x</div>', {'html': '<em>italic</em> <a href="#">link</a>'});
        expect(result, contains('<em>italic</em>'));
        expect(result, contains('<a href="#">link</a>'));
      });

      // The inserted value is output, not template code: evaluating its tl:* attributes would let any HTML that
      // reaches tl:utext read the render context and include other templates.
      group('inserted HTML is not processed', () {
        const html = r'<i tl:text="${secret}">y</i><span tl:insert="~{admin :: panel}">z</span>';
        final ctx = {'secret': 'LEAKED', 'html': html, 'cls': 'c'};
        late Trellis withAdmin;

        setUp(() {
          withAdmin = Trellis(loader: MapLoader({'admin': '<div tl:fragment="panel">ADMIN-ONLY</div>'}), cache: false);
        });

        test('tl:* attributes in the value are output verbatim', () {
          final result = withAdmin.render(r'<div tl:utext="${html}">x</div>', ctx);
          expect(result, contains('<div>$html</div>'));
          expect(result, isNot(contains('LEAKED')));
          expect(result, isNot(contains('ADMIN-ONLY')));
        });

        for (final directive in [r'tl:class="${cls}"', r'tl:attr="title=${cls}"', 'tl:remove="none"']) {
          test('stays verbatim alongside $directive', () {
            final result = withAdmin.render('<div tl:utext="\${html}" $directive>x</div>', ctx);
            expect(result, contains(html));
            expect(result, isNot(contains('LEAKED')));
            expect(result, isNot(contains('ADMIN-ONLY')));
          });
        }

        test('stays verbatim through a tl:block host', () {
          final result = withAdmin.render(r'<p><tl:block tl:utext="${html}">x</tl:block></p>', ctx);
          expect(result, contains('<p>$html</p>'));
        });

        // tl:insert processes the inserted fragment itself; a tl:utext that keeps the content must not process it
        // again, or HTML an inner tl:utext inserted is evaluated on the second pass.
        for (final keep in ['tl:utext="_"', r'tl:text="_" tl:utext="${cls}"']) {
          test('stays verbatim inside a fragment inserted by a host with $keep', () {
            final result = withAdmin.render(
              '<div tl:fragment="u"><span tl:utext="\${html}"></span></div><p tl:insert="u" $keep></p>',
              ctx,
            );
            expect(result, contains('<p><span>$html</span></p>'));
            expect(result, isNot(contains('LEAKED')));
            expect(result, isNot(contains('ADMIN-ONLY')));
          });
        }
      });
    });

    group('attribute removal', () {
      test('tl:text attribute removed from output', () {
        final result = render('<p tl:text="\${name}">x</p>', {'name': 'Alice'});
        expect(result, isNot(contains('tl:text')));
      });

      test('tl:utext attribute removed from output', () {
        final result = render('<div tl:utext="\${html}">x</div>', {'html': '<b>hi</b>'});
        expect(result, isNot(contains('tl:utext')));
      });
    });

    group('no-op sentinel _', () {
      test('tl:text="_" leaves element text unchanged', () {
        final result = render('<p tl:text="_">original</p>', {});
        expect(result, contains('>original</p>'));
        expect(result, isNot(contains('tl:text')));
      });

      test('tl:utext="_" leaves element content unchanged', () {
        final result = render('<div tl:utext="_"><b>original</b></div>', {});
        expect(result, contains('<b>original</b>'));
        expect(result, isNot(contains('tl:utext')));
      });

      test('tl:utext="_" still processes the template content it keeps', () {
        final result = render(r'<div tl:utext="_"><b tl:text="${name}">x</b></div>', {'name': 'Alice'});
        expect(result, contains('<div><b>Alice</b></div>'));
      });

      test('tl:utext defers to tl:text="_" and the kept template content is processed', () {
        final result = render(r'<div tl:text="_" tl:utext="${html}"><b tl:text="${name}">x</b></div>', {
          'name': 'Alice',
          'html': '<i>raw</i>',
        });
        expect(result, contains('<div><b>Alice</b></div>'));
      });

      for (final mode in ['body', 'all-but-first']) {
        test('tl:utext="_" does not process the children tl:remove="$mode" discards', () {
          final result = render('<div tl:utext="_" tl:remove="$mode"><i>kept</i><b tl:insert="missing"></b></div>', {});
          expect(result, contains(mode == 'body' ? '<div></div>' : '<div><i>kept</i></div>'));
        });
      }

      test(r'tl:text="${x}" where x is "_" is NOT no-op', () {
        final result = render(r'<p tl:text="${x}">original</p>', {'x': '_'});
        expect(result, contains('>_</p>'));
        expect(result, isNot(contains('original')));
      });
    });
  });
}
