import 'package:test/test.dart';
import 'package:trellis/src/utils/binding_parser.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('splitTopLevel', () {
    test('simple comma-separated', () {
      expect(splitTopLevel('a,b,c'), ['a', 'b', 'c']);
    });

    test('nested string with comma', () {
      expect(splitTopLevel("a='hello,world',b"), ["a='hello,world'", 'b']);
    });

    test('nested expression', () {
      expect(splitTopLevel(r'a=${x},b=${y}'), [r'a=${x}', r'b=${y}']);
    });

    test('nested parens', () {
      expect(splitTopLevel('a=@{/path(x=1,y=2)},b=3'), ['a=@{/path(x=1,y=2)}', 'b=3']);
    });

    test('no commas', () {
      expect(splitTopLevel('single'), ['single']);
    });

    test('empty input', () {
      expect(splitTopLevel(''), ['']);
    });

    test('whitespace trimmed', () {
      expect(splitTopLevel(' a , b '), ['a', 'b']);
    });
  });

  group('parseBindings', () {
    test('single binding', () {
      final result = parseBindings(r'name=${user.name}');
      expect(result, hasLength(1));
      expect(result[0].$1, 'name');
      expect(result[0].$2, r'${user.name}');
    });

    test('multiple bindings', () {
      final result = parseBindings(r'a=${x},b=${y}');
      expect(result, hasLength(2));
      expect(result[0].$1, 'a');
      expect(result[1].$1, 'b');
    });

    test('expression with == splits on first =', () {
      final result = parseBindings(r'x=${a == b}');
      expect(result, hasLength(1));
      expect(result[0].$1, 'x');
      expect(result[0].$2, r'${a == b}');
    });

    test('whitespace trimmed', () {
      final result = parseBindings(r' name = ${val} ');
      expect(result[0].$1, 'name');
      expect(result[0].$2, r'${val}');
    });

    test('malformed — no = throws', () {
      expect(() => parseBindings('invalid'), throwsA(isA<TemplateException>()));
    });

    test('malformed — empty name throws', () {
      expect(() => parseBindings(r'=${val}'), throwsA(isA<TemplateException>()));
    });
  });
}
