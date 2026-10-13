import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/src/generator/theme_example_link.dart';
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

/// Runs [body], returning what it wrote to stdout and stderr.
Future<({String out, String err})> _captured(Future<void> Function() body) async {
  final out = StringBuffer();
  final err = StringBuffer();
  await IOOverrides.runZoned(body, stdout: () => _BufferStdout(out), stderr: () => _BufferStdout(err));
  return (out: out.toString(), err: err.toString());
}

/// Proves the flow the generated README and the authoring guide tell a theme
/// author to run: scaffold a theme, `cd example`, `trellis build`.
void main() {
  late Directory workDir;

  setUp(() {
    workDir = Directory.systemTemp.createTempSync('trellis_theme_first_build_');
  });

  tearDown(() => workDir.deleteSync(recursive: true));

  group('theme scaffold first build', () {
    late String themeRoot;
    late String exampleDir;

    setUp(() async {
      expect(await TrellisCli(workingDirectory: workDir.path).run(['create', 'my_theme', '--template', 'theme']), 0);
      themeRoot = p.join(workDir.path, 'my_theme');
      exampleDir = p.join(themeRoot, 'example');
    });

    test('builds the theme: compiles its SASS to css/main.css and renders its layouts', () async {
      late int exitCode;
      final output = await _captured(() async {
        exitCode = await TrellisCli(workingDirectory: exampleDir).run(['build']);
      });

      expect(exitCode, 0, reason: output.err);
      final css = File(p.join(exampleDir, 'output', 'css', 'main.css'));
      expect(css.existsSync(), isTrue, reason: 'the first build must compile the theme, not just the static dir');
      expect(css.readAsStringSync(), contains('--trellis-primary'));

      final home = File(p.join(exampleDir, 'output', 'index.html')).readAsStringSync();
      expect(home, contains('css/main.css'), reason: "the theme's base layout links its stylesheet");
    });

    test('leaves no example layout to shadow the theme', () {
      expect(Directory(p.join(exampleDir, 'layouts')).existsSync(), isFalse);
    });

    test('points the example at the theme through a relative link', () {
      final link = Link(p.join(exampleDir, 'themes', 'my_theme'));
      expect(link.existsSync(), isTrue);
      expect(link.targetSync(), p.join('..', '..'));
      expect(File(p.join(exampleDir, 'trellis_site.yaml')).readAsStringSync(), contains('theme: my_theme'));
    });

    test('README documents the manual Windows link with literal backslashes', () {
      expect(File(p.join(themeRoot, 'README.md')).readAsStringSync(), contains(r'mklink /J example\themes\my_theme .'));
    });

    test('does not suggest the self-copying theme add', () {
      expect(File(p.join(exampleDir, 'trellis_site.yaml')).readAsStringSync(), isNot(contains('theme add')));
    });
  });

  group('linkThemeIntoExample', () {
    test('reports how to link by hand when the link cannot be created', () {
      final project = Directory(p.join(workDir.path, 'proj'))..createSync();
      // A file where the `themes` directory must go makes the link impossible
      // on every platform, standing in for Windows without symlink rights.
      Directory(p.join(project.path, 'example')).createSync();
      File(p.join(project.path, 'example', 'themes')).writeAsStringSync('');

      final warning = linkThemeIntoExample(project.path, 'proj');

      expect(warning, isNotNull);
      expect(warning, contains(p.join('example', 'themes', 'proj')));
      expect(warning, contains('theme: proj'));
    });
  });

  group('theme add from a source that contains the site', () {
    late String themeRoot;
    late String exampleDir;

    setUp(() async {
      // Written without the example link, as a hand-made or older scaffold has it.
      themeRoot = p.join(workDir.path, 'my_theme');
      await ThemeProjectGenerator(projectName: 'my_theme', writer: DiskFileWriter(themeRoot)).generate();
      exampleDir = p.join(themeRoot, 'example');
    });

    test('refuses the theme root as the source and writes nothing', () async {
      final configBefore = File(p.join(exampleDir, 'trellis_site.yaml')).readAsStringSync();
      late int exitCode;
      final output = await _captured(() async {
        exitCode = await TrellisCli(workingDirectory: exampleDir).run(['theme', 'add', themeRoot]);
      });

      expect(exitCode, 1);
      expect(output.err, contains('contains'));
      expect(Directory(p.join(exampleDir, 'themes')).existsSync(), isFalse, reason: 'nothing may be written');
      expect(File(p.join(exampleDir, 'trellis_site.yaml')).readAsStringSync(), configBefore);
    });

    test('refuses the site directory itself as the source', () async {
      File(p.join(workDir.path, 'theme.yaml')).writeAsStringSync('name: top\nversion: 1.0.0\n');
      File(p.join(workDir.path, 'trellis_site.yaml')).writeAsStringSync('title: T\nbaseUrl: https://example.com\n');

      late int exitCode;
      final output = await _captured(() async {
        exitCode = await TrellisCli(workingDirectory: workDir.path).run(['theme', 'add', workDir.path]);
      });

      expect(exitCode, 1);
      expect(output.err, contains('contains'));
      expect(Directory(p.join(workDir.path, 'themes')).existsSync(), isFalse);
    });
  });
}
