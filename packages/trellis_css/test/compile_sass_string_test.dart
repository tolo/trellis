import 'package:trellis_css/trellis_css.dart';
import 'package:test/test.dart';

void main() {
  group('TrellisCss.compileSassString()', () {
    test('compiles basic SCSS', () {
      const source = '.btn { color: blue; }';
      final css = TrellisCss.compileSassString(source);
      expect(css, contains('.btn'));
      expect(css, contains('color: blue'));
    });

    test('compiles SCSS with nesting', () {
      const source = '.container { .header { color: red; } }';
      final css = TrellisCss.compileSassString(source);
      expect(css, contains('.container .header'));
      expect(css, contains('color: red'));
    });

    test('compiles SCSS with variables', () {
      const source = r'''
        $primary: #3498db;
        .btn { color: $primary; }
      ''';
      final css = TrellisCss.compileSassString(source);
      expect(css, contains('.btn'));
      expect(css, contains('#3498db'));
    });

    test('compiles SCSS with mixins', () {
      const source = r'''
        @mixin flex { display: flex; }
        .row { @include flex; }
      ''';
      final css = TrellisCss.compileSassString(source);
      expect(css, contains('.row'));
      expect(css, contains('display: flex'));
    });

    test('OutputStyle.expanded produces readable output', () {
      const source = '.a { color: red; } .b { color: blue; }';
      final css = TrellisCss.compileSassString(source, outputStyle: OutputStyle.expanded);
      expect(css, contains('\n'));
    });

    test('OutputStyle.compressed produces minified output', () {
      const source = '.a { color: red; } .b { color: blue; }';
      final css = TrellisCss.compileSassString(source, outputStyle: OutputStyle.compressed);
      // Compressed output should not have newlines between rules
      expect(css, isNot(contains('\n.b')));
      expect(css, contains('.a'));
      expect(css, contains('.b'));
    });

    test('Syntax.sass compiles indented syntax', () {
      const source = '.btn\n  color: blue\n';
      final css = TrellisCss.compileSassString(source, syntax: Syntax.sass);
      expect(css, contains('.btn'));
      expect(css, contains('color: blue'));
    });

    test('empty input produces empty or minimal CSS', () {
      final css = TrellisCss.compileSassString('');
      expect(css, isEmpty);
    });

    test('invalid SCSS throws SassCompilationException', () {
      expect(() => TrellisCss.compileSassString('body { color: ; }'), throwsA(isA<SassCompilationException>()));
    });

    test('SassCompilationException has error message', () {
      try {
        TrellisCss.compileSassString('body { color: ; }');
        fail('Expected SassCompilationException');
      } on SassCompilationException catch (e) {
        expect(e.message, isNotEmpty);
        expect(e.toString(), startsWith('SassCompilationException:'));
      }
    });
  });
}
