import 'package:html/parser.dart' as html;
import 'package:test/test.dart';
import 'package:trellis/testing.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Attribute processor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    group('shorthand attributes', () {
      test('tl:href sets href', () {
        final result = render(r'<a tl:href="${url}">link</a>', {'url': '/home'});
        expect(result, contains('href="/home"'));
        expect(result, contains('>link</a>'));
      });

      test('tl:src sets src', () {
        final result = render(r'<img tl:src="${imgUrl}">', {'imgUrl': '/img/photo.png'});
        expect(result, contains('src="/img/photo.png"'));
      });

      test('tl:value sets value', () {
        final result = render(r'<input tl:value="${val}">', {'val': 'hello'});
        expect(result, contains('value="hello"'));
      });

      test('tl:class replaces existing class', () {
        final result = render(r'<div class="old" tl:class="${cls}">x</div>', {'cls': 'new'});
        expect(result, contains('class="new"'));
        expect(result, isNot(contains('old')));
      });

      test('tl:id sets id', () {
        final result = render(r'<div tl:id="${myId}">x</div>', {'myId': 'main'});
        expect(result, contains('id="main"'));
      });

      test('multiple shorthands on same element', () {
        final result = render(r'<a tl:href="${url}" tl:class="${cls}">link</a>', {'url': '/page', 'cls': 'active'});
        expect(result, contains('href="/page"'));
        expect(result, contains('class="active"'));
      });
    });

    group('tl:attr', () {
      test('single attribute', () {
        final result = render(r'<div tl:attr="data-id=${id}">x</div>', {'id': 42});
        expect(result, contains('data-id="42"'));
      });

      test('multiple attributes', () {
        final result = render(r'<div tl:attr="data-id=${id},title=${name}">x</div>', {'id': 42, 'name': 'Item'});
        expect(result, contains('data-id="42"'));
        expect(result, contains('title="Item"'));
      });

      test('expression with == in value', () {
        final result = render(r'<div tl:attr="data-match=${a} == ${b}">x</div>', {'a': 1, 'b': 1});
        expect(result, contains('data-match="true"'));
      });
    });

    group('null handling', () {
      test('null removes attribute', () {
        final result = render(r'<a tl:href="${url}">link</a>', {'url': null});
        expect(result, isNot(contains('href')));
      });

      test('null removes existing attribute', () {
        final result = render(r'<a href="/old" tl:href="${url}">link</a>', {'url': null});
        expect(result, isNot(contains('href')));
      });

      test('missing var (null) removes attribute', () {
        final result = render(r'<a tl:href="${missing}">link</a>', {});
        expect(result, isNot(contains('href')));
      });
    });

    group('boolean HTML attributes', () {
      test('true renders valueless attribute', () {
        final result = render(r'<input tl:attr="disabled=${active}">', {'active': true});
        expect(result, contains('disabled'));
        // valueless: should not have disabled="true"
        expect(result, isNot(contains('disabled="true"')));
      });

      test('false removes boolean attribute', () {
        final result = render(r'<input disabled tl:attr="disabled=${active}">', {'active': false});
        expect(result, isNot(contains('disabled')));
      });

      test('non-bool value on boolean attr renders as string', () {
        final result = render(r'<input tl:attr="disabled=${val}">', {'val': 'yes'});
        expect(result, contains('disabled="yes"'));
      });
    });

    group('tl:class behavior', () {
      test('replaces not appends', () {
        final result = render(r'<div class="a b" tl:class="${cls}">x</div>', {'cls': 'c'});
        expect(result, contains('class="c"'));
        expect(result, isNot(contains('a b')));
      });

      test('null removes class', () {
        final result = render(r'<div class="old" tl:class="${cls}">x</div>', {'cls': null});
        expect(result, isNot(contains('class')));
      });
    });

    group('URL expression in attr', () {
      test('tl:href with URL expression', () {
        final result = render(r'<a tl:href="@{/users(id=${userId})}">link</a>', {'userId': 42});
        expect(result, contains('href="/users?id=42"'));
      });

      test('tl:href encodes spaces as percent-20', () {
        final result = render(r'<a tl:href="@{/search(q=${val})}">link</a>', {'val': 'hello world'});
        expect(result, contains('href="/search?q=hello%20world"'));
      });

      test('tl:src with URL expression encodes special chars', () {
        final result = render(r'<img tl:src="@{/img(name=${n})}">', {'n': 'a&b'});
        expect(result, contains('src="/img?name=a%26b"'));
      });
    });

    group('URL-context attributes via tl:attr', () {
      test('action attribute with URL expression', () {
        final result = render(r'<form tl:attr="action=@{/submit(q=${val})}">x</form>', {'val': 'hello world'});
        expect(result, contains('action="/submit?q=hello%20world"'));
      });

      test('formaction attribute with URL expression', () {
        final result = render(r'<button tl:attr="formaction=@{/go(x=${v})}">go</button>', {'v': 'test value'});
        expect(result, contains('formaction="/go?x=test%20value"'));
      });

      test('poster attribute with URL expression encodes ampersand', () {
        final result = render(r'<video tl:attr="poster=@{/img(name=${n})}">x</video>', {'n': 'a&b'});
        expect(result, contains('poster="/img?name=a%26b"'));
      });

      test('data attribute with URL expression encodes equals', () {
        final result = render(r'<object tl:attr="data=@{/api(key=${k})}">x</object>', {'k': 'abc=def'});
        expect(result, contains('data="/api?key=abc%3Ddef"'));
      });

      test('non-URL attribute with variable expression is HTML-escaped', () {
        final result = render(r'<div tl:attr="title=${val}">x</div>', {'val': 'a&b'});
        // package:html HTML-entity-escapes attribute values
        expect(result, contains('title="a&amp;b"'));
      });
    });

    group('error handling', () {
      test('malformed tl:attr throws', () {
        expect(() => render('<div tl:attr="invalid">x</div>', {}), throwsA(isA<TemplateException>()));
      });
    });

    group('tl:classappend', () {
      test('appends to existing class attribute', () {
        final result = render(r'<div class="btn" tl:classappend="${cls}">x</div>', {'cls': 'active'});
        expect(result, contains('class="btn active"'));
      });

      test('sets class when no class attribute exists', () {
        final result = render(r'<div tl:classappend="${cls}">x</div>', {'cls': 'primary'});
        expect(result, contains('class="primary"'));
      });

      test('null expression leaves existing class unchanged', () {
        final result = render(r'<div class="btn" tl:classappend="${cls}">x</div>', {'cls': null});
        expect(result, contains('class="btn"'));
      });

      test('empty string result leaves existing class unchanged', () {
        final result = render(r'<div class="btn" tl:classappend="${cls}">x</div>', {'cls': ''});
        expect(result, contains('class="btn"'));
      });

      test('ternary — appends only when truthy', () {
        final result = render(
          r'''<div class="item" tl:classappend="${active} ? 'active' : ''">x</div>''',
          {'active': true},
        );
        expect(result, contains('class="item active"'));
      });

      test('ternary — no-op when falsy', () {
        final result = render(
          r'''<div class="item" tl:classappend="${active} ? 'active' : ''">x</div>''',
          {'active': false},
        );
        expect(result, contains('class="item"'));
        expect(result, isNot(contains('active')));
      });

      test('tl:classappend removed from output', () {
        final result = render(r'<div tl:classappend="${cls}">x</div>', {'cls': 'x'});
        expect(result, isNot(contains('tl:classappend')));
      });

      test('multiple classes in single append', () {
        final result = render(r'<div class="a" tl:classappend="${cls}">x</div>', {'cls': 'b c'});
        expect(result, contains('class="a b c"'));
      });

      test('tl:class and tl:classappend together', () {
        final result = render(r'<div class="old" tl:class="${cls}" tl:classappend="${extra}">x</div>', {
          'cls': 'base',
          'extra': 'active',
        });
        expect(result, contains('class="base active"'));
        expect(result, isNot(contains('old')));
      });
    });

    group('tl:styleappend', () {
      test('appends to existing style', () {
        final result = render(r'<div style="color: red" tl:styleappend="${s}">x</div>', {'s': 'font-size: 12px'});
        expect(result, contains('style="color: red; font-size: 12px"'));
      });

      test('existing style ends with semicolon — no double semicolon', () {
        final result = render(r'<div style="color: red;" tl:styleappend="${s}">x</div>', {'s': 'font-size: 12px'});
        expect(result, contains('style="color: red; font-size: 12px"'));
        expect(result, isNot(contains(';;')));
      });

      test('sets style when no style attribute exists', () {
        final result = render(r'<div tl:styleappend="${s}">x</div>', {'s': 'color: red'});
        expect(result, contains('style="color: red"'));
      });

      test('null expression leaves existing style unchanged', () {
        final result = render(r'<div style="color: red" tl:styleappend="${s}">x</div>', {'s': null});
        expect(result, contains('style="color: red"'));
      });

      test('empty string leaves existing style unchanged', () {
        final result = render(r'<div style="color: red" tl:styleappend="${s}">x</div>', {'s': ''});
        expect(result, contains('style="color: red"'));
      });

      test('tl:styleappend removed from output', () {
        final result = render(r'<div tl:styleappend="${s}">x</div>', {'s': 'color: red'});
        expect(result, isNot(contains('tl:styleappend')));
      });

      test('ternary expression — appends when truthy', () {
        final result = render(
          r'''<div style="display: block" tl:styleappend="${active} ? 'color: red' : ''">x</div>''',
          {'active': true},
        );
        expect(result, contains('color: red'));
      });

      test('ternary expression — no-op when falsy', () {
        final result = render(
          r'''<div style="display: block" tl:styleappend="${active} ? 'color: red' : ''">x</div>''',
          {'active': false},
        );
        expect(result, isNot(contains('color: red')));
        expect(result, contains('style="display: block"'));
      });
    });

    group('attribute removal', () {
      test('tl:href removed from output', () {
        final result = render(r'<a tl:href="${url}">link</a>', {'url': '/x'});
        expect(result, isNot(contains('tl:href')));
      });

      test('tl:attr removed from output', () {
        final result = render(r'<div tl:attr="data-x=${val}">x</div>', {'val': 1});
        expect(result, isNot(contains('tl:attr')));
      });

      test('tl:class removed from output', () {
        final result = render(r'<div tl:class="${cls}">x</div>', {'cls': 'a'});
        expect(result, isNot(contains('tl:class')));
      });
    });

    group('no-op sentinel _', () {
      test('tl:href="_" preserves existing href', () {
        final result = render('<a href="/original" tl:href="_">link</a>', {});
        expect(result, contains('href="/original"'));
        expect(result, isNot(contains('tl:href')));
      });

      test('tl:src="_" preserves existing src', () {
        final result = render('<img src="img.png" tl:src="_">', {});
        expect(result, contains('src="img.png"'));
      });

      test('tl:value="_" preserves existing value', () {
        final result = render('<input value="orig" tl:value="_">', {});
        expect(result, contains('value="orig"'));
      });

      test('tl:class="_" preserves existing class', () {
        final result = render('<div class="foo" tl:class="_">x</div>', {});
        expect(result, contains('class="foo"'));
      });

      test('tl:id="_" preserves existing id', () {
        final result = render('<div id="bar" tl:id="_">x</div>', {});
        expect(result, contains('id="bar"'));
      });

      test('tl:attr="_" leaves all attrs unchanged', () {
        final result = render('<div data-x="1" tl:attr="_">x</div>', {});
        expect(result, contains('data-x="1"'));
        expect(result, isNot(contains('tl:attr')));
      });
    });

    group('tl:attrs', () {
      const spreadInput = r'<input tl:attrs="${attrs}">';

      test('spreads a map onto an element whose only directive is tl:attrs', () {
        final result = render(spreadInput, {
          'attrs': {'type': 'email', 'data-test': 'field', 'hx-post': '/save'},
        });
        expect(result, contains('type="email"'));
        expect(result, contains('data-test="field"'));
        expect(result, contains('hx-post="/save"'));
        expect(result, isNot(contains('tl:attrs')));
      });

      test('explicit tl:attr, tl:class and shorthands win over spread entries', () {
        final result = render(r'<input class="base" tl:attrs="${attrs}" tl:attr="type=${type}" tl:class="${cls}">', {
          'attrs': {'type': 'text', 'class': 'spread', 'name': 'email'},
          'type': 'password',
          'cls': 'explicit',
        });
        expect(result, contains('type="password"'));
        expect(result, contains('class="explicit"'));
        expect(result, isNot(contains('spread')));
        expect(result, contains('name="email"'));
      });

      test('overwrites literal attributes but appends class and style', () {
        final result = render(r'<div id="a" class="card" style="color:red" tl:attrs="${attrs}">x</div>', {
          'attrs': {'id': 'b', 'class': 'active', 'style': 'margin:0'},
        });
        expect(result, contains('id="b"'));
        expect(result, contains('class="card active"'));
        expect(result, contains('style="color:red; margin:0"'));
      });

      test('class and style set on an element that has none', () {
        final result = render(r'<div tl:attrs="${attrs}">x</div>', {
          'attrs': {'class': 'a', 'style': 'margin:0'},
        });
        expect(result, contains('class="a"'));
        expect(result, contains('style="margin:0"'));
      });

      test('values follow tl:attr semantics and null class/style is a no-op append', () {
        final result = render(r'<input class="base" style="color:red" value="x" checked tl:attrs="${attrs}">', {
          'attrs': {'disabled': true, 'checked': false, 'value': null, 'class': null, 'style': null},
        });
        expect(result, contains('disabled'));
        expect(result, isNot(contains('checked')));
        expect(result, isNot(contains('value')));
        expect(result, contains('class="base"'));
        expect(result, contains('style="color:red"'));
      });

      test('escapes values like tl:attr', () {
        final result = render(spreadInput, {
          'attrs': {'title': 'a"b<c'},
        });
        expect(result, contains('title="a&quot;b<c"'));
      });

      test('tl:attrs="_" is a no-op', () {
        final result = render('<a href="/home" tl:attrs="_">Home</a>', {});
        expect(result, contains('<a href="/home">Home</a>'));
      });

      test('null map is a no-op on a non-strict engine', () {
        final result = render(r'<a href="/home" tl:attrs="${attrs}">Home</a>', {'attrs': null});
        expect(result, contains('<a href="/home">Home</a>'));
      });

      test('absent map throws the inherited undefined-variable error on a strict engine', () {
        final strict = testEngine();
        expect(
          () => strict.render(r'<a href="/home" tl:attrs="${attrs}">Home</a>', {}),
          throwsA(isA<ExpressionException>()),
        );
      });

      test('non-Map value throws TemplateException naming tl:attrs and the value', () {
        expect(
          () => render(r'<div tl:attrs="${attrs}">x</div>', {'attrs': 'class=highlight'}),
          throwsA(
            isA<TemplateException>().having(
              (e) => e.message,
              'message',
              allOf(contains('tl:attrs'), contains('class=highlight')),
            ),
          ),
        );
      });

      test('illegal attribute name throws naming the key and writes nothing', () {
        expect(
          () => render(r'<div class="card" tl:attrs="${attrs}">x</div>', {
            'attrs': {'data-ok': '1', 'bad name': 'x'},
          }),
          throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('bad name'))),
        );
      });

      test('every illegal name shape throws, even when a valid key precedes it', () {
        // Rendering throws, so partial mutation is observable only through a shared DOM; the guard is that the
        // exception is raised for a later bad key although earlier keys were valid.
        for (final bad in ['1abc', '', 'a b', 'x=y', 'a>b', '-x']) {
          expect(
            () => render(spreadInput, {
              'attrs': {'data-ok': '1', bad: 'x'},
            }),
            throwsA(isA<TemplateException>()),
            reason: 'key "$bad"',
          );
        }
      });

      test('non-String key throws TemplateException', () {
        expect(
          () => render(spreadInput, {
            'attrs': {1: 'x'},
          }),
          throwsA(isA<TemplateException>()),
        );
      });

      test('keys naming an engine directive are rejected case-insensitively without leaking values', () {
        final strict = testEngine();
        const source = r'<div class="card" tl:attrs="${attrs}">x</div>';
        final maps = [
          {'tl:remove': 'all'},
          {'tl:attr': r'data-x=${secret}'},
          {'TL:Remove': 'all'},
          {'tl:href': '/x'},
        ];
        for (final attrs in maps) {
          try {
            final out = strict.render(source, {'attrs': attrs, 'secret': 'API-KEY-123'});
            fail('expected TemplateException, rendered: $out');
          } on TemplateException catch (e) {
            expect(e.message, contains(attrs.keys.single));
            expect(e.toString(), isNot(contains('API-KEY-123')));
          }
        }
      });

      test('prefix rejection compares against the configured prefix', () {
        final custom = testEngine(prefix: 'data-tl');
        expect(
          () => custom.render(r'<div data-tl-attrs="${attrs}">x</div>', {
            'attrs': {'data-tl-remove': 'all'},
          }),
          throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('data-tl-remove'))),
        );
        final result = custom.render(r'<div data-tl-attrs="${attrs}">x</div>', {
          'attrs': {'tl:remove': 'all'},
        });
        expect(result, contains('tl:remove="all"'));
        expect(result, contains('>x</div>'));
      });

      test('browser prototype keeps literal attributes and renders the same with an empty map', () {
        const source = r'<input class="trellis-field-input" type="text" tl:attrs="${attrs}">';
        final raw = html.parseFragment(source).children.single;
        expect(raw.attributes['class'], 'trellis-field-input');
        expect(raw.attributes['type'], 'text');
        expect(raw.text, isEmpty);
        expect(raw.children, isEmpty);

        final rendered = render(source, {'attrs': <String, dynamic>{}});
        expect(rendered, contains('<input class="trellis-field-input" type="text">'));
      });
    });
  });
}
