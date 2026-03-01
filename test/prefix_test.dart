import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('prefix mode', () {
    group('default tl prefix', () {
      late Trellis engine;

      setUp(() {
        engine = Trellis(loader: MapLoader({}), cache: false);
      });

      test('tl:text works', () {
        final result = engine.render(r'<p tl:text="${x}">d</p>', {'x': 'hi'});
        expect(result, contains('<p>hi</p>'));
      });
    });

    group('data-tl prefix', () {
      late Trellis engine;

      setUp(() {
        engine = Trellis(loader: MapLoader({}), cache: false, prefix: 'data-tl');
      });

      test('data-tl-text renders correctly', () {
        final result = engine.render(r'<p data-tl-text="${x}">d</p>', {'x': 'hi'});
        expect(result, contains('<p>hi</p>'));
        expect(result, isNot(contains('data-tl-text')));
      });

      test('data-tl-if conditional', () {
        final result = engine.render('<p data-tl-if="true">yes</p>', {});
        expect(result, contains('yes'));
      });

      test('data-tl-unless conditional', () {
        final result = engine.render('<p data-tl-unless="true">no</p>', {});
        expect(result, isNot(contains('no')));
      });

      test('data-tl-each iteration', () {
        final result = engine.render(r'<li data-tl-each="item : ${items}" data-tl-text="${item}">x</li>', {
          'items': ['a', 'b'],
        });
        expect(result, contains('<li>a</li>'));
        expect(result, contains('<li>b</li>'));
      });

      test('data-tl-href attribute', () {
        final result = engine.render(r'<a data-tl-href="${url}">link</a>', {'url': '/home'});
        expect(result, contains('href="/home"'));
        expect(result, isNot(contains('data-tl-href')));
      });

      test('data-tl-class attribute', () {
        final result = engine.render(r'<div data-tl-class="${cls}">x</div>', {'cls': 'active'});
        expect(result, contains('class="active"'));
      });

      test('data-tl-fragment and data-tl-insert', () {
        final result = engine.render(
          '<div>'
          '<p data-tl-fragment="greeting">Hello</p>'
          '<div data-tl-insert="greeting"></div>'
          '</div>',
          {},
        );
        expect(result, contains('Hello'));
      });

      test('data-tl-* attributes stripped from output', () {
        final result = engine.render(r'<p data-tl-text="${x}">d</p>', {'x': 'hi'});
        expect(result, isNot(contains('data-tl-')));
      });

      test('tl:text ignored when prefix is data-tl', () {
        final result = engine.render(r'<p tl:text="${x}">default</p>', {'x': 'ignored'});
        expect(result, contains('default'));
        // tl:text is left as-is since prefix is data-tl
        expect(result, contains('tl:text'));
      });
    });

    group('data-tl-block', () {
      test('data-tl-block unwraps correctly', () {
        final engine = Trellis(loader: MapLoader({}), cache: false, prefix: 'data-tl');
        final result = engine.render('<div><data-tl-block>content</data-tl-block></div>', {});
        expect(result, contains('content'));
        expect(result, isNot(contains('data-tl-block')));
      });
    });
  });
}
