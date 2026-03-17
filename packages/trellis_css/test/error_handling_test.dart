import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_css/trellis_css.dart';
import 'package:test/test.dart';

late String _testFixturesDir;

String fixture(String name) => p.join(_testFixturesDir, name);

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_css/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _testFixturesDir = p.join(packageRoot, 'test_fixtures');
  });

  group('SassCompilationException', () {
    test('has correct message field', () {
      try {
        TrellisCss.compileSassString('body { color: ; }');
        fail('Expected exception');
      } on SassCompilationException catch (e) {
        expect(e.message, isNotEmpty);
      }
    });

    test('toString() returns SassCompilationException: <message>', () {
      try {
        TrellisCss.compileSassString('body { color: ; }');
        fail('Expected exception');
      } on SassCompilationException catch (e) {
        expect(e.toString(), startsWith('SassCompilationException:'));
        expect(e.toString(), contains(e.message));
      }
    });

    test('has cause referencing original error', () {
      try {
        TrellisCss.compileSassString('body { color: ; }');
        fail('Expected exception');
      } on SassCompilationException catch (e) {
        expect(e.cause, isNotNull);
      }
    });

    test('file-based error has line info', () {
      try {
        TrellisCss.compileSass(fixture('invalid.scss'));
        fail('Expected exception');
      } on SassCompilationException catch (e) {
        expect(e.line, isNotNull);
        expect(e.line, greaterThan(0));
      }
    });

    test('file-based error has path info', () {
      try {
        TrellisCss.compileSass(fixture('invalid.scss'));
        fail('Expected exception');
      } on SassCompilationException catch (e) {
        expect(e.path, isNotNull);
        expect(e.path, contains('invalid'));
      }
    });

    test('file-not-found produces meaningful error message', () {
      try {
        TrellisCss.compileSass('missing_file.scss');
        fail('Expected exception');
      } on SassCompilationException catch (e) {
        expect(e.message, isNotEmpty);
      }
    });

    test('string-based error has line info', () {
      try {
        TrellisCss.compileSassString('body { color: ; }');
        fail('Expected exception');
      } on SassCompilationException catch (e) {
        expect(e.line, isNotNull);
        expect(e.column, isNotNull);
      }
    });
  });
}
