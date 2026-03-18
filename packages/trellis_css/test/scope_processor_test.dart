import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_css/trellis_css.dart';

/// Create a Trellis engine with CssDialect registered.
Trellis _engine({String prefix = 'tl'}) =>
    Trellis(loader: MapLoader({}), cache: false, prefix: prefix, dialects: [CssDialect()]);

void main() {
  group('ScopeProcessor', () {
    group('basic scoping', () {
      test('T01: wraps CSS in @scope, adds scope class, removes tl:scope attribute', () {
        final engine = _engine();
        final result = engine.renderFragment(
          '<div tl:fragment="card">'
          '<style tl:scope>h2 { color: navy; }</style>'
          '<h2>Title</h2>'
          '</div>',
          fragment: 'card',
          context: <String, dynamic>{},
        );
        expect(result, contains('class="tl-scope-card"'));
        expect(result, contains('@scope (.tl-scope-card)'));
        expect(result, contains('h2 { color: navy; }'));
        expect(result, isNot(contains('tl:scope')));
      });

      test('T02: existing class on fragment root is preserved — scope class appended', () {
        final engine = _engine();
        final result = engine.renderFragment(
          '<div class="card-component" tl:fragment="card">'
          '<style tl:scope>h2 { color: red; }</style>'
          '</div>',
          fragment: 'card',
          context: <String, dynamic>{},
        );
        expect(result, contains('class="card-component tl-scope-card"'));
      });

      test('T03: scope class not duplicated across multiple renders', () {
        final engine = _engine();
        const template =
            '<div tl:fragment="card">'
            '<style tl:scope>h2 { color: navy; }</style>'
            '</div>';
        final result = engine.renderFragment(template, fragment: 'card', context: <String, dynamic>{});
        // 'tl-scope-card' appears in: class attr (1) + @scope selector (1) = exactly 2
        final count = 'tl-scope-card'.allMatches(result).length;
        expect(count, 2);
      });

      test('T04: multiline CSS is preserved inside @scope wrapper', () {
        final engine = _engine();
        final result = engine.renderFragment(
          '<div tl:fragment="hero">'
          '<style tl:scope>\nh1 { font-size: 2rem; }\nh2 { font-size: 1.5rem; }\n</style>'
          '</div>',
          fragment: 'hero',
          context: <String, dynamic>{},
        );
        expect(result, contains('@scope (.tl-scope-hero)'));
        expect(result, contains('h1 { font-size: 2rem; }'));
        expect(result, contains('h2 { font-size: 1.5rem; }'));
      });

      test('T05: empty <style tl:scope> produces @scope wrapper without error', () {
        final engine = _engine();
        late final String result;
        expect(() {
          result = engine.renderFragment(
            '<div tl:fragment="empty"><style tl:scope></style></div>',
            fragment: 'empty',
            context: <String, dynamic>{},
          );
        }, returnsNormally);
        expect(result, contains('@scope (.tl-scope-empty)'));
      });

      test('fragment with tl:text sibling — scope class and content both rendered', () {
        final engine = _engine();
        const template =
            '<div tl:fragment="card">'
            '<style tl:scope>p { color: blue; }</style>'
            '<p tl:text="\${content}">placeholder</p>'
            '</div>';
        final result = engine.renderFragment(
          template,
          fragment: 'card',
          context: <String, dynamic>{'content': 'Hello'},
        );
        expect(result, contains('tl-scope-card'));
        expect(result, contains('Hello'));
      });
    });

    group('multiple fragments', () {
      test('T06: two scoped fragments render independently', () {
        final engine = _engine();
        const template =
            '<div tl:fragment="header"><style tl:scope>h1 { color: red; }</style><h1>Header</h1></div>'
            '<div tl:fragment="footer"><style tl:scope>p { color: blue; }</style><p>Footer</p></div>';

        final headerResult = engine.renderFragment(template, fragment: 'header', context: <String, dynamic>{});
        final footerResult = engine.renderFragment(template, fragment: 'footer', context: <String, dynamic>{});

        expect(headerResult, contains('tl-scope-header'));
        expect(headerResult, contains('@scope (.tl-scope-header)'));
        expect(headerResult, isNot(contains('tl-scope-footer')));

        expect(footerResult, contains('tl-scope-footer'));
        expect(footerResult, contains('@scope (.tl-scope-footer)'));
        expect(footerResult, isNot(contains('tl-scope-header')));
      });

      test('T07: nested fragments — inner scope resolves to inner fragment name', () {
        final engine = _engine();
        const template =
            '<section tl:fragment="outer">'
            '<style tl:scope>.outer { padding: 1rem; }</style>'
            '<div tl:fragment="inner">'
            '<style tl:scope>.inner { margin: 0; }</style>'
            '</div>'
            '</section>';

        final innerResult = engine.renderFragment(template, fragment: 'inner', context: <String, dynamic>{});
        expect(innerResult, contains('tl-scope-inner'));
        expect(innerResult, contains('@scope (.tl-scope-inner)'));
        expect(innerResult, isNot(contains('tl-scope-outer')));
      });

      test('T19: rendering outer fragment does not steal inner fragment scope', () {
        // Regression: ScopeProcessor must not collect <style tl:scope> elements
        // that belong to a nested tl:fragment — they own their own scope boundary.
        // Each fragment's ScopeProcessor pass handles only its directly-owned styles.
        final engine = _engine();
        const template =
            '<section tl:fragment="outer">'
            '<style tl:scope>.outer { padding: 1rem; }</style>'
            '<div tl:fragment="inner">'
            '<style tl:scope>.inner { margin: 0; }</style>'
            '</div>'
            '</section>';

        final outerResult = engine.renderFragment(template, fragment: 'outer', context: <String, dynamic>{});
        // Outer root gets outer scope class
        expect(outerResult, contains('tl-scope-outer'));
        // Outer style scoped to outer
        expect(outerResult, contains('@scope (.tl-scope-outer)'));
        expect(outerResult, contains('.outer { padding: 1rem; }'));
        // Inner style must NOT be wrapped inside @scope (.tl-scope-outer)
        expect(outerResult, isNot(contains('.tl-scope-outer) {\n  .inner')));
        // Inner fragment root gets its own scope class
        expect(outerResult, contains('tl-scope-inner'));
        // Inner style correctly scoped to inner
        expect(outerResult, contains('@scope (.tl-scope-inner)'));
        expect(outerResult, contains('.inner { margin: 0; }'));
        // No stray tl:scope attributes left after processing
        expect(outerResult, isNot(contains('tl:scope')));
      });
    });

    group('interaction with other processors', () {
      test('T08: tl:scope and tl:text coexist on same page without conflict', () {
        final engine = _engine();
        final result = engine.renderFragment(
          '<div tl:fragment="card">'
          '<style tl:scope>h2 { color: navy; }</style>'
          '<h2 tl:text="\${title}">old</h2>'
          '</div>',
          fragment: 'card',
          context: <String, dynamic>{'title': 'Hello World'},
        );
        expect(result, contains('tl-scope-card'));
        expect(result, contains('Hello World'));
      });

      test('T10: renderFragment returns scoped CSS and scope class', () {
        final engine = _engine();
        final result = engine.renderFragment(
          '<div tl:fragment="widget">'
          '<style tl:scope>span { font-weight: bold; }</style>'
          '<span>text</span>'
          '</div>',
          fragment: 'widget',
          context: <String, dynamic>{},
        );
        expect(result, contains('class="tl-scope-widget"'));
        expect(result, contains('@scope (.tl-scope-widget)'));
        expect(result, contains('span { font-weight: bold; }'));
      });

      test('T11: renderFragments (OOB) returns scoped CSS and scope class', () {
        final engine = _engine();
        final result = engine.renderFragments(
          '<div tl:fragment="panel">'
          '<style tl:scope>div { border: 1px solid; }</style>'
          '</div>',
          fragments: ['panel'],
          context: <String, dynamic>{},
        );
        expect(result, contains('tl-scope-panel'));
        expect(result, contains('@scope (.tl-scope-panel)'));
      });
    });

    group('warning scenarios (no-crash)', () {
      test('T12: tl:scope outside tl:fragment — does not crash, tl:scope attr removed', () {
        final engine = _engine();
        late final String result;
        expect(() {
          result = engine.render('<style tl:scope>h1 { color: red; }</style>', <String, dynamic>{});
        }, returnsNormally);
        expect(result, isNot(contains('tl:scope')));
      });

      test('T13: tl:scope on non-style element — removes attribute, no crash', () {
        final engine = _engine();
        late final String result;
        expect(() {
          result = engine.render('<div tl:fragment="x"><div tl:scope="yes">content</div></div>', <String, dynamic>{});
        }, returnsNormally);
        expect(result, isNot(contains('tl:scope')));
      });

      test('T16: onWarning callback invoked for tl:scope outside tl:fragment', () {
        final warnings = <String>[];
        final engine = Trellis(
          loader: MapLoader({}),
          cache: false,
          dialects: [CssDialect(onWarning: warnings.add)],
        );
        engine.render('<style tl:scope>h1 { color: red; }</style>', <String, dynamic>{});
        expect(warnings, hasLength(1));
        expect(warnings.first, contains('outside a tl:fragment'));
      });

      test('T17: onWarning callback invoked for tl:scope on non-style element', () {
        final warnings = <String>[];
        final engine = Trellis(
          loader: MapLoader({}),
          cache: false,
          dialects: [CssDialect(onWarning: warnings.add)],
        );
        engine.render('<div tl:fragment="x"><span tl:scope>text</span></div>', <String, dynamic>{});
        expect(warnings, hasLength(1));
        expect(warnings.first, contains('only supported on <style>'));
      });

      test('T18: no warning callback (default) — tl:scope outside fragment does not throw', () {
        // Default behaviour: warnings silently dropped (no stderr, no exception)
        final engine = Trellis(
          loader: MapLoader({}),
          cache: false,
          dialects: [CssDialect()],
        );
        expect(
          () => engine.render('<style tl:scope>h1{}</style>', <String, dynamic>{}),
          returnsNormally,
        );
      });

      test('T14: fragment with multiple direct children — rendering completes and scope class added', () {
        final engine = _engine();
        late final String result;
        expect(() {
          result = engine.renderFragment(
            '<div tl:fragment="multi">'
            '<style tl:scope>p { color: red; }</style>'
            '<p>One</p>'
            '<p>Two</p>'
            '</div>',
            fragment: 'multi',
            context: <String, dynamic>{},
          );
        }, returnsNormally);
        expect(result, contains('tl-scope-multi'));
        expect(result, contains('@scope (.tl-scope-multi)'));
      });
    });

    group('custom prefix', () {
      test('T15: data-tl prefix — data-tl-scope triggers same behavior', () {
        final engine = Trellis(loader: MapLoader({}), cache: false, prefix: 'data-tl', dialects: [CssDialect()]);
        final result = engine.renderFragment(
          '<div data-tl-fragment="card">'
          '<style data-tl-scope="">h2 { color: navy; }</style>'
          '</div>',
          fragment: 'card',
          context: <String, dynamic>{},
        );
        expect(result, contains('tl-scope-card'));
        expect(result, contains('@scope (.tl-scope-card)'));
        expect(result, isNot(contains('data-tl-scope')));
      });
    });
  });
}
