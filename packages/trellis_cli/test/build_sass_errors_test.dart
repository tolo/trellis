import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

class _BufferStdout implements Stdout {
  _BufferStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Runs `trellis build` in [dir], returning the exit code and the stderr text.
Future<({int exitCode, String stderrText})> _build(Directory dir) async {
  final errors = StringBuffer();
  final exitCode = await IOOverrides.runZoned(
    () => TrellisCli(workingDirectory: dir.path).run(['build']),
    stderr: () => _BufferStdout(errors),
    stdout: () => _BufferStdout(StringBuffer()),
  );
  return (exitCode: exitCode, stderrText: errors.toString());
}

void main() {
  late Directory siteDir;

  setUp(() {
    siteDir = Directory.systemTemp.createTempSync('trellis_build_sass_errors_');
  });

  tearDown(() => siteDir.deleteSync(recursive: true));

  /// A themed site whose theme entry is [mainScss] and which carries the extra
  /// SASS [partials] (file name to source) next to it.
  void themedSite(String mainScss, {Map<String, String> partials = const {}}) {
    File(p.join(siteDir.path, 'trellis_site.yaml')).writeAsStringSync('''
title: Test Site
baseUrl: https://example.com
theme: legacy-theme
''');
    Directory(p.join(siteDir.path, 'content')).createSync();
    File(p.join(siteDir.path, 'content', '_index.md')).writeAsStringSync('---\ntitle: Home\n---\nHello.\n');

    final themeDir = Directory(p.join(siteDir.path, 'themes', 'legacy-theme'))..createSync(recursive: true);
    File(p.join(themeDir.path, 'theme.yaml')).writeAsStringSync('''
name: legacy-theme
version: 1.0.0
params:
  primary_color:
    type: color
    default: "#ff0000"
    description: Primary color
''');
    Directory(p.join(themeDir.path, 'layouts')).createSync();
    File(p.join(themeDir.path, 'layouts', 'home.html')).writeAsStringSync(r'''
<!DOCTYPE html>
<html><head><title tl:text="${page.title}">T</title></head><body><h1 tl:text="${page.title}">T</h1></body></html>
''');
    final sassDir = Directory(p.join(themeDir.path, 'sass'))..createSync();
    File(p.join(sassDir.path, 'main.scss')).writeAsStringSync(mainScss);
    for (final entry in partials.entries) {
      File(p.join(sassDir.path, entry.key)).writeAsStringSync(entry.value);
    }
  }

  group('theme SASS failures', () {
    test('an @import theme names the theme, the file and line, and the remedy first', () async {
      themedSite(
        "@forward 'variables';\n@use 'variables' as *;\n\n@import 'legacy';\n",
        partials: {
          '_variables.scss':
              r'$trellis-primary-color: #ff0000 !default;'
              '\n',
          '_legacy.scss': '.legacy { color: red; }\n',
        },
      );

      final result = await _build(siteDir);

      expect(result.exitCode, 1);
      final lines = result.stderrText.trim().split('\n');
      final headline = lines.take(6).join('\n');
      expect(headline, contains('legacy-theme'));
      expect(headline, contains(p.join('themes', 'legacy-theme', 'sass', 'main.scss')));
      expect(headline, contains('main.scss:4:'), reason: 'the @import rule is on line 4');
      // `--theme` selects a theme inside the tolo/trellis repo, so the re-add only fits a built-in theme.
      expect(headline, contains('if it is a built-in Trellis theme'));
      expect(
        headline,
        contains('trellis theme add https://github.com/tolo/trellis --theme legacy-theme --ref v$cliVersion'),
      );
      expect(headline, contains('otherwise migrate'));
      expect(headline, contains('@use'));
      expect(headline, contains('docs/themes/authoring'));
      expect(
        headline,
        isNot(contains('Remove this setting')),
        reason: "Sass's advice points at a knob the user does not have",
      );
      // The raw Sass text stays available beneath the Trellis lines.
      expect(result.stderrText, contains('import deprecation'));
    });

    test('any other SASS error prints path:line:column', () async {
      themedSite(
        "@forward 'variables';\n@use 'variables' as *;\n\n.a { color: \$no-such-variable; }\n",
        partials: {
          '_variables.scss':
              r'$trellis-primary-color: #ff0000 !default;'
              '\n',
        },
      );

      final result = await _build(siteDir);

      expect(result.exitCode, 1);
      expect(result.stderrText, contains('Undefined variable'));
      expect(
        result.stderrText,
        contains('${p.join('themes', 'legacy-theme', 'sass', 'main.scss')}:4:'),
        reason: 'the failing declaration is on line 4 of the theme entry',
      );
      expect(result.stderrText, isNot(contains('legacy-theme" uses @import')));
    });

    test('a site stylesheet error also prints its location', () async {
      File(p.join(siteDir.path, 'trellis_site.yaml')).writeAsStringSync('title: T\nbaseUrl: https://example.com\n');
      Directory(p.join(siteDir.path, 'content')).createSync();
      File(p.join(siteDir.path, 'content', '_index.md')).writeAsStringSync('---\ntitle: Home\n---\nHi.\n');
      Directory(p.join(siteDir.path, 'layouts')).createSync();
      File(p.join(siteDir.path, 'layouts', 'home.html')).writeAsStringSync('<html><body>x</body></html>\n');
      Directory(p.join(siteDir.path, 'static', 'css')).createSync(recursive: true);
      File(p.join(siteDir.path, 'static', 'css', 'site.scss')).writeAsStringSync('a {\n  color: \$missing;\n}\n');

      final result = await _build(siteDir);

      expect(result.exitCode, 1);
      expect(result.stderrText, contains('${p.join('static', 'css', 'site.scss')}:2:'));
    });
  });
}
