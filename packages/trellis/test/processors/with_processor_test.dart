import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('With processor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    test('single binding', () {
      final result = render(r'<p tl:with="name=${user.name}" tl:text="${name}">x</p>', {
        'user': {'name': 'Alice'},
      });
      expect(result, contains('<p>Alice</p>'));
    });

    test('multiple bindings', () {
      final result = render(r'<p tl:with="a=${x},b=${y}" tl:text="${a} + ${b}">x</p>', {'x': 'hello', 'y': 'world'});
      expect(result, contains('<p>helloworld</p>'));
    });

    test('sequential reference — b references a', () {
      // a binds to val, then b references a
      final result = render(r'<p tl:with="a=${val},b=${a}" tl:text="${b}">x</p>', {'val': 'hi'});
      expect(result, contains('<p>hi</p>'));
    });

    test('scope to descendants', () {
      final result = render(r'<div tl:with="x=${val}"><p tl:text="${x}">y</p></div>', {'val': 'hello'});
      expect(result, contains('<p>hello</p>'));
    });

    test('no leak to siblings', () {
      final result = render(r'<div><p tl:with="x=${val}">a</p><p tl:text="${x}">b</p></div>', {'val': 'hello'});
      // Second <p> should not see x — renders empty (null → '')
      expect(result, contains('<p>a</p>'));
      expect(result, contains('<p></p>'));
    });

    test('shadow context variable', () {
      final result = render(r'<p tl:with="name=${override}" tl:text="${name}">x</p>', {
        'name': 'original',
        'override': 'local',
      });
      expect(result, contains('<p>local</p>'));
    });

    test('binding with expression evaluation', () {
      final result = render(r'<p tl:with="adult=${age} >= 18" tl:if="${adult}">ok</p>', {'age': 21});
      expect(result, contains('<p>ok</p>'));
    });

    test('tl:with + tl:if — with processed first', () {
      final result = render(r'<p tl:with="x=${val}" tl:if="${x}">visible</p>', {'val': true});
      expect(result, contains('<p>visible</p>'));
    });

    test('tl:with attribute removed from output', () {
      final result = render(r'<p tl:with="x=${val}">text</p>', {'val': 'y'});
      expect(result, isNot(contains('tl:with')));
    });

    test('malformed binding throws', () {
      expect(() => render('<p tl:with="invalid">x</p>', {}), throwsA(isA<TemplateException>()));
    });
  });
}
