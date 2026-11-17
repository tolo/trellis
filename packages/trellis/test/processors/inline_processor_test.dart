import 'package:html/dom.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

/// Writes a context value as the element's text, before tl:inline runs, as a custom dialect might.
class _ValueProcessor extends Processor {
  @override
  String get attribute => 'show';

  @override
  ProcessorPriority get priority => .afterIteration;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    element.nodes
      ..clear()
      ..add(Text('${context.evaluate(value, context.variables)}'));
    return true;
  }
}

void main() {
  group('Inline processor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    // tl:text, tl:utext and inline output is data, not template text: inlining it would let a value read the render
    // context.
    group('output of tl:text, tl:utext and tl:inline', () {
      const ctx = {'v': r'[[${secret}]] [(${secret})]', 'secret': 'SECRET', 'name': 'World'};

      for (final content in [r'tl:text="${v}"', r'tl:utext="${v}"', r'tl:text="${v}" tl:utext="_"']) {
        test('leaves the $content output literal', () {
          final result = render('<p $content tl:inline="text">Hello, [[\${name}]]</p>', ctx);
          expect(result, contains(r'<p>[[${secret}]] [(${secret})]</p>'));
          expect(result, isNot(contains('SECRET')));
        });
      }

      for (final content in ['tl:text="_"', 'tl:utext="_"', r'tl:text="_" tl:utext="${v}"']) {
        test('still inlines the template text $content keeps', () {
          final result = render('<p $content tl:inline="text">Hello, [[\${name}]]</p>', ctx);
          expect(result, contains('<p>Hello, World</p>'));
        });
      }

      // tl:insert processes the fragment before the host's own tl:inline runs, so output reaches the host as text.
      for (final fragment in [
        r'<span tl:fragment="f" tl:text="${v}">x</span>',
        r'<span tl:fragment="f" tl:utext="${v}">x</span>',
        r'<span tl:fragment="f"><tl:block tl:text="${v}">x</tl:block></span>',
        r'<span tl:fragment="f" tl:inline="text">[(${v})]</span>',
      ]) {
        test('leaves output a tl:insert host receives from $fragment literal', () {
          final result = render('$fragment<div tl:insert="f" tl:inline="text"></div>', ctx);
          expect(result, contains(r'<div>[[${secret}]] [(${secret})]</div>'));
          expect(result, isNot(contains('SECRET')));
        });
      }

      test('still inlines fragment template text a tl:insert host receives', () {
        final result = render(
          r'<span tl:fragment="f">Hello, [[${name}]]</span><div tl:insert="f" tl:inline="text">',
          ctx,
        );
        expect(result, contains('<div>Hello, World</div>'));
      });

      test('leaves a custom processor\'s value output literal', () {
        final custom = Trellis(loader: MapLoader({}), cache: false, processors: [_ValueProcessor()]);
        final result = custom.render(r'<p tl:show="${v}" tl:inline="text">x</p>', ctx);
        expect(result, contains(r'<p>[[${secret}]] [(${secret})]</p>'));
      });

      test('inlines template text from a cached template on every render', () {
        final cached = Trellis(loader: MapLoader({}));
        for (final name in ['A', 'B']) {
          expect(cached.render(r'<p tl:inline="text">[[${name}]]</p>', {'name': name}), contains('<p>$name</p>'));
        }
      });

      test('inlines template text of a cross-file fragment', () {
        final files = Trellis(
          loader: MapLoader({'f.html': r'<span tl:fragment="f">Hi [[${name}]]</span>'}),
          cache: false,
        );
        expect(
          files.render(r'<div tl:insert="~{f.html :: f}" tl:inline="text"></div>', ctx),
          contains('<div>Hi World</div>'),
        );
      });

      test('inlines template text of a tl:extends parent and the child\'s tl:define content', () {
        final child = Trellis(
          loader: MapLoader({
            'base.html':
                r'<html><body><p tl:inline="text">Base [[${name}]]</p><main tl:define="m" tl:inline="text">x</main>'
                '</body></html>',
          }),
          cache: false,
        );
        final result = child.render(
          r'<html tl:extends="base.html"><body><main tl:define="m">Child [[${name}]]</main></body></html>',
          ctx,
        );
        expect(result, contains('<p>Base World</p>'));
        expect(result, contains('<main>Child World</main>'));
      });

      test('still rejects an invalid mode', () {
        expect(() => render(r'<p tl:text="${v}" tl:inline="bogus"></p>', ctx), throwsA(isA<TemplateException>()));
      });
    });

    group('text mode', () {
      test('evaluates escaped inline expression', () {
        final result = render(r'<p tl:inline="text">Hello, [[${name}]]!</p>', {'name': 'World'});
        expect(result, contains('Hello, World!'));
      });

      test('multiple expressions', () {
        final result = render(r'<p tl:inline="text">[[${a}]] and [[${b}]]</p>', {'a': 'X', 'b': 'Y'});
        expect(result, contains('X and Y'));
      });

      test('unescaped inline in text mode — still HTML-escaped by Text node serializer', () {
        // In text mode, unescaped [()] skips the escape function, but the content
        // goes into a Text node which package:html serializes with HTML escaping.
        final result = render(r'<p tl:inline="text">[(${html})]</p>', {'html': '<b>bold</b>'});
        expect(result, contains('&lt;b&gt;bold&lt;/b&gt;'));
      });

      test('no expressions — unchanged', () {
        final result = render('<p tl:inline="text">No expressions here</p>', {});
        expect(result, contains('No expressions here'));
      });

      test('null value renders empty string', () {
        final result = render(r'<p tl:inline="text">[[${val}]]</p>', {});
        expect(result, contains('<p></p>'));
      });

      test('HTML special chars escaped via Text node', () {
        final result = render(r'<p tl:inline="text">[[${val}]]</p>', {'val': '<script>'});
        expect(result, contains('&lt;script&gt;'));
        expect(result, isNot(contains('<script>')));
      });

      test('integer value toString', () {
        final result = render(r'<p tl:inline="text">Count: [[${n}]]</p>', {'n': 42});
        expect(result, contains('Count: 42'));
      });
    });

    group('javascript mode', () {
      test('escapes single quotes', () {
        final result = render(
          r'''<script tl:inline="javascript">var name = '[[${name}]]';</script>''',
          {'name': "O'Brien"},
        );
        expect(result, contains(r"O\'Brien"));
      });

      test('escapes double quotes', () {
        final result = render(r'<script tl:inline="javascript">var s = "[[${s}]]";</script>', {'s': 'say "hello"'});
        expect(result, contains(r'say \"hello\"'));
      });

      test('escapes newlines', () {
        final result = render(
          r'''<script tl:inline="javascript">var s = '[[${s}]]';</script>''',
          {'s': 'line1\nline2'},
        );
        expect(result, contains(r'line1\nline2'));
      });

      test('escapes backslashes', () {
        final result = render(r'''<script tl:inline="javascript">var x = '[[${x}]]';</script>''', {'x': r'a\b'});
        expect(result, contains(r'a\\b'));
      });

      test('escapes </script to prevent breakout', () {
        final result = render(
          r'''<script tl:inline="javascript">var x = '[[${x}]]';</script>''',
          {'x': '</script>alert(1)'},
        );
        expect(result, contains(r'<\/script'));
        expect(result, isNot(contains('</script>alert')));
      });

      test('escapes tabs and carriage returns', () {
        final result = render(r'''<script tl:inline="javascript">var x = '[[${x}]]';</script>''', {'x': 'a\tb\rc'});
        expect(result, contains(r'a\tb\rc'));
      });

      test('unescaped inline — no escaping', () {
        final result = render(r'''<script tl:inline="javascript">var x = [(${x})];</script>''', {'x': "'hello'"});
        expect(result, contains("'hello'"));
      });
    });

    group('css mode', () {
      test('simple value', () {
        final result = render(r'<style tl:inline="css">.cls { color: [[${color}]]; }</style>', {'color': 'red'});
        expect(result, contains('color: red'));
      });

      test('escapes quotes', () {
        final result = render(r'''<style tl:inline="css">.cls { content: '[[${val}]]'; }</style>''', {'val': "it's"});
        expect(result, contains(r"it\'s"));
      });

      test('escapes </style to prevent breakout', () {
        final result = render(
          r'''<style tl:inline="css">.cls { content: '[[${val}]]'; }</style>''',
          {'val': '</style>'},
        );
        expect(result, contains(r'\3c /style'));
        expect(result, isNot(contains('</style>}')));
      });

      test('escapes backslashes', () {
        final result = render(r'''<style tl:inline="css">.cls { content: '[[${val}]]'; }</style>''', {'val': r'a\b'});
        expect(result, contains(r'a\\b'));
      });
    });

    group('none mode', () {
      test('preserves literal [[...]] text', () {
        final result = render(r'<p tl:inline="none">[[${name}]]</p>', {'name': 'World'});
        expect(result, contains(r'[[${name}]]'));
        expect(result, isNot(contains('World')));
      });
    });

    group('without tl:inline', () {
      test('[[...]] left untouched', () {
        final result = render(r'<p>[[${name}]]</p>', {'name': 'World'});
        expect(result, contains(r'[[${name}]]'));
        expect(result, isNot(contains('World')));
      });
    });

    group('invalid mode', () {
      test('throws TemplateException', () {
        expect(() => render('<p tl:inline="invalid">text</p>', {}), throwsA(isA<TemplateException>()));
      });
    });

    group('security', () {
      test('JS mode: script injection prevented', () {
        final result = render(
          r'''<script tl:inline="javascript">var x = '[[${x}]]';</script>''',
          {'x': '</script><script>alert(1)</script>'},
        );
        expect(result, contains(r'<\/script'));
        expect(result, isNot(contains('</script><script>')));
      });

      test('JS mode: single quote injection prevented', () {
        final result = render(
          r'''<script tl:inline="javascript">var x = '[[${x}]]';</script>''',
          {'x': "'; alert(1); '"},
        );
        expect(result, contains(r"\'; alert(1); \'"));
      });

      test('JS mode: backslash-quote injection prevented', () {
        final result = render(
          r'''<script tl:inline="javascript">var x = '[[${x}]]';</script>''',
          {'x': r'\"; alert(1); \"'},
        );
        expect(result, contains(r'\\\"'));
      });

      test('CSS mode: style breakout prevented', () {
        final result = render(
          r'''<style tl:inline="css">.cls { content: '[[${val}]]'; }</style>''',
          {'val': '</style><script>alert(1)</script>'},
        );
        expect(result, isNot(contains('</style><script>')));
      });

      test('text mode: HTML escaped via Text node serializer', () {
        final result = render(r'<p tl:inline="text">[[${val}]]</p>', {'val': '<img onerror=alert(1)>'});
        expect(result, contains('&lt;img'));
        expect(result, isNot(contains('<img')));
      });
    });

    group('attribute removal', () {
      test('tl:inline removed from output', () {
        final result = render(r'<p tl:inline="text">[[${name}]]</p>', {'name': 'x'});
        expect(result, isNot(contains('tl:inline')));
      });

      test('tl:inline="none" removed from output', () {
        final result = render(r'<p tl:inline="none">[[${name}]]</p>', {});
        expect(result, isNot(contains('tl:inline')));
      });
    });

    group('tl:text and tl:inline interaction', () {
      test('tl:text sets content, tl:inline processes inline expressions', () {
        final result = render(r'<p tl:text="|Hello [[${name}]]!|" tl:inline="text">placeholder</p>', {'name': 'World'});
        // tl:text sets content to "Hello [[World]]!" (literal sub evaluates ${name})
        // tl:inline is a no-op here since tl:text already evaluated the expression
        expect(result, contains('Hello'));
      });
    });

    group('security: closing-tag breakout prevention', () {
      test('JS mode escapes lowercase </script', () {
        final result = render(r'<script tl:inline="javascript">var s = "[[${val}]]";</script>', {
          'val': '</script><script>alert(1)</script>',
        });
        expect(result, isNot(contains('</script><script>')));
        expect(result, contains(r'<\/script'));
      });

      test('JS mode escapes mixed-case </ScRiPt (case-insensitive)', () {
        final result = render(r'<script tl:inline="javascript">var s = "[[${val}]]";</script>', {
          'val': '</ScRiPt><script>alert(1)</script>',
        });
        expect(result, isNot(contains('</ScRiPt><script>')));
        expect(result, contains(r'<\/script'));
      });

      test('JS mode escapes uppercase </SCRIPT', () {
        final result = render(r'<script tl:inline="javascript">var s = "[[${val}]]";</script>', {'val': '</SCRIPT>'});
        expect(result, isNot(contains('</SCRIPT>')));
      });

      test('CSS mode escapes lowercase </style', () {
        final result = render(r'<style tl:inline="css">.cls { content: "[[${val}]]"; }</style>', {
          'val': '</style><style>body{display:none}</style>',
        });
        expect(result, isNot(contains('</style><style>')));
        expect(result, contains(r'\3c /style'));
      });

      test('CSS mode escapes mixed-case </StYlE', () {
        final result = render(r'<style tl:inline="css">.cls { content: "[[${val}]]"; }</style>', {'val': '</StYlE>'});
        expect(result, isNot(contains('</StYlE>')));
        expect(result, contains(r'\3c /style'));
      });

      test('CSS mode escapes newlines', () {
        final result = render(r'<style tl:inline="css">.cls { content: "[[${val}]]"; }</style>', {
          'val': 'line1\nline2\r\nline3',
        });
        expect(result, isNot(matches(RegExp(r'\n|\r'))));
        expect(result, contains(r'\n'));
      });
    });

    group('expression features in inline', () {
      test('ternary expression', () {
        final result = render(r'''<p tl:inline="text">Status: [[${active} ? 'on' : 'off']]</p>''', {'active': true});
        expect(result, contains('Status: on'));
      });

      test('arithmetic expression', () {
        final result = render(r'<p tl:inline="text">Total: [[${a + b}]]</p>', {'a': 3, 'b': 4});
        expect(result, contains('Total: 7'));
      });

      test('nested member access', () {
        final result = render(r'<p tl:inline="text">Name: [[${user.name}]]</p>', {
          'user': {'name': 'Alice'},
        });
        expect(result, contains('Name: Alice'));
      });
    });
  });
}
