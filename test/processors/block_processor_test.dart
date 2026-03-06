import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('tl:block', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    test('renders only children (wrapper element absent)', () {
      final result = render('<div><tl:block><p>one</p><p>two</p></tl:block></div>', {});
      expect(result, contains('<p>one</p>'));
      expect(result, contains('<p>two</p>'));
      expect(result, isNot(contains('tl:block')));
    });

    test('tl:if false — nothing rendered', () {
      final result = render(r'<div><tl:block tl:if="${show}"><p>hidden</p></tl:block></div>', {'show': false});
      expect(result, isNot(contains('<p>hidden</p>')));
      expect(result, isNot(contains('tl:block')));
    });

    test('tl:if true — children rendered, no wrapper', () {
      final result = render(r'<div><tl:block tl:if="${show}"><p>visible</p></tl:block></div>', {'show': true});
      expect(result, contains('<p>visible</p>'));
      expect(result, isNot(contains('tl:block')));
    });

    test('tl:each — children replicated N times, no wrapper', () {
      final result = render(r'<dl><tl:block tl:each="item : ${items}"><dt tl:text="${item}">x</dt></tl:block></dl>', {
        'items': ['a', 'b', 'c'],
      });
      expect(result, contains('<dt>a</dt>'));
      expect(result, contains('<dt>b</dt>'));
      expect(result, contains('<dt>c</dt>'));
      expect(result, isNot(contains('tl:block')));
      expect(result, isNot(contains('tl:each')));
    });

    test('tl:with — children rendered with bound variable', () {
      final result = render(r'<div><tl:block tl:with="x=${val}"><p tl:text="${x}">default</p></tl:block></div>', {
        'val': 'bound',
      });
      expect(result, contains('<p>bound</p>'));
      expect(result, isNot(contains('tl:block')));
    });

    test('nested tl:block inside tl:block — all unwrapped', () {
      final result = render('<div><tl:block><tl:block><p>inner</p></tl:block></tl:block></div>', {});
      expect(result, contains('<p>inner</p>'));
      expect(result, isNot(contains('tl:block')));
    });

    test('empty tl:block renders nothing', () {
      final result = render('<div><tl:block></tl:block></div>', {});
      expect(result, contains('<div></div>'));
      expect(result, isNot(contains('tl:block')));
    });

    test('tl:text on tl:block — text node promoted to parent', () {
      final result = render(r'<div><tl:block tl:text="${val}">default</tl:block></div>', {'val': 'hello'});
      expect(result, contains('<div>hello</div>'));
      expect(result, isNot(contains('tl:block')));
    });

    test('tl:utext on tl:block — HTML nodes promoted to parent', () {
      final result = render(r'<div><tl:block tl:utext="${html}">default</tl:block></div>', {'html': '<b>bold</b>'});
      expect(result, contains('<b>bold</b>'));
      expect(result, isNot(contains('tl:block')));
    });

    test('tl:insert on tl:block — fragment content promoted to parent', () {
      final e = Trellis(
        loader: MapLoader({'frag-tmpl': '<div><span tl:fragment="frag">included</span></div>'}),
        cache: false,
      );
      final result = e.render('<div><tl:block tl:insert="~{frag-tmpl :: frag}">fallback</tl:block></div>', {});
      expect(result, contains('included'));
      expect(result, isNot(contains('tl:block')));
    });

    test('multiple tl:* attrs on tl:block interact correctly', () {
      final result = render(
        r'<div><tl:block tl:if="${show}" tl:with="x=${val}" tl:text="${x}">default</tl:block></div>',
        {'show': true, 'val': 'yes'},
      );
      expect(result, contains('<div>yes</div>'));
      expect(result, isNot(contains('tl:block')));
    });

    group('self-closing <tl:block/>', () {
      test('does not consume subsequent siblings', () {
        final result = render(r'<div><tl:block tl:utext="${body}"/><p>sibling</p></div>', {'body': '<b>hi</b>'});
        expect(result, contains('<b>hi</b>'));
        expect(result, contains('<p>sibling</p>'));
        expect(result, isNot(contains('tl:block')));
      });

      test('preserves attributes on self-closing block', () {
        final result = render(r'<div><tl:block tl:text="${val}"/>after</div>', {'val': 'hello'});
        expect(result, contains('hello'));
        expect(result, contains('after'));
      });

      test('self-closing block with no attributes', () {
        final result = render('<div><tl:block/>tail</div>', {});
        expect(result, contains('tail'));
        expect(result, isNot(contains('tl:block')));
      });

      test('self-closing block with > in attribute value preserves siblings', () {
        final result = render(r'<div><tl:block tl:if="${count > 0}" tl:text="${count}"/><p>sibling</p></div>', {
          'count': 3,
        });
        expect(result, contains('3'));
        expect(result, contains('<p>sibling</p>'));
        expect(result, isNot(contains('tl:block')));
      });

      test('self-closing block with >= in attribute value', () {
        final result = render(r'''<div><tl:block tl:if="${x >= 5}" tl:text="'yes'"/><p>after</p></div>''', {'x': 10});
        expect(result, contains('yes'));
        expect(result, contains('<p>after</p>'));
      });

      test('self-closing block with single-quoted attribute containing >', () {
        final result = render("<div><tl:block tl:if='\${n > 1}' tl:text='\${n}'/>tail</div>", {'n': 5});
        expect(result, contains('5'));
        expect(result, contains('tail'));
      });

      test('multiple self-closing blocks preserve order', () {
        final result = render(r'<div><tl:block tl:text="${a}"/><tl:block tl:text="${b}"/></div>', {
          'a': 'first',
          'b': 'second',
        });
        expect(result, contains('first'));
        expect(result, contains('second'));
        final idx1 = result.indexOf('first');
        final idx2 = result.indexOf('second');
        expect(idx1, lessThan(idx2));
      });
    });

    group('tl:fragment on tl:block', () {
      test('renderFragment returns unwrapped children', () {
        final source = '<div><tl:block tl:fragment="msg"><p>content</p></tl:block></div>';
        final result = engine.renderFragment(source, fragment: 'msg', context: {});
        expect(result, contains('<p>content</p>'));
        expect(result, isNot(contains('tl:block')));
      });

      test('renderFragment with expression in block fragment', () {
        final source = r'<div><tl:block tl:fragment="greeting"><span tl:text="${name}">x</span></tl:block></div>';
        final result = engine.renderFragment(source, fragment: 'greeting', context: {'name': 'World'});
        expect(result, contains('<span>World</span>'));
        expect(result, isNot(contains('tl:block')));
      });

      test('renderFragments returns unwrapped children for block fragments', () {
        final source =
            '<div>'
            '<tl:block tl:fragment="a"><p>alpha</p></tl:block>'
            '<tl:block tl:fragment="b"><p>beta</p></tl:block>'
            '</div>';
        final result = engine.renderFragments(source, fragments: ['a', 'b'], context: {});
        expect(result, contains('<p>alpha</p>'));
        expect(result, contains('<p>beta</p>'));
        expect(result, isNot(contains('tl:block')));
      });

      test('mixed block and regular fragment rendering', () {
        final source =
            '<div>'
            '<tl:block tl:fragment="block-frag"><p>from block</p></tl:block>'
            '<span tl:fragment="span-frag">from span</span>'
            '</div>';
        final blockResult = engine.renderFragment(source, fragment: 'block-frag', context: {});
        final spanResult = engine.renderFragment(source, fragment: 'span-frag', context: {});
        expect(blockResult, contains('<p>from block</p>'));
        expect(blockResult, isNot(contains('tl:block')));
        expect(spanResult, contains('<span>from span</span>'));
      });
    });
  });
}
