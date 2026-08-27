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

  group('themeNameFromUrl', () {
    test('strips trellis-theme- prefix and .git suffix from HTTPS URL', () {
      expect(themeNameFromUrl('https://github.com/user/trellis-theme-verdant.git'), 'verdant');
    });

    test('strips .git suffix from HTTPS URL without prefix', () {
      expect(themeNameFromUrl('https://github.com/user/verdant.git'), 'verdant');
    });

    test('handles SSH URL format', () {
      expect(themeNameFromUrl('git@github.com:user/verdant.git'), 'verdant');
    });

    test('handles SSH URL with trellis-theme- prefix', () {
      expect(themeNameFromUrl('git@github.com:user/trellis-theme-my-theme.git'), 'my-theme');
    });

    test('handles HTTPS URL without .git suffix', () {
      expect(themeNameFromUrl('https://github.com/user/my-theme'), 'my-theme');
    });

    test('handles multi-segment paths (e.g. GitLab subgroups)', () {
      expect(themeNameFromUrl('https://gitlab.com/org/sub/trellis-theme-custom.git'), 'custom');
    });
  });

  group('validateThemeName', () {
    test('accepts the names the theme gallery generator accepts', () {
      for (final name in <String>['lattice', 'folio', 'my-theme', 'theme_2', '0x']) {
        expect(validateThemeName(name), isNull, reason: name);
      }
    });

    test('rejects values that would escape or rename the destination directory', () {
      for (final name in <String>[
        '',
        '..',
        '../../etc',
        '/etc/passwd',
        'a/b',
        r'a\\b',
        'Verdant',
        '-lead',
        '.hidden',
      ]) {
        expect(validateThemeName(name), isNotNull, reason: name);
      }
    });

    test('names the offending value so the operator can see what was rejected', () {
      expect(validateThemeName('../escape'), contains('"../escape"'));
    });
  });
}
