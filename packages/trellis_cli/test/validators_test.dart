import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  group('validateProjectName', () {
    test('accepts valid names', () {
      expect(validateProjectName('my_app'), isNull);
      expect(validateProjectName('app'), isNull);
      expect(validateProjectName('hello_world_42'), isNull);
      expect(validateProjectName('a'), isNull);
      expect(validateProjectName('x123'), isNull);
    });

    test('rejects empty name', () {
      expect(validateProjectName(''), isNotNull);
      expect(validateProjectName(''), contains('empty'));
    });

    test('rejects names starting with digit', () {
      expect(validateProjectName('1app'), isNotNull);
    });

    test('rejects names starting with underscore', () {
      expect(validateProjectName('_app'), isNotNull);
    });

    test('rejects uppercase letters', () {
      expect(validateProjectName('MyApp'), isNotNull);
      expect(validateProjectName('myApp'), isNotNull);
    });

    test('rejects hyphens', () {
      expect(validateProjectName('my-app'), isNotNull);
    });

    test('rejects spaces', () {
      expect(validateProjectName('my app'), isNotNull);
    });

    test('rejects Dart reserved words', () {
      expect(validateProjectName('class'), isNotNull);
      expect(validateProjectName('class'), contains('reserved'));
      expect(validateProjectName('import'), isNotNull);
      expect(validateProjectName('var'), isNotNull);
      expect(validateProjectName('if'), isNotNull);
      expect(validateProjectName('abstract'), isNotNull);
      expect(validateProjectName('dynamic'), isNotNull);
    });
  });
}
