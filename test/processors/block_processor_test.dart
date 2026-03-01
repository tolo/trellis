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
  });
}
