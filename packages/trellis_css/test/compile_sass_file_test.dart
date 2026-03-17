import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_css/trellis_css.dart';
import 'package:test/test.dart';

late String _testFixturesDir;

/// Path to a fixture file, resolved via package resolution so it works
/// regardless of where `dart test` is invoked from.
String fixture(String name) => p.join(_testFixturesDir, name);

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_css/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _testFixturesDir = p.join(packageRoot, 'test_fixtures');
  });

  group('TrellisCss.compileSass() (file-based)', () {
    test('compiles basic.scss', () {
      final css = TrellisCss.compileSass(fixture('basic.scss'));
      expect(css, contains('.container'));
      expect(css, contains('.hero'));
      expect(css, contains('display: flex'));
    });

    test('compiles indented.sass', () {
      final css = TrellisCss.compileSass(fixture('indented.sass'));
      expect(css, contains('.container'));
      expect(css, contains('.header'));
    });

    test('OutputStyle.compressed produces minified output', () {
      final css = TrellisCss.compileSass(fixture('basic.scss'), outputStyle: OutputStyle.compressed);
      // Compressed output should not have blank lines
      expect(css, isNot(contains('\n\n')));
      expect(css, contains('.container'));
    });

    test('loadPaths resolves @use with partial', () {
      final css = TrellisCss.compileSass(fixture('uses_variables.scss'), loadPaths: [fixture('')]);
      expect(css, contains('.btn'));
      expect(css, contains('#3498db'));
    });

    test('loadPaths resolves @forward', () {
      // forwards_variables just forwards, so importing uses_variables with same path works
      final css = TrellisCss.compileSass(fixture('uses_variables.scss'), loadPaths: [fixture('')]);
      expect(css, contains('#3498db'));
    });

    test('nested partial resolved via loadPaths', () {
      final css = TrellisCss.compileSass(fixture('nested/theme.scss'), loadPaths: [fixture('nested')]);
      expect(css, contains('.theme'));
      expect(css, contains('#f5f5f5'));
    });

    test('non-existent file throws SassCompilationException', () {
      expect(() => TrellisCss.compileSass('non_existent_file.scss'), throwsA(isA<SassCompilationException>()));
    });

    test('invalid SCSS file throws SassCompilationException', () {
      expect(() => TrellisCss.compileSass(fixture('invalid.scss')), throwsA(isA<SassCompilationException>()));
    });

    test('SassCompilationException for invalid file has message and line info', () {
      try {
        TrellisCss.compileSass(fixture('invalid.scss'));
        fail('Expected SassCompilationException');
      } on SassCompilationException catch (e) {
        expect(e.message, isNotEmpty);
        expect(e.line, isNotNull);
        expect(e.toString(), startsWith('SassCompilationException:'));
      }
    });
  });
}
